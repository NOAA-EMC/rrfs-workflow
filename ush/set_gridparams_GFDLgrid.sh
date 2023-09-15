#
#-----------------------------------------------------------------------
#
# This file defines and then calls a function that sets the parameters
# for a grid that is to be generated using the "GFDLgrid" grid genera-
# tion method (i.e. GRID_GEN_METHOD set to "GFDLgrid").
#
#-----------------------------------------------------------------------
#
function set_gridparams_GFDLgrid() {
#
#-----------------------------------------------------------------------
#
# Save current shell options (in a global array).  Then set new options
# for this script/function.
#
#-----------------------------------------------------------------------
#
  { save_shell_opts; set -u +x; } > /dev/null 2>&1
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
# Specify the set of valid argument names for this script/function.  
# Then process the arguments provided to this script/function (which 
# should consist of a set of name-value pairs of the form arg1="value1",
# etc).
#
#-----------------------------------------------------------------------
#
  local valid_args=( \
"lon_of_t6_ctr" \
"lat_of_t6_ctr" \
"res_of_t6g" \
"stretch_factor" \
"refine_ratio_t6g_to_t7g" \
"istart_of_t7_on_t6g" \
"iend_of_t7_on_t6g" \
"jstart_of_t7_on_t6g" \
"jend_of_t7_on_t6g" \
"output_varname_lon_of_t7_ctr" \
"output_varname_lat_of_t7_ctr" \
"output_varname_nx_of_t7_on_t7g" \
"output_varname_ny_of_t7_on_t7g" \
"output_varname_halo_width_on_t7g" \
"output_varname_stretch_factor" \
"output_varname_istart_of_t7_with_halo_on_t6sg" \
"output_varname_iend_of_t7_with_halo_on_t6sg" \
"output_varname_jstart_of_t7_with_halo_on_t6sg" \
"output_varname_jend_of_t7_with_halo_on_t6sg" \
  )
  process_args valid_args "$@"
#
#-----------------------------------------------------------------------
#
# Declare local variables.
#
#-----------------------------------------------------------------------
#
  local nx_of_t6_on_t6g \
        ny_of_t6_on_t6g \
        num_left_margin_cells_on_t6g \
        num_right_margin_cells_on_t6g \
        num_bot_margin_cells_on_t6g \
        num_top_margin_cells_on_t6g \
        lon_of_t7_ctr \
        lat_of_t7_ctr \
        istart_of_t7_on_t6sg \
        iend_of_t7_on_t6sg \
        jstart_of_t7_on_t6sg \
        jend_of_t7_on_t6sg \
        halo_width_on_t7g \
        halo_width_on_t6sg \
        istart_of_t7_with_halo_on_t6sg \
        iend_of_t7_with_halo_on_t6sg \
        jstart_of_t7_with_halo_on_t6sg \
        jend_of_t7_with_halo_on_t6sg \
        halo_width_on_t6sg \
        halo_width_on_t6g \
        halo_width_on_t7g \
        nx_of_t7_on_t6sg \
        nx_of_t7_on_t6g \
        nx_of_t7_on_t7g \
        ny_of_t7_on_t6sg \
        ny_of_t7_on_t6g \
        ny_of_t7_on_t7g \
        nx_of_t6_on_t6sg \
        ny_of_t6_on_t6sg \
        prime_factors_nx_of_t7_on_t7g \
        prime_factors_ny_of_t7_on_t7g \
        nx_of_t7_with_halo_on_t6sg \
        nx_of_t7_with_halo_on_t6g \
        nx_of_t7_with_halo_on_t7g \
        ny_of_t7_with_halo_on_t6sg \
        ny_of_t7_with_halo_on_t6g \
        ny_of_t7_with_halo_on_t7g
#
#-----------------------------------------------------------------------
#
# To simplify the grid setup, we require that tile 7 be centered on tile 
# 6.  Note that this is not really a restriction because tile 6 can al-
# ways be moved so that it is centered on tile 7 [the location of tile 6 
# doesn't really matter because for a regional setup, the forecast model 
# will only run on tile 7 (not on tiles 1-6)].
#
# We now check that tile 7 is centered on tile 6 by checking (1) that 
# the number of cells (on tile 6) between the left boundaries of these 
# two tiles is equal to that between their right boundaries and (2) that 
# the number of cells (on tile 6) between the bottom boundaries of these
# two tiles is equal to that between their top boundaries.  If not, we 
# print out an error message and exit.  If so, we set the longitude and 
# latitude of the center of tile 7 to those of tile 6 and continue.
#
#-----------------------------------------------------------------------
#
  nx_of_t6_on_t6g=${res_of_t6g}
  ny_of_t6_on_t6g=${res_of_t6g}

  num_left_margin_cells_on_t6g=$(( istart_of_t7_on_t6g - 1 ))
  num_right_margin_cells_on_t6g=$(( nx_of_t6_on_t6g - iend_of_t7_on_t6g )) 

  num_bot_margin_cells_on_t6g=$(( jstart_of_t7_on_t6g - 1 ))
  num_top_margin_cells_on_t6g=$(( ny_of_t6_on_t6g - jend_of_t7_on_t6g )) 

  lon_of_t7_ctr="${lon_of_t6_ctr}"
  lat_of_t7_ctr="${lat_of_t6_ctr}"
#
#-----------------------------------------------------------------------
#
# The grid generation script grid_gen_scr called below in turn calls the
# make_hgrid utility/executable to construct the regional grid.  make_-
# hgrid accepts as arguments the index limits (i.e. starting and ending
# indices) of the regional grid on the supergrid of the regional grid's
# parent tile.  The regional grid's parent tile is tile 6, and the su-
# pergrid of any given tile is defined as the grid obtained by doubling
# the number of cells in each direction on that tile's grid.  We will
# denote these index limits by
#
#   istart_of_t7_on_t6sg
#   iend_of_t7_on_t6sg
#   jstart_of_t7_on_t6sg
#   jend_of_t7_on_t6sg
#
# The "_T6SG" suffix in these names is used to indicate that the indices
# are on the supergrid of tile 6.  Recall, however, that we have as in-
# puts the index limits of the regional grid on the tile 6 grid, not its
# supergrid.  These are given by
#
#   istart_of_t7_on_t6g
#   iend_of_t7_on_t6g
#   jstart_of_t7_on_t6g
#   jend_of_t7_on_t6g
#
# We can obtain the former from the latter by recalling that the super-
# grid has twice the resolution of the original grid.  Thus,
#
#   istart_of_t7_on_t6sg = 2*istart_of_t7_on_t6g - 1
#   iend_of_t7_on_t6sg = 2*iend_of_t7_on_t6g
#   jstart_of_t7_on_t6sg = 2*jstart_of_t7_on_t6g - 1
#   jend_of_t7_on_t6sg = 2*jend_of_t7_on_t6g
#
# These are obtained assuming that grid cells on tile 6 must either be
# completely within the regional domain or completely outside of it,
# i.e. the boundary of the regional grid must coincide with gridlines
# on the tile 6 grid; it cannot cut through tile 6 cells.  (Note that
# this implies that the starting indices on the tile 6 supergrid must be
# odd while the ending indices must be even; the above expressions sa-
# tisfy this requirement.)  We perfrom these calculations next.
#
#-----------------------------------------------------------------------
#
  istart_of_t7_on_t6sg=$(( 2*istart_of_t7_on_t6g - 1 ))
  iend_of_t7_on_t6sg=$(( 2*iend_of_t7_on_t6g ))
  jstart_of_t7_on_t6sg=$(( 2*jstart_of_t7_on_t6g - 1 ))
  jend_of_t7_on_t6sg=$(( 2*jend_of_t7_on_t6g ))
#
#-----------------------------------------------------------------------
#
# If we simply pass to make_hgrid the index limits of the regional grid
# on the tile 6 supergrid calculated above, make_hgrid will generate a
# regional grid without a halo.  To obtain a regional grid with a halo,
# we must pass to make_hgrid the index limits (on the tile 6 supergrid)
# of the regional grid including a halo.  We will let the variables
#
#   istart_of_t7_with_halo_on_t6sg
#   iend_of_t7_with_halo_on_t6sg
#   jstart_of_t7_with_halo_on_t6sg
#   jend_of_t7_with_halo_on_t6sg
#
# denote these limits.  The reason we include "_wide_halo" in these va-
# riable names is that the halo of the grid that we will first generate
# will be wider than the halos that are actually needed as inputs to the
# FV3LAM model (i.e. the 0-cell-wide, 3-cell-wide, and 4-cell-wide halos
# described above).  We will generate the grids with narrower halos that
# the model needs later on by "shaving" layers of cells from this wide-
# halo grid.  Next, we describe how to calculate the above indices.
#
# Let halo_width_on_t7g denote the width of the "wide" halo in units of number of
# grid cells on the regional grid (i.e. tile 7) that we'd like to have
# along all four edges of the regional domain (left, right, bottom, and
# top).  To obtain the corresponding halo width in units of number of
# cells on the tile 6 grid -- which we denote by halo_width_on_t6g -- we simply di-
# vide halo_width_on_t7g by the refinement ratio, i.e.
#
#   halo_width_on_t6g = halo_width_on_t7g/refine_ratio_t6g_to_t7g
#
# The corresponding halo width on the tile 6 supergrid is then given by
#
#   halo_width_on_t6sg = 2*halo_width_on_t6g
#                      = 2*halo_width_on_t7g/refine_ratio_t6g_to_t7g
#
# Note that halo_width_on_t6sg must be an integer, but the expression for it de-
# rived above may not yield an integer.  To ensure that the halo has a
# width of at least halo_width_on_t7g cells on the regional grid, we round up the
# result of the expression above for halo_width_on_t6sg, i.e. we redefine halo_width_on_t6sg
# to be
#
#   halo_width_on_t6sg = ceil(2*halo_width_on_t7g/refine_ratio_t6g_to_t7g)
#
# where ceil(...) is the ceiling function, i.e. it rounds its floating
# point argument up to the next larger integer.  Since in bash division
# of two integers returns a truncated integer and since bash has no
# built-in ceil(...) function, we perform the rounding-up operation by
# adding the denominator (of the argument of ceil(...) above) minus 1 to
# the original numerator, i.e. by redefining halo_width_on_t6sg to be
#
#   halo_width_on_t6sg = (2*halo_width_on_t7g + refine_ratio_t6g_to_t7g - 1)/refine_ratio_t6g_to_t7g
#
# This trick works when dividing one positive integer by another.
#
# In order to calculate halo_width_on_t6g using the above expression, we must
# first specify halo_width_on_t7g.  Next, we specify an initial value for it by
# setting it to one more than the largest-width halo that the model ac-
# tually needs, which is NH4.  We then calculate halo_width_on_t6sg using the
# above expression.  Note that these values of halo_width_on_t7g and halo_width_on_t6sg will
# likely not be their final values; their final values will be calcula-
# ted later below after calculating the starting and ending indices of
# the regional grid with wide halo on the tile 6 supergrid and then ad-
# justing the latter to satisfy certain conditions.
#
#-----------------------------------------------------------------------
#
  halo_width_on_t7g=$(( NH4 + 1 ))
  halo_width_on_t6sg=$(( (2*halo_width_on_t7g + refine_ratio_t6g_to_t7g - 1)/refine_ratio_t6g_to_t7g ))
#
#-----------------------------------------------------------------------
#
# With an initial value of halo_width_on_t6sg now available, we can obtain the
# tile 6 supergrid index limits of the regional domain (including the
# wide halo) from the index limits for the regional domain without a ha-
# lo by simply subtracting halo_width_on_t6sg from the lower index limits and add-
# ing halo_width_on_t6sg to the upper index limits, i.e.
#
#   istart_of_t7_with_halo_on_t6sg = istart_of_t7_on_t6sg - halo_width_on_t6sg
#   iend_of_t7_with_halo_on_t6sg = iend_of_t7_on_t6sg + halo_width_on_t6sg
#   jstart_of_t7_with_halo_on_t6sg = jstart_of_t7_on_t6sg - halo_width_on_t6sg
#   jend_of_t7_with_halo_on_t6sg = jend_of_t7_on_t6sg + halo_width_on_t6sg
#
# We calculate these next.
#
#-----------------------------------------------------------------------
#
  istart_of_t7_with_halo_on_t6sg=$(( istart_of_t7_on_t6sg - halo_width_on_t6sg ))
  iend_of_t7_with_halo_on_t6sg=$(( iend_of_t7_on_t6sg + halo_width_on_t6sg ))
  jstart_of_t7_with_halo_on_t6sg=$(( jstart_of_t7_on_t6sg - halo_width_on_t6sg ))
  jend_of_t7_with_halo_on_t6sg=$(( jend_of_t7_on_t6sg + halo_width_on_t6sg ))
#
#-----------------------------------------------------------------------
#
# As for the regional grid without a halo, the regional grid with a wide
# halo that make_hgrid will generate must be such that grid cells on
# tile 6 either lie completely within this grid or outside of it, i.e.
# they cannot lie partially within/outside of it.  This implies that the
# starting indices on the tile 6 supergrid of the grid with wide halo
# must be odd while the ending indices must be even.  Thus, below, we
# subtract 1 from the starting indices if they are even (which ensures
# that there will be at least halo_width_on_t7g halo cells along the left and bot-
# tom boundaries), and we add 1 to the ending indices if they are odd
# (which ensures that there will be at least halo_width_on_t7g halo cells along the
# right and top boundaries).
#
#-----------------------------------------------------------------------
#
  if [ $(( istart_of_t7_with_halo_on_t6sg%2 )) -eq 0 ]; then
    istart_of_t7_with_halo_on_t6sg=$(( istart_of_t7_with_halo_on_t6sg - 1 ))
  fi

  if [ $(( iend_of_t7_with_halo_on_t6sg%2 )) -eq 1 ]; then
    iend_of_t7_with_halo_on_t6sg=$(( iend_of_t7_with_halo_on_t6sg + 1 ))
  fi

  if [ $(( jstart_of_t7_with_halo_on_t6sg%2 )) -eq 0 ]; then
    jstart_of_t7_with_halo_on_t6sg=$(( jstart_of_t7_with_halo_on_t6sg - 1 ))
  fi

  if [ $(( jend_of_t7_with_halo_on_t6sg%2 )) -eq 1 ]; then
    jend_of_t7_with_halo_on_t6sg=$(( jend_of_t7_with_halo_on_t6sg + 1 ))
  fi
#
#-----------------------------------------------------------------------
#
# Save the current shell options and temporarily turn off the xtrace op-
# tion to prevent clutter in stdout.
#
#-----------------------------------------------------------------------
#
  { save_shell_opts; set +x; } > /dev/null 2>&1
#
#-----------------------------------------------------------------------
#
# Now that the starting and ending tile 6 supergrid indices of the re-
# gional grid with the wide halo have been calculated (and adjusted), we
# recalculate the width of the wide halo on:
#
# 1) the tile 6 supergrid;
# 2) the tile 6 grid; and
# 3) the tile 7 grid.
#
# These are the final values of these quantities that are guaranteed to
# correspond to the starting and ending indices on the tile 6 supergrid.
#
#-----------------------------------------------------------------------
#
  print_info_msg "$VERBOSE" "
Original values of the halo width on the tile 6 supergrid and on the 
tile 7 grid are:
  halo_width_on_t6sg = ${halo_width_on_t6sg}
  halo_width_on_t7g  = ${halo_width_on_t7g}"

  halo_width_on_t6sg=$(( istart_of_t7_on_t6sg - istart_of_t7_with_halo_on_t6sg ))
  halo_width_on_t6g=$(( halo_width_on_t6sg/2 ))
  halo_width_on_t7g=$(( halo_width_on_t6g*refine_ratio_t6g_to_t7g ))

  print_info_msg "$VERBOSE" "
Values of the halo width on the tile 6 supergrid and on the tile 7 grid 
AFTER adjustments are:
  halo_width_on_t6sg = ${halo_width_on_t6sg}
  halo_width_on_t7g  = ${halo_width_on_t7g}"
#
#-----------------------------------------------------------------------
#
# Calculate the number of cells that the regional domain (without halo)
# has in each of the two horizontal directions (say x and y).  We denote
# these by nx_of_t7_on_t7g and ny_of_t7_on_t7g, respectively.  These 
# will be needed in the "shave" steps in the grid generation task of the
# workflow.
#
#-----------------------------------------------------------------------
#
  nx_of_t7_on_t6sg=$(( iend_of_t7_on_t6sg - istart_of_t7_on_t6sg + 1 ))
  nx_of_t7_on_t6g=$(( nx_of_t7_on_t6sg/2 ))
  nx_of_t7_on_t7g=$(( nx_of_t7_on_t6g*refine_ratio_t6g_to_t7g ))

  ny_of_t7_on_t6sg=$(( jend_of_t7_on_t6sg - jstart_of_t7_on_t6sg + 1 ))
  ny_of_t7_on_t6g=$(( ny_of_t7_on_t6sg/2 ))
  ny_of_t7_on_t7g=$(( ny_of_t7_on_t6g*refine_ratio_t6g_to_t7g ))
#
# The following are set only for informational purposes.
#
  nx_of_t6_on_t6sg=$(( 2*nx_of_t6_on_t6g ))
  ny_of_t6_on_t6sg=$(( 2*ny_of_t6_on_t6g ))

  prime_factors_nx_of_t7_on_t7g=$( factor ${nx_of_t7_on_t7g} | sed -r -e 's/^[0-9]+: (.*)/\1/' )
  prime_factors_ny_of_t7_on_t7g=$( factor ${ny_of_t7_on_t7g} | sed -r -e 's/^[0-9]+: (.*)/\1/' )

  print_info_msg "$VERBOSE" "
The number of cells in the two horizontal directions (x and y) on the 
parent tile's (tile 6) grid and supergrid are:
  nx_of_t6_on_t6g = ${nx_of_t6_on_t6g}
  ny_of_t6_on_t6g = ${ny_of_t6_on_t6g}
  nx_of_t6_on_t6sg = ${nx_of_t6_on_t6sg}
  ny_of_t6_on_t6sg = ${ny_of_t6_on_t6sg}

The number of cells in the two horizontal directions on the tile 6 grid
and supergrid that the regional domain (tile 7) WITHOUT A HALO encompas-
ses are:
  nx_of_t7_on_t6g = ${nx_of_t7_on_t6g}
  ny_of_t7_on_t6g = ${ny_of_t7_on_t6g}
  nx_of_t7_on_t6sg = ${nx_of_t7_on_t6sg}
  ny_of_t7_on_t6sg = ${ny_of_t7_on_t6sg}

The starting and ending i and j indices on the tile 6 grid used to gene-
rate this regional grid are:
  istart_of_t7_on_t6g = ${istart_of_t7_on_t6g}
  iend_of_t7_on_t6g   = ${iend_of_t7_on_t6g}
  jstart_of_t7_on_t6g = ${jstart_of_t7_on_t6g}
  jend_of_t7_on_t6g   = ${jend_of_t7_on_t6g}

The corresponding starting and ending i and j indices on the tile 6 su-
pergrid are:
  istart_of_t7_on_t6sg = ${istart_of_t7_on_t6sg}
  iend_of_t7_on_t6sg   = ${iend_of_t7_on_t6sg}
  jstart_of_t7_on_t6sg = ${jstart_of_t7_on_t6sg}
  jend_of_t7_on_t6sg   = ${jend_of_t7_on_t6sg}

The refinement ratio (ratio of the number of cells in tile 7 that abut
a single cell in tile 6) is:
  refine_ratio_t6g_to_t7g = ${refine_ratio_t6g_to_t7g}

The number of cells in the two horizontal directions on the regional do-
main's (i.e. tile 7's) grid WITHOUT A HALO are:
  nx_of_t7_on_t7g = ${nx_of_t7_on_t7g}
  ny_of_t7_on_t7g = ${ny_of_t7_on_t7g}

