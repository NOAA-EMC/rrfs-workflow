#
#-----------------------------------------------------------------------
#
# This file defines and then calls a function that sets grid parameters
# for the specified predefined grid.
#
#-----------------------------------------------------------------------
#
function set_predef_grid_params() {
#
#-----------------------------------------------------------------------
#
# Get the full path to the file in which this script/function is located
# (scrfunc_fp), the name of that file (scrfunc_fn), and the directory in
# which the file is located (scrfunc_dir).
#
#-----------------------------------------------------------------------
#
local scrfunc_fp=$( readlink -f "${BASH_SOURCE[0]}" )
local scrfunc_fn=$( basename "${scrfunc_fp}" )
local scrfunc_dir=$( dirname "${scrfunc_fp}" )
#
#-----------------------------------------------------------------------
#
# Get the name of this function.
#
#-----------------------------------------------------------------------
#
local func_name="${FUNCNAME[0]}"
#
#-----------------------------------------------------------------------
#
# Set grid and other parameters according to the value of the predefined
# domain (PREDEF_GRID_NAME).  Note that the code will enter this script
# only if PREDEF_GRID_NAME has a valid (and non-empty) value.
#
####################
# The following comments need to be updated:
####################
#
# 1) Reset the experiment title (expt_title).
# 2) Reset the grid parameters.
# 3) If the write component is to be used (i.e. QUILTING is set to
#    "TRUE") and the variable WRTCMP_PARAMS_TMPL_FN containing the name
#    of the write-component template file is unset or empty, set that
#    filename variable to the appropriate preexisting template file.
#
# For the predefined domains, we determine the starting and ending indi-
# ces of the regional grid within tile 6 by specifying margins (in units
# of number of cells on tile 6) between the boundary of tile 6 and that
# of the regional grid (tile 7) along the left, right, bottom, and top
# portions of these boundaries.  Note that we do not use "west", "east",
# "south", and "north" here because the tiles aren't necessarily orient-
# ed such that the left boundary segment corresponds to the west edge,
# etc.  The widths of these margins (in units of number of cells on tile
# 6) are specified via the parameters
#
#   num_margin_cells_T6_left
#   num_margin_cells_T6_right
#   num_margin_cells_T6_bottom
#   num_margin_cells_T6_top
#
# where the "_T6" in these names is used to indicate that the cell count
# is on tile 6, not tile 7.
#
# Note that we must make the margins wide enough (by making the above
# four parameters large enough) such that a region of halo cells around
# the boundary of the regional grid fits into the margins, i.e. such
# that the halo does not overrun the boundary of tile 6.  (The halo is
# added later in another script; its function is to feed in boundary
# conditions to the regional grid.)  Currently, a halo of 5 regional
# grid cells is used around the regional grid.  Setting num_margin_-
# cells_T6_... to at least 10 leaves enough room for this halo.
#
#-----------------------------------------------------------------------
#
case ${PREDEF_GRID_NAME} in
#
#-----------------------------------------------------------------------
#
# The RRFS CONUS domain with ~25km cells.
#
#-----------------------------------------------------------------------
#
"RRFS_CONUS_25km")

  GRID_GEN_METHOD="ESGgrid"
  ESGgrid_LON_CTR="-97.5"
  ESGgrid_LAT_CTR="38.5"
  ESGgrid_DELX="25000.0"
  ESGgrid_DELY="25000.0"
  ESGgrid_NX="219"
  ESGgrid_NY="131"
  ESGgrid_PAZI="0.0"
  ESGgrid_WIDE_HALO_WIDTH="6"
  DT_ATMOS="${DT_ATMOS:-150}"
  LAYOUT_X="${LAYOUT_X:-5}"
  LAYOUT_Y="${LAYOUT_Y:-2}"
  BLOCKSIZE="${BLOCKSIZE:-40}"

  if [ "$QUILTING" = "TRUE" ]; then
    WRTCMP_write_groups="${WRTCMP_write_groups:-1}"
    WRTCMP_write_tasks_per_group=$(( 1*LAYOUT_Y ))
    WRTCMP_output_grid="${WRTCMP_output_grid:-lambert_conformal}"
    if [ "${WRTCMP_output_grid}" = "lambert_conformal" ]; then
      WRTCMP_cen_lon="${ESGgrid_LON_CTR}"
      WRTCMP_cen_lat="${ESGgrid_LAT_CTR}"
      WRTCMP_stdlat1="${ESGgrid_LAT_CTR}"
      WRTCMP_stdlat2="${ESGgrid_LAT_CTR}"
      WRTCMP_nx="217"
      WRTCMP_ny="128"
      WRTCMP_lon_lwr_left="-122.719528"
      WRTCMP_lat_lwr_left="21.138123"
      WRTCMP_dx="${ESGgrid_DELX}"
      WRTCMP_dy="${ESGgrid_DELY}"
    elif [ "${WRTCMP_output_grid}" = "rotated_latlon" ] || [ "${WRTCMP_output_grid}" = "regional_latlon" ]; then
      if [ "${WRTCMP_output_grid}" = "rotated_latlon" ]; then
        WRTCMP_cen_lon="${ESGgrid_LON_CTR}"
        WRTCMP_cen_lat="${ESGgrid_LAT_CTR}"
      fi
      WRTCMP_lon_lwr_left="-122.719528"
      WRTCMP_lat_lwr_left="21.138123"
      WRTCMP_lon_upr_rght="-72.280472"
      WRTCMP_lat_upr_rght="55.861877"
      WRTCMP_dlon="0.112412"
      WRTCMP_dlat="0.112412"
    else
      err_exit "The parameters for this output grid are not set."
    fi
  fi
  ;;
