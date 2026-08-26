#!/usr/bin/env python
import os
import sys
import shutil


def modify(file, changesets):
    shutil.copy(file, ".tmpfile")  # this can preserve the file permission
    with open(file, 'r') as infile, open(".tmpfile", 'w') as outfile:
        for line in infile:
            for key, value in changesets.items():
                if key in line:
                    line = line.replace(key, value)
            outfile.write(line)
    os.replace(".tmpfile", file)


# ------------------------------------------------------------------------------
args = sys.argv
nargs = len(args) - 1
if nargs < 1:
    print(f"{args[0]} <exp_file>")
    exit()
#
exp_file = args[1]
changesets = {
    'export DO_CHEMISTRY=false': 'export DO_CHEMISTRY=true\nexport CYCLETHROTTLE=1',
    'export DO_IODA=true': 'export DO_IODA=false',
    'export DO_JEDI=true': 'export DO_JEDI=false',
    'export DO_CYC=true': 'export DO_CYC=false',
    'export DO_SPINUP=true': 'export DO_SPINUP=false',

    'for i in {0..23..12}; do arr[$i]="12"; done # 12hr fcst every 12hrs': 'for i in {0..23}; do arr[i]="24"; done # 24hr fcst, only take effect at coldstart cycles',
    'export LBC_CYCS="00 12"': 'export LBC_CYCS="00"',
    'export COLDSTART_CYCS="00 12"': 'export COLDSTART_CYCS="00"',
    'export COLDSTART_CYCS="03 15"': 'export COLDSTART_CYCS="00"',
    'export LBC_LENGTH=18': 'export LBC_LENGTH=24',
}
modify(exp_file, changesets)

print(f'''Done, {exp_file} modified to run coldstart-only experiments:
DA turned off,
FCST_LEN_HRS_CYCLES, LBC_CYCS, COLDSTART_CYCS, LBC_LENGTH changed
      to cold start once per day at 00z and make 24h forecasts,
      edit further when needed.
''')