The prime factors of nx_of_t7_on_t7g and ny_of_t7_on_t7g are (useful for
determining an MPI task layout):
  prime_factors_nx_of_t7_on_t7g: ${prime_factors_nx_of_t7_on_t7g}
  prime_factors_ny_of_t7_on_t7g: ${prime_factors_ny_of_t7_on_t7g}"
#
#-----------------------------------------------------------------------
#
# For informational purposes, calculate the number of cells in each di-
# rection on the regional grid including the wide halo (of width halo_-
# width_on_t7g cells).  We denote these by nx_of_t7_with_halo_on_t7g and
# ny_of_t7_with_halo_on_t7g, respectively.
#
#-----------------------------------------------------------------------
#
  nx_of_t7_with_halo_on_t6sg=$(( iend_of_t7_with_halo_on_t6sg - istart_of_t7_with_halo_on_t6sg + 1 ))
  nx_of_t7_with_halo_on_t6g=$(( nx_of_t7_with_halo_on_t6sg/2 ))
  nx_of_t7_with_halo_on_t7g=$(( nx_of_t7_with_halo_on_t6g*refine_ratio_t6g_to_t7g ))

  ny_of_t7_with_halo_on_t6sg=$(( jend_of_t7_with_halo_on_t6sg - jstart_of_t7_with_halo_on_t6sg + 1 ))
  ny_of_t7_with_halo_on_t6g=$(( ny_of_t7_with_halo_on_t6sg/2 ))
  ny_of_t7_with_halo_on_t7g=$(( ny_of_t7_with_halo_on_t6g*refine_ratio_t6g_to_t7g ))

  print_info_msg "$VERBOSE" "