#
#-----------------------------------------------------------------------
#
# The RRFS CONUS domain with ~13km cells.
#
#-----------------------------------------------------------------------
#
"RRFS_CONUS_13km")

  GRID_GEN_METHOD="ESGgrid"
  ESGgrid_LON_CTR="-97.5"
  ESGgrid_LAT_CTR="38.5"
  ESGgrid_DELX="13000.0"
  ESGgrid_DELY="13000.0"
  ESGgrid_NX="420"
  ESGgrid_NY="252"
  ESGgrid_PAZI="0.0"
  ESGgrid_WIDE_HALO_WIDTH="6"
  DT_ATMOS="${DT_ATMOS:-75}"
  LAYOUT_X="${LAYOUT_X:-16}"
  LAYOUT_Y="${LAYOUT_Y:-10}"
  BLOCKSIZE="${BLOCKSIZE:-32}"

  if [ "$QUILTING" = "TRUE" ]; then
    WRTCMP_write_groups="${WRTCMP_write_groups:-1}"
    WRTCMP_write_tasks_per_group="${WRTCMP_write_tasks_per_group:-10}"
    WRTCMP_output_grid="${WRTCMP_output_grid:-lambert_conformal}"
    WRTCMP_cen_lon="${ESGgrid_LON_CTR}"
    WRTCMP_cen_lat="${ESGgrid_LAT_CTR}"
    WRTCMP_stdlat1="${ESGgrid_LAT_CTR}"
    WRTCMP_stdlat2="${ESGgrid_LAT_CTR}"
    WRTCMP_nx="416"
    WRTCMP_ny="245"
    WRTCMP_lon_lwr_left="-121.719528"
    WRTCMP_lat_lwr_left="21.138123"
    WRTCMP_dx="${ESGgrid_DELX}"
    WRTCMP_dy="${ESGgrid_DELY}"
  fi
  ;;
#
#-----------------------------------------------------------------------
#
# The RRFS CONUS domain with ~3km cells
#
#-----------------------------------------------------------------------
#
"RRFS_CONUS_3km")

  GRID_GEN_METHOD="ESGgrid"
  ESGgrid_LON_CTR="-97.5"
  ESGgrid_LAT_CTR="38.5"
  ESGgrid_DELX="3000.0"
  ESGgrid_DELY="3000.0"
  ESGgrid_NX="1820"
  ESGgrid_NY="1092"
  ESGgrid_PAZI="0.0"
  ESGgrid_WIDE_HALO_WIDTH="6"
  DT_ATMOS="${DT_ATMOS:-36}"
  LAYOUT_X="${LAYOUT_X:-30}"
  LAYOUT_Y="${LAYOUT_Y:-16}"
  BLOCKSIZE="${BLOCKSIZE:-32}"

  if [ "$QUILTING" = "TRUE" ]; then
    WRTCMP_write_groups="${WRTCMP_write_groups:-1}"
    WRTCMP_write_tasks_per_group=$(( 2*LAYOUT_Y ))
    WRTCMP_output_grid="${WRTCMP_output_grid:-lambert_conformal}"
    WRTCMP_cen_lon="${ESGgrid_LON_CTR}"
    WRTCMP_cen_lat="${ESGgrid_LAT_CTR}"
    WRTCMP_stdlat1="${ESGgrid_LAT_CTR}"
    WRTCMP_stdlat2="${ESGgrid_LAT_CTR}"
    WRTCMP_nx="1799"
    WRTCMP_ny="1059"
    WRTCMP_lon_lwr_left="-122.719528"
    WRTCMP_lat_lwr_left="21.138123"
    WRTCMP_dx="${ESGgrid_DELX}"
    WRTCMP_dy="${ESGgrid_DELY}"
  fi
  ;;
#
#-----------------------------------------------------------------------
#
# The RRFS CONUS domain with ~3km cells (C3357, HRRRIC)
#
#-----------------------------------------------------------------------
#
"RRFS_CONUS_3km_HRRRIC")

  GRID_GEN_METHOD="ESGgrid"
  ESGgrid_LON_CTR="-97.5"
  ESGgrid_LAT_CTR="38.5"
  ESGgrid_DELX="3000.0"
  ESGgrid_DELY="3000.0"
  ESGgrid_NX="1748"
  ESGgrid_NY="1038"
  ESGgrid_PAZI="0.0"
  ESGgrid_WIDE_HALO_WIDTH="6"
  DT_ATMOS="${DT_ATMOS:-40}"
  LAYOUT_X="${LAYOUT_X:-30}"
  LAYOUT_Y="${LAYOUT_Y:-16}"
  BLOCKSIZE="${BLOCKSIZE:-32}"

  if [ "$QUILTING" = "TRUE" ]; then
    WRTCMP_write_groups="1"
    WRTCMP_write_tasks_per_group=$(( 1*LAYOUT_Y ))
    WRTCMP_output_grid="${WRTCMP_output_grid:-lambert_conformal}"
    WRTCMP_cen_lon="${ESGgrid_LON_CTR}"
    WRTCMP_cen_lat="${ESGgrid_LAT_CTR}"
    WRTCMP_stdlat1="${ESGgrid_LAT_CTR}"
    WRTCMP_stdlat2="${ESGgrid_LAT_CTR}"
    WRTCMP_nx="1746"
    WRTCMP_ny="1014"
    WRTCMP_lon_lwr_left="-122.17364391"
    WRTCMP_lat_lwr_left="21.88588562"
    WRTCMP_dx="${ESGgrid_DELX}"
    WRTCMP_dy="${ESGgrid_DELY}"
  fi
  ;;
