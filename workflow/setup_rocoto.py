#!/usr/bin/env python
# Aloha!
print('Aloha!')
#
import os, sys, shutil, glob
from rocoto_funcs.base import source, get_yes_or_no
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
user_id=os.getlogin()
# create comroot (no matter exists or not)
comroot=os.getenv('COMROOT',f'/tmp/${user_id}/com')
dataroot=os.getenv('DATAROOT',f'/tmp/${user_id}/stmp')
os.makedirs(comroot,exist_ok=True)
os.makedirs(dataroot,exist_ok=True)

# set the expdir variable
basedir=os.getenv('EXP_BASEDIR',f'/tmp/{user_id}')
version=os.getenv('VERSION','community')
exp_name=os.getenv('EXP_NAME','')
expdir=f'{basedir}/{version}'
if exp_name !="":
  expdir=f'{expdir}/{exp_name}'

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
text=f'''#=== Auto-generation of HOMErrfs, MACHINE, EXPDIR
export HOMErrfs={HOMErrfs}
export MACHINE={machine}
export EXPDIR={expdir}
#===
'''
#
EXPout=f'{expdir}/exp.setup'
with open(EXPin, 'r') as infile, open(EXPout, 'w') as outfile:
  # add HOMErrfs, MACHINE, EXPDIR to the beginning of the exp.setup file under expdir/
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
      rm_list=('EXP_BASEDIR=','EXP_NAME=','REALTIME=','REALTIME_DAYS=','RETRO_PERIOD=','RETRO_CYCLETHROTTLE=',
        'RETRO_TASKTHROTTLE=','ACCOUNT','QUEUE','PARTITION','RESERVATION','STARTTIME','NODES','WALLTIME',
        'FCST_ONLY=','DO_DETERMINISTIC','DO_ENSEMBLE',
          )
      found=False
      for rmstr in rm_list:
        if rmstr in line:
          found=True; break
      if not found:
        outfile.write(line)

setup_xml(HOMErrfs, expdir) 
#
# end of setup_exp.py
