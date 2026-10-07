#!/bin/bash
#
# Ursa, coarser domains (strip when merging to the nco branch): this whole directory is for
# development runs on Ursa; operations runs only RRFS_NA_3km.
#
# RRFS_CONUS_3km: ESG grid C3359, 1820 x 1092 points at 3 km, centred on 38.5N 97.5W. Same grid
# spacing as the operational NA domain over about a fifth of the area. Grid and write-component
# values come from dev-sci's ush/set_predef_grid_params.sh; job sizes from the WCOSS2 block of its
# ush/set_rrfs_config_general.sh, adjusted for Ursa's smaller per-node memory. Sourced by
# ecf/setup_ecf_links.sh and ecf/defs/make_ursa_def.sh when DOMAIN=RRFS_CONUS_3km.
#

# Fix files for this grid, from dev-sci's shared fix tree on Ursa. setup_ecf_links.sh links each
# one in as fix/<subdir>/RRFS_CONUS_3km beside the NA files. Use the C3359 directories: dev-sci's
# plain lam/RRFS_CONUS_3km and gsi/RRFS_CONUS_3km are an older 1748 x 1038 grid that does not match.
DOMAIN_FIX_LINKS=(
  "lam:/scratch4/BMC/rtrr/FIX_RRFS/lam/RRFS_CONUS_3km_C3359_Lake_fracSV"
  "gsi:/scratch4/BMC/rtrr/FIX_RRFS/gsi/RRFS_CONUS_3km_C3359"
  "smoke_dust:/scratch4/BMC/rtrr/FIX_RRFS/smoke_dust/RRFS_CONUS_3km"
)

# Namelist grid (parm/config/{det,enkf}/input.nml*); npx/npy are the grid points plus one
NML_NPX=1821
NML_NPY=1093
NML_TARGET_LAT=38.5
NML_TARGET_LON=-97.5
NML_LAYOUT="31, 32"

# Appended to fix/workflow/<wgf>/workflow.conf for det and enkf; the jobs source that file, so
# these later exports win over the NA values above them.
domain_workflow_conf() {
  cat <<'EOF'

# ---- RRFS_CONUS_3km (appended by setup_ecf_links.sh from ecf/defs/domains/RRFS_CONUS_3km.sh)
export PREDEF_GRID_NAME='RRFS_CONUS_3km'
  # how exrrfs_prdgen.sh names this domain's products
  export PRDGEN_GRIDNAME='conus'
  export PRDGEN_GRIDSPACING='3km'
export FIXLAM="${HOMErrfs}/fix/lam/RRFS_CONUS_3km"
export CRES='C3359'
export RES_IN_FIXLAM_FILENAMES='3359'
export ESGgrid_LON_CTR='-97.5'
export ESGgrid_LAT_CTR='38.5'
export ESGgrid_DELX='3000.0'
export ESGgrid_DELY='3000.0'
export ESGgrid_NX='1820'
export ESGgrid_NY='1092'
export LON_CTR='-97.5'
export LAT_CTR='38.5'
export NX='1820'
export NY='1092'
export DT_ATMOS='36'
export BLOCKSIZE='32'
# 31 x 32 compute ranks and one write group of 128: 1120 ranks at 48 per node, so 24 nodes
export LAYOUT_X='31'
export LAYOUT_Y='32'
export LAYOUT_X_18H='31'
export LAYOUT_Y_18H='32'
export LAYOUT_X_LONG='31'
export LAYOUT_Y_LONG='32'
export LAYOUT_X_SPINUP='31'
export LAYOUT_Y_SPINUP='32'
# ensf picks its layout from the _ENSF names, not the ones above (exrrfs_forecast.sh keys on a
# 60 h forecast length); LARGER is the variant three of the five members use
export LAYOUT_X_ENSF='31'
export LAYOUT_X_ENSF_LARGER='31'
export LAYOUT_Y_ENSF='32'
export WRTCMP_write_groups_ENSF='1'
export WRTCMP_write_tasks_per_group_ENSF='128'
# dev-sci uses 64 write tasks here; 128 keeps each write rank holding about as much as the NA
# domain does on Ursa, which is what its write ranks need to stay inside a node's memory
export WRTCMP_write_groups='1'
export WRTCMP_write_tasks_per_group='128'
export WRTCMP_write_groups_18H='1'
export WRTCMP_write_tasks_per_group_18H='128'
export WRTCMP_write_groups_LONG='1'
export WRTCMP_write_tasks_per_group_LONG='128'
export WRTCMP_write_groups_SPINUP='1'
export WRTCMP_write_tasks_per_group_SPINUP='128'
export PPN_FORECAST='48'
export TPP_FORECAST='2'
# output on the CONUS Lambert grid instead of the NA rotated lat-lon one
export WRTCMP_output_grid='lambert_conformal'
export WRTCMP_cen_lon='-97.5'
export WRTCMP_cen_lat='38.5'
export WRTCMP_stdlat1='38.5'
export WRTCMP_stdlat2='38.5'
export WRTCMP_nx='1799'
export WRTCMP_ny='1059'
export WRTCMP_lon_lwr_left='-122.719528'
export WRTCMP_lat_lwr_left='21.138123'
export WRTCMP_dx='3000.0'
export WRTCMP_dy='3000.0'
# analysis on 10 nodes (320 ranks) and post on one node, as dev-sci runs this grid; the NA values
# above are sized for a domain five times larger. make_ics, make_lbcs, the cloud analysis and the
# observation processing keep the NA settings, which dev-sci also uses here.
export NNODES_ANALYSIS_GSI='10'
export PPN_ANALYSIS_GSI='32'
export TPP_ANALYSIS_GSI='4'
export NNODES_POST='1'
export PPN_POST='128'
export TPP_POST='1'
export NNODES_POST_SUBH='1'
export PPN_POST_SUBH='128'
export TPP_POST_SUBH='1'
# EnKF cold start without ensemble blending: rrfs_util_fv3lam_pre_blending.exe has the NA
# resolution (C3463_oro_data...) and cold2warm_all.nc compiled into it, so the blending step
# cannot run on another grid. The members start from the GDAS ensemble directly instead.
export DO_ENS_BLENDING='FALSE'
# EnKF: the member forecast uses the same 31 x 32 layout and 1 x 128 write group as the
# deterministic run, so 1120 ranks at 48 per node is 24 nodes. The EnSRF update keeps its own
# sizes because exrrfs_analysis_enkf.sh hardcodes 160 cores at 8 per node.
export NNODES_RECENTER='2'
export PPN_RECENTER='64'
export NNODES_ANALYSIS_ENKF='20'
export PPN_ANALYSIS_ENKF='8'
export TPP_ANALYSIS_ENKF='16'
EOF
}