#
#-----------------------------------------------------------------------
#
# The RRFS SUBCONUS domain with ~3km cells.
#
#-----------------------------------------------------------------------
#
"RRFS_SUBCONUS_3km")

  GRID_GEN_METHOD="ESGgrid"
  ESGgrid_LON_CTR="-97.5"
  ESGgrid_LAT_CTR="35.0"
  ESGgrid_DELX="3000.0"
  ESGgrid_DELY="3000.0"
  ESGgrid_PAZI="0.0"
  ESGgrid_NX="840"
  ESGgrid_NY="600"
  ESGgrid_WIDE_HALO_WIDTH="6"
  DT_ATMOS="${DT_ATMOS:-40}"
  LAYOUT_X="${LAYOUT_X:-30}"
  LAYOUT_Y="${LAYOUT_Y:-24}"
  BLOCKSIZE="${BLOCKSIZE:-35}"

  if [ "$QUILTING" = "TRUE" ]; then
    WRTCMP_write_groups="1"
    WRTCMP_write_tasks_per_group=$(( 1*LAYOUT_Y ))
    WRTCMP_output_grid="${WRTCMP_output_grid:-lambert_conformal}"
    WRTCMP_cen_lon="${ESGgrid_LON_CTR}"
    WRTCMP_cen_lat="${ESGgrid_LAT_CTR}"
    WRTCMP_stdlat1="${ESGgrid_LAT_CTR}"
    WRTCMP_stdlat2="${ESGgrid_LAT_CTR}"
    WRTCMP_nx="837"
    WRTCMP_ny="595"
    WRTCMP_lon_lwr_left="-109.97410429"
    WRTCMP_lat_lwr_left="26.31459843"
    WRTCMP_dx="${ESGgrid_DELX}"
    WRTCMP_dy="${ESGgrid_DELY}"
  fi
  ;;
#
#-----------------------------------------------------------------------
#
# The RRFS Alaska domain with ~13km cells.
#
# Note:
# This grid has not been thoroughly tested (as of 20201027).
#
#-----------------------------------------------------------------------
#
"RRFS_AK_13km")

  GRID_GEN_METHOD="ESGgrid"
  ESGgrid_LON_CTR="-161.5"
  ESGgrid_LAT_CTR="63.0"
  ESGgrid_DELX="13000.0"
  ESGgrid_DELY="13000.0"
  ESGgrid_PAZI="0.0"
  ESGgrid_NX="320"
  ESGgrid_NY="240"
  ESGgrid_WIDE_HALO_WIDTH="6"
  DT_ATMOS="${DT_ATMOS:-10}"
  LAYOUT_X="${LAYOUT_X:-16}"
  LAYOUT_Y="${LAYOUT_Y:-12}"
  BLOCKSIZE="${BLOCKSIZE:-40}"

  if [ "$QUILTING" = "TRUE" ]; then
    WRTCMP_write_groups="1"
    WRTCMP_write_tasks_per_group=$(( 1*LAYOUT_Y ))
    WRTCMP_output_grid="${WRTCMP_output_grid:-lambert_conformal}"
    WRTCMP_cen_lon="${ESGgrid_LON_CTR}"
    WRTCMP_cen_lat="${ESGgrid_LAT_CTR}"
    WRTCMP_stdlat1="${ESGgrid_LAT_CTR}"
    WRTCMP_stdlat2="${ESGgrid_LAT_CTR}"
    WRTCMP_nx="318"
    WRTCMP_ny="234"
    WRTCMP_lon_lwr_left="172.23339164"
    WRTCMP_lat_lwr_left="45.77691870"
    WRTCMP_dx="${ESGgrid_DELX}"
    WRTCMP_dy="${ESGgrid_DELY}"
  fi
  ;;
#
#-----------------------------------------------------------------------
#
# The RRFS Alaska domain with ~3km cells.
#
# Note:
# This grid has not been thoroughly tested (as of 20201027).
#
#-----------------------------------------------------------------------
#
"RRFS_AK_3km")

  GRID_GEN_METHOD="ESGgrid"
  ESGgrid_LON_CTR="-161.5"
  ESGgrid_LAT_CTR="63.0"
  ESGgrid_DELX="3000.0"
  ESGgrid_DELY="3000.0"
  ESGgrid_NX="1380"
  ESGgrid_NY="1020"
  ESGgrid_PAZI="0.0"
  ESGgrid_WIDE_HALO_WIDTH="6"
  DT_ATMOS="${DT_ATMOS:-10}"
  LAYOUT_X="${LAYOUT_X:-30}"
  LAYOUT_Y="${LAYOUT_Y:-17}"
  BLOCKSIZE="${BLOCKSIZE:-40}"

  if [ "$QUILTING" = "TRUE" ]; then
    WRTCMP_write_groups="1"
    WRTCMP_write_tasks_per_group=$(( 1*LAYOUT_Y ))
    WRTCMP_output_grid="${WRTCMP_output_grid:-lambert_conformal}"
    WRTCMP_cen_lon="${ESGgrid_LON_CTR}"
    WRTCMP_cen_lat="${ESGgrid_LAT_CTR}"
    WRTCMP_stdlat1="${ESGgrid_LAT_CTR}"
    WRTCMP_stdlat2="${ESGgrid_LAT_CTR}"
    WRTCMP_nx="1379"
    WRTCMP_ny="1003"
    WRTCMP_lon_lwr_left="-187.89737923"
    WRTCMP_lat_lwr_left="45.84576053"
    WRTCMP_dx="${ESGgrid_DELX}"
    WRTCMP_dy="${ESGgrid_DELY}"
  fi
  ;;
