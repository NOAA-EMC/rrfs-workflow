!-------------------------------------------------------------------------
!  NASA/GSFC, Global Modeling and Assimilation Office, Code 610.3, GMAO  !
!-------------------------------------------------------------------------
!BOP
!
! !MODULE: gsimod  ---

!
! !INTERFACE:
!
  module gsimod

! !USES:

  use m_kinds, only: i_kind,r_kind

  use mpeu_util,only: die,warn
  use mpeu_util,only: uppercase
  use m_mpimod, only: npe,gsi_mpi_comm_world,ierror,mype
  use balmod, only: init_balmod,fstat,lnobalance

  use jfunc, only: jfunc_init,mockbkg
  use jfunc, only: cwoption,qoption,pseudo_q2
  use jfunc, only: switch_on_derivatives
  use jfunc, only: tendsflag

  use gsi_4dvar, only: setup_4dvar,init_4dvar,clean_4dvar
  use gsi_4dvar, only: l4densvar,nmn_obsbin

  use gsibec_adjtest_mod, only: iadtest

  use state_vectors, only: init_anasv,final_anasv
  use control_vectors, only: init_anacv,final_anacv,nrf,nvars,nrf_3d,cvars3d,cvars2d,&
     cvarsmd,nrf_var,lcalc_gfdl_cfrac 
  use berror, only: norh,ndeg,vs,bw,init_berror,hzscl,hswgt,pert_berr,pert_berr_fct,&
     bkgv_flowdep,bkgv_rewgtfct,bkgv_write,fpsproj,nhscrf,adjustozvar,fut2ps,cwcoveqqcov,adjustozhscl,&
     bkgv_write_cv,bkgv_write_sv
  use berror, only: simcv !_RT intro for testing
  use m_berror_stats, only: usenewgfsberror
  use compact_diffs, only: noq,init_compact_diffs

  use gridmod, only: nlat,nlon,nsig,&
     nsig1o,nnnn1o,&
     init_grid,init_grid_vars,&
     nlayers,jcap,jcap_b,vlevs,&
     use_sp_eqspace,final_grid_vars,&
     jcap_gfs,nlat_gfs,nlon_gfs,jcap_cut,&
     rlat_start,rlat_end,&
     rlon_start,rlon_end,&
     north_pole_lat,north_pole_lon

  use gridmod, only: init_reg_glob_ll,regional,fv3_regional,grid_ratio_fv3_regional,mpas_regional

  use constants, only: zero,one,init_constants,gps_constants,three
  use constants, only: init_constants,init_constants_derived
  use constants, only: final_constants,final_constants_derived

  use fgrid2agrid_mod, only: set_fgrid2agrid

  use smooth_polcarf, only: norsp,init_smooth_polcas

  use gsi_metguess_mod, only: gsi_metguess_init,gsi_metguess_final
  use gsi_metguess_mod, only: gsi_metguess_destroy_grids
  use gsi_chemguess_mod, only: gsi_chemguess_init,gsi_chemguess_final
  use gsi_chemguess_mod, only: gsi_chemguess_destroy_grids

  use general_commvars_mod, only: init_general_commvars,destroy_general_commvars
  use general_commvars_mod, only: init_general_commvars_dims
  use general_commvars_mod, only: final_general_commvars_dims

  use derivsmod, only: dvars2d, dvars3d
  use derivsmod, only: create_ges_derivatives,init_anadv,destroy_ges_derivatives
  use derivsmod, only: final_anadv 

  use tendsmod, only: create_ges_tendencies
  use tendsmod, only: destroy_ges_tendencies

  use hybrid_ensemble_parameters,only : l_hyb_ens,uv_hyb_ens,aniso_a_en,generate_ens,&
                         n_ens,nlon_ens,nlat_ens,jcap_ens,jcap_ens_test,oz_univ_static,&
                         regional_ensemble_option,merge_two_grid_ensperts, &
                         full_ensemble,pseudo_hybens,pwgtflg,&
                         beta_s0,s_ens_h,s_ens_v,init_hybrid_ensemble_parameters,&
                         readin_localization,write_ens_sprd,eqspace_ensgrid,grid_ratio_ens,&
                         readin_beta,use_localization_grid,use_gfs_ens,q_hyb_ens,i_en_perts_io, &
                         l_ens_in_diff_time,ensemble_path,ens_fast_read,sst_staticB,&
                         bens_recenter,upd_ens_spread,upd_ens_localization,ens_fname_tmpl,&
                         EnsSource

  use gsi_io, only: init_io, verbose

  use mod_vtrans, only: nvmodes_keep,init_vtrans,destroy_vtrans
  use mod_strong, only: reg_tlnmc_type,l_tlnmc,nstrong,tlnmc_option,&
       period_max,period_width,baldiag_full,baldiag_inc, &
       init_strongvars ! RT: this needs attention
  use turblmod, only: create_turblvars

  implicit none

  private

! !PUBLIC ROUTINES:

   public :: gsimain_initialize
   public :: gsimain_gridopts
   public :: gsimain_finalize

   interface gsimain_initialize
      module procedure gsimain_initialize_
   end interface gsimain_initialize
   interface gsimain_gridopts
      module procedure gridopts0_
      module procedure gridopts1_
   end interface gsimain_gridopts
   interface gsimain_finalize
      module procedure gsimain_finalize_
   end interface gsimain_finalize
