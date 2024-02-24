#########################################################################
#                                                                       #
# Python script for fire emissions preprocessing from RAVE FRP and FRE  #
# (Li et al.,2022).                                                     #
# johana.romero-alvarez@noaa.gov                                        #
#                                                                       #
#########################################################################
import sys
import os
import time
import numpy as np
import fire_emiss_tools as femmi_tools
import HWP_tools
import interp_tools as i_tools

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Workflow
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
def generate_emiss_workflow(staticdir, ravedir, newges_dir, predef_grid):
   
   # ----------------------------------------------------------------------
   # Import envs from workflow and get the predifying grid
   # Set variable names, constants and unit conversions
   # Set predefined grid
   # Set directories 
   # ----------------------------------------------------------------------
   beta = 0.3
   fg_to_ug = 1e6
   current_day = os.environ.get("CDATE")
   nwges_dir = os.environ.get("NWGES_DIR")    
   vars_emis = ["FRP_MEAN","FRE"]
   cols, rows = (2700, 3950) if predef_grid == 'RRFS_NA_3km' else (1092, 1820) 
   print('PREDEF GRID',predef_grid,'cols,rows',cols,rows)
   veg_map = staticdir+'/veg_map.nc' 
   RAVE= ravedir
   print(RAVE)
   rave_to_intp = predef_grid+"_intp_"  
   intp_dir = newges_dir
   grid_in = staticdir+'/grid_in.nc'
   weightfile = staticdir+'/weight_file.nc'
   grid_out = staticdir+'/ds_out_base.nc'
   hourly_hwpdir = os.path.join(nwges_dir,'HOURLY_HWP')

   # ----------------------------------------------------------------------
   # Workflow
   # ----------------------------------------------------------------------
  
   # ----------------------------------------------------------------------
   # Sort raw RAVE, create source and target filelds, and compute emissions 
   # ----------------------------------------------------------------------
   fcst_dates = i_tools.date_range(current_day)
   intp_avail_hours, intp_non_avail_hours, inp_files_2use = i_tools.check_for_intp_rave(intp_dir, fcst_dates, rave_to_intp)
   rave_avail, rave_avail_hours, rave_nonavail_hours_test, first_day = i_tools.check_for_raw_rave(RAVE, intp_non_avail_hours, intp_avail_hours)
   srcfield, tgtfield, tgt_latt, tgt_lont, srcgrid, tgtgrid, src_latt, tgt_area = i_tools.creates_st_fields(grid_in, grid_out, intp_dir, rave_avail_hours) 
  
   if not first_day:
       regridder, use_dummy_emiss = i_tools.generate_regrider(rave_avail_hours, srcfield, tgtfield, weightfile, inp_files_2use, intp_avail_hours)
       if use_dummy_emiss:
           print('RAVE files corrupted, no data to process')
           i_tools.create_dummy(intp_dir, current_day, tgt_latt, tgt_lont, cols, rows)
       else:
           i_tools.interpolate_rave(RAVE, rave_avail, rave_avail_hours,
                                    use_dummy_emiss, vars_emis, regridder, srcgrid, tgtgrid, rave_to_intp,
                                    intp_dir, src_latt, tgt_latt, tgt_lont, cols, rows)
           print('Restart dates to process',fcst_dates)
           hwp_avail_hours, hwp_non_avail_hours = HWP_tools.check_restart_files(hourly_hwpdir, fcst_dates)
           restart_avail, restart_nonavail_hours_test = HWP_tools.copy_missing_restart(nwges_dir, hwp_non_avail_hours, hourly_hwpdir)
           start = time.time()
           hwp_ave_arr, xarr_hwp, totprcp_ave_arr, xarr_totprcp = HWP_tools.process_hwp(fcst_dates, hourly_hwpdir, cols, rows, intp_dir, rave_to_intp)
           frp_avg_reshaped, ebb_tot_reshaped = femmi_tools.averaging_FRP(fcst_dates, cols, rows, intp_dir, rave_to_intp, veg_map, tgt_area, beta, fg_to_ug)
           #Fire end hours processing
           te = femmi_tools.estimate_fire_duration(intp_avail_hours, intp_dir, fcst_dates, current_day, cols, rows, rave_to_intp)
           fire_age = femmi_tools.save_fire_dur(cols, rows, te)
           #produce emiss file 
           femmi_tools.produce_emiss_file(xarr_hwp, frp_avg_reshaped, totprcp_ave_arr, xarr_totprcp, intp_dir, current_day, tgt_latt, tgt_lont, ebb_tot_reshaped, fire_age, cols, rows)
   else:
       print('First day true, no RAVE files available. Use dummy emissions file')
       i_tools.create_dummy(intp_dir, current_day, tgt_latt, tgt_lont, cols, rows)

if __name__ == '__main__':

        print('')
        print('~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~')
        print('Welcome to interpolating RAVE and processing fire emissions!')
        print('~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~')
        print('')
        generate_emiss_workflow(sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4])
        print('')
        print('~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~')
        print('Successful Completion. Bye!')
        print('~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~')
        print('')
        print()