#
#-----------------------------------------------------------------------
#
# A CONUS domain of GFDLgrid type with ~25km cells.
#
# Note:
# This grid is larger than the HRRRX domain and thus cannot be initialized
# using the HRRRX.
#
#-----------------------------------------------------------------------
#
"CONUS_25km_GFDLgrid")

  GRID_GEN_METHOD="GFDLgrid"
  GFDLgrid_LON_T6_CTR="-97.5"
  GFDLgrid_LAT_T6_CTR="38.5"
  GFDLgrid_STRETCH_FAC="1.4"
  GFDLgrid_RES="96"
  GFDLgrid_REFINE_RATIO="3"
  num_margin_cells_T6_left="12"
  GFDLgrid_ISTART_OF_RGNL_DOM_ON_T6G=$(( num_margin_cells_T6_left + 1 ))
  num_margin_cells_T6_right="12"
  GFDLgrid_IEND_OF_RGNL_DOM_ON_T6G=$(( GFDLgrid_RES - num_margin_cells_T6_right ))
  num_margin_cells_T6_bottom="16"
  GFDLgrid_JSTART_OF_RGNL_DOM_ON_T6G=$(( num_margin_cells_T6_bottom + 1 ))
  num_margin_cells_T6_top="16"
  GFDLgrid_JEND_OF_RGNL_DOM_ON_T6G=$(( GFDLgrid_RES - num_margin_cells_T6_top ))
  GFDLgrid_USE_GFDLgrid_RES_IN_FILENAMES="TRUE"
  DT_ATMOS="${DT_ATMOS:-225}"
  LAYOUT_X="${LAYOUT_X:-6}"
  LAYOUT_Y="${LAYOUT_Y:-4}"
  BLOCKSIZE="${BLOCKSIZE:-36}"

  if [ "$QUILTING" = "TRUE" ]; then
    WRTCMP_write_groups="1"
    WRTCMP_write_tasks_per_group=$(( 1*LAYOUT_Y ))
    WRTCMP_output_grid="rotated_latlon"
    WRTCMP_cen_lon="${GFDLgrid_LON_T6_CTR}"
    WRTCMP_cen_lat="${GFDLgrid_LAT_T6_CTR}"
    WRTCMP_lon_lwr_left="-24.40085141"
    WRTCMP_lat_lwr_left="-19.65624142"
    WRTCMP_lon_upr_rght="24.40085141"
    WRTCMP_lat_upr_rght="19.65624142"
    WRTCMP_dlon="0.22593381"
    WRTCMP_dlat="0.22593381"
  fi
  ;;
#
#-----------------------------------------------------------------------
#
# A CONUS domain of GFDLgrid type with ~3km cells.
#
# Note:
# This grid is larger than the HRRRX domain and thus cannot be initialized
# using the HRRRX.
#
#-----------------------------------------------------------------------
#
"CONUS_3km_GFDLgrid")

  GRID_GEN_METHOD="GFDLgrid"
  GFDLgrid_LON_T6_CTR="-97.5"
  GFDLgrid_LAT_T6_CTR="38.5"
  GFDLgrid_STRETCH_FAC="1.5"
  GFDLgrid_RES="768"
  GFDLgrid_REFINE_RATIO="3"
  num_margin_cells_T6_left="69"
  GFDLgrid_ISTART_OF_RGNL_DOM_ON_T6G=$(( num_margin_cells_T6_left + 1 ))
  num_margin_cells_T6_right="69"
  GFDLgrid_IEND_OF_RGNL_DOM_ON_T6G=$(( GFDLgrid_RES - num_margin_cells_T6_right ))
  num_margin_cells_T6_bottom="164"
  GFDLgrid_JSTART_OF_RGNL_DOM_ON_T6G=$(( num_margin_cells_T6_bottom + 1 ))
  num_margin_cells_T6_top="164"
  GFDLgrid_JEND_OF_RGNL_DOM_ON_T6G=$(( GFDLgrid_RES - num_margin_cells_T6_top ))
  GFDLgrid_USE_GFDLgrid_RES_IN_FILENAMES="TRUE"
  DT_ATMOS="${DT_ATMOS:-18}"
  LAYOUT_X="${LAYOUT_X:-30}"
  LAYOUT_Y="${LAYOUT_Y:-22}"
  BLOCKSIZE="${BLOCKSIZE:-35}"

  if [ "$QUILTING" = "TRUE" ]; then
    WRTCMP_write_groups="1"
    WRTCMP_write_tasks_per_group=$(( 1*LAYOUT_Y ))
    WRTCMP_output_grid="rotated_latlon"
    WRTCMP_cen_lon="${GFDLgrid_LON_T6_CTR}"
    WRTCMP_cen_lat="${GFDLgrid_LAT_T6_CTR}"
    WRTCMP_lon_lwr_left="-25.23144805"
    WRTCMP_lat_lwr_left="-15.82130419"
    WRTCMP_lon_upr_rght="25.23144805"
    WRTCMP_lat_upr_rght="15.82130419"
    WRTCMP_dlon="0.02665763"
    WRTCMP_dlat="0.02665763"
  fi
  ;;
