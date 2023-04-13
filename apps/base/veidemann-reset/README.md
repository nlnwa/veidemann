 # Reset veidemann

```bash
kubectl --context=<minikube|kind-kind> apply -k .
```

### Remove files

Tries to remove all files in (cannot remove open files):

```bash
/warcs
/validwarcs
/invalidwarcs
/backup/oos
``` 

### Empty database tables
`r.db("veidemann").table(name).delete()` is performed on the following database tables :

```bash
"crawl_host_group"
"crawl_log"
"crawled_content"
"events"
"executions"
"job_executions"
"page_log"
"storage_ref"
"uri_queue"
```