# Job sizes: <ecflow task-name glob>:<extra sbatch options>. The first matching pattern wins, so
# the narrower ones come first. make_ics, make_lbcs and the one-node jobs keep the card's values.
DOMAIN_SBATCH=(
  "jrrfs_det_analysis_gsi_diag*:--nodes=1 --time=00:20:00"
  # 18z timed out at 40 min; the spinup analyses run 10-25 min but the heavier cycles need room
  "jrrfs_det_analysis_gsi*:--nodes=10 --time=01:30:00"
  "jrrfs_det_forecast:--nodes=24 --time=01:00:00"
  "jrrfs_det_forecast_long:--nodes=24 --time=03:00:00"
  "jrrfs_det_forecast_spinup:--nodes=24 --time=00:30:00"
  "jrrfs_det_post_f*:--nodes=1"
  # EnKF at this resolution: a member forecast is the same size as the deterministic one
  "jrrfs_enkf_forecast*:--nodes=24 --time=01:00:00"
  "jrrfs_enkf_recenter*:--nodes=2"
  # The observer tasks size themselves from NNODES_ANALYSIS_GSI x PPN_ANALYSIS_GSI, 10 x 32 here,
  # but their cards ask for one node, so srun wants 320 tasks in a 1-node allocation and exits in
  # seconds. The 13 km domain never hit this because it sets NNODES_ANALYSIS_GSI=1.
  "jrrfs_enkf_observer_gsi*:--nodes=10 --time=00:50:00"
  "jrrfs_enkf_calc_ensmean*:--nodes=2"
  "jrrfs_enkf_make_ics*:--nodes=2"
)

# ---- Fixed namelist overrides (not configuration options) ----
# None: no NML_SED_EXTRA. Smoke and dust stay on because dev-sci has the fix files for this grid
# (dust12m_data.nc, emi_data.nc and the dummy emissions are all 1820 x 1092), and sppint already
# matches the 36 s step, so the shipped namelists need nothing beyond the grid values above.