#
#-----------------------------------------------------------------------
#
# EMC's Alaska grid.
#
#-----------------------------------------------------------------------
#
"EMC_AK")

  GRID_GEN_METHOD="ESGgrid"
  ESGgrid_LON_CTR="-153.0"
  ESGgrid_LAT_CTR="61.0"
  ESGgrid_DELX="3000.0"
  ESGgrid_DELY="3000.0"
  ESGgrid_NX="1344" # Supergrid value 2704
  ESGgrid_NY="1152" # Supergrid value 2320
  ESGgrid_PAZI="0.0"
  ESGgrid_WIDE_HALO_WIDTH="6"
  DT_ATMOS="${DT_ATMOS:-18}"
  LAYOUT_X="${LAYOUT_X:-28}"
  LAYOUT_Y="${LAYOUT_Y:-16}"
  BLOCKSIZE="${BLOCKSIZE:-24}"

  if [ "$QUILTING" = "TRUE" ]; then
    WRTCMP_write_groups="1"
    WRTCMP_write_tasks_per_group="24"
    WRTCMP_output_grid="lambert_conformal"
    WRTCMP_cen_lon="${ESGgrid_LON_CTR}"
    WRTCMP_cen_lat="${ESGgrid_LAT_CTR}"
    WRTCMP_stdlat1="${ESGgrid_LAT_CTR}"
    WRTCMP_stdlat2="${ESGgrid_LAT_CTR}"
    WRTCMP_nx="1344"
    WRTCMP_ny="1152"
    WRTCMP_lon_lwr_left="-177.0"
    WRTCMP_lat_lwr_left="42.5"
    WRTCMP_dx="$ESGgrid_DELX"
    WRTCMP_dy="$ESGgrid_DELY"
  fi
  ;;
#
#-----------------------------------------------------------------------
#
# EMC's Hawaii grid.
#
#-----------------------------------------------------------------------
#
"EMC_HI")

  GRID_GEN_METHOD="ESGgrid"
  ESGgrid_LON_CTR="-157.0"
  ESGgrid_LAT_CTR="20.0"
  ESGgrid_DELX="3000.0"
  ESGgrid_DELY="3000.0"
  ESGgrid_PAZI="0.0"
  ESGgrid_NX="432" # Supergrid value 880
  ESGgrid_NY="360" # Supergrid value 736
  ESGgrid_WIDE_HALO_WIDTH="6"
  DT_ATMOS="${DT_ATMOS:-18}"
  LAYOUT_X="${LAYOUT_X:-8}"
  LAYOUT_Y="${LAYOUT_Y:-8}"
  BLOCKSIZE="${BLOCKSIZE:-27}"

  if [ "$QUILTING" = "TRUE" ]; then
    WRTCMP_write_groups="1"
    WRTCMP_write_tasks_per_group="8"
    WRTCMP_output_grid="lambert_conformal"
    WRTCMP_cen_lon="${ESGgrid_LON_CTR}"
    WRTCMP_cen_lat="${ESGgrid_LAT_CTR}"
    WRTCMP_stdlat1="${ESGgrid_LAT_CTR}"
    WRTCMP_stdlat2="${ESGgrid_LAT_CTR}"
    WRTCMP_nx="420"
    WRTCMP_ny="348"
    WRTCMP_lon_lwr_left="-162.8"
    WRTCMP_lat_lwr_left="15.2"
    WRTCMP_dx="$ESGgrid_DELX"
    WRTCMP_dy="$ESGgrid_DELY"
  fi
  ;;
#
#-----------------------------------------------------------------------
#
# EMC's Puerto Rico grid.
#
#-----------------------------------------------------------------------
#
"EMC_PR")

  GRID_GEN_METHOD="ESGgrid"
  ESGgrid_LON_CTR="-69.0"
  ESGgrid_LAT_CTR="18.0"
  ESGgrid_DELX="3000.0"
  ESGgrid_DELY="3000.0"
  ESGgrid_NX="576" # Supergrid value 1168
  ESGgrid_NY="432" # Supergrid value 880
  ESGgrid_PAZI="0.0"
  ESGgrid_WIDE_HALO_WIDTH="6"
  DT_ATMOS="${DT_ATMOS:-18}"
  LAYOUT_X="${LAYOUT_X:-16}"
  LAYOUT_Y="${LAYOUT_Y:-8}"
  BLOCKSIZE="${BLOCKSIZE:-24}"
  if [ "$QUILTING" = "TRUE" ]; then
    WRTCMP_write_groups="1"
    WRTCMP_write_tasks_per_group="24"
    WRTCMP_output_grid="lambert_conformal"
    WRTCMP_cen_lon="${ESGgrid_LON_CTR}"
    WRTCMP_cen_lat="${ESGgrid_LAT_CTR}"
    WRTCMP_stdlat1="${ESGgrid_LAT_CTR}"
    WRTCMP_stdlat2="${ESGgrid_LAT_CTR}"
    WRTCMP_nx="576"
    WRTCMP_ny="432"
    WRTCMP_lon_lwr_left="-77"
    WRTCMP_lat_lwr_left="12"
    WRTCMP_dx="$ESGgrid_DELX"
    WRTCMP_dy="$ESGgrid_DELY"
  fi
  ;;
