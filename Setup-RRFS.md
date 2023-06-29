This is instruction on how to set up the options in config.sh file for real-time and retrospective runs. 
There are many config.sh files in RRFS_dev1 branch, which can be used as a start for your won experiments:
* config.sh.3DRTMA_dev1    : 3DRTMA
* config.sh.RRFS_AK_dev1   : RRFS 3-km Alaska hourly cycling
* config.sh.RRFS_dev1      : RRFS 3-km CONUS hourly cycling
* config.sh.RRFS_NA_13km   : RRFS 13km North American domain hourly cycling
* config.sh.RRFS_NA_3km    : RRF 3-km North American domain code start 

# Run experiment under reservation

Some of those experiments are set to run under JET reservation for real-time experiments.
Please make sure the following option is comment out before you build the workflow unless 
you are running under reservation:

* RESERVATION="rrfsdet"


# Setup experiment locations

## workflow directory:

The workflow directory can be set by:

* EXPT_BASEDIR="/mnt/lfs4/BMC/rtwbl/mhu/rrfs"
* EXPT_SUBDIR="RRFS_dev1"

This directory "/mnt/lfs4/BMC/rtwbl/mhu/rrfs/RRFS_dev1" contents XML, model namelist/configure, links to the fix files, var_defns.sh, and launch_FV3LAM_wflow.sh. You will control the experiment from this directory. You can manually run experiment by:
./launch_FV3LAM_wflow.sh
You can also check the experiment running status through rocotocheck, rocotostatus, and other rocoto command.


## running directory 
The working directory can be set by:

* STMP="/mnt/lfs4/BMC/rtwbl/mhu/rrfs"  
* RUN="RRFS_dev1"

This decides where to run all the cycles:
  "/mnt/lfs4/BMC/rtwbl/mhu/rrfs/tmpnwprd/${RUN}"
This is working directory suppose to be purged quite frequently based on the space availability.

## log and product directory 

The log files and grib2 and plot products are located at:
* PTMP="/mnt/lfs4/BMC/rtwbl/mhu/rrfs"
* NET="RRFS_CONUS"

The log files are in: "/mnt/lfs4/BMC/rtwbl/mhu/rrfs/com/logs/${NET}/${RUN}.${YYYYMMDD}/${HH}"
The products are in: "/mnt/lfs4/BMC/rtwbl/mhu/rrfs/com/${NET}/para/${RUN}.${YYYYMMDD}/${HH}"

## archive directory
ARCHIVEDIR="/5year/BMC/wrfruc/rrfs_dev1"


# Use group cycldef to construct cycles
The current workflow uses groups to control which task should be in certain cycle (run time).

## groups and tasks

We have defined 10 groups and here is a list of the group:

*   INITIAL_CYCLEDEF: cycle to generate cold start initial condition, you should see tasks get_extra_ics and make_ics in this cycle.
*   BOUNDARY_CYCLEDEF: cycle to generate boundary condition, you should see tasks get_extra_lbcs and make_lbcs in this cycle.
*   BOUNDARY_LONG_CYCLEDEF: same as BOUNDARY_CYCLEDEF but will generate longer boundary conditions based on the setup
*   PREP_COLDSTART_CYCLEDEF: cycle to build FV3LAM model run directory and stage cold start files from the same cycle for INPUT, task is "prep_clodstart"
*   PREP_WARMSTART_CYCLEDEF: cycle to build FV3LAM model run directory and stage warm start files from the past 6 cycles for INPUT, task is "prep_warmstart"
*   ANALYSIS_CYCLEDEF: cycle to conduct GSI analysis, cloud analysis, preparing radar tten; tasks include: process_radar_ref, process_lghtning, process_bufr, anal_gsi, radar_ref2tten, cldanl_nonvar.
*   FORECAST_CYCLEDEF: cycle to run fv3lam; tasks include run_fcst, python_skewt, clean
*   POSTPROC_CYCLEDEF: cycle to run postprocess; tasks include run_post, run_ncl, run_ncl_zip
*   POSTPROC_LONG_CYCLEDEF: same as POSTPROC_CYCLEDEF but add more post-process tasks
*   ARCHIVE_CYCLEDEF: cycle to run archive

## setup cycles using CYCLEDEF and related parameters
The setup of CYCLEDEF is decided by experiment target and available data. We will discuss this topic in three sections: analysis and forecast; prepare initial and boundary; postprocess
### analysis and forecast
The analysis and forecast are center of the whole system. When we talk about this part, we assume the boundary and cold start initial conditions are always available and we are not thinking how to provide the products yet.

