---
basepath: "/home/work/sivabs"
request:
  listen:
    port: 8080
    cycle: '60'
    protocol: tcp
    mon_idc: local
    req_type: port
log:
  access_log:
    path: "/home/work/sivabs/log/sivabs.log"
    flow:
      regex: "^.*$"
      foumula: foumula > 100
      alert:
        rd: warning
        op: error
        qa: nil
  error_log:
    path: "/home/work/sivabs/log/sivabs.log.wf"
    fatal:
      regex: fatal
      foumula: foumula > 0
      alert:
        rd: error
        op: info
        qa: error
proc:
  main:
    path: "/home/work/sivabs/bin/sivabs"
name: sivabs
contacts:
  rd: nil
  op: g_ecomop_houyi_op
  qa: nil
exec:
- "/home/work/opbin/noah/sivabs.sh"