#
#-----------------------------------------------------------------------
#
# EMC's Guam grid.
#
#-----------------------------------------------------------------------
#
"EMC_GU")

  GRID_GEN_METHOD="ESGgrid"
  ESGgrid_LON_CTR="146.0"
  ESGgrid_LAT_CTR="15.0"
  ESGgrid_DELX="3000.0"
  ESGgrid_DELY="3000.0"
  ESGgrid_NX="432" # Supergrid value 880
  ESGgrid_NY="360" # Supergrid value 736
  ESGgrid_PAZI="0.0"
  ESGgrid_WIDE_HALO_WIDTH="6"
  DT_ATMOS="${DT_ATMOS:-18}"
  LAYOUT_X="${LAYOUT_X:-16}"
  LAYOUT_Y="${LAYOUT_Y:-12}"
  BLOCKSIZE="${BLOCKSIZE:-27}"

  if [ "$QUILTING" = "TRUE" ]; then
    WRTCMP_write_groups="1"
    WRTCMP_write_tasks_per_group="24"
    WRTCMP_output_grid="lambert_conformal"
    WRTCMP_cen_lon="${ESGgrid_LON_CTR}"
    WRTCMP_cen_lat="${ESGgrid_LAT_CTR}"
    WRTCMP_stdlat1="${ESGgrid_LAT_CTR}"
    WRTCMP_stdlat2="${ESGgrid_LAT_CTR}"
    WRTCMP_nx="420"
    WRTCMP_ny="348"
    WRTCMP_lon_lwr_left="140"
    WRTCMP_lat_lwr_left="10"
    WRTCMP_dx="$ESGgrid_DELX"
    WRTCMP_dy="$ESGgrid_DELY"
  fi
  ;;
#
#-----------------------------------------------------------------------
#
# Emulation of the HAFS v0.A grid at 25 km.
#
#-----------------------------------------------------------------------
#
"GSL_HAFSV0.A_25km")

  GRID_GEN_METHOD="ESGgrid"
  ESGgrid_LON_CTR="-62.0"
  ESGgrid_LAT_CTR="22.0"
  ESGgrid_DELX="25000.0"
  ESGgrid_DELY="25000.0"
  ESGgrid_NX="345"
  ESGgrid_NY="230"
  ESGgrid_PAZI="0.0"
  ESGgrid_WIDE_HALO_WIDTH="6"
  DT_ATMOS="${DT_ATMOS:-300}"
  LAYOUT_X="${LAYOUT_X:-5}"
  LAYOUT_Y="${LAYOUT_Y:-5}"
  BLOCKSIZE="${BLOCKSIZE:-6}"

  if [ "$QUILTING" = "TRUE" ]; then
    WRTCMP_write_groups="1"
    WRTCMP_write_tasks_per_group="32"
    WRTCMP_output_grid="regional_latlon"
    WRTCMP_cen_lon="${ESGgrid_LON_CTR}"
    WRTCMP_cen_lat="25.0"
    WRTCMP_lon_lwr_left="-114.5"
    WRTCMP_lat_lwr_left="-5.0"
    WRTCMP_lon_upr_rght="-9.5"
    WRTCMP_lat_upr_rght="55.0"
    WRTCMP_dlon="0.25"
    WRTCMP_dlat="0.25"
  fi
  ;;
#
#-----------------------------------------------------------------------
#
# Emulation of the HAFS v0.A grid at 13 km.
#
#-----------------------------------------------------------------------
#
"GSL_HAFSV0.A_13km")

  GRID_GEN_METHOD="ESGgrid"
  ESGgrid_LON_CTR="-62.0"
  ESGgrid_LAT_CTR="22.0"
  ESGgrid_DELX="13000.0"
  ESGgrid_DELY="13000.0"
  ESGgrid_NX="665"
  ESGgrid_NY="444"
  ESGgrid_PAZI="0.0"
  ESGgrid_WIDE_HALO_WIDTH="6"
  DT_ATMOS="${DT_ATMOS:-180}"
  LAYOUT_X="${LAYOUT_X:-19}"
  LAYOUT_Y="${LAYOUT_Y:-12}"
  BLOCKSIZE="${BLOCKSIZE:-35}"

  if [ "$QUILTING" = "TRUE" ]; then
    WRTCMP_write_groups="1"
    WRTCMP_write_tasks_per_group="32"
    WRTCMP_output_grid="regional_latlon"
    WRTCMP_cen_lon="${ESGgrid_LON_CTR}"
    WRTCMP_cen_lat="25.0"
    WRTCMP_lon_lwr_left="-114.5"
    WRTCMP_lat_lwr_left="-5.0"
    WRTCMP_lon_upr_rght="-9.5"
    WRTCMP_lat_upr_rght="55.0"
    WRTCMP_dlon="0.13"
    WRTCMP_dlat="0.13"
  fi
  ;;