The following option set the data assimilation interval:

* DA_CYCLE_INTERV="1"

It can be 1 to 6 but usually set to 1 or 3 for hourly cycle and 3 hourly cycle. The cold start only test does not use this parameter.
After you set cycling frequency, you need to set:
* PREP_COLDSTART_CYCLEDEF: the cycle has cold start: one or twice per day can be any hour that has cold start initial conditions.
* PREP_WARMSTART_CYCLEDEF: the cycle has warm start: rest of the hours other than PREP_COLDSTART_CYCLEDEF based on cycle frequency; it will build model INPUT directory based on previous 6 cycles of the forecast RESTART files.
* ANALYSIS_CYCLEDEF: the cycle run GSI analysis and other data related tasks: match cycle frequency hourly or 3-hourly.
* FORECAST_CYCLEDEF: the cycle run fv3lam: the same as ANALYSIS_CYCLEDEF but does not need to be.

The length of the forecast for each hour can be control by setting:
* #FCST_LEN_HRS_CYCLES=(48 18 18 18 18 18 48 18 18 18 18 18 48 18 18 18 18 18 48 18 18 18 18 18)
* for i in {0..23}; do FCST_LEN_HRS_CYCLES[$i]=18; done
* for i in {0..23..6}; do FCST_LEN_HRS_CYCLES[$i]=48; done

Here we set cycle 0,06,12,18Z to run 48-h forecast and rest of cycles run 18-h forecast.


### Prepare boundary and cold start initial conditions
We need to decide how to prepare boundary and cold start initial conditions based on the availability of the external model and the needs of RRFS cycles. The boundary and initial condition should start when ever the external model forecast are available and provide enough coverage for the next several cycles in boundary length. There are no dependence between boundary and model runs. When prepare the INPUT files in the model run directory, the scripts will look back to previous 12 cycles to find the closest cycle that can provide enough boundary coverage. However, preparing the INPUT files for the cold start depends on the make_ics in the same cycle.

Here are related parameters for setting up cold start initial conditions:
* EXTRN_MDL_ICS_OFFSET_HRS="3"
* INITIAL_CYCLEDEF="00 03,15 ${CYCLEDAY} ${CYCLEMONTH} 2021 *"
* EXTRN_MDL_NAME_ICS="FV3GFS"
Those three decide we want to generate cold start initial condition for cycle hours (INITIAL_CYCLEDEF) using the forecast hour (EXTRN_MDL_ICS_OFFSET_HRS) results from the model (EXTRN_MDL_NAME_ICS), which should valid at the cycle time. In this example, the GFS 3-h forecast from 0/12Z cycle will be used to generate cold start initial condition for 03/15Z RRFS cycles.

Here are related parameters for setting up boundary conditions:
* BOUNDARY_LEN_HRS="21"
* BOUNDARY_LONG_LEN_HRS="51"
* LBC_SPEC_INTVL_HRS="1"
* EXTRN_MDL_LBCS_OFFSET_HRS="0"
* EXTRN_MDL_LBCS_SEARCH_OFFSET_HRS="0"
* EXTRN_MDL_NAME_LBCS="RAP"

The EXTRN_MDL_NAME_LBCS sets which external model will be used for boundary conditions. The interval between each boundary condition is decided by "LBC_SPEC_INTVL_HRS". It can be larger than the product available frequency from  external model forecast. We typically set it to 1 or 3. "EXTRN_MDL_LBCS_OFFSET_HRS" will look for boundary conditions from older (compare to current cycle) external model runs. We suggest to set it to 0 for data assimilation cycles. But for cold start, it can be a positive number to get faster start of the cold forecast. For example, if you set it to 3 and use RAP forecast (EXTRN_MDL_NAME_LBCS), the condition condition will come from the RAP cycle 3-hours older than the current RRFS cycle. "EXTRN_MDL_LBCS_SEARCH_OFFSET_HRS" will be used for retrospective experiment only. It trys to mimic the real-time situation and tells the current cycle to search for the boundary starting from previous "EXTRN_MDL_LBCS_SEARCH_OFFSET_HRS" hour cycle.

* BOUNDARY_LEN_HRS="21"
* BOUNDARY_LONG_LEN_HRS="51"
* BOUNDARY_CYCLEDEF="00 00-02/01,04-08/01,10-14/01,16-20/01,22,23 ${CYCLEDAY} ${CYCLEMONTH} 2021 *"
* BOUNDARY_LONG_CYCLEDEF="00 03,09,15,21 ${CYCLEDAY} ${CYCLEMONTH} 2021 *"