!
! !DESCRIPTION: This module contains code originally in the GSI main program.
! The main
!               program has been split in initialize/run/finalize segments, and
!               subroutines
!  created for these steps: gsimain_initialize(), gsimain_run() and
!  gsimain_finalize().
!  In non-ESMF mode (see below) a main program is assembled by calling these 3
!  routines in
!  sequence.
                                                                                                                         
                    
!  This file can be compiled in 2 different modes: an ESMF and a non-ESMF mode.
!  When HAVE_ESMF
!  is defined (ESMF mode), a few I/O related statements are skipped during
!  initialize() and
!  a main program is not provided. These is no dependency on the ESMF in this
!  file and in the
!  routines called from here. The ESMF interface is implemented in
!  GSI_GridCompMod which in
!  turn calls the initialize/run/finalize routines defined here.
!
! !REVISION HISTORY:
!
!  01Jul2006  Cruz      Initial code.
!  19Oct2006  da Silva  Updated prologue.
!  10Apr2007  Todling   Created from gsimain
!  13Jan2007  Tremolet  Updated interface to setup_4dvar
!  03Oct2007  Todling   Add lobserver
!  03Oct2007  Tremolet  Add DFI and lanczos-save
!  04Jan2008  Tremolet  Add forecast sensitivity to observations options
!  10Sep2008  Guo       Add CRTM files directory path
!  02Dec2008  Todling   Remove reference to old TLM of analysis  
!  20Nov2008  Todling   Add lferrscale to scale OMF w/ Rinv (actual fcst not guess)
!  08Dec2008  Todling   Placed switch_on_derivatives,tendsflag in jcopts namelist
!  28Jan2009  Todling   Remove original GMAO interface
!  06Mar2009  Meunier   Add initialisation for lagrangian data
!  04-21-2009 Derber    Ensure that ithin is positive if neg. set to zero
!  07-08-2009 Sato      Update for anisotropic mode (global/ensemble based)
!  08-31-2009 Parrish   Add changes for version 3 regional tangent linear normal mode constraint
!  09-22-2009 Parrish   Add read of namelist/hybrid_ensemble/.  contains parameters used for hybrid
!                        ensemble option.
!  02-17-2010 Parrish   add nlon_ens, nlat_ens, jcap_ens to namelist/hybrid_ensemble/, in preparation for 
!                         dual resolution capability when running gsi in hybrid ensemble mode.
!  02-20-2010 Zhu       Add init_anacv,nrf,nvars,nrf_3d for control variables;
!  02-21-2010 Parrish   add jcap_ens_test to namelist/hybrid_ensemble/ so can simulate lower resolution
!                         ensemble compared to analysis for case when ensemble and analysis resolution are
!                         the same.  used for preliminary testing of dual resolution hybrid ensemble option.
!  02-25-2010 Zhu       Remove berror_nvars
!  03-06-2010 Parrish   add flag use_gfs_ozone to namelist SETUP--allows read of gfs ozone for regional runs
!  03-09-2010 Parrish   add flag check_gfs_ozone_date to namelist SETUP--if true, date check gfs ozone
!  03-15-2010 Parrish   add flag regional_ozone to namelist SETUP--if true, then turn on ozone in 
!                         regional analysis
!  03-17-2010 todling   add knob for analysis error estimate (jsiga)
!  03-17-2010 Zhu       Add nc3d and nvars in init_grid_vars interface
!  03-29-2010 hu        add namelist variables for controling rapid refesh options
!                                 including cloud analysis and surface enhancement
!                       add and read namelist for RR
!  03-31-2010 Treadon   replace init_spec, init_spec_vars, destroy_spec_vars with general_* routines
!  04-07-2010 Treadon   write rapidrefresh_cldsurf settings to stdout
!  04-10-2010 Parrish   add vlevs from gridmod, so can pass as argument to init_mpi_vars, which must
!                        be called after init_grid_vars, as it currently is.  This must be done to
!                        avoid "use gridmod" in mpimod.F90, which causes compiler conflict, since
!                        "use m_mpimod" appears in gridmod.f90.
!  04-22-2010 Tangborn  add carbon monoxide settings
!  04-25-2010 Zhu       Add option newpc4pred for new pre-conditioning of predictors
!  05-05-2010 Todling   replace parallel_init w/ corresponding from gsi_4dcoupler
!  05-06-2010 Zhu       Add option adp_anglebc for radiance variational angle bias correction;
!                       npred was removed from setup namelist
!  05-12-2010 Zhu       Add option passive_bc for radiance bias correction for monitored channels
!  05-30-2010 Todling   reposition init of control and state vectors; add init_anasv; update chem
!  06-04-2010 Todling   update interface to init_grid_vars
!  06-05-2010 Todling   remove as,tsfc_sdv,an_amp0 from bkgerr namelist (now in anavinfo table)
!  08-10-2010 Wu        add nvege_type to gridopts namelist 
!  08-24-2010 hcHuang   add diag_aero and init_aero for aerosol observations
!  08-26-2010 Cucurull  add use_compress to setup namelist, add a call to gps_constants
!  09-06-2010 Todling   add Errico-Ehrendorfer parameter for E-norm used in DFI
!  09-03-2010 Todling   add opt to output true J-cost from within Lanczos (beware: expensive)
!  10-05-2010 Todling   add lbicg option
!  09-02-2010 Zhu       Add option use_edges for the usage of radiance data on scan edges
!  10-18-2010 hcHuang   Add option use_gfs_nemsio to read global model NEMS/GFS first guess
!  11-17-2010 Pagowski  add chemical species and related namelist
!  12-20-2010 Cucurull  add nsig_ext to setup namelist for the usage of gpsro bending angle
!  01-05-2011 Cucurull  add gpstop to setup namelist for the usage of gpsro data assimilation
!  04-08-2011 Li        (1) add integer variable nst_gsi and nstinfo for the use of oceanic first guess
!                       (2) add integer variable fac_dtl & fac_tsl to control the use of NST model
!                       (3) add integer variable tzr_qc to control the Tzr QC
!                       (4) add integer tzr_bufrsave to control if save Tz retrieval or not
!  04-07-2011 todling   move newpc4pred to radinfo
!  04-19-2011 El Akkraoui add iorthomax to control numb of vecs in orthogonalization for CG opts
!  05-05-2011 mccarty   removed references to repe_dw
!  05-21-2011 todling   add call to setservice
!  06-01-2011 guo/zhang add liauon
!  07-27-2011 todling   add use_prepb_satwnd to control usage of satwnd''s in prepbufr files
!  08-15-2011 gu/todling add pseudo-q2 option
!  09-10-2011 parrish   add use_localization_grid to handle (global) non-gaussian ensemble grid
!  09-14-2011 parrish/todling   add use_sp_eqspace for handling lat/lon grids
!  09-14-2011 todling   add use_gfs_ens to control global ensemble; also use_localization_grid
!  11-14-2011  wu       add logical switch to use extended forward model for sonde data
!  01-16-2012 m. tong   add parameter pseudo_hybens to turn on pseudo ensemble hybrid
!  01-17-2012 wu        add switches: gefs_in_regional,full_ensemble,pwgtflg
!  01-18-2012 parrish   add integer parameter regional_ensemble_option to select ensemble source.
!                                 =1: use GEFS internally interpolated to ensemble grid.
!                                 =2: ensembles are WRF NMM format.
!                                 =3: ensembles are ARW netcdf format.
!                                 =4: ensembles are NEMS NMMB format.
!  02-07-2012 tong      remove parameter gefs_in_regional and reduce regional_ensemble_option to
!                       4 options
!  02-08-2012 kleist    add parameters to control new 4d-ensemble-var features.
!  02-17-2012 tong      add parameter merge_two_grid_ensperts to merge ensemble perturbations
!                       from two forecast domains to analysis domain  
!  05-25-2012 li/wang   add TDR fore/aft sweep separation for thinning,xuguang.wang@ou.edu
!  06-12-2012 parrish   remove calls to subroutines init_mpi_vars, destroy_mpi_vars.
!                       add calls to init_general_commvars, destroy_general_commvars.
!  10-11-2012 eliu      add wrf_nmm_regional in determining logic for use_gfs_stratosphere                
!  05-14-2012 wargan    add adjustozvar to adjust ozone in stratosphere
!  05-14-2012 todling   defense to set nstinfo only when nst_gsi>0
!  05-23-2012 todling   add lnested_loops option
!  09-10-2012 Gu        add fut2ps to project unbalanced temp to surface pressure in static B modeling
!  12-05-2012 el akkraoui  hybrid beta parameters now vertically varying
!  07-10-2012 sienkiewicz  add ssmis_method control for noise reduction
!  02-19-2013 sienkiewicz  add ssmis_precond for SSMIS bias coeff weighting
!  04-15-2013 zhu       add aircraft_t_bc_pof and aircraft_t_bc for aircraft temperature bias correction
!  04-24-2013 parrish   move calls to subroutines init_constants and
!                       gps_constants before convert_regional_guess
!                       so that rearth is defined when used
!  05-07-2013 tong      add tdrerr_inflate for tdr obs err inflation and
!                       tdrgross_fact for tdr gross error adjustment
!  05-31-2013 wu        write ext_sonde output to standard out
!  07-02-2013 parrish   change tlnmc_type to reg_tlnmc_type.  tlnmc_type no
!                         longer used for global analysis.  
!                         for regional analysis, reg_tlnmc_type=1 or 2 for two
!                         different regional balance methods.
!  07-10-2013 zhu       add upd_pred as bias update indicator for radiance bias correction
!  07-19-2013 zhu       add emiss_bc for emissivity predictor in radiance bias correction scheme
!  08-20-2013 s.liu     add option to use reflectivity
!  09-27-2013 todling   redefine how instrument information is read into code (no longer namelist)
!  10-26-2013 todling   add regional_init; revisit init of aniso-filter arrays;
!                       revisit various init/final procedures
!  10-30-2013 jung      added clip_supersaturation to setup namelist
!  12-02-2013 todling   add call to set_fgrid2agrid
!  12-03-2013 Hu        add parameter grid_ratio_wrfmass for analysis on larger
!                              grid than mass background grid
!  12-10-2013 zhu       add cwoption
!  02-05-2014 todling   add parameter cwcoveqqcov (cw_cov=q_cov)
!  02-24-2014 sienkiewicz added aircraft_t_bc_ext for GMAO external aircraft temperature bias correction
!  04-21-2014 weir      replaced co settings with trace gas settings
!  05-29-2014 Thomas    add lsingleradob logical for single radiance ob test
!                       (originally of mccarty)
!  06-19-2014 carley/zhu  add factl and R_option for twodvar_regional lcbas/ceiling analysis
!  08-05-2014 carley    add safeguard so that oneobtest disables hilbert_curve if user accidentally sets hilbert_curve=.true.
!  10-04-2014 todling   revised meanning of parameter bcoption
!  08-18-2014 tong      add jcap_gfs to allow spectral transform to a coarser resolution grid,
!                       when running with use_gfs_ozone = .true. or use_gfs_stratosphere = .true. for
!                       regional analysis
!  10-07-2014 carley    added buddy check options under obsqc
!  11-12-2014 pondeca   must read in from gridopts before calling obsmod_init_instr_table. swap order
!  01-30-2015 Hu        added option i_en_perts_io,l_ens_in_diff_time under hybrid_ensemble
!  01-15-2015 Hu        added options i_use_2mq4b,i_use_2mt4b, i_gsdcldanal_type
!                              i_gsdsfc_uselist,i_lightpcp,i_sfct_gross under
!                              rapidrefresh_cldsurf
!  02-09-2015 Sienkiewicz id_drifter flag - modify KX values for drifting buoys if set
!  02-29-2015 S.Liu     added option l_use_hydroretrieval_all
!  03-01-2015 Li        add zsea1 & zsea2 to namelist for vertical mean temperature based on NSST T-Profile
!  05-02-2015 Parrish   add option rtma_bkerr_sub2slab to allow dual resolution for application of
!                       anisotropic recursive filter (RTMA application only for now).
!  05-13-2015 wu        remove check to turn off regional 4densvar
!  01-13-2015 Ladwig    added option l_numconc
!  09-01-2015 Hu        added option l_closeobs
!  10-01-2015 guo       option to redistribute observations in 4d observer mode
!  07-20-2015 zhu       re-structure codes for enabling all-sky/aerosol radiance assimilation, 
!                       add radiance_mode_init, radiance_mode_destroy & radiance_obstype_destroy
!  01-28-2016 mccarty   add netcdf_diag capability
!  03-02-2016 s.liu/carley - remove use_reflectivity and use i_gsdcldanal_type
!  03-10-2016 ejones    add control for gmi noise reduction
!  03-25-2016 ejones    add control for amsr2 noise reduction
!  04-18-2016 Yang      add closest_obs for selecting obs. from multi-report at a surface observation.
!  06-17-2016 Sienkiewicz  virtmp switch for oneobmod
!  06-24-2016 j. guo    added alwaysLocal => m_obsdiags::obsdiags_alwaysLocal to
!                       namelist /SETUP/.
!  08-12-2016 lippi     added namelist parameters for single radial wind
!                       experiment (anaz_rw,anel_rw,range_rw,sstn,lsingleradar,
!                       singleradar,learthrel_rw). added a radar station look-up
!                       table.
!  08-12-2016 Mahajan   NST stuff belongs in NST module, Adding a NST namelist
!                       option
!  08-24-2016 lippi     added nml option lnobalance to zero out all balance correlation
!                       matricies for univariate analysis.
!  08-28-2016 li - tic591: add use_readin_anl_sfcmask for consistent sfcmask
!                          between analysis grids and others
!  11-29-2016 shlyaeva  add lobsdiag_forenkf option for writing out linearized
!                       H(x) for EnKF
!  12-14-2016 lippi     added nml variable learthrel_rw for single radial
!                       wind observation test, and nml option for VAD QC
!                       vadwnd_l2rw_qc of level 2 winds.
!  02-02-2017 Hu        added option i_coastline to turn on the observation
!                              operator for surface observations along the coastline area
!  04-01-2017 Hu        added option i_gsdqc to turn on special observation qc
!                              from GSD (for RAP/HRRR application)
!  02-15-2016 Y. Wang, Johnson, X. Wang - added additional options if_vterminal, if_model_dbz,
!                                         for radar DA, POC: xuguang.wang@ou.edu
!  08-31-2017 Li        add sfcnst_comb for option to read sfc & nst combined file 
!  10-10-2017 Wu,W      added option fv3_regional and rid_ratio_fv3_regional, setup FV3, earthuv
!  01-11-2018 Yang      add namelist variables required by the nonlinear transform to vis and cldch
!                      (Jim Purser 2018). Add estvisoe and estcldchoe to replace the hardwired 
!                       prescribed vis/cldch obs. errort in read_prepbufr. (tentatively?)
!  03-22-2018 Yang      remove "logical closest_obs", previously applied to the analysis of vis and cldch.
!                       The option to use only the closest ob to the analysis time is now handled
!                       by Ming Hu''s "logical l_closeobs" for all variables.
!  01-04-2018 Apodaca   add diag_light and lightinfo for GOES/GLM lightning
!                           data assimilation
!  08-16-2018 akella    id_ship flag - modify KX values for ships if set
!  08-25-2018 Collard   Introduce bias_zero_start
!  09-12-2018 Ladwig    added option l_precip_clear_only
!  03-28-2019 Ladwig    merging additional options for cloud product assimilation
!  03-11-2019 Collard   Introduce ec_amv_qc as temporary control of GOES-16/17 AMVS
!  03-14-2019 eliu      add logic to turn on using full set of hydrometeors in
!                       obs operator and analysis
!  03-14-2019 eliu      add precipitation component 
!  05-09-2019 mtong     move initializing derivative vector here
!  06-19-2019 Hu        Add option reset_bad_radbc for reseting radiance bias correction when it is bad
!  06-25-2019 Hu        Add option print_obs_para to turn on OBS_PARA list
!  07-09-2019 Todling   Introduce cld_det_dec2bin and diag_version
!  07-11-2019 Todling   move vars imp_physics,lupp from CV to init_nems
!  08-14-2019 W. Gu     add lupdqc to replace the obs errors from satinfo with diag of est(R)
!  08-14-2019 W. Gu     add lqcoef to combine the inflation coefficients generated by qc with est(R)
!  10-15-2019 Wei/Martin   added option lread_ext_aerosol to read in aerfXX file for NEMS aerosols;
!                          added option use_fv3_aero to choose between NGAC and FV3GFS-GSDChem 
!  07-14-2020 todling   add adjustozhscl to scale ozone hscales (>0 will scale by this number)
!
!EOP
!-------------------------------------------------------------------------

