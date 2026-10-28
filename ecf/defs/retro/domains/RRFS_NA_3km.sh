#!/bin/bash
#
# Coarser domains (strip when merging to the nco branch): this whole directory is for
# development retros; operations runs only RRFS_NA_3km.
#
# RRFS_NA_3km: the operational domain, ESG grid C3463, 3950 x 2700 points at 3 km, centred on
# 55N 112.5W. Values come from the package's fix/workflow/{det,enkf,ensf}/workflow.conf_dev, the
# development job sizes, which keep every job inside Ursa's 75-node limit; the retro overrides at
# the end are the changes the retros need on top of them. RESOURCE_CONFIG then picks only the ecf
# cards. Sourced by ush/retro/setup_retro_links.sh and ecf/defs/retro/make_rrfs_retro_def.sh when
# DOMAIN=RRFS_NA_3km in retro/config.sh (the default).
#

# Fix files: none to add, the package's fix tree is this grid's
DOMAIN_FIX_LINKS=()

# Namelist grid: none. Each parm/config/{det,enkf,ensf}/input.nml* already has this grid, and
# their layouts differ from file to file, so no single NML_LAYOUT applies.

# The package workflow.conf the values below were taken from. setup_retro_links.sh warns about any
# value above the retro overrides that no longer matches it, so a package update shows up.
DOMAIN_PACKAGE_CONF=workflow.conf_dev

# Appended to fix/workflow/<wgf>/workflow.conf for det, enkf and ensf; the jobs source that file, so
# these later exports win over the package values above them. Unlike the other domains, the three
# groups differ here (the EnKF members run a smaller layout), so each has its own block.
domain_workflow_conf() {
  cat <<'EOF'

# ---- RRFS_NA_3km (appended by setup_retro_links.sh from ecf/defs/retro/domains/RRFS_NA_3km.sh)
export PREDEF_GRID_NAME='RRFS_NA_3km'
export CRES='C3463'
export RES_IN_FIXLAM_FILENAMES='3463'
export ESGgrid_LON_CTR='-112.5'
export ESGgrid_LAT_CTR='55.0'
export ESGgrid_DELX='3000.0'
export ESGgrid_DELY='3000.0'
export ESGgrid_NX='3950'
export ESGgrid_NY='2700'
export LON_CTR='-112.5'
export LAT_CTR='55.0'
export NX='3950'
export NY='2700'
export DT_ATMOS='36'
export BLOCKSIZE='28'
export PPN_FORECAST='64'
export TPP_FORECAST='2'
# output on the NA rotated lat-lon grid
export WRTCMP_output_grid='rotated_latlon'
export WRTCMP_cen_lon='-113.0'
export WRTCMP_cen_lat='55.0'
export WRTCMP_dlon='0.025'
export WRTCMP_dlat='0.025'
export NNODES_POST='4'
export PPN_POST='32'
export TPP_POST='4'
export NNODES_MAKE_ICS='2'
export PPN_MAKE_ICS='32'
export TPP_MAKE_ICS='4'
export NNODES_RECENTER='10'
export PPN_RECENTER='128'
export NNODES_ANALYSIS_ENKF='10'
export PPN_ANALYSIS_ENKF='8'
export TPP_ANALYSIS_ENKF='16'
EOF
  case $1 in
    det) cat <<'EOF'
# det: 43 x 64 compute ranks for the 18 h and 84 h forecasts, 29 x 64 for the spinup
export LAYOUT_X='43'
export LAYOUT_Y='64'
export LAYOUT_X_18H='43'
export LAYOUT_Y_18H='64'
export LAYOUT_X_LONG='43'
export LAYOUT_Y_LONG='64'
export LAYOUT_X_SPINUP='29'
export LAYOUT_Y_SPINUP='64'
export WRTCMP_write_groups='3'
export WRTCMP_write_tasks_per_group='192'
export WRTCMP_write_groups_18H='3'
export WRTCMP_write_tasks_per_group_18H='192'
export WRTCMP_write_groups_LONG='3'
export WRTCMP_write_tasks_per_group_LONG='192'
export WRTCMP_write_groups_SPINUP='1'
export WRTCMP_write_tasks_per_group_SPINUP='128'
export WRTCMP_lon_lwr_left='-61.0'
export WRTCMP_lat_lwr_left='-37.0'
export WRTCMP_lon_upr_rght='61.0'
export WRTCMP_lat_upr_rght='37.0'
# the analysis runs at twice the grid spacing
export grid_ratio_fv3='2.0'
export NNODES_ANALYSIS_GSI='60'
export PPN_ANALYSIS_GSI='8'
export TPP_ANALYSIS_GSI='16'
export NNODES_POST_SUBH='2'
export PPN_POST_SUBH='64'
export TPP_POST_SUBH='2'
export DO_SMOKE_DUST='TRUE'
export DO_ENS_BLENDING='FALSE'
EOF
      ;;
    enkf) cat <<'EOF'