We can prepare two different length of the boundary conditions, based on the availability of the external model forecast.  The cycles in BOUNDARY_CYCLEDEF will generate boundary condition cover forecast length up to BOUNDARY_LEN_HRS hours. While The cycles in BOUNDARY_LONG_CYCLEDEF will generate boundary condition cover forecast length up to BOUNDARY_LONG_LEN_HRS hours.

We usually generate enough long boundary to cover several cycles that may use this boundary. Here we only give the example based on 
EXTRN_MDL_LBCS_OFFSET_HRS="0". If the external model arrives 2 hours later than the current cycle, we want to cover 12-hour forecast for the next 3 cycles, the length of such boundary condition should be 2+12+3=17 hours. It is OK to prepare a little longer boundary condition to cover mode cycles, but boundary condition process takes long time.

You don't need to set BOUNDARY_LONG_LEN_HRS and BOUNDARY_LONG_CYCLEDEF if the normal boundary can cover all the cycles.


### generate products
The product generation is based on the model forecast. For most of the case, we generate product for all the forecast files.

* FCST_LEN_HRS="18"
* POSTPROC_LEN_HRS="18"
* POSTPROC_LONG_LEN_HRS="48"
* POSTPROC_CYCLEDEF="00 00-23/01 ${CYCLEDAY} ${CYCLEMONTH} 2021 *"
* POSTPROC_LONG_CYCLEDEF="00 00,06,12,18 ${CYCLEDAY} ${CYCLEMONTH} 2021 *"

Based on the forecast length, the FCST_LEN_HRS and POSTPROC_LEN_HRS are set to the normal forecast length and POSTPROC_LONG_LEN_HRS is set to long forecast length. POSTPROC_CYCLEDEF should be the as FORECAST_CYCLEDEF and POSTPROC_LONG_CYCLEDEF set to the cycles that have longer forecast, based on setup in FCST_LEN_HRS_CYCLES. 

You don't need to set POSTPROC_LONG_LEN_HRS and POSTPROC_LONG_CYCLEDEF if all the cycles use the same forecast length.

### Time Format for CYCLEDEF  

CYCLDEFs are string and have default: "00 01 01 01 2100 *", which means to be never executed in real-time (not active) and retros (no satisfy dependence)
We only have to format to set up this string:
1) 00 HHs DDs MMs YYYYs *
      HHs can be "01-03/01" or "01,02,03" or "*"
      DDs,MMs can be "01-03" or "01,02,03" or "*"
      YYYYs can be "2020-2021" or "2020,2021" or "*"
2) start_time(YYYYMMDDHH00) end_time(YYYYMMDDHH00) interval(HH:MM:SS)
     for example: 202104010000 202104310000 12:00:00

# Setup cold start runs
The default setup are data assimilation. to set up cold start run only, just need to comment out or delete:
* DO_DACYCLE="true"

The cold start run is a subset of the DA cycles. The default for "DO_DACYCLE" is false, which will only build 
initial/boundary condition, model forecast, post process in to workflow. The following CYCEDEF works for cold start:

*   INITIAL_CYCLEDEF:
*   BOUNDARY_CYCLEDEF: 
*   PREP_COLDSTART_CYCLEDEF:
*   FORECAST_CYCLEDEF:
*   POSTPROC_CYCLEDEF:
*   ARCHIVE_CYCLEDEF:

Most of time, the BOUNDARY_LONG_CYCLEDEF and POSTPROC_LONG_CYCLEDEF can also be used but are not needed for most of the cold start runs as all cold start runs make the same length of the forecast. The INITIAL_CYCLEDEF, BOUNDARY_CYCLEDEF, PREP_COLDSTART_CYCLEDEF, FORECAST_CYCLEDEF, POSTPROC_CYCLEDEF should have the same hours for most of the cold start. The PREP_COLDSTART_CYCLEDEF does depend on both initial and boundary tasks. If cold start need to run earlier in real time, "EXTRN_MDL_LBCS_OFFSET_HRS" need to set to a number to
make boundary from previous external model cycles. For example, "EXTRN_MDL_LBCS_OFFSET_HRS=3" for RAP boundary will use 21Z RAP forecast for 00Z cold start model forecast.  

# Setup real time runs
Most of the sample configurations are set to run real-time, which means the following two options are comment out/set to false/not shown in config.sh:
* DO_RETRO="true"
* LBCS_ICS_ONLY="true"

