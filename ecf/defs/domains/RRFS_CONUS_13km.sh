#!/bin/bash
#
# Ursa, coarser domains (strip when merging to the nco branch): this whole directory is for
# development runs on Ursa; operations runs only RRFS_NA_3km.
#
# RRFS_CONUS_13km: ESG grid C775, 420 x 252 points at 13 km, centred on 38.5N 97.5W.
# Grid and write-component values come from dev-sci's ush/set_predef_grid_params.sh; job sizes
# and science settings from its ush/set_rrfs_config_general.sh (WCOSS2/Ursa block) and the
# RRFS_v1.2 13 km retro sample configs. Sourced by ecf/setup_ecf_links.sh and
# ecf/defs/make_ursa_def.sh when DOMAIN=RRFS_CONUS_13km in ursa_config.sh.
#

# Fix files for this grid, from dev-sci's shared fix tree on Ursa. setup_ecf_links.sh links each
# one in as fix/<subdir>/RRFS_CONUS_13km beside the NA files. lam/ uses RRFS_CONUS_13km_Lake_fracSV
# (420 x 252); FIX_RRFS lam/RRFS_CONUS_13km is an older 396 x 232 grid that does not match.
DOMAIN_FIX_LINKS=(
  "lam:/scratch4/BMC/rtrr/FIX_RRFS/lam/RRFS_CONUS_13km_Lake_fracSV"
  "gsi:/scratch4/BMC/rtrr/FIX_RRFS/gsi/RRFS_CONUS_13km"
)

# Namelist grid (parm/config/{det,enkf}/input.nml*); npx/npy are the grid points plus one
NML_NPX=421
NML_NPY=253
NML_TARGET_LAT=38.5
NML_TARGET_LON=-97.5
NML_LAYOUT="7, 8"
# No smoke/dust fix files (dust12m_data.nc, emi_data.nc) exist for this grid, so turn the package
# off in the namelists; the model reads those files whenever rrfs_sd is on. dev-sci also runs its
# 13 km configurations with smoke and dust off.
NML_SED_EXTRA="s/^( *rrfs_sd *= *).*/\\1.false./; s/^( *mix_chem *= *).*/\\1.false./; s/^( *do_smoke_transport *= *).*/\\1.false./; s/^( *aero_dir_fdb *= *).*/\\1.false./; s/^( *dust_opt *= *).*/\\10/; s/^( *drydep_opt *= *).*/\\10/; s/^( *addsmoke_flag *= *).*/\\10/"

