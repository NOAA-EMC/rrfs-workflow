#!/usr/bin/env python
#
import os, sys, stat
from rocoto_funcs.base import header_begin, header_entities, header_end, source, \
  wflow_begin, wflow_log, wflow_cycledefs, wflow_end
from rocoto_funcs.smart_cycledefs import smart_cycledefs
from rocoto_funcs.ungrib_ic import ungrib_ic
from rocoto_funcs.ungrib_lbc import ungrib_lbc
from rocoto_funcs.ic import ic
from rocoto_funcs.lbc import lbc
from rocoto_funcs.prep_ic import prep_ic
from rocoto_funcs.prep_lbc import prep_lbc
from rocoto_funcs.jedivar import jedivar
from rocoto_funcs.fcst import fcst
from rocoto_funcs.save_fcst import save_fcst
from rocoto_funcs.getkf_observer import getkf_observer
from rocoto_funcs.getkf_solver import getkf_solver
from rocoto_funcs.mpassit import mpassit
from rocoto_funcs.upp import upp
from rocoto_funcs.ioda_bufr import ioda_bufr
from rocoto_funcs.clean import clean
from rocoto_funcs.graphics import graphics

### setup_xml
def setup_xml(HOMErrfs, expdir):
  # source the config cascade
  source(f'{expdir}/exp.setup')
  machine=os.getenv('MACHINE').lower()
  do_deterministic=os.getenv('DO_DETERMINISTIC','true').upper()
  do_ensemble=os.getenv('DO_ENSEMBLE','false').upper()
  if do_ensemble == "TRUE":
    source(f"{expdir}/config/config.ens")
  #
  source(f"{expdir}/config/config.{machine}")
  source(f"{expdir}/config/config.base")
  #
  source(f"{HOMErrfs}/workflow/config_resources/config.{machine}")
  source(f"{HOMErrfs}/workflow/config_resources/config.base")
  realtime=os.getenv('REALTIME','false')
  if realtime.upper() == "TRUE":
    source(f"{HOMErrfs}/workflow/config_resources/config.realtime")
  #
  # create cycledefs smartly
  dcCycledef=smart_cycledefs()
  
  COMROOT=os.getenv('COMROOT','COMROOT_not_defined')
  TAG=os.getenv('TAG','TAG_not_defined')
  NET=os.getenv('NET','NET_not_defined')
  VERSION=os.getenv('VERSION','VERSION_not_defined')

  fPath=f"{expdir}/rrfs.xml"
  with open(fPath, 'w') as xmlFile:
    header_begin(xmlFile)
    header_entities(xmlFile,expdir)
    header_end(xmlFile)
    wflow_begin(xmlFile)
    log_fpath=f'&LOGROOT;/rrfs&WGF;.@Y@m@d/@H/rrfs&WGF;_{TAG}.log'
    wflow_log(xmlFile,log_fpath)
    wflow_cycledefs(xmlFile,dcCycledef)
    
# ---------------------------------------------------------------------------
# assemble tasks for a deterministic experiment
    if do_deterministic == "TRUE":
      if os.getenv("DO_IODA","FALSE").upper()=="TRUE":
        ioda_bufr(xmlFile,expdir)
      #
      ungrib_ic(xmlFile,expdir)
      ungrib_lbc(xmlFile,expdir)
      ic(xmlFile,expdir)
      lbc(xmlFile,expdir)
      if os.getenv("DO_SPINUP","FALSE").upper() == "TRUE":
        prep_lbc(xmlFile,expdir)
        # spin up line
        prep_ic(xmlFile,expdir,spinup_mode=1)
        jedivar(xmlFile,expdir,do_spinup=True)
        fcst(xmlFile,expdir,do_spinup=True)
        # prod line
        prep_ic(xmlFile,expdir,spinup_mode = -1)
        jedivar(xmlFile,expdir)
        fcst(xmlFile,expdir)
        save_fcst(xmlFile,expdir)
      else:
        prep_ic(xmlFile,expdir)
        prep_lbc(xmlFile,expdir)
        if os.getenv("DO_JEDI","FALSE").upper()=="TRUE":
          jedivar(xmlFile,expdir)
        fcst(xmlFile,expdir)
        save_fcst(xmlFile,expdir)
      #
      mpassit(xmlFile,expdir)
      upp(xmlFile,expdir)
      #
      #if machine == "jet": #currently only support graphics on jet
      #  graphics(xmlFile,expdir)
      #
# ---------------------------------------------------------------------------
# assemble tasks for an ensemble experiment
    if do_ensemble == "TRUE":
      if os.getenv("DO_IODA","FALSE").upper()=="TRUE":
        ioda_bufr(xmlFile,expdir)
      ungrib_ic(xmlFile,expdir,do_ensemble=True)
      ungrib_lbc(xmlFile,expdir,do_ensemble=True)
      ic(xmlFile,expdir,do_ensemble=True)
      lbc(xmlFile,expdir,do_ensemble=True)
      prep_ic(xmlFile,expdir,do_ensemble=True)
      prep_lbc(xmlFile,expdir,do_ensemble=True)
      if os.getenv("DO_JEDI","FALSE").upper()=="TRUE":
        getkf_observer(xmlFile,expdir)
        getkf_solver(xmlFile,expdir)
      fcst(xmlFile,expdir,do_ensemble=True)
      save_fcst(xmlFile,expdir,do_ensemble=True)
      mpassit(xmlFile,expdir,do_ensemble=True)
      upp(xmlFile,expdir,do_ensemble=True)

# ---------------------------------------------------------------------------
#    if realtime.upper() == "TRUE": # write out the clean task for realtime runs and retros don't need it
#      clean(xmlFile,expdir)
    #
    wflow_end(xmlFile)
# ---------------------------------------------------------------------------

  fPath=f"{expdir}/run_rocoto.sh"
  with open(fPath,'w') as rocotoFile:
    text= \
f'''#!/usr/bin/env bash
source /etc/profile
module load rocoto
cd {expdir}
rocotorun -w rrfs.xml -d rrfs.db
'''
    rocotoFile.write(text)

  # set run_rocoto.sh to be executable
  st = os.stat(fPath)
  os.chmod(fPath, st.st_mode | stat.S_IEXEC)

  print(f'rrfs.xml and run_rocoto.sh created at:\n  {expdir}')
### end of setup_xml
