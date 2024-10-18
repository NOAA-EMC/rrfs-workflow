#!/usr/bin/env python
# Aloha!
print('Aloha!')
#
import os, sys, shutil, glob
from rocoto_funcs.base import source, get_yes_or_no, get_required_env
from rocoto_funcs.smart_cycledefs import smart_cycledefs
from rocoto_funcs.setup_xml import setup_xml

if len(sys.argv) == 2:
  EXPin = sys.argv[1]
else:
  EXPin = "exp.setup"

# find the HOMErrfs directory
HOMErrfs=os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
os.system(f'{HOMErrfs}/workflow/ush/init.sh')
#
if os.path.exists(EXPin):
  source(EXPin)
else:
  print(f'{EXPin}: no such file')
  exit()

# create comroot (no matter exists or not)
comroot=get_required_env('COMROOT')
dataroot=get_required_env('DATAROOT')
os.makedirs(comroot,exist_ok=True)
os.makedirs(dataroot,exist_ok=True)

# set the expdir variable
expdir=get_required_env('EXPDIR')
version=os.getenv('VERSION','0.0.0')
exp_name=os.getenv('EXP_NAME','exp1')

# if expdir exists, find an available dir name to backup old files first
# and then upgrade expdir
if os.path.exists(expdir):
  knt=1
  savedir=f'{expdir}_old{knt:04}'
  while os.path.exists(savedir):
    knt += 1
    savedir=f'{expdir}_old{knt:04}'
  shutil.copytree(expdir, savedir, copy_function=shutil.copy2)
else:
  os.makedirs(expdir)

# copy the config file, excluding the resources subdirectory
configdir=f'{HOMErrfs}/parm/config'
exp_configdir=f'{expdir}/config'
if os.path.exists(exp_configdir):
  if os.path.isfile(exp_configdir):
    os.remove(exp_configdir)
  else:
    shutil.rmtree(exp_configdir)
os.makedirs(exp_configdir,exist_ok=True)
for cfile in glob.glob(f'{configdir}/config.*'):
  shutil.copy(cfile,exp_configdir)

# generate exp.setup under $expdir
source(f'{HOMErrfs}/workflow/ush/detect_machine.sh')
machine=os.getenv('MACHINE')
if machine=='UNKNOWN':
    print(f'WARNING: machine is UNKNOWN! ')
text=f'''#=== Auto-generation of HOMErrfs, MACHINE
export HOMErrfs={HOMErrfs}
export MACHINE={machine}
#===
'''
#
EXPout=f'{expdir}/exp.setup'
with open(EXPin, 'r') as infile, open(EXPout, 'w') as outfile:
  # add HOMErrfs, MACHINE to the beginning of the exp.setup file under expdir/
  header=""
  still_header=True
  for line in infile:
    if still_header:
      if line.strip().startswith('#'):
        header=header+line
      else:
        still_header=False
        outfile.write(header)
        outfile.write(text)
        outfile.write(line)
    else:
      rm_list=('REALTIME=','REALTIME_DAYS=','RETRO_PERIOD=','RETRO_CYCLETHROTTLE=',
        'RETRO_TASKTHROTTLE=','ACCOUNT','QUEUE','PARTITION','RESERVATION','STARTTIME','NODES','WALLTIME',
        'FCST_ONLY=','FCST_ONLY_FREQ','DO_DETERMINISTIC','DO_ENSEMBLE',
          )
      found=False
      for rmstr in rm_list:
        if rmstr in line:
          found=True; break
      if not found:
        outfile.write(line)
  #
  # preempt the PROD_BGN_AT_HRS array if FCST_ONLY
  if os.getenv('FCST_ONLY','FALSE').upper() == "TRUE":
    freq=int(os.getenv('FCST_ONLY_FREQ',6))
    PROD_BGN_AT_HRS=' '.join([f'{hour:02}' for hour in range(0, 24, freq)])
    outfile.write(f'PROD_BGN_AT_HRS="{PROD_BGN_AT_HRS}"')

setup_xml(HOMErrfs, expdir) 
#
# end of setup_exp.py