! Declare variables.
  character(len=*),parameter :: myname='gsimod'

  logical:: writediag,l_foto
  integer(i_kind) i,ngroup

  character(len=*),parameter :: gsimain_rc = 'gsiberror.nml'

! Declare namelists with run-time gsi options.
!
! Namelists:  setup,gridopts,jcopts,bkgerr,anbkgerr,obsqc,obs_input,
!             singleob_test,superob_radar,emissjac,chem,nst
!
! SETUP (general control namelist) :
!
!     qoption  - option of analysis variable: 1:q/qsatg-bkg 2:norm RH
!     cwoption  - option of could-water analysis variable
!     pseudo_q2- breed between q1/q2 options, that is, (q1/sig(q))
!     mockbgk - if .true., use internally defined (fake) background fields
!     iadtest - perform various adjoint tests: <=0: none; 1=cv/sv; 2=<x,By>
!

  namelist/setup/&
       pseudo_q2,&
       cwoption,&
       qoption,&
       verbose,&
       l4densvar,&
       nmn_obsbin,&
       iadtest,&
       mockbkg

! GRIDOPTS (grid setup variables,including regional specific variables):
!     jcap     - spectral resolution
!     jcap_b   - background spectral resolution (when applicable)
!     nsig     - number of sigma levels
!     nlat     - number of latitudes
!     nlon     - number of longitudes
!     use_sp_eqspace    - if .true., then ensemble grid is equal spaced, staggered 1/2 grid unit off
!                         poles.  if .false., then gaussian grid assumed for ensemble (global only)


  namelist/gridopts/jcap,jcap_b,nlat,nlon,nsig,use_sp_eqspace,fv3_regional,grid_ratio_fv3_regional,&
                    regional,mpas_regional,rlat_start,rlat_end,rlon_start,rlon_end,&
                    north_pole_lat,north_pole_lon

