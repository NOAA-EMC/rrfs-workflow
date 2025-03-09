#!/usr/bin/env python
from pathlib import Path
import os
import sys
import shutil
from datetime import datetime
"""
 clean up com/ stmp/ logs/ directoris mostly for realtime runs
 but it can also be used for offline clean up at the command line
"""
def is_directory_empty(directory_path):
    with os.scandir(directory_path) as it:
        return not any(it)
#
def day_clean(srcPath,cyc1,cyc2,srcType,WGF):
   for i in range(cyc1, cyc2 + 1):
       if srcType == "log":
         pattern = f'{i:02}/{WGF}'
       elif srcType == "stmp":
         pattern = f'*_{i:02}_*/{WGF}'
       else: #com 
         pattern = f'{i:02}/*/{WGF}'
       pathlist = list(Path(srcPath).glob(pattern))
       for mypath in pathlist:
           sys.stdout.write(f'purge {mypath}......')
           try:
               shutil.rmtree(mypath)
               sys.stdout.write(f'done!\n')
           except Exception as e:
               sys.stdout.write(f'\n    An error occurred: {e}')
       #~~~~~~~~~~~~
       # remove empty directories
       #
       pathlist = list(Path(srcPath).glob(pattern.rstrip(f'/{WGF}')))
       for mypath in pathlist:
           if is_directory_empty(mypath):
               os.rmdir(mypath)
               print(f'remove empty directory: {mypath}')
       #~~~~~~~~~~~~
       # remove RUN.PDY/cyc if it is empty under com/
       #
       cycPath = srcPath.rstrip('/') + f"/{i:02}"
       if os.path.exists(cycPath) and srcType ==  "com" and is_directory_empty(cycPath):
           os.rmdir(cycPath)
           print(f'remove empty directory: {cycPath}')
       #~~~~~~~~~~~~
       # remove srcPath if it is empty
       #
       if os.path.exists(srcPath) and is_directory_empty(srcPath):
           os.rmdir(srcPath)
           print(f'remove empty directory: {srcPath}')

#----------------------------------------------------------------------
# get system environmental variables
#
comroot = os.getenv("COMROOT","")
dataroot = os.getenv("DATAROOT","")
pdy = os.getenv("PDY","")
cyc = os.getenv("cyc","")
net = os.getenv("NET","")
run = os.getenv("RUN","")
rrfs_ver = os.getenv("rrfs_ver","")
wgf = os.getenv("WGF","")
list_envars = [comroot, dataroot, pdy, cyc, net, run, rrfs_ver, wgf]
if not all (envar.strip() for envar in list_envars): # if not "all envars are non-empty"
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
#----------------------------------------------------------------------
# get clean-realted environmental variables
#
stmp_clean_hrs = int(os.getenv("STMP_CLEAN_HRS","24"))
com_clean_hrs = int(os.getenv("COM_CLEAN_HRS","120"))
log_clean_hrs = int(os.getenv("LOG_CLEAN_HRS","840"))
clean_back_days = int(os.getenv("CLEAN_BACK_DAYS","5"))
#
#----------------------------------------------------------------------
# remove data based on clean-realted environmental variables
#



