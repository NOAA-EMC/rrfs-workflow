#!/usr/bin/env python
# Aloha!
import glob
import shutil
import sys
import os
from rocoto_funcs.setup_xml import setup_xml
from rocoto_funcs.base import source, get_required_env
print('Aloha!')
#

if len(sys.argv) == 2:
    EXPin = sys.argv[1]
else:
    EXPin = "exp.setup"

# find the HOMErrfs directory and the MACHINE; run init.sh
HOMErrfs = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
os.system(f'{HOMErrfs}/workflow/ush/init.sh')
source(f'{HOMErrfs}/workflow/ush/detect_machine.sh')
machine = os.getenv('MACHINE')
if machine == 'UNKNOWN':
    print(f'WARNING: machine is UNKNOWN! ')
#
if os.path.exists(EXPin):
    source(EXPin)
else:
    print(f'{EXPin}: no such file')
    exit()

# create comroot (no matter exists or not)
comroot = get_required_env('COMROOT')
dataroot = get_required_env('DATAROOT')
os.makedirs(comroot, exist_ok=True)
os.makedirs(dataroot, exist_ok=True)

# set the expdir variable
expdir = get_required_env('EXPDIR')
version = os.getenv('VERSION', '0.0.0')
exp_name = os.getenv('EXP_NAME', 'exp1')

# if expdir exists, find an available dir name to backup old files first
# and then upgrade expdir
if os.path.exists(expdir):
    knt = 1
    savedir = f'{expdir}_old{knt:04}'
    while os.path.exists(savedir):
        knt += 1
        savedir = f'{expdir}_old{knt:04}'
    shutil.copytree(expdir, savedir, copy_function=shutil.copy2)
else:
    os.makedirs(expdir)

# copy the config file, excluding the resources subdirectory
configdir = f'{HOMErrfs}/parm/config'
exp_configdir = f'{expdir}/config'
if os.path.exists(exp_configdir):
    if os.path.isfile(exp_configdir):
        os.remove(exp_configdir)
    else:
        shutil.rmtree(exp_configdir)
os.makedirs(exp_configdir, exist_ok=True)
for cfile in glob.glob(f'{configdir}/config.*'):
    shutil.copy(cfile, exp_configdir)

# copy the zeta_levels file if defined
zeta_levels = os.getenv('ZETA_LEVELS', '')
if zeta_levels != '':
    shutil.copy(f'{HOMErrfs}/fix/meshes/{zeta_levels}', f'{exp_configdir}/ZETA_LEVELS.txt')

# if DO_JEDI, copy the super YAML, convinfo, [satinfo] files to EXPDIR
if os.getenv("DO_JEDI", 'false').upper() == "TRUE":
    if not os.path.exists('convinfo'):
        print('convinfo not found under current directoy, copy from ${FIXrrfs}/jedi\n')
        shutil.copy(f'{HOMErrfs}/fix/jedi/convinfo.rrfs', 'convinfo')
    # copy convinfo to exp_configdir
    shutil.copy('convinfo', f'{exp_configdir}/convinfo')
    # if satinfo is available, copy it to exp_configdir
    if os.path.exists('satinfo'):
        shutil.copy('satinfo', f'{exp_configdir}/satinfo')
    # copy jedivar.yaml or getkf yamls to exp_configdir
    if os.getenv('DO_ENSEMBLE','FALSE').upper() == True:
        shutil.copy('{HOMErrfs}/parm/getkf_observer.yaml', f'{exp_configdir}/getkf_observer.yaml')
        shutil.copy('{HOMErrfs}/parm/getkf_solver.yaml', f'{exp_configdir}/getkf_observer.yaml')
    else
        shutil.copy('{HOMErrfs}/parm/jedivar.yaml', f'{exp_configdir}/jedivar.yaml')

# copyover the VERSION file
shutil.copy(f'{HOMErrfs}/workflow/VERSION', f'{expdir}/VERSION')

# generate exp.setup under $expdir
text = f'''#=== Auto-generation of HOMErrfs, MACHINE
export HOMErrfs={HOMErrfs}
export MACHINE={machine}
#===
'''
#
EXPout = f'{expdir}/exp.setup'
with open(EXPin, 'r') as infile, open(EXPout, 'w') as outfile:
    # add HOMErrfs, MACHINE to the beginning of the exp.setup file under expdir/
    header = ""
    still_header = True
    for line in infile:
        if still_header:
            if line.strip().startswith('#'):
                header = header + line
            else:
                still_header = False
                outfile.write(header)
                outfile.write(text)
                outfile.write(line)
        else:
            rm_list = ('REALTIME=', 'RETRO_CYCLETHROTTLE=',
                       'RETRO_TASKTHROTTLE=', 'ACCOUNT', 'QUEUE', 'PARTITION', 'RESERVATION', 'STARTTIME', 'NODES', 'WALLTIME',
                       'CYC_INTERVAL', 'DO_DETERMINISTIC', 'DO_ENSEMBLE',
                       )
            found = False
            for rmstr in rm_list:
                if rmstr in line:
                    found = True
                    break
            if not found:
                outfile.write(line)
    #

setup_xml(HOMErrfs, expdir)

if os.getenv('YAML_GEN_METHOD', '1') == '1':
    srcdir = f'{HOMErrfs}/workflow/ush/qrocoto'
    dstdir = f'{expdir}/qrocoto'
    shutil.copytree(srcdir, dstdir, dirs_exist_ok=True)

elif os.getenv('YAML_GEN_METHOD', '1') == '2':
    # Copy files from HOMErrfs/workflow/ush to expdir
    source_dir = os.path.join(HOMErrfs, 'workflow', 'ush')
    target_files = ['rr', 'rc', 'rb', 'rs']
    if os.path.isdir(source_dir):
        for file_name in target_files:
            s = os.path.join(source_dir, file_name)
            if os.path.isfile(s):
                shutil.copy2(s, expdir)

    print(f'You can add to crontab:\n*/1 * * * * cd {expdir} && ./run_rocoto.sh && ./rs')
#
# end of setup_exp.py
