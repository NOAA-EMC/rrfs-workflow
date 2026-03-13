#!/usr/bin/env python
from pathlib import Path
import os
import sys
import shutil
from datetime import datetime, timedelta, timezone
import sqlite3
"""
 clean up com/ stmp/ logs/ directoris mostly for realtime runs
 but it can also be used for offline clean up at the command line
"""


def is_directory_empty(directory_path):
    with os.scandir(directory_path) as it:
        return not any(it)
#
# ----------------------------------------------------------------------
#


def is_cycle_done(EXPDIR, CDATE):
    is_done = False
    db = f"{EXPDIR}/rrfs.db"
    conn = sqlite3.connect(db)
    cur = conn.cursor()
    cur.execute(f"SELECT * FROM cycles")
    rows = cur.fetchall()  # id, cycle, activated, expired, done, draining
    for r in rows:
        dt = datetime.fromtimestamp(r[1], tz=timezone.utc)
        rcycle = dt.strftime("%Y%m%d%H%M")
        if rcycle == f'{CDATE}00':
            if r[4] != 0:  # non-zero means "done"
                is_done = True
            break
    # ~~~~~~~~
    return is_done
#
# ----------------------------------------------------------------------
#


def day_clean(srcPath, cyc1, cyc2, srcType, WGF):
    check_is_cyc_done = os.getenv("CHECK_IS_CYC_DONE", "FALSE").upper() == "TRUE"
    if check_is_cyc_done:  # mainly for retros. Not needed by realtime runs as we want to remove all old cycles including expired ones
        EXPDIR = os.getenv("EXPDIR", "EXPDIR_not_defined")
        STMP_KEPT_TASKS = os.getenv("STMP_KEPT_TASKS", "").strip()
        RUN = os.getenv("RUN", "")
    else:
        STMP_KEPT_TASKS = ""

    for i in range(cyc1, cyc2 + 1):
        if check_is_cyc_done:
            CDATE = srcPath.rstrip("/")[-8:] + f'{i:02}'
            if not is_cycle_done(EXPDIR, CDATE):  # skip the clean process for cycles not done yet
                print(f'{CDATE} NOT done yet, no cleaning')
                continue

        if srcType == "log":
            pattern = f'{i:02}/{WGF}'
        elif srcType == "stmp":
            pattern = f'*_{i:02}_*/{WGF}'
        elif srcType == "com_lbc":
            pattern = f'{i:02}/lbc/{WGF}'
        else:  # com
            pattern = f'{i:02}/*/{WGF}'

        pathlist = list(Path(srcPath).glob(pattern))
        if srcType == "stmp" and STMP_KEPT_TASKS != "":  # exclude STMP_KEPT_TASKS from pathlist
            kept_tasks = STMP_KEPT_TASKS.split(",")
            excludes = []
            for task in kept_tasks:
                excludes.append(f'{RUN}_{task}_{i:02}_')
            pathlist = [p for p in pathlist if not any(ex in str(p) for ex in excludes)]

        for mypath in pathlist:
            if os.path.exists(mypath):
                sys.stdout.write(f'purge {mypath}......')
                try:
                    shutil.rmtree(mypath)
                    sys.stdout.write(f'done!\n')
                except Exception as e:
                    sys.stdout.write(f'\n    An error occurred: {e}')
        # ~~~~~~~~~~~~
        # remove empty directories
        #
        pathlist = list(Path(srcPath).glob(pattern.rstrip(f'/{WGF}')))
        for mypath in pathlist:
            if os.path.exists(mypath) and is_directory_empty(mypath):
                os.rmdir(mypath)
                print(f'remove empty directory: {mypath}')
        # ~~~~~~~~~~~~
        # remove RUN.PDY/cyc if it is empty under com/
        #
        cycPath = srcPath.rstrip('/') + f"/{i:02}"
        if os.path.exists(cycPath) and srcType == "com" and is_directory_empty(cycPath):
            os.rmdir(cycPath)
            print(f'remove empty directory: {cycPath}')
        # ~~~~~~~~~~~~
        # remove srcPath if it is empty
        #
        if os.path.exists(srcPath) and is_directory_empty(srcPath):
            os.rmdir(srcPath)
            print(f'remove empty directory: {srcPath}')
#
# ----------------------------------------------------------------------
#