#
#-----------------------------------------------------------------------
#
# Emulation of the HAFS v0.A grid at 3 km.
#
#-----------------------------------------------------------------------
#
"GSL_HAFSV0.A_3km")

  GRID_GEN_METHOD="ESGgrid"
  ESGgrid_LON_CTR="-62.0"
  ESGgrid_LAT_CTR="22.0"
  ESGgrid_DELX="3000.0"
  ESGgrid_DELY="3000.0"
  ESGgrid_NX="2880"
  ESGgrid_NY="1920"
  ESGgrid_PAZI="0.0"
  ESGgrid_WIDE_HALO_WIDTH="6"
  DT_ATMOS="${DT_ATMOS:-40}"
  LAYOUT_X="${LAYOUT_X:-32}"
  LAYOUT_Y="${LAYOUT_Y:-24}"
  BLOCKSIZE="${BLOCKSIZE:-32}"

  if [ "$QUILTING" = "TRUE" ]; then
    WRTCMP_write_groups="1"
    WRTCMP_write_tasks_per_group="32"
    WRTCMP_output_grid="regional_latlon"
    WRTCMP_cen_lon="${ESGgrid_LON_CTR}"
    WRTCMP_cen_lat="25.0"
    WRTCMP_lon_lwr_left="-114.5"
    WRTCMP_lat_lwr_left="-5.0"
    WRTCMP_lon_upr_rght="-9.5"
    WRTCMP_lat_upr_rght="55.0"
    WRTCMP_dlon="0.03"
    WRTCMP_dlat="0.03"
  fi
  ;;
#
#-----------------------------------------------------------------------
#
# 50-km HRRR Alaska grid.
#
#-----------------------------------------------------------------------
#
"GSD_HRRR_AK_50km")

  GRID_GEN_METHOD="ESGgrid"
  ESGgrid_LON_CTR="-163.5"
  ESGgrid_LAT_CTR="62.8"
  ESGgrid_DELX="50000.0"
  ESGgrid_DELY="50000.0"
  ESGgrid_NX="74"
  ESGgrid_NY="51"
  ESGgrid_PAZI="0.0"
  ESGgrid_WIDE_HALO_WIDTH="6"
  DT_ATMOS="${DT_ATMOS:-600}"
  LAYOUT_X="${LAYOUT_X:-2}"
  LAYOUT_Y="${LAYOUT_Y:-3}"
  BLOCKSIZE="${BLOCKSIZE:-37}"

  if [ "$QUILTING" = "TRUE" ]; then
    WRTCMP_write_groups="1"
    WRTCMP_write_tasks_per_group="1"
    WRTCMP_output_grid="lambert_conformal"
    WRTCMP_cen_lon="${ESGgrid_LON_CTR}"
    WRTCMP_cen_lat="${ESGgrid_LAT_CTR}"
    WRTCMP_stdlat1="${ESGgrid_LAT_CTR}"
    WRTCMP_stdlat2="${ESGgrid_LAT_CTR}"
    WRTCMP_nx="70"
    WRTCMP_ny="45"
    WRTCMP_lon_lwr_left="172.0"
    WRTCMP_lat_lwr_left="49.0"
    WRTCMP_dx="${ESGgrid_DELX}"
    WRTCMP_dy="${ESGgrid_DELY}"
  fi
  ;;
#
#-----------------------------------------------------------------------
#
# Emulation of GSD's RAP domain with ~13km cell size.
#
#-----------------------------------------------------------------------
#
"GSD_RAP13km")

  GRID_GEN_METHOD="ESGgrid"
  ESGgrid_LON_CTR="-106.0"
  ESGgrid_LAT_CTR="54.0"
  ESGgrid_DELX="13000.0"
  ESGgrid_DELY="13000.0"
  ESGgrid_NX="960"
  ESGgrid_NY="960"
  ESGgrid_PAZI="0.0"
  ESGgrid_WIDE_HALO_WIDTH="6"
  DT_ATMOS="${DT_ATMOS:-50}"
  LAYOUT_X="${LAYOUT_X:-16}"
  LAYOUT_Y="${LAYOUT_Y:-16}"
  BLOCKSIZE="${BLOCKSIZE:-30}"

  if [ "$QUILTING" = "TRUE" ]; then
    WRTCMP_write_groups="${WRTCMP_write_groups:-1}"
    WRTCMP_write_tasks_per_group="${WRTCMP_write_tasks_per_group:-16}"
    WRTCMP_output_grid="rotated_latlon"
    WRTCMP_cen_lon="${ESGgrid_LON_CTR}"
    WRTCMP_cen_lat="${ESGgrid_LAT_CTR}"
    WRTCMP_lon_lwr_left="-55.82538869"
    WRTCMP_lat_lwr_left="-48.57685654"
    WRTCMP_lon_upr_rght="55.82538869"
    WRTCMP_lat_upr_rght="48.57685654"
    WRTCMP_dlon="0.11691181"
    WRTCMP_dlat="0.11691181"
  fi
  ;;