nx_of_t7_with_halo_on_t7g = ${nx_of_t7_with_halo_on_t7g} \
(istart_of_t7_with_halo_on_t6sg = ${istart_of_t7_with_halo_on_t6sg}, \
iend_of_t7_with_halo_on_t6sg = ${iend_of_t7_with_halo_on_t6sg})"

  print_info_msg "$VERBOSE" "
ny_of_t7_with_halo_on_t7g = ${ny_of_t7_with_halo_on_t7g} \
(jstart_of_t7_with_halo_on_t6sg = ${jstart_of_t7_with_halo_on_t6sg}, \
jend_of_t7_with_halo_on_t6sg = ${jend_of_t7_with_halo_on_t6sg})"
#
#-----------------------------------------------------------------------
#
# Set output variables.
#
#-----------------------------------------------------------------------
#
  eval ${output_varname_lon_of_t7_ctr}="${lon_of_t7_ctr}"
  eval ${output_varname_lat_of_t7_ctr}="${lat_of_t7_ctr}"
  eval ${output_varname_nx_of_t7_on_t7g}="${nx_of_t7_on_t7g}"
  eval ${output_varname_ny_of_t7_on_t7g}="${ny_of_t7_on_t7g}"
  eval ${output_varname_halo_width_on_t7g}="${halo_width_on_t7g}"
  eval ${output_varname_stretch_factor}="${stretch_factor}"
  eval ${output_varname_istart_of_t7_with_halo_on_t6sg}="${istart_of_t7_with_halo_on_t6sg}"
  eval ${output_varname_iend_of_t7_with_halo_on_t6sg}="${iend_of_t7_with_halo_on_t6sg}"
  eval ${output_varname_jstart_of_t7_with_halo_on_t6sg}="${jstart_of_t7_with_halo_on_t6sg}"
  eval ${output_varname_jend_of_t7_with_halo_on_t6sg}="${jend_of_t7_with_halo_on_t6sg}"
#
#-----------------------------------------------------------------------
#
# Restore the shell options before turning off xtrace.
#
#-----------------------------------------------------------------------
#
  { restore_shell_opts; } > /dev/null 2>&1

}

