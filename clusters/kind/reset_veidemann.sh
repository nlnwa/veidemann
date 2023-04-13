#!/usr/bin/env bash

# Delete warc and backup files, delete rethinkdb tables
kubectl --context=kind-kind -n veidemann delete job veidemann-reset
kubectl --context=kind-kind -n veidemann apply -k "$(dirname $0)/../../base/veidemann-reset"

# Delete redis data
kubectl --context=kind-kind exec -t -n veidemann svc/redis-veidemann-frontier-master -c redis -- redis-cli flushall sync

# Delete pagelog/crawlog
kubectl --context=kind-kind exec -it -n veidemann svc/scylla-client -- cqlsh localhost -e "TRUNCATE TABLE v7n_v2_dc1.crawl_log;"
kubectl --context=kind-kind exec -it -n veidemann svc/scylla-client -- cqlsh localhost -e "TRUNCATE TABLE v7n_v2_dc1.page_log;"