def group_clean(cdate, retention_cycs, srcBase, srcType, NET, RUN, WGF, rrfs_ver):
    clean_back_days = int(os.getenv("CLEAN_BACK_DAYS", "5"))

    srcBase = srcBase.rstrip('/')
    pdate = cdate - timedelta(hours=retention_cycs)  # first cycle to be cleaned
    pPDY = pdate.strftime("%Y%m%d")
    pcyc = pdate.strftime("%H")
    #
    if srcType == "stmp":
        srcBase = os.path.dirname(srcBase)
    #
    for i in reversed(range(clean_back_days)):
        bdate = pdate - timedelta(days=i + 1)  # go back to bdate
        bPDY = bdate.strftime("%Y%m%d")
        if srcType == "stmp":
            srcPath = f"{srcBase}/{bPDY}"
        elif srcType.startswith("com"):
            srcPath = f"{srcBase}/{NET}/{rrfs_ver}/{RUN}.{bPDY}"
        elif srcType == "log":
            srcPath = f"{srcBase}/{NET}/{rrfs_ver}/logs/{RUN}.{bPDY}"
        if os.path.exists(srcPath):
            print(f"----\nday_clean {srcPath} 0 23 {srcType} {WGF}\n----")
            day_clean(srcPath, 0, 23, srcType, WGF)
    # ~~~~~~
    # clean cycles in the first clean cycle day
    if srcType == "stmp":
        srcPath = f"{srcBase}/{pPDY}"
    elif srcType.startswith("com"):
        srcPath = f"{srcBase}/{NET}/{rrfs_ver}/{RUN}.{pPDY}"
    elif srcType == "log":
        srcPath = f"{srcBase}/{NET}/{rrfs_ver}/logs/{RUN}.{pPDY}"
    if os.path.exists(srcPath):
        print(f"----\nday_clean {srcPath} 0 {pcyc} {srcType} {WGF}\n----")
        day_clean(srcPath, 0, int(pcyc), srcType, WGF)


#
# ----------------------------------------------------------------------
# ** main starts here **
# get system environmental variables
#
COMROOT = os.getenv("COMROOT", "")
DATAROOT = os.getenv("DATAROOT", "")
PDY = os.getenv("PDY", "")
cyc = os.getenv("cyc", "")
NET = os.getenv("NET", "")
RUN = os.getenv("RUN", "")
rrfs_ver = os.getenv("rrfs_ver", "")
WGF = os.getenv("WGF", "")
list_envars = [COMROOT, DATAROOT, PDY, cyc, NET, RUN, rrfs_ver, WGF]
if not all(envar.strip() for envar in list_envars):  # if not "all envars are non-empty"
    # 'Not enough environmental variables are set, use the command line inputs'
    args = sys.argv
    if len(args) < 6:
        print(f'Usage: {args[0]} <srcPath> <cyc1> <cyc2> <com|stmp|log> <WGF>')
        print(f'                      srcPath has to include PDY')
    else:
        day_clean(args[1], int(args[2]), int(args[3]), args[4], args[5])
        print("Done.")
    exit()
#
# ----------------------------------------------------------------------
# get clean-related environmental variables
#
stmp_retention_cycs = int(os.getenv("STMP_RETENTION_CYCS", "24"))
com_retention_cycs = int(os.getenv("COM_RETENTION_CYCS", "120"))
com_lbc_retention_cycs = int(os.getenv("COM_LBC_RETENTION_CYCS", "48"))
log_retention_cycs = int(os.getenv("LOG_RETENTION_CYCS", "840"))
clean_back_days = int(os.getenv("CLEAN_BACK_DAYS", "5"))
#
# ----------------------------------------------------------------------
# remove data based on clean-realted environmental variables
#
cdate = datetime.strptime(f'{PDY}{cyc}', "%Y%m%d%H")
cdate = cdate.replace(tzinfo=timezone.utc)  # make it UTC-aware
print(f'cdate={cdate}')
print(f'stmp_retention_cycs={stmp_retention_cycs}')
print(f'com_retention_cycs={com_retention_cycs}')
print(f'com_lbc_retention_cycs={com_lbc_retention_cycs}')
print(f'log_retention_cycs={log_retention_cycs}')
print(f'clean_back_days={clean_back_days}')

print(f'\nTry to clean stmp: {os.path.dirname(DATAROOT)}')
group_clean(cdate, stmp_retention_cycs, DATAROOT, 'stmp', NET, RUN, WGF, rrfs_ver)

print(f'\nTry to clean com: {COMROOT}')
group_clean(cdate, com_retention_cycs, COMROOT, 'com', NET, RUN, WGF, rrfs_ver)

print(f'\nTry to clean com_lbc: {COMROOT}')
group_clean(cdate, com_lbc_retention_cycs, COMROOT, 'com_lbc', NET, RUN, WGF, rrfs_ver)

print('\nTry to clean log: ' + COMROOT.rstrip('/') + f'{NET}/{rrfs_ver}/logs')
group_clean(cdate, log_retention_cycs, COMROOT, 'log', NET, RUN, WGF, rrfs_ver)

print('\nDone!')
