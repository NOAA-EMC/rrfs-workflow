#!/usr/bin/env python3

debug = 0

import os, sys
import ecflow

PRODCLONEPREFIX = os.getenv("PRODCLONEPREFIX")
assert PRODCLONEPREFIX, "$PRODCLONEPREFIX not defined!"

assert os.getenv("ECF_PORT")=="32035", "ECF_PORT is not 31419. Quitting!"
assert os.getenv("ECF_HOST") is not None, "ECF_HOST is not set. Quitting!"
assert len(sys.argv)==3, "%s takes two and only two arguments. Quitting!"%os.path.basename(sys.argv[0])

ci = ecflow.Client()
if debug == 1:
  print("ecf client host, port: %s, %s"%(ci.get_host(),ci.get_port()))

# Get prod checkpoint files"
prod = ecflow.Defs(sys.argv[1])
# Get para checkpoint file
para = ecflow.Defs(sys.argv[2])
prodtasks = prod.get_all_tasks()
paratasks = para.get_all_tasks()
parapaths_all = [t.get_abs_node_path() for t in paratasks]
parapaths = [p for p in parapaths_all if p.startswith(PRODCLONEPREFIX)]

if debug: print("Parapaths: %s"%", ".join(parapaths))

# Loop over prod tasks, see if it appears in prod_clone suite on para server, and update if needed
for prodtask in prodtasks:
  ## Check whether job exists:
  prodpath = prodtask.get_abs_node_path()
  #prodclonepath = (PRODCLONEPREFIX+prodpath).replace("//","/")
  #prodclonepath = (PRODCLONEPREFIX+prodpath).replace("/prod_clone/prod/","/prod_clone/")
  prodclonepath = prodpath.replace("/prod/","/prod_clone/")
  if prodclonepath not in parapaths:
    if debug == 2: print("Skipping %s"%prodclonepath)
    continue # We only want to update the statuses of jobs that are under the /prod_cloned suite on the para server
  ## Force status of job under para if the statuses don't match:
  paratask = para.find_abs_node(prodclonepath)
  if paratask.get_state() != prodtask.get_state():
    if debug: print("Updating status for %s"%prodclonepath)
    # The following lines are the only direct communication with any server in this job:
    ci.force_state(prodclonepath,prodtask.get_state()) # FORCE PROD_CLONE JOB STATE
  # FORCE PROD_CLONE JOB EVENTS:
  prodevents_dict = {}
  for prodevent in prodtask.events: prodevents_dict[prodevent.name()] = prodevent.value()
  for paraevent in paratask.events:
    paraeventname = paraevent.name()
    if paraeventname in prodevents_dict.keys():
      prodeventvalue = prodevents_dict[paraeventname]
      if prodeventvalue != paraevent.value():
        if prodeventvalue: ci.alter(prodclonepath,"change","event",paraeventname,"set")
        else: ci.alter(prodclonepath,"change","event",paraeventname,"clear")
