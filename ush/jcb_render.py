#!/usr/bin/env python
import os
import sys
import yamltools4rrfs as yt
import jcb
import yaml
from datetime import datetime, timedelta

args = sys.argv
nargs = len(args) - 1
if nargs < 1:
    sys.stderr.write("jcb_render.py  <jedivar.yaml|getkf.yaml|hofx.yaml|test.yaml>\n")
    sys.exit(1)
yfile = args[1]
ytype = yfile.split(".", 1)[0]  # get the yaml file type: jedivar, getkf, hofx, etc

# get environmental variables
PARMrrfs = os.getenv("PARMrrfs", "PARMrrfs_not_defined")
analysisDate = os.getenv("analysisDate", "{{analysisDate}}")
beginDate = os.getenv("beginDate", "{{beginDate}}")
HYB_WGT_STATIC = os.getenv("HYB_WGT_STATIC", "{{HYB_WGT_STATIC}}")
HYB_WGT_ENS = os.getenv("HYB_WGT_ENS", "{{HYB_WGT_ENS}}")
emptyObsSpaceAction = os.getenv("EMPTY_OBS_SPACE_ACTION", "{{emptyObsSpaceAction}}")

start_type = os.getenv("start_type", "start_type_NOT_DEFINED")
GETKF_TYPE = os.getenv("GETKF_TYPE", "TYPE_NOT_DEFINED")
use_conv_sat_info = (os.getenv("USE_CONV_SAT_INFO", "True").upper() != "FALSE")

STATIC_BEC_MODEL = os.getenv("STATIC_BEC_MODEL", "GSIBEC")
GSIBEC_X = os.getenv("GSIBEC_X", "{{GSIBEC_X}}")
GSIBEC_Y = os.getenv("GSIBEC_Y", "{{GSIBEC_Y}}")
GSIBEC_NLAT = os.getenv("GSIBEC_NLAT", "{{GSIBEC_NLAT}}")
GSIBEC_NLON = os.getenv("GSIBEC_NLON", "{{GSIBEC_NLON}}")
GSIBEC_LAT_START = os.getenv("GSIBEC_LAT_START", "{{GSIBEC_LAT_START}}")
GSIBEC_LAT_END = os.getenv("GSIBEC_LAT_END", "{{GSIBEC_LAT_END}}")
GSIBEC_LON_START = os.getenv("GSIBEC_LON_START", "{{GSIBEC_LON_START}}")
GSIBEC_LON_END = os.getenv("GSIBEC_LON_END", "{{GSIBEC_LON_END}}")
GSIBEC_NORTH_POLE_LAT = os.getenv("GSIBEC_NORTH_POLE_LAT", "{{GSIBEC_NORTH_POLE_LAT}}")
GSIBEC_NORTH_POLE_LON = os.getenv("GSIBEC_NORTH_POLE_LON", "{{GSIBEC_NORTH_POLE_LON}}")

# determine the temporal grid for Gaussian Thinning
time_mesh = 3
THINNING_TIME_MESH = f"PT{time_mesh:02d}H"
analysis_time = datetime.strptime(analysisDate, "%Y-%m-%dT%H:%M:%SZ")
delta = timedelta(hours=time_mesh / 2)
time_min = analysis_time - delta
time_max = analysis_time + delta
THINNING_TIME_MIN = time_min.strftime("%Y-%m-%dT%H:%M:%SZ")
THINNING_TIME_MAX = time_max.strftime("%Y-%m-%dT%H:%M:%SZ")

# replacements for the {{VAR}} patterns and top level options for JCB
dict_for_jcb = {
    "analysisDate": f"{analysisDate}",
    "beginDate": f"{beginDate}",
    "HYB_WGT_STATIC": f"{HYB_WGT_STATIC}",
    "HYB_WGT_ENS": f"{HYB_WGT_ENS}",
    "emptyObsSpaceAction": f"{emptyObsSpaceAction}",
    "GSIBEC_X": f"{GSIBEC_X}",
    "GSIBEC_Y": f"{GSIBEC_Y}",
    "GSIBEC_NLAT": f"{GSIBEC_NLAT}",
    "GSIBEC_NLON": f"{GSIBEC_NLON}",
    "GSIBEC_LAT_START": f"{GSIBEC_LAT_START}",
    "GSIBEC_LAT_END": f"{GSIBEC_LAT_END}",
    "GSIBEC_LON_START": f"{GSIBEC_LON_START}",
    "GSIBEC_LON_END": f"{GSIBEC_LON_END}",
    "GSIBEC_NORTH_POLE_LAT": f"{GSIBEC_NORTH_POLE_LAT}",
    "GSIBEC_NORTH_POLE_LON": f"{GSIBEC_NORTH_POLE_LON}",
    "THINNING_TIME_MESH": f"{THINNING_TIME_MESH}",
    "THINNING_TIME_MIN": f"{THINNING_TIME_MIN}",
    "THINNING_TIME_MAX": f"{THINNING_TIME_MAX}",

    "algorithm": ytype,
    "algorithm_path": f"{PARMrrfs}/jcb-rrfs",
    "app_path_observations": f"{PARMrrfs}/jcb-rrfs/obs",
}

