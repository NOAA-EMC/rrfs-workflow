#!/usr/bin/env python
import os
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


# set the current directory to HOMErrfs
mypath = os.path.dirname(os.path.abspath(__file__))
os.chdir(os.path.join(mypath, "../.."))

# check whether a given modification has been made to avoid a second run of this script
already_modified = False
with open("parm/convection_permitting/namelist.atmosphere", 'r') as infile:
    for line in infile:
        if "config_do_restart = ${do_restart}" in line:
            already_modified = True
            break
if already_modified:
    print("It is expected to run 'mpasout_to_restart' in a clean git status")
    print("It looks like target files have been modified")
    print("Run 'git status` to check what files have been modified")
    print("Run 'git checkout <file>' to undo changes")
    exit()


# tweak 1  ----------------------------------------------------------
with open("parm/streams.atmosphere") as infile, open(".tmpfile", 'w') as outfile:
    skip = False
    for line in infile:
        if '<immutable_stream name="invariant"' in line:
            skip = True
        elif '<stream name="da_state"' in line:
            skip = True
        elif '<stream' in line or '<immutable_stream' in line:  # a new stream starts
            skip = False
        if not skip:
            outfile.write(line)
os.replace(".tmpfile", "parm/streams.atmosphere")


# tweak 2 ----------------------------------------------------------
myfile = "parm/convection_permitting/namelist.atmosphere"
changesets = {
    "config_do_restart = false": "config_do_restart = ${do_restart}",
}
modify(myfile, changesets)


# tweak 3 ----------------------------------------------------------
myfile = "scripts/exrrfs_fcst.sh"
changesets = {
    'mpasout': 'restart',
    "start_type='cold'": "start_type='cold'\n  do_restart='false'",
    "do_DAcycling='true'": "do_DAcycling='true'\n  do_restart='true'",
    #    'jedi_da="true" #true': 'jedi_da="false" #true',
}
modify(myfile, changesets)


# tweak 4 and 5 ----------------------------------------------------------
myfile = "scripts/exrrfs_mpassit.sh"
changesets = {
    "fhr_string=$( seq 0 $((10#${HISTORY_INTERVAL})) $((10#${fcst_len_hrs_thiscyc} )) | paste -sd ' ' )":
    "fhr_string=$( seq 1 $((10#${HISTORY_INTERVAL})) $((10#${fcst_len_hrs_thiscyc} )) | paste -sd ' ' )",
}
modify(myfile, changesets)
myfile = "scripts/exrrfs_upp.sh"
modify(myfile, changesets)


# tweak 6 ----------------------------------------------------------
myfile = "scripts/exrrfs_save_for_next.sh"
changesets = {
    "mpasout": "restart",
    "history_all=$(seq 0 $((10#${history_interval})) $((10#${fcst_len_hrs_thiscyc} )) )":
    "history_all=$(seq 1 $((10#${history_interval})) $((10#${fcst_len_hrs_thiscyc} )) )",

    "if (( ii <= cyc_interval )) && (( ii > 0 )); then": "if (( ii <= cyc_interval )) && (( ii >= 0 )); then",
}
modify(myfile, changesets)


# tweak 7 ----------------------------------------------------------
myfile = "workflow/rocoto_funcs/save_for_next.py"
changesets = {
    'diag.@Y-@m-@d_@H.@M.@S.nc':
    '</cyclestr><cyclestr offset="1:00:00">diag.@Y-@m-@d_@H.@M.@S.nc',
}
modify(myfile, changesets)

# tweak 8 ----------------------------------------------------------
myfile = "scripts/exrrfs_jedivar.sh"
changesets = {
    "mpasout": "restart",
    "start_type='cold'": "start_type='cold'\n  do_restart='false'",
    "do_DAcycling='true'": "do_DAcycling='true'\n  do_restart='true'",
}
modify(myfile, changesets)

# tweak 9 ----------------------------------------------------------
myfile = "scripts/exrrfs_getkf.sh"
changesets = {
    "mpasout": "restart",
    "start_type='cold'": "start_type='cold'\n  do_restart='false'",
    "do_DAcycling='true'": "do_DAcycling='true'\n  do_restart='true'",
}
modify(myfile, changesets)

# tweak 10, 11, 12, 13, 14, 15 -------------------------------------
myfile = "scripts/exrrfs_prep_ic.sh"
changesets = {
    "mpasout": "restart",
}
modify(myfile, changesets)
myfile = "parm/jedivar.yaml"
modify(myfile, changesets)
myfile = "scripts/exrrfs_recenter.sh"
modify(myfile, changesets)
myfile = "workflow/rocoto_funcs/recenter.py"
modify(myfile, changesets)
myfile = "workflow/rocoto_funcs/prep_ic.py"
modify(myfile, changesets)
myfile = "workflow/rocoto_funcs/jedivar.py"
modify(myfile, changesets)

print("Done\nNow your rrfs-workflow uses restart.nc instead of mpasout.nc")
print("Add `export RESTART_INTERVAL=1` into the exp file before setting up an experiment")
