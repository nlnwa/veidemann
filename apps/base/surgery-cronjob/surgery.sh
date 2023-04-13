#!/usr/bin/env bash

set -e

function usage() {
  echo "$0 <JOB_EXECUTION_ID> \"[STATE1 STATE2 ...]\" \"[FILTER1 FILTER2 ...]\""
}

JOB_EXECUTION_ID=${1}
[ -z "${JOB_EXECUTION_ID}" ] && {
  usage
  exit 1
}
STATES=${2}
FILTERS=${3}

# execute redis command via kubectl in redis master pod
REDIS_MASTER_CLI='kubectl exec -n veidemann svc/redis-veidemann-frontier-master -c redis -- redis-cli'

# create bash array to hold crawl host group id's
CHGIDS=()

echo "--- Pinging redis ---"
${REDIS_MASTER_CLI} ping

echo "--- Resolving job ---"
JOB_ID=$(veidemannctl report jobexecution -o template -t '{{ .JobId }}' ${JOB_EXECUTION_ID})
veidemannctl get crawlJob ${JOB_ID} -o template -t '{{ .Meta.Name }}{{ nl }}'

function crawlexecutions() {
  local limit=1000

  local command=(veidemannctl report crawlexecution -s=${limit})
  command+=(-o template -t "{{ .Id }} {{ .SeedId }} {{ .LastChangeTime | time }}{{ nl }}")

  local job_execution_id=${1}
  [ -z "$job_execution_id" ] && return 1
  command+=(-q jobExecutionId="${job_execution_id}" -q jobId=${JOB_ID})

  local states=(${2})
  for ((i = 0; i < ${#states[@]}; i++)); do
    command+=(--state="${states[i]}")
  done

  local filters=(${3})
  for ((i = 0; i < ${#filters[@]}; i++)); do
    command+=(-q "${filter[i]}")
  done

  "${command[@]}" |
    tr -s ' ' |     # translate any whitespace to single space
    cut -d" " -f1,2 # output 1. and 2. field (ceid and seedid)
}

echo "--- Querying crawl executions ---"
# Query for crawlexecutions - assign to variable to catch errors
CEIDS=$(crawlexecutions "${JOB_EXECUTION_ID}" "${STATES}" "${FILTERS}")

function crawlhostgroup() {
  local ceid=${1}
  ${REDIS_MASTER_CLI} keys UEID:*:${ceid} | cut -d":" -f2
}

function find_crawl_host_groups() {
  while read -ra ids; do
    local ceid=${ids[0]}
    local seedid=${ids[1]}

    # find crawl host group(s) - assign to variable to catch errors from function
    local chgids=($(crawlhostgroup ${ceid}))

    # print info
    veidemannctl get seed -o template -t '{{ .Meta.Name | printf "%-50s" }} SEEDID: {{ .Id }}' "${seedid}"
    [ -z "${ceid}" ] || echo -e "\tCEID: ${ceid}\tCHGID: ${chgids[*]}"

    # check if we got multiple crawl host groups, skip if more than one (to be on the safe side)
    #	(( ${#chgids[@]} > 1 )) && { echo "Found crawl execution with multiple crawl host groups, skipping..."; continue; }

    # add chg id to array of chg id's
    CHGIDS+=("${chgids}")
  done <<<${CEIDS}
}

find_crawl_host_groups

# Make array a set - to get unique list of crawl host groups
IFS=" " read -ra CHGIDS <<<"$(echo "${CHGIDS[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' ')" | echo

# Create regular expression: "chgid1|chgId2|..." - for use in filter function
regexp=$(printf "|%s" "${CHGIDS[@]}")
regexp=${regexp:1}

# list of chgids in the loop (busy, wait, ready or timeout queue)
IN_THE_LOOP=()

function filter() {
  local queue=${1}
  shift
  local redis_command="$@"

  while read -r perpetrator; do
    [ -z "$perpetrator" ] && continue
    # commented because it does not seem to work
    # CHGIDS=( "${CHGIDS[@]/$perpetrator}" )
    IN_THE_LOOP+=($perpetrator)
    echo "Found $perpetrator in the $queue queue"
  done <<<$(${REDIS_MASTER_CLI} ${redis_command} | grep -oE "${regexp}")
}

echo "--- Looking for crawl host groups in the loop ---"

# run filter twice (because we are on thin ice)
for ((i = 0; i < 2; i++)); do
  filter busy 'zrangebyscore chg_busy{chg} -inf +inf'
  filter wait 'zrangebyscore chg_wait{chg} -inf +inf'
  filter ready 'lrange chg_ready{chg} 0 1000000'
  filter timeout 'lrange chg_timeout{chg} 0 100000'
done

function amend() {
  local chgid=${1}
  echo Amending "${chgid}"
  ${REDIS_MASTER_CLI} hdel "CHG{chg}:${chgid}" ts ma df mi rd st u mr
  ${REDIS_MASTER_CLI} lpush "chg_ready{chg}" ${chgid}
}

echo "--- Amending crawl host groups out of the loop ---"

# Create string of all crawl host groups in the loop separated by spaces
PERPETRATORS=" ${IN_THE_LOOP[*]} "

# Back in the loop
for chgid in "${CHGIDS[@]}"; do
  # don't amend crawl host groups in the loop
  if [[ "${PERPETRATORS}" == *"${chgid}"* ]]; then continue; fi

  amend "${chgid}"
done