! BKGERR (background error related variables):
!     vs       - scale factor for vertical correlation lengths for background error
!     nhscrf   - number of horizontal scales for recursive filter
!     hzscl(n) - scale factor for horizontal smoothing, n=1,number of scales (3 for now)
!                specifies factor by which to reduce horizontal scales (i.e. 2 would
!                then apply 1/2 of the horizontal scale
!     hswgt(n) - empirical weights to apply to each horizontal scale
!     norh     - order of interpolation in smoothing
!     ndeg     - degree of smoothing in recursive filters
!     noq      - 1/4 of accuracy in compact finite differencing
!     bw       - factor in background error calculation
!     norsp    - order of interpolation for smooth polar cascade routine
!                 default is norsp=0, in which case norh is used with original
!                 polar cascade interpolation.
!     pert_berror - logical to turn on random inflation/deflation of background error
!                   tuning parameters
!     pert_berr_fct - factor for increasing/decreasing berror parameters, this is multiplied
!                     by random number
!     bkgv_flowdep  - flag to turn on flow dependence to background error variances
!     bkgv_rewgtfct - factor used to perform flow dependent reweighting of error variances
!     bkgv_write - flag to turn on=.true. /off=.false. generation of binary file with reweighted variances
!     fpsproj  - controls full nsig projection to surface pressure
!     fut2ps  - controls the projection from unbalance T to surface pressure
!     adjustozvar - adjusts ozone variances in the stratosphere based on guess field
!     cwcoveqqcov  - sets cw Bcov to be the same as B-cov(q) (presently glb default)
!     adjustozhscl - when > 0, scales ozone horizontal scales by this number

  namelist/bkgerr/vs,nhscrf,hzscl,hswgt,norh,ndeg,noq,bw,norsp,fstat,pert_berr,pert_berr_fct, &
	bkgv_flowdep,bkgv_rewgtfct,bkgv_write,fpsproj,adjustozvar,fut2ps,cwcoveqqcov,adjustozhscl,&
        simcv,bkgv_write_cv,bkgv_write_sv,usenewgfsberror

! STRONGOPTS (strong dynamic constraint)
!     reg_tlnmc_type -  =1 for 1st version of regional strong constraint
!                       =2 for 2nd version of regional strong constraint
!     nstrong  - if > 0, then number of iterations of implicit normal mode initialization
!                   to apply for each inner loop iteration
!     period_max     - cutoff period for gravity waves included in implicit normal mode
!                    initialization (units = hours)
!     period_width   - defines width of transition zone from included to excluded gravity waves
!     period_max - cutoff period for gravity waves included in implicit normal mode
!                   initialization (units = hours)
!     period_width - defines width of transition zone from included to excluded gravity waves
!     nvmodes_keep - number of vertical modes to use in implicit normal mode initialization
!     baldiag_full
!     baldiag_inc
!     tlnmc_option : integer flag for strong constraint (various capabilities for hybrid)
!                   =0: no TLNMC
!                   =1: TLNMC for 3DVAR mode
!                   =2: TLNMC on total increment for single time level only (for 3D EnVar)
!                       or if 4D EnVar mode, TLNMC applied to increment in center of window
!                   =3: TLNMC on total increment over all time levels (if in 4D EnVar mode)
!                   =4: TLNMC on static contribution to increment ONLY for any EnVar mode

  namelist/strongopts/tlnmc_option, &
                      nstrong,period_max,period_width,nvmodes_keep, &
                      baldiag_full,baldiag_inc

! HYBRID_ENSEMBLE (parameters for use with hybrid ensemble option)
!     l_hyb_ens     - if true, then turn on hybrid ensemble option
!     uv_hyb_ens    - if true, then ensemble perturbation wind variables are u,v,
!                       otherwise, ensemble perturbation wind variables are stream, pot. functions.
!     q_hyb_ens     - if true, then use specific humidity ensemble perturbations,
!                       otherwise, use relative humidity
!     oz_univ_static- if true, decouple ozone from other variables and defaults to static B (ozone only)
!     aniso_a_en - if true, then use anisotropic localization of hybrid ensemble control variable a_en.
!     generate_ens - if true, then generate internal ensemble based on existing background error
!     n_ens        - number of ensemble members.
!     nlon_ens     - number of longitudes on ensemble grid (may be different from analysis grid nlon)
!     nlat_ens     - number of latitudes on ensemble grid (may be different from analysis grid nlat)
!     jcap_ens     - for global spectral model, spectral truncation
!     jcap_ens_test- for global spectral model, test spectral truncation (to test dual resolution)
!     beta_s0      -  the default weight given to static background error covariance if (.not. readin_beta)
!                              0 <= beta_s0 <= 1,  tuned for optimal performance
!                             =1, then ensemble information turned off
!                             =0, then static background turned off
!                            the weights are applied per vertical level such that : 
!                                        beta_s(:) = beta_s0     , vertically varying weights given to static B ; 
!                                        beta_e(:) = 1 - beta_s0 , vertically varying weights given ensemble derived covariance.
!                            If (readin_beta) then beta_s and beta_e are read from a file and beta_s0 is not used.
!     s_ens_h             - homogeneous isotropic horizontal ensemble localization scale (km)
!     s_ens_v             - vertical localization scale (grid units for now)
!                              s_ens_h, s_ens_v, and beta_s0 are tunable parameters.
!     use_gfs_ens  - controls use of global ensemble: .t. use GFS (default); .f. uses user-defined ens
!     readin_localization - flag to read (.true.)external localization information file
!     readin_beta         - flag to read (.true.) the vertically varying beta parameters beta_s and beta_e
!                              from a file.
!     eqspace_ensgrid     - if .true., then ensemble grid is equal spaced, staggered 1/2 grid unit off
!                               poles.  if .false., then gaussian grid assumed
!                               for ensemble (global only)
!     use_localization_grid - if true, then use extra lower res gaussian grid for horizontal localization
!                                   (global runs only--allows possiblity for non-gaussian ensemble grid)
!     pseudo_hybens    - if true, turn on pseudo ensemble hybrid for HWRF
!     merge_two_grid_ensperts  - if true, merge ensemble perturbations from two forecast domains
!                                to analysis domain (one way to deal with hybrid DA for HWRF moving nest)
!     regional_ensemble_option - integer, used to select type of ensemble to read in for regional
!                              application.  Currently takes values from 1 to 4.
!                                 =1: use GEFS internally interpolated to ensemble grid.
!                                 =2: ensembles are WRF NMM format
!                                 =3: ensembles are ARW netcdf format.
!                                 =4: ensembles are NEMS NMMB format.
!     full_ensemble    - if true, first ensemble perturbation on first guess istead of on ens mean
!     pwgtflg          - if true, use vertical integration function on ensemble contribution of Psfc
!     grid_ratio_ens   - for regional runs, ratio of ensemble grid resolution to analysis grid resolution
!                            default value = 1  (dual resolution off)
!     i_en_perts_io - flag to read in ensemble perturbations in ensemble grid.
!                         This is to speed up RAP/HRRR hybrid runs because the
!                         same ensemble perturbations are used in 6 cycles    
!                           =0:  No ensemble perturbations IO (default)
!                           =2:  skip get_gefs_for_regional and read in ensemble
!                                 perturbations from saved files.
!     l_ens_in_diff_time  -  if use ensembles that are available at different time
!                              from analysis time.
!                             =false: only ensembles available at analysis time
!                                      can be used for hybrid. (default)
!                             =true: ensembles available time can be different
!                                      from analysis time in hybrid analysis
!     ensemble_path - path to ensemble members; default './'
!     ens_fast_read - read ensemble in parallel; default '.false.'
!     sst_staticB - use only static background error covariance for SST statistic
!     bens_recenter - center Bens around background/guess
!     upd_ens_spread - update ens spread with recentering around guess 
!     upd_ens_localization - update ens localizations (goes together w/ upd_ens_spread)
!     ens_fname_tmpl - provides template name of ensmeble members
!              
!                         
  namelist/hybrid_ensemble/l_hyb_ens,uv_hyb_ens,q_hyb_ens,aniso_a_en,generate_ens,n_ens,nlon_ens,nlat_ens,jcap_ens,&
                pseudo_hybens,merge_two_grid_ensperts,regional_ensemble_option,full_ensemble,pwgtflg,&
                jcap_ens_test,beta_s0,s_ens_h,s_ens_v,readin_localization,eqspace_ensgrid,readin_beta,&
                grid_ratio_ens, ens_fname_tmpl, &
                oz_univ_static,write_ens_sprd,use_localization_grid,use_gfs_ens, &
                i_en_perts_io,l_ens_in_diff_time,ensemble_path,ens_fast_read,sst_staticB,&
                bens_recenter,upd_ens_spread,upd_ens_localization,EnsSource
   CONTAINS

!-------------------------------------------------------------------------
!  NASA/GSFC, Global Modeling and Assimilation Office, Code 610.3, GMAO  !
!-------------------------------------------------------------------------
!BOP

! ! IROUTINE: gsimain_initialize

! ! INTERFACE:

  subroutine gsimain_initialize_(nfldsig,nmlfile)

!*************************************************************
! Begin gsi code
!
  use gsi_fixture_GEOS, only: config_GEOS => fixture_config
  use gsi_fixture_GFS,  only: config_GFS  => fixture_config
  implicit none
  integer,optional,intent(in):: nfldsig
  character(len=*),optional,intent(in):: nmlfile

  character(len=*),parameter :: myname_=myname//'*gsimain_initialize'
  integer:: ier,ios,lendian_in,nfldsig_
  logical:: flag
  logical:: already_init_mpi
  real(r_kind):: varqc_max,c_varqc_new
  character(len=255) :: thisrc

  ierror=0
  if (present(nmlfile)) then
     thisrc = trim(nmlfile)
  else
     thisrc = gsimain_rc
  endif
  nfldsig_ = 1
  if (present(nfldsig)) then
    nfldsig_ = nfldsig
  endif

! Read in user specification of state and control variables
  call gsi_metguess_init(rcname=thisrc)
  call gsi_chemguess_init(rcname=thisrc)
  call init_anasv(rcname=thisrc)
  call init_anacv(rcname=thisrc)
  call init_anadv(rcname=thisrc)

  call init_io(mype,npe-1)
  call jfunc_init
  call init_constants_derived
  call init_constants(regional)
  call init_balmod
  call init_berror
  call init_grid
  call init_compact_diffs
  call init_smooth_polcas
  call init_strongvars
  call init_vtrans
  call init_hybrid_ensemble_parameters
  call set_fgrid2agrid
  call init_4dvar


! Read user input from namelists.  All processor elements 
! read the namelist input.  SGI MPI FORTRAN does not allow
! all tasks to read from standard in (unit 5).  Hence, open
! namelist to different unit number and have each task read 
! namelist file.
  open(11,file=thisrc)
  read(11,setup,iostat=ios)
  if(ios/=0) call die(myname_,'read(setup)',ios)  
  close(11)

  call gridopts0_(thisrc)

  open(11,file=thisrc)
  read(11,bkgerr,iostat=ios)
  if(ios/=0) call die(myname_,'read(bkgerr)',ios)
  close(11)

  open(11,file=thisrc)
  read(11,strongopts,iostat=ios)
  if(ios/=0) then
    call warn(myname_,'using default(strongopts)')
  endif
  close(11)

  open(11,file=thisrc)
  read(11,hybrid_ensemble,iostat=ios)
  if(ios/=0) then
     call warn(myname_,'using default(hybrid_ensemble)')
  endif
  close(11)

  if (l_hyb_ens) then
    select case (trim(uppercase(EnsSource)))
      case("GEOS")
        call config_GEOS()
      case("GFS")
        call config_GFS()
      case default
        call die(myname_,': unknown ensemble source')
    end select
  endif

  if(jcap > jcap_cut)then
    jcap_cut = jcap+1
    if(mype == 0)then
      write(6,*) ' jcap_cut increased to jcap+1 = ', jcap+1
      write(6,*) ' jcap_cut < jcap+1 not allowed '
    end if
  end if

!_RT call gsi_4dcoupler_setservices(rc=ier)
!_RT if(ier/=0) call die(myname_,'gsi_4dcoupler_setServices(), rc =',ier)

  call setup_4dvar(mype)

! Ensure valid number of horizontal scales
  if (nhscrf<0 .or. nhscrf>3) then
     if(mype==0) write(6,*)' GSIMOD: invalid specifications for number of horizontal scales nhscrf = ',nhscrf
     call die(myname_,'invalid nhscrf, check namelist settings',336)
  end if


! Write namelist output to standard out
  if(mype==0) then
     write(6,200)
200  format(' calling gsisub with following input parameters:',//)
     write(6,setup)
     write(6,gridopts)
     write(6,bkgerr)
     write(6,strongopts)
     write(6,hybrid_ensemble)
  endif

! Consistency check for TLNMC options
  if(reg_tlnmc_type>0) then
     call die(myname_,'regional optional not available',999)  
  endif
  if (tlnmc_option>=2 .and. tlnmc_option<=4) then
     if (.not.l_hyb_ens) then
     if(mype==0) write(6,*)' GSIMOD: inconsistent set of options for Hybrid/EnVar & TLNMC = ',l_hyb_ens,tlnmc_option
     if(mype==0) write(6,*)' GSIMOD: resetting tlnmc_option to 1 for 3DVAR mode'
     tlnmc_option=1
     end if
  else if (tlnmc_option<0 .or. tlnmc_option>4) then
     if(mype==0) write(6,*)' GSIMOD: This option does not yet exist for tlnmc_option: ',tlnmc_option
     if(mype==0) write(6,*)' GSIMOD: Reset to default 0'
     tlnmc_option=0
  end if
  if (tlnmc_option>0 .and. tlnmc_option<5) then
     l_tlnmc=.true.
     if(mype==0) write(6,*)' GSIMOD: valid TLNMC option chosen, setting l_tlnmc logical to true'
  end if

! If strong constraint is turned off, force other strong constraint variables to zero
  if ((.not.l_tlnmc) .and. nstrong/=0 ) then
     nstrong=0
     if (mype==0) write(6,*)'GSIMOD:  reset nstrong=',nstrong,&
          ' because TLNMC option is set to off= ',tlnmc_option
  endif
  if (.not.l_tlnmc) then
     baldiag_full=.false.
     baldiag_inc =.false.
  end if

! check consistency in q option
  if(pseudo_q2 .and. qoption==1)then
     if(mype==0)then
       write(6,*)' pseudo-q2 = ', pseudo_q2, ' qoption = ', qoption
       write(6,*)' pseudo-q2 must be used together w/ qoption=2 only, aborting.'
     endif
     call die(myname_,'consistency(q2)',999)  
  endif

  if (qoption==2.or.l_tlnmc) then
     tendsflag =.true.
     switch_on_derivatives = .true.
     if (mype==0) write(6,*)'GSIMOD:  tendencies and derivatives are on'
  endif

! Initialize variables, create/initialize arrays
  lendian_in = -1
  call create_ges_tendencies(tendsflag,thisrc)
  call create_ges_derivatives(switch_on_derivatives,nfldsig_)
  call init_reg_glob_ll(mype,lendian_in)
  call init_grid_vars(jcap,npe,cvars3d,cvars2d,nrf_var,mype)
  call init_general_commvars_dims (cvars2d,cvars3d,cvarsmd,nrf_var, &
                                   dvars2d,dvars3d)
  call init_general_commvars
  if (tendsflag) then
     call create_turblvars()
  endif

  if(mype==0)then
    write(6,*) myname_, ': Complete'
  endif
  
  end subroutine gsimain_initialize_

  subroutine gridopts0_(nmlfile)
  implicit none
  character(len=*),optional,intent(in)  :: nmlfile
  character(len=*),parameter :: myname_="gsimod*gridopts0_"
  integer(i_kind) :: ios
  character(len=255) :: thisrc

  if (present(nmlfile)) then
     thisrc = trim(nmlfile)
  else
     thisrc = gsimain_rc
  endif

! read in basic grid parameters
  open(11,file=thisrc)
  read(11,gridopts,iostat=ios)
  if(ios/=0) call die(myname_,'read(gridopts)',ios)  
  close(11)

  end subroutine gridopts0_
  
  subroutine gridopts1_(thisrc,thispe,npex,npey,&
                        gnlat,gnlon,gnlev,eqspace,&
                        glon2,glat2,&
                        isc,iec,jsc,jec,igdim)
  use general_sub2grid_mod, only: general_deter_subdomain_withLayout
  implicit none
  character(len=*),intent(in)  :: thisrc
  integer,intent(in)  :: thispe
  integer,intent(in)  :: npex,npey
  integer,intent(out) :: gnlat,gnlon,gnlev
  integer,intent(out) :: glon2,glat2
  logical,intent(out) :: eqspace
  integer,intent(out) :: isc,iec,jsc,jec,igdim
  character(len=*),parameter :: myname_="gsimod*gridopts1_"
  integer(i_kind) :: glon1,glat1,j,nxy,ios
  logical :: verbose,periodic
  logical,allocatable :: periodic_s(:)
  integer(i_kind),allocatable :: iglat1(:),igstart(:),jglon1(:),jgstart(:)

  verbose = thispe==0

  call gridopts0_(nmlfile=thisrc)
  gnlat=nlat
  gnlon=nlon
  gnlev=nsig
  eqspace=use_sp_eqspace

  nxy=npex*npey
  allocate(periodic_s(nxy))
  allocate(iglat1(nxy),igstart(nxy),jglon1(nxy),jgstart(nxy))

  call general_deter_subdomain_withLayout(nxy,npex,npey,&
                thispe,nlat,nlon,.false.,periodic,periodic_s,&
                glon1,glon2,glat1,glat2,&
                iglat1,igstart,jglon1,jgstart,&
                verbose)

  do j=1,nxy
     if(thispe==j-1) then
       isc = jgstart(j)
       iec = jgstart(j) + jglon1(j) - 1
       jsc = igstart(j)
       jec = igstart(j) + iglat1(j) - 1
     endif
  end do
  igdim=glon1*glat1

  deallocate(iglat1,igstart,jglon1,jgstart)
  deallocate(periodic_s)

  end subroutine gridopts1_
  
!-------------------------------------------------------------------------
!  NASA/GSFC, Global Modeling and Assimilation Office, Code 610.3, GMAO  !
!-------------------------------------------------------------------------
!BOP

! ! IROUTINE: gsimain_finalize

 subroutine gsimain_finalize_(closempi)

! !REVISION HISTORY:
!
!  30May2010 Todling - add final_anasv and final_anacv
!  27Oct2013 Todling - get mype again for consistency w/ initialize
!                      revisit a few of finalizes for consistency w/ init
!
!EOC
!---------------------------------------------------------------------------

  implicit none
  logical, intent(in) :: closempi
  integer :: ier
! Deallocate arrays

  call destroy_vtrans
  call destroy_ges_tendencies
  call destroy_ges_derivatives
! call final_reg_glob_ll ! if ever regional
  call destroy_general_commvars
  call final_general_commvars_dims
  call final_grid_vars
  call clean_4dvar
  call final_anadv
  call final_anacv
  call final_anasv
  call gsi_chemguess_final
  call gsi_metguess_final
  call gsi_metguess_destroy_grids(ier)
  call gsi_chemguess_destroy_grids(ier)
  call final_constants_derived
  call final_constants

  if (closempi) then
     call mpi_finalize(ierror)
  endif
 
 end subroutine gsimain_finalize_

 end module gsimod