# EnKF members: 16 x 44 compute ranks and one write group of 64
export LAYOUT_X='16'
export LAYOUT_Y='44'
export LAYOUT_X_SPINUP='16'
export LAYOUT_Y_SPINUP='44'
export WRTCMP_write_groups='1'
export WRTCMP_write_tasks_per_group='64'
export WRTCMP_write_groups_SPINUP='1'
export WRTCMP_write_tasks_per_group_SPINUP='64'
export WRTCMP_lon_lwr_left='-0.1'
export WRTCMP_lat_lwr_left='-0.1'
export WRTCMP_lon_upr_rght='0.1'
export WRTCMP_lat_upr_rght='0.1'
export grid_ratio_fv3='2.0'
export NNODES_ANALYSIS_GSI='1'
export PPN_ANALYSIS_GSI='16'
export TPP_ANALYSIS_GSI='8'
export DO_SMOKE_DUST='FALSE'
export DO_ENS_BLENDING='TRUE'
EOF
      ;;
    ensf) cat <<'EOF'
# ensf picks its layout from the _ENSF names, not the ones above (exrrfs_forecast.sh keys on a
# 60 h forecast length); LARGER is the variant three of the five members use
export LAYOUT_X='50'
export LAYOUT_Y='64'
export LAYOUT_X_ENSF='50'
export LAYOUT_X_ENSF_LARGER='50'
export LAYOUT_Y_ENSF='64'
export WRTCMP_write_groups_ENSF='1'
export WRTCMP_write_tasks_per_group_ENSF='128'
export WRTCMP_write_groups='1'
export WRTCMP_write_tasks_per_group='128'
export WRTCMP_lon_lwr_left='-61.0'
export WRTCMP_lat_lwr_left='-37.0'
export WRTCMP_lon_upr_rght='61.0'
export WRTCMP_lat_upr_rght='37.0'
export NNODES_ANALYSIS_GSI='1'
export PPN_ANALYSIS_GSI='16'
export TPP_ANALYSIS_GSI='8'
export DO_SMOKE_DUST='FALSE'
export DO_ENS_BLENDING='TRUE'
EOF
      ;;
  esac

  # Retro overrides: where the retros differ from workflow.conf_dev on purpose
  echo "# ---- RRFS_NA_3km retro overrides"
  cat <<'EOF'
# The retro fix tree is outside the repo, so the ex-scripts' ${HOMErrfs}/fix/lam default misses it
export FIXLAM="${FIXrrfs}/lam/RRFS_NA_3km"
EOF
  if [ "$1" = "ensf" ]; then
    cat <<'EOF'
# The dev ensf layout (50 x 64 for every member) does not match the per-member stochastic
# physics namelists, which are 40 x 72 for members 1 and 4 and 44 x 72 for 2, 3 and 5, so the
# model aborts with "at least one pe in pelist is not used by any tile". workflow.conf_prod agrees
# with them, so take its layout; LAYOUT_X_ENSF_LARGER is the value members 2, 3 and 5 use.
export LAYOUT_X_ENSF='40'
export LAYOUT_X_ENSF_LARGER='44'
export LAYOUT_Y_ENSF='72'
EOF
  fi
  # Ursa nodes have less memory than WCOSS2's, so the forecasts run fewer ranks per node.
  if [ "${MACHINE}" = "URSA" ]; then
    case $1 in
      det) cat <<'EOF'
# An Ursa node has 360 GB for 192 cores, against 500 GB on WCOSS2, so 64 forecast ranks per node
# leaves the write tasks short and they are OOM-killed. 48 per node restores ~7.5 GB per rank;
# the rank count itself comes from the layout and does not change (see the ecf cards' --nodes).
export PPN_FORECAST='48'
# Even at 48 per node the production forecast's write ranks run out of memory as output builds up.
# One write group of 768 instead of three of 192 quarters what each write rank holds and keeps a
# single output copy in flight; the rank count is unchanged, so the job still fits in 74 nodes.
export WRTCMP_write_groups='1'
export WRTCMP_write_tasks_per_group='768'
export WRTCMP_write_groups_18H='1'
export WRTCMP_write_tasks_per_group_18H='768'
export WRTCMP_write_groups_LONG='1'
export WRTCMP_write_tasks_per_group_LONG='768'
EOF
        ;;
      enkf) cat <<'EOF'
# An EnKF member spreads the same domain over 704 ranks against 1856 for the deterministic
# spinup, so each rank holds far more and needs 24 per node (see the member cards' --nodes).
export PPN_FORECAST='24'
EOF
        ;;
      ensf) cat <<'EOF'
# A 60 h member OOM-killed a write rank at hour 58 with one group of 128, the same way the
# deterministic forecast did: the write ranks fill as output accumulates. Doubling the group
# halves what each one holds. 2880 or 3168 compute plus 256 write at 48 per node is 66 or 72
# nodes, inside the 75-node cap.
export WRTCMP_write_tasks_per_group_ENSF='256'
export PPN_FORECAST='48'
EOF
        ;;
    esac
  fi
}

# Job sizes: none. The ecf cards are sized for this domain.
DOMAIN_SBATCH=()