We will discuss the retrospective experiment in the next section. For real-time run, most of tasks control by time:
* boundary and initial condition: the tasks will run only all the external model forecast for boundary and initial available. But the external model forecast usually arrive much later than the current cycle. For example, RAP/HRRR arrives two hours later than current cycle and GFS arrives 5-6 hours later than current cycle. So, the boundary prepared in current cycle is actually used by cycles much later than current cycle. But the initial condition needs to be ready for cold start cycles, "EXTRN_MDL_ICS_OFFSET_HRS" can be used to get forecast from previous external model cycle for initial condition, like EXTRN_MDL_ICS_OFFSET_HRS=3 for GFS will used 3-h forecast from GFS 00Z cycle to generate initial condition for 3Z RRFS cold start cycle.
* data preprocess and GSI analysis: we have set the time dependence for all data preprocess and GSI analysis to make sure they are NOT start before the typical data arrive time. We need to know when data will arrive and set the corresponding time in "templates/FV3LAM_wflow.xml":

` <!ENTITY START_TIME_ANALYSIS     "02:37:00">`
 `<!ENTITY START_TIME_CONVENTIONAL "00:40:00">`
 `<!ENTITY START_TIME_NSSLMOSIAC   "00:45:00">`
 `<!ENTITY START_TIME_LIGHTNINGNC  "00:45:00">`

Please not the GSI can be run without any observations. The GSI analysis does not depend on any data preprocess or data observation files. When GSI needs to start, it will run with whatever available observations. Also, the "START_TIME_ANALYSIS" is the time that prep_warmstart start to look for background more than 1-h forecast (for hourly cycle) because the previous cycle is delayed too much. 

# Setup retrospective experiments

The current retro runs are constructed as two steps:

1. prepare boundary and initial condition:
set the following two options to "true"
* DO_RETRO="true"
* LBCS_ICS_ONLY="true"
and the generate the workflow and run workflow to prepare all the boundary condition and initial conditions.

2. run cycles
After all boundary and initial conditions are generated, come back the ush directory and set 
* DO_RETRO="true"
* LBCS_ICS_ONLY="false"

or comment LBCS_ICS_ONLY out.
You need to generate the workflow again and then run the workflow for cold start runs or data assimilation cycles runs.
Because the real-time run always use the boundary from older external model forecast, "EXTRN_MDL_LBCS_SEARCH_OFFSET_HRS" is used to
set which older boundary condition should be used in the retro runs. If it is 3, it will start looking for boundary 3-hour and older.

The retro also assume all the data are available. We may need to add the dependence to the certain data assimilation components to make sure 
they are running in certain order.

## effective retro runs:
Also, we need to discuss if we need to share a common set of boundary and initial condition, how to start from a warm started cycles, the right "cyclethrottle" numbers for retros.

## Data stage
We need a common location for all of the retrospective data. Need to turn off write permission for retro data

# Data assimilation configurations
## how to setup new observation
1) need to make sure the GSI convinfo and satinfo (in fix directory) are set right
2) need to add more elements to **obs_files_source**  and **obs_files_target** in regional_workflow/scripts/exregional_run_analysis.sh:
 obs_files_source[0]=${obspath_tmp}/${obsfileprefix}.t${HH}z.prepbufr.tm00
 obs_files_target[0]=prepbufr
 obs_files_source[1]=${obspath_tmp}/${obsfileprefix}.t${HH}z.satwnd.tm00.bufr_d
 obs_files_target[1]=satwndbufr
 obs_files_source[2]=${obspath_tmp}/${obsfileprefix}.t${HH}z.nexrad.tm00.bufr_d
 obs_files_target[2]=l2rwbufr

## Radar tten and cloud analysis:
Those two will add the tasks to do radar tten and non-var cloud analysis:
* DO_NONVAR_CLDANAL="true"
* DO_REFL2TTEN="true"

Three more options can be used for radar tten:

* OBSPATH_NSSLMOSIAC=/public/data/radar/nssl/mrms/conus
* RADARREFL_TIMELEVEL=(0 15 30 45)
* FH_DFI_RADAR="0.0,0.25,0.5"

RADARREFL_TIMELEVEL will set how often and which minutes after the cycle hour to preprocess the radar data
FH_DFI_RADAR will decide when radar tten will be used in the forecast. Here the example is to use radar tten 
in the first 30 minutes of the forecast and read the radar tten at 00 and 15 minutes of the forecast.

# Archive (levels of archive) and clean (control how many cycles we need to clean) process in retro 