#
#-----------------------------------------------------------------------
#
# 13-km AQM NA grid for Online-CMAQ.
#
#-----------------------------------------------------------------------
#
"AQM_NA_13km")

  GRID_GEN_METHOD="ESGgrid"
  ESGgrid_LON_CTR="-118.0"
  ESGgrid_LAT_CTR="50.0"
  ESGgrid_DELX="13000.0"
  ESGgrid_DELY="13000.0"
  ESGgrid_NX="800"
  ESGgrid_NY="544"
  ESGgrid_PAZI="0.0"
  ESGgrid_WIDE_HALO_WIDTH="6"
  DT_ATMOS="180"
  LAYOUT_X="50"
  LAYOUT_Y="34"
  BLOCKSIZE="16"
  if [ "$QUILTING" = "TRUE" ]; then
    WRTCMP_write_groups="${WRTCMP_write_groups:-2}"
    WRTCMP_write_tasks_per_group="${WRTCMP_write_tasks_per_group:-46}"
    WRTCMP_output_grid="${WRTCMP_output_grid:-rotated_latlon}"
    WRTCMP_cen_lon="-118.0"
    WRTCMP_cen_lat="50.0"
    WRTCMP_lon_lwr_left="-45.25"
    WRTCMP_lat_lwr_left="-28.5"
    WRTCMP_lon_upr_rght="45.25"
    WRTCMP_lat_upr_rght="28.5"
    WRTCMP_dlon="0.116908139"
    WRTCMP_dlat="0.116908139"
  fi
  ;;
#
#-----------------------------------------------------------------------
#
# The RRFS North America domain with ~3km cells.
#
#-----------------------------------------------------------------------
#
"RRFS_NA_3km")

  GRID_GEN_METHOD="ESGgrid"
  ESGgrid_LON_CTR="-112.5"
  ESGgrid_LAT_CTR="55.0"
  ESGgrid_DELX="3000.0"
  ESGgrid_DELY="3000.0"
  ESGgrid_NX=3950
  ESGgrid_NY=2700
  ESGgrid_PAZI="0.0"
  ESGgrid_WIDE_HALO_WIDTH="6"
  DT_ATMOS="${DT_ATMOS:-60}"
  LAYOUT_X="${LAYOUT_X:-40}"
  LAYOUT_Y="${LAYOUT_Y:-45}"
  BLOCKSIZE="${BLOCKSIZE:-28}"

  if [ "$QUILTING" = "TRUE" ]; then
    WRTCMP_write_groups="${WRTCMP_write_groups:-1}"
    WRTCMP_write_tasks_per_group="${WRTCMP_write_tasks_per_group:-50}"
    WRTCMP_output_grid="${WRTCMP_output_grid:-rotated_latlon}"
    if [ "${WRTCMP_output_grid}" = "rotated_latlon" ]; then
      WRTCMP_cen_lon="-113.0"
      WRTCMP_cen_lat="55.0"
      WRTCMP_lon_lwr_left="-61.0"
      WRTCMP_lat_lwr_left="-37.0"
      WRTCMP_lon_upr_rght="61.0"
      WRTCMP_lat_upr_rght="37.0"
      if [[ ${DO_ENSEMBLE}  == "TRUE" ]]; then
        if [[ ${DO_ENSFCST} != "TRUE" ]] ; then
          WRTCMP_lon_lwr_left="-0.1"
          WRTCMP_lat_lwr_left="-0.1"
          WRTCMP_lon_upr_rght="0.1"
          WRTCMP_lat_upr_rght="0.1"
        fi
      fi
      WRTCMP_dlon="0.025"
      WRTCMP_dlat="0.025"
    elif [ "${WRTCMP_output_grid}" = "regional_latlon" ]; then
      WRTCMP_lon_lwr_left="-135.0"
      WRTCMP_lat_lwr_left="22.0"
      WRTCMP_lon_upr_rght="-60.0"
      WRTCMP_lat_upr_rght="53.5"
      WRTCMP_dlon="0.03"
      WRTCMP_dlat="0.03"
    fi
  fi
  ;;
#
#-----------------------------------------------------------------------
#
# The RRFS Fire Weather domain with ~1.5km cells.
#
#-----------------------------------------------------------------------
#
"RRFS_FIREWX_1.5km")

  GRID_GEN_METHOD="ESGgrid"
  ESGgrid_LON_CTR="${CENTLON:--106.0}"
  ESGgrid_LAT_CTR="${CENTLAT:-39.2}"
  ESGgrid_DELX="1501.18"
  ESGgrid_DELY="1501.18"
  ESGgrid_NX=350
  ESGgrid_NY=350
  ESGgrid_PAZI="0.0"
  ESGgrid_WIDE_HALO_WIDTH="6"
  DT_ATMOS="${DT_ATMOS:-12}"
  LAYOUT_X="${LAYOUT_X:-14}"
  LAYOUT_Y="${LAYOUT_Y:-14}"
  BLOCKSIZE="${BLOCKSIZE:-32}"

  if [ "$QUILTING" = "TRUE" ]; then
    WRTCMP_write_groups="2"
    WRTCMP_write_tasks_per_group="$(( 2*LAYOUT_Y ))"
    WRTCMP_output_grid="rotated_latlon"
    WRTCMP_cen_lon="${CENTLON:--106.0}"
    WRTCMP_cen_lat="${CENTLAT:-39.2}"
    WRTCMP_lon_lwr_left="-2.5"
    WRTCMP_lat_lwr_left="-2.5"
    WRTCMP_lon_upr_rght="2.5"
    WRTCMP_lat_upr_rght="2.5"
    WRTCMP_dlon="0.0125"
    WRTCMP_dlat="0.0125"
  fi
  ;;

*)
  if [ "$QUILTING" = "TRUE" ]; then
    WRTCMP_write_groups="${WRTCMP_write_groups:-1}"
    WRTCMP_write_tasks_per_group="${WRTCMP_write_tasks_per_group:-20}"
  fi
  ;;

esac

}
#
#-----------------------------------------------------------------------
#
# Call the function defined above.
#
#-----------------------------------------------------------------------
#
set_predef_grid_params

