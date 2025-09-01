#!/usr/bin/env python
import os
import hifiyaml as hy



analysisDate = os.getenv("analysisDate", "analysisDate_NOT_DEFINED")
beginDate = os.getenv("beginDate", "beginDate_NOT_DEFINED")
HYB_WGT_STATIC = os.getenv("HYB_WGT_STATIC", "HYB_WGT_STATIC_NOT_DEFINED")
HYB_WGT_ENS = os.getenv("HYB_WGT_ENS", "HYB_WGT_ENS_NOT_DEFINED")
# replacements for the @VAR@ patterns
replacements = {
    "analysisDate": f"{analysisDate}",
    "beginDate": f"{beginDate}",
    "HYB_WGT_STATIC": f"{HYB_WGT_STATIC}",
    "HYB_WGT_ENS": f"{HYB_WGT_ENS}",
    "empty": "empty",
}

data = hy.load("jedivar.yaml", replacements)

# modify a key:value YAML block
querystr = "cost function/background error/components/1/convariance/members from template/template/filename"
hy.dump(hy.modify(data, querystr, "begin: end"))