# Appended to fix/workflow/<wgf>/workflow.conf for det and enkf; the jobs source that file, so
# these later exports win over the NA values above them.
domain_workflow_conf() {
  cat <<'EOF'

# ---- RRFS_CONUS_13km (appended by setup_ecf_links.sh from ecf/defs/domains/RRFS_CONUS_13km.sh)
export PREDEF_GRID_NAME='RRFS_CONUS_13km'
  # how exrrfs_prdgen.sh names this domain's products
  export PRDGEN_GRIDNAME='conus'
  export PRDGEN_GRIDSPACING='13km'
export FIXLAM="${HOMErrfs}/fix/lam/RRFS_CONUS_13km"
export CRES='C775'
export RES_IN_FIXLAM_FILENAMES='775'
export ESGgrid_LON_CTR='-97.5'
export ESGgrid_LAT_CTR='38.5'
export ESGgrid_DELX='13000.0'
export ESGgrid_DELY='13000.0'
export ESGgrid_NX='420'
export ESGgrid_NY='252'
export LON_CTR='-97.5'
export LAT_CTR='38.5'
export NX='420'
export NY='252'
# 36 s, not the 120 s dev-sci uses. The suite hardcodes the name of the model's first output,
# f000-00-36, which is one 36 s step: the post manager waits for it and setup_ecf_links.sh
# generates post and prdgen tasks with that name. Another step size writes a differently named
# file and those tasks wait forever. 36 s also divides the 900 s output interval.
export DT_ATMOS='36'
export BLOCKSIZE='32'
# 7 x 8 compute ranks and one write group of 8: 64 ranks, one node
export LAYOUT_X='7'
export LAYOUT_Y='8'
export LAYOUT_X_18H='7'
export LAYOUT_Y_18H='8'
export LAYOUT_X_LONG='7'
export LAYOUT_Y_LONG='8'
export LAYOUT_X_SPINUP='7'
export LAYOUT_Y_SPINUP='8'
# ensf picks its layout from the _ENSF names, not the ones above (exrrfs_forecast.sh keys on a
# 60 h forecast length); LARGER is the variant three of the five members use
export LAYOUT_X_ENSF='7'
export LAYOUT_X_ENSF_LARGER='7'
export LAYOUT_Y_ENSF='8'
export WRTCMP_write_groups_ENSF='1'
export WRTCMP_write_tasks_per_group_ENSF='8'
export WRTCMP_write_groups='1'
export WRTCMP_write_tasks_per_group='8'
export WRTCMP_write_groups_18H='1'
export WRTCMP_write_tasks_per_group_18H='8'
export WRTCMP_write_groups_LONG='1'
export WRTCMP_write_tasks_per_group_LONG='8'
export WRTCMP_write_groups_SPINUP='1'
export WRTCMP_write_tasks_per_group_SPINUP='8'
export PPN_FORECAST='64'
export TPP_FORECAST='2'
# output on the CONUS Lambert grid instead of the NA rotated lat-lon one
export WRTCMP_output_grid='lambert_conformal'
export WRTCMP_cen_lon='-97.5'
export WRTCMP_cen_lat='38.5'
export WRTCMP_stdlat1='38.5'
export WRTCMP_stdlat2='38.5'
export WRTCMP_nx='416'
export WRTCMP_ny='245'
export WRTCMP_lon_lwr_left='-121.719528'
export WRTCMP_lat_lwr_left='21.138123'
export WRTCMP_dx='13000.0'
export WRTCMP_dy='13000.0'
# the analysis runs on the model grid at 13 km (3 km runs analyse at twice the grid spacing)
export grid_ratio_fv3='1.0'
# one-node analysis, post and initial conditions
export NNODES_ANALYSIS_GSI='1'
export PPN_ANALYSIS_GSI='64'
export TPP_ANALYSIS_GSI='2'
export NNODES_POST='1'
export PPN_POST='64'
export TPP_POST='1'
# the sub-hourly post is a separate set of resources; on one node it must also fit in one node
export NNODES_POST_SUBH='1'
export PPN_POST_SUBH='64'
export TPP_POST_SUBH='1'
export NNODES_MAKE_ICS='1'
export PPN_MAKE_ICS='64'
export TPP_MAKE_ICS='2'
# no smoke or dust fix files and no BUFR sounding station list exist for this grid
export DO_SMOKE_DUST='FALSE'
# EnKF: a member forecast is the same 7 x 8 layout as the deterministic run, so 64 ranks on one
# node. Recentering and the ensemble mean also fit on one node here. The EnKF update itself is
# left alone: exrrfs_analysis_enkf.sh hardcodes 160 cores at 8 per node, so it keeps its 20 nodes.
export NNODES_RECENTER='1'
export PPN_RECENTER='64'
export NNODES_ANALYSIS_ENKF='20'
export PPN_ANALYSIS_ENKF='8'
export TPP_ANALYSIS_ENKF='16'
# EnKF cold start without ensemble blending: rrfs_util_fv3lam_pre_blending.exe has the NA
# resolution (C3463_oro_data...) and cold2warm_all.nc compiled into it, so the blending step
# cannot run on another grid. The members start from the GDAS ensemble directly instead.
export DO_ENS_BLENDING='FALSE'
EOF
}

# Job sizes: <ecflow task-name glob>:<extra sbatch options>. make_ursa_def.sh puts the options on
# the matching tasks, and sbatch command-line options override the #SBATCH lines in the ecf cards,
# so the cards themselves stay as they are.
DOMAIN_SBATCH=(
  # ensf: 5 members of a 60 h forecast. The cards ask for 68 nodes per member and 4 per post, as
  # the NA domain needs; at this resolution one node does either. prep_cyc, make_lbcs and prdgen
  # are already one node on the cards.
  "jrrfs_ensf_forecast*:--nodes=1 --time=01:30:00"
  "jrrfs_ensf_post_*:--nodes=1"
  "jrrfs_ensf_recenter*:--nodes=1"
  "jrrfs_det_forecast:--nodes=1 --time=00:35:00"
  "jrrfs_det_forecast_long:--nodes=1 --time=02:30:00"
  "jrrfs_det_forecast_spinup:--nodes=1 --time=00:15:00"
  "jrrfs_det_analysis_gsi*:--nodes=1 --time=00:20:00"
  "jrrfs_det_post_f*:--nodes=1"
  "jrrfs_det_make_ics:--nodes=1"
  "jrrfs_enkf_forecast*:--nodes=1 --time=00:30:00"
  "jrrfs_enkf_recenter*:--nodes=1"
  "jrrfs_enkf_calc_ensmean*:--nodes=1"
  "jrrfs_enkf_make_ics*:--nodes=1"
)