# use JCB to render the YAML file
data = jcb.render(dict_for_jcb)
if ytype == "getkf":
    observers = data["observations"]["observers"]
else:
    observers = data["cost function"]["observations"]["observers"]

# keep/drop/passivate observations based on convifo/satinfo
if use_conv_sat_info:
    dcConvInfo = yt.load_convinfo()
    dcSatInfo = yt.load_satinfo()
    if not dcConvInfo:
        sys.stderr.write("INFO: no convinfo, or empty/corrupt convinfo\n")
    if not dcSatInfo:
        sys.stderr.write("INFO: no satinfo, or empty/corrupt satinfo\n")

    # assemble observers
    delete_indices = []
    for index, observer in enumerate(observers):
        # get the shortest observer name
        is_sat_radiance = (observer["obs operator"]["name"].upper() == "CRTM")
        name = observer["obs space"]["name"]
        tmp = observer["obs space"]["name"].split("_", 1)
        if len(tmp) > 1 and not is_sat_radiance:
            sname = tmp[1].strip()
        else:
            sname = name
        # if ytype == "getkf" and (GETKF_TYPE == "solver" or GETKF_TYPE == "post"):
        #    yt.getkf_observer_tweak(tmp, GETKF_TYPE)

        found = False
        if is_sat_radiance:  # check against satinfo
            for sis, info in dcSatInfo.items():
                if sis == sname:
                    found = True
                    break
        else:  # check against convinfo
            for iname, info in dcConvInfo.items():
                if iname == sname:
                    if info['iuse'] != "0":  # assimilate or monitor
                        found = True
                        if info['iuse'] == "-1":   # monitor, need to insert a passivate filter
                            pfilter = {"filter": "Perform Action",
                                       "action": {"name": "passivate"}}
                            observers[index]["obs filters"].insert(0, pfilter)
                    # ~~~~~~~
                    break
        # ~~~~~~~~~~~~~~~~
        if not found:
            delete_indices.append(index)
    # ~~~~~~~~~~~~~~~~~~~~
    for i in reversed(range(len(delete_indices))):
        del observers[delete_indices[i]]

if ytype == "getkf":
    data["observations"]["observers"] = observers
else:
    data["cost function"]["observations"]["observers"] = observers

# modify variable list if do_radar_ref
do_radar_ref = (os.getenv("DO_RADAR_REF", "FASLE").upper() == "TRUE" and start_type != "cold")
if not do_radar_ref and ytype == "jedivar":
    var_list = ['water_vapor_mixing_ratio_wrt_moist_air', 'air_pressure_at_surface', 'air_temperature', 'northward_wind', 'eastward_wind']
    data["cost function"]["analysis variables"] = var_list
    data["cost function"]["background error"]["components"][0]["covariance"]["linear variable change"]["output variables"] = var_list
    data["cost function"]["background error"]["components"][1]["covariance"]["localization"]["saber central block"]["active variables"] = var_list
    data["cost function"]["background error"]["components"][1]["covariance"]["members from template"]["template"]["state variables"] = var_list
    state_vars = data["cost function"]["background"]["state variables"]
    for i in reversed(range(len(state_vars))):
        if state_vars[i] in ["equivalent_reflectivity_factor", "w", "upward_air_velocity"]:
            del state_vars[i]
    data["cost function"]["background"]["state variables"] = state_vars

elif not do_radar_ref and ytype == "getkf":
    var_list = ['air_temperature', 'water_vapor_mixing_ratio_wrt_moist_air', 'eastward_wind', 'northward_wind', 'air_pressure_at_surface']
    data["increment variables"] = var_list
    state_vars = data["background"]["members from template"]["template"]["state variables"]
    for i in reversed(range(len(state_vars))):
        if state_vars[i] in ["equivalent_reflectivity_factor", "w", "upward_air_velocity"]:
            del state_vars[i]
    data["background"]["members from template"]["template"]["state variables"] = state_vars

# modify BEC models for jedivar
if ytype == "jedivar":
    if "@" not in HYB_WGT_STATIC and float(HYB_WGT_STATIC) == 0.0:
        # remove the static BEC component, yield a pure 3DEnVar
        del data["cost function"]["background error"]["components"][0]
    if "@" not in HYB_WGT_ENS and float(HYB_WGT_ENS) == 0.0:
        # remove the ensemble BEC component, yield a pure 3DVar
        del data["cost function"]["background error"]["components"][1]

# tweaks for cold start DA
if ytype == "jedivar" and start_type == "cold":
    data["output"]["filename"] = "init.nc"
    data["cost function"]["background"]["filename"] = "init.nc"

# tweaks getkf.yaml from the observer mode to the solver mode
solver_driver = {
    "read HX from disk": True,
    "save posterior ensemble": True,
    "save prior mean": True,
    "save posterior mean": True,
    "do posterior observer": False,
}
if ytype == "getkf" and GETKF_TYPE == "solver":
    data["driver"] = solver_driver

# write out the JCB yaml file
with open(yfile, "w") as f:
    yaml.safe_dump(data, f, default_flow_style=False, sort_keys=False)
