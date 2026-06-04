#!/usr/bin/env python
import os
import sys
import ast
import re
import glob


args = sys.argv
nargs = len(args) - 1
if nargs < 4:
    print(f"{os.path.basename(sys.argv[0])} <basedir> <spec> <prefix> <outfile>")
    exit()
#
basedir = sys.argv[1]
spec = sys.argv[2]
prefix = sys.argv[3]
outfile = sys.argv[4]
WGF = os.getenv('WGF', 'det')
#
# save current dir and change to basedir
CWD = os.getcwd()
os.chdir(basedir)
#
# get include files
dcSpec = ast.literal_eval(spec)
items = re.split(r'[\s,]+', dcSpec['include'].strip())
includes = []
for pattern in items:
    if not pattern:
        continue
    if f'/{WGF}' not in pattern:  # add WGF if missing
        pattern += f'/{WGF}'
    if pattern.endswith(f'/{WGF}') or pattern.endswith(f'/') or os.path.isdir(pattern):
        pattern += '/**/*'
    includes.extend(glob.glob(f'{pattern}', recursive=True))
# ~~~~
# remove any directories
includes = [f for f in includes if not os.path.isdir(f)]
# remove all links under pyDAmonitor
includes = [f for f in includes if not (os.path.islink(f) and f'pyDAmonitor/{WGF}' in f)]
#
# remove files specified by the 'exclude' key
if 'exclude' in dcSpec:
    items = re.split(r'[\s,]+', dcSpec['exclude'].strip())
    items = [x.replace('*', '') for x in items if x]   # remove any empty string item
    includes = [
        x for x in includes
        if not any(x.startswith(pattern) for pattern in items)
    ]
#
# write out the list
os.chdir(CWD)
includes = [os.path.join(prefix, x) for x in includes]
with open(outfile, 'w') as f:
    f.writelines(line + '\n' for line in includes)
