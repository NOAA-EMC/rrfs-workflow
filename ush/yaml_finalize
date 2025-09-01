#!/usr/bin/env python
import os
import sys
import hifiyaml as hy

args = sys.argv
nargs = len(args) - 1
if nargs < 1:
    sys.stderr.write("yamlfinalize <jedivar|getkf>\n")
    sys.exit(1)

ytype = args[1]
yfile = ytype + ".yaml"

# read needed environmental variables
analysisDate = os.getenv("analysisDate", "analysisDate_NOT_DEFINED")
beginDate = os.getenv("beginDate", "beginDate_NOT_DEFINED")
HYB_WGT_STATIC = os.getenv("HYB_WGT_STATIC", "HYB_WGT_STATIC_NOT_DEFINED")
HYB_WGT_ENS = os.getenv("HYB_WGT_ENS", "HYB_WGT_ENS_NOT_DEFINED")
start_type = os.getenv("start_type", "start_type_NOT_DEFINED")
GETKF_TYPE = os.getenv("TYPE", "TYPE_NOT_DEFINED")  # TYPE -> GETKF_TYPE

# replacements for the @VAR@ patterns
replacements = {
    "analysisDate": f"{analysisDate}",
    "beginDate": f"{beginDate}",
    "HYB_WGT_STATIC": f"{HYB_WGT_STATIC}",
    "HYB_WGT_ENS": f"{HYB_WGT_ENS}",
}

# load the YAML data and complete the pattern replacement
data = hy.load(yfile, replacements)

# modify a key:value YAML block
if float(HYB_WGT_STATIC) == 0.0:
    # remove the static BEC component, yield a pure 3DEnVar
    querystr = "cost function/background error/components/0"
    hy.drop(data, querystr)
elif float(HYB_WGT_ENS) == 0.0:
    # remove the ensemble BEC component, yield a pure 3DVar
    querystr = "cost function/background error/components/1"
    hy.drop(data, querystr)

# tweaks for cold start DA
if ytype == "jedivar":
    hy.modify(data, "output/filename", "filename: ana.nc")
    hy.modify(data, "cost function/background/filename", "filename: ana.nc")
elif ytype == "getkf":
    hy.modify(data, "output/filename", "filename: ./data/ana/mem%{member}%.nc")

# querystr = "cost function/background error/components/1/convariance/members from template/template/filename"
hy.dump(data)
sys.exit(0)
