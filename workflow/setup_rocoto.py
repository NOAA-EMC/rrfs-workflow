#!/usr/bin/env python
# Aloha!
import shutil
import sys
import os
from rocoto_funcs.setup_xml import setup_xml
from rocoto_funcs.base import source, get_required_env, run_git_command
print('Aloha!')
#

if len(sys.argv) == 2:
    EXPin = sys.argv[1]
else:
    EXPin = "exp.setup"

# find the HOMErrfs directory and the MACHINE; run init.sh
HOMErrfs = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
os.environ["HOMErrfs"] = HOMErrfs
os.system(f'{HOMErrfs}/workflow/tools/init.sh')
source(f'{HOMErrfs}/workflow/tools/detect_machine.sh')
machine = os.getenv('MACHINE')
if machine == 'UNKNOWN':
    print(f'WARNING: machine is UNKNOWN! ')
#
if os.path.exists(EXPin):
    source(EXPin)
else:
    print(f'{EXPin}: no such file')
    exit()

# source the config cascase
source(f"{HOMErrfs}/workflow/config_resources/config.machines")
source(f"{HOMErrfs}/workflow/config_resources/config.meshdep")
source(f"{HOMErrfs}/workflow/config_resources/config.base")
if os.getenv('REALTIME', 'false').upper() == "TRUE":
    source(f"{HOMErrfs}/workflow/config_resources/config.realtime")

if os.getenv("DO_CHEMISTRY", "FALSE").upper() == "TRUE" and os.path.exists(f"{HOMErrfs}/workflow/config.chemistry"):
    source(f"{HOMErrfs}/workflow/config.chemistry")
    print("NOTE: config.chemistry found and some exp settings overwritten by it.\n")

if os.path.exists(f"{HOMErrfs}/workflow/config.override"):
    source(f"{HOMErrfs}/workflow/config.override")
    print("NOTE: config.override found and some exp settings overwritten by it.\n")

# Check compatibility of setup with nonvar cloud analysis
if os.getenv("DO_NONVAR_CLOUD_ANA", "FALSE").upper() == "TRUE":
    mesh = os.getenv("MESH_NAME", "conus3km")
    if mesh not in ["conus3km", "south3.5km", "conus12km"]:
        print(f'{mesh} is not compatible with the nonvar cloud analysis')
        print('Please set DO_NONVAR_CLOUD_ANA=false and try again')
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
exp_configdir = f'{expdir}/config'
os.makedirs(exp_configdir, exist_ok=True)

# copy the zeta_levels file if defined
zeta_levels = os.getenv('ZETA_LEVELS', '')
if zeta_levels != '':
    shutil.copy(f'{HOMErrfs}/fix/vert_levels/{zeta_levels}', f'{exp_configdir}/ZETA_LEVELS.txt')
if os.getenv("DO_CHEMISTRY", "FALSE").upper() == "TRUE" and os.path.exists(f"{HOMErrfs}/workflow/config.chemistry"):
    shutil.copy(f'{HOMErrfs}/workflow/config.chemistry', f'{expdir}/config.chemistry')  # save a copy for reference
if os.path.exists(f"{HOMErrfs}/workflow/config.override"):
    shutil.copy(f'{HOMErrfs}/workflow/config.override', f'{expdir}/config.override')  # save a copy for reference

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
    if os.getenv('DO_ENSEMBLE', 'FALSE').upper() == "TRUE":
        shutil.copy(f'{HOMErrfs}/parm/getkf.yaml', f'{exp_configdir}/getkf.yaml')
    else:
        shutil.copy(f'{HOMErrfs}/parm/jedivar.yaml', f'{exp_configdir}/jedivar.yaml')
        shutil.copy(f'{HOMErrfs}/parm/bec_bump.yaml', f'{exp_configdir}/bec_bump.yaml')
#
if os.getenv('DO_HOFX', 'FALSE').upper() == "TRUE":
    shutil.copy(f'{HOMErrfs}/parm/hofx.yaml', f'{exp_configdir}/hofx.yaml')

# copyover the VERSION file
shutil.copy(f'{HOMErrfs}/workflow/VERSION', f'{expdir}/VERSION')

# generate exp.setup, snapshot_git_diff.txt under $expdir
latest_log = run_git_command(['git', 'log', '--oneline', '--no-decorate', '-1'])
branch = run_git_command(['git', 'rev-parse', '--abbrev-ref', 'HEAD'])
try:
    remote = run_git_command(['git', 'config', f'branch.{branch}.remote'])
    remote_url = run_git_command(['git', 'remote', 'get-url', remote])
except Exception:
    remote_url = "this_is_local_branch"
diff_results = run_git_command(['git', 'diff'])
diff_results += run_git_command(['git', 'diff', '--cached'])
with open(f'{expdir}/config/snapshot_git_diff.txt', 'w') as outfile:
    outfile.write(diff_results)
text = f'''#=== Auto-generation of HOMErrfs, MACHINE, etc
# {remote_url} -b {branch};  the latest log:
#  {latest_log}
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
            outfile.write(line)
    # ~~~~~~~~~~~~

setup_xml(HOMErrfs, expdir)

if os.getenv('YAML_GEN_METHOD', '1') == '1':
    # copy qrocoto utilities to expdir/qrocoto
    srcdir = f'{HOMErrfs}/workflow/tools/qrocoto'
    dstdir = f'{expdir}/qrocoto'
    shutil.copytree(srcdir, dstdir, dirs_exist_ok=True)
    if os.getenv("DO_JEDI", 'false').upper() == "TRUE" and os.path.exists('satinfo'):
        print(f'''\nRun the following commands to prepare the initial satbias files:
  cd  {expdir}
  source qrocoto/load_qrocoto.sh
  prep_satbias.sh YYYYMMDDHH [satbias_path]
check https://github.com/NOAA-EMC/rrfs-workflow/wiki for more details''')

elif os.getenv('YAML_GEN_METHOD', '1') == '2':
    print("If doing radiance DA, run `prep_satbias.sh` to prepare the initial stabias files")
    # Copy files from HOMErrfs/workflow/tools to expdir
    shutil.copy2(f'{HOMErrfs}/workflow/tools/qrocoto/prep_satbias.sh', expdir)
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
