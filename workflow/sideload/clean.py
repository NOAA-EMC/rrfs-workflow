#!/usr/bin/env python
from pathlib import Path
import os
import sys
import shutil
#
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
           sys.stdout.write(f'remove {mypath}......')
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
       # remove srcPath if it is empty
       #
       if is_directory_empty(srcPath):
           os.rmdir(mypath)
           print(f'remove empty directory: {mypath}')

#----------------------------------------------------------------------
args = sys.argv

day_clean(args[1], int(args[2]), int(args[3]), args[4], args[5])
