gsi_namelist="
 &SETUP
   miter=${miter},niter(1)=${niter1},niter(2)=${niter2},
   write_diag(1)=.true.,write_diag(2)=${write_diag_2},write_diag(3)=.true.,
   qoption=2,print_obs_para=.true.,diag_radardbz=${diag_radardbz},
   if_model_dbz=${if_model_dbz},static_gsi_nopcp_dbz=0.0,if_use_w_vr=.false.,
   rmesh_dbz=4.0,rmesh_vr=4.0,zmesh_dbz=1000.0,zmesh_vr=1000.0,
   inflate_dbz_obserr=.true.,missing_to_nopcp=.false.,radar_no_thinning=.true.,
   gencode=78,factqmin=0.0,factqmax=0.0,
   iguess=-1,crtm_coeffs_path='./crtm_coeffs/',
   lread_obs_save=${lread_obs_save},lread_obs_skip=${lread_obs_skip},
   ${ens_nstarthr:+"ens_nstarthr=$ens_nstarthr,"}
   oneobtest=.false.,retrieval=.false.,
   nhr_assimilation=3,l_foto=.false.,
   use_pbl=.false.,use_prepb_satwnd=$ifsatbufr,
   newpc4pred=.true.,adp_anglebc=.true.,angord=4,
   passive_bc=.true.,use_edges=.false.,emiss_bc=.true.,
   diag_precon=.true.,step_start=1.e-3,
   l4densvar=.false.,nhr_obsbin=3,
   use_gfs_nemsio=.false.,use_gfs_ncio=.true.,reset_bad_radbc=.true.,
   netcdf_diag=${netcdf_diag},binary_diag=${binary_diag},
   l_obsprvdiag=${l_obsprvdiag},
   lwrite_peakwt=.true.,
 /     
 &GRIDOPTS
   fv3_regional=.true.,grid_ratio_fv3_regional=${grid_ratio_fv3},nvege_type=20,
   fv3_io_layout_y=${n_iolayouty},
 /
 &BKGERR
   vs=${bkgerr_vs},
   hzscl=${bkgerr_hzscl},
   bw=0.,fstat=.true.,
   usenewgfsberror=${usenewgfsberror},
/
 &ANBKGERR
   anisotropic=.false.,
 /
 &JCOPTS
 /
 &STRONGOPTS
 /
 &OBSQC
   dfact=0.75,dfact1=3.0,noiqc=.false.,c_varqc=0.02,vadfile='prepbufr',
   vadwnd_l2rw_qc=.true.,
 /
 &OBS_INPUT
   dmesh(1)=120.0,dmesh(2)=60.0,dmesh(3)=30,time_window_max=1.5,time_window_rad=1.0,ext_sonde=.true.,
 /
OBS_INPUT::
!  dfile          dtype       dplat     dsis                 dval    dthin dsfcalc
   pm25bufr       pm2_5       null      TEOM                 1.0     0     0
   dbzobs.nc      dbz         null      dbz                  1.0     0     0
   prepbufr       ps          null      ps                   1.0     0     0
   prepbufr       t           null      t                    1.0     0     0
   prepbufr       q           null      q                    1.0     0     0
   prepbufr       pw          null      pw                   1.0     0     0
   satwndbufr     uv          null      uv                   1.0     0     0
   prepbufr       uv          null      uv                   1.0     0     0
   prepbufr       spd         null      spd                  1.0     0     0
   prepbufr       dw          null      dw                   1.0     0     0
   l2rwbufr       rw          null      l2rw                 1.0     0     0
   prepbufr       sst         null      sst                  1.0     0     0
   gpsrobufr      gps_ref     null      gps                  1.0     0     0
   ssmirrbufr     pcp_ssmi    dmsp      pcp_ssmi             1.0    -1     0
   tmirrbufr      pcp_tmi     trmm      pcp_tmi              1.0    -1     0
   sbuvbufr       sbuv2       n16       sbuv8_n16            0.0     0     0
   sbuvbufr       sbuv2       n17       sbuv8_n17            0.0     0     0
   sbuvbufr       sbuv2       n18       sbuv8_n18            0.0     0     0
   hirs3bufr      hirs3       n16       hirs3_n16            0.0     1     0
   hirs3bufr      hirs3       n17       hirs3_n17            0.0     1     0
   hirs4bufr      hirs4       metop-a   hirs4_metop-a        0.0     2     0
   hirs4bufr      hirs4       n18       hirs4_n18            0.0     1     0
   hirs4bufr      hirs4       n19       hirs4_n19            0.0     2     0
   hirs4bufr      hirs4       metop-b   hirs4_metop-b        0.0     2     0
   gimgrbufr      goes_img    g11       imgr_g11             0.0     1     0
   gimgrbufr      goes_img    g12       imgr_g12             0.0     1     0
   airsbufr       airs        aqua      airs_aqua            0.0     2     0
   amsuabufr      amsua       n15       amsua_n15            0.0     2     0
   amsuabufr      amsua       n18       amsua_n18            0.0     2     0
   amsuabufr      amsua       n19       amsua_n19            0.0     2     0
   amsuabufr      amsua       metop-a   amsua_metop-a        0.0     2     0
   amsuabufr      amsua       metop-b   amsua_metop-b        0.0     2     0
   amsuabufr      amsua       metop-c   amsua_metop-c        0.0     2     0
   airsbufr       amsua       aqua      amsua_aqua           0.0     2     0
   amsubbufr      amsub       n17       amsub_n17            0.0     1     0
   mhsbufr        mhs         n18       mhs_n18              0.0     2     0
   mhsbufr        mhs         n19       mhs_n19              0.0     2     0
   mhsbufr        mhs         metop-a   mhs_metop-a          0.0     2     0
   mhsbufr        mhs         metop-b   mhs_metop-b          0.0     2     0
   mhsbufr        mhs         metop-c   mhs_metop-c          0.0     2     0
   ssmitbufr      ssmi        f13       ssmi_f13             0.0     2     0
   ssmitbufr      ssmi        f14       ssmi_f14             0.0     2     0
   ssmitbufr      ssmi        f15       ssmi_f15             0.0     2     0
   amsrebufr      amsre_low   aqua      amsre_aqua           0.0     2     0
   amsrebufr      amsre_mid   aqua      amsre_aqua           0.0     2     0
   amsrebufr      amsre_hig   aqua      amsre_aqua           0.0     2     0
   ssmisbufr      ssmis       f16       ssmis_f16            0.0     2     0
   ssmisbufr      ssmis       f17       ssmis_f17            0.0     2     0
   ssmisbufr      ssmis       f18       ssmis_f18            0.0     2     0
   ssmisbufr      ssmis       f19       ssmis_f19            0.0     2     0
   gsnd1bufr      sndrd1      g12       sndrD1_g12           0.0     1     0
   gsnd1bufr      sndrd2      g12       sndrD2_g12           0.0     1     0
   gsnd1bufr      sndrd3      g12       sndrD3_g12           0.0     1     0
   gsnd1bufr      sndrd4      g12       sndrD4_g12           0.0     1     0
   gsnd1bufr      sndrd1      g11       sndrD1_g11           0.0     1     0
   gsnd1bufr      sndrd2      g11       sndrD2_g11           0.0     1     0
   gsnd1bufr      sndrd3      g11       sndrD3_g11           0.0     1     0
   gsnd1bufr      sndrd4      g11       sndrD4_g11           0.0     1     0
   gsnd1bufr      sndrd1      g13       sndrD1_g13           0.0     1     0
   gsnd1bufr      sndrd2      g13       sndrD2_g13           0.0     1     0
   gsnd1bufr      sndrd3      g13       sndrD3_g13           0.0     1     0
   gsnd1bufr      sndrd4      g13       sndrD4_g13           0.0     1     0
   gsnd1bufr      sndrd1      g15       sndrD1_g15           0.0     2     0
   gsnd1bufr      sndrd2      g15       sndrD2_g15           0.0     2     0
   gsnd1bufr      sndrd3      g15       sndrD3_g15           0.0     2     0
   gsnd1bufr      sndrd4      g15       sndrD4_g15           0.0     2     0
   iasibufr       iasi        metop-a   iasi_metop-a         0.0     2     0
   gomebufr       gome        metop-a   gome_metop-a         0.0     2     0
   omibufr        omi         aura      omi_aura             0.0     2     0
   sbuvbufr       sbuv2       n19       sbuv8_n19            0.0     0     0
   tcvitl         tcp         null      tcp                  0.0     0     0
   seviribufr     seviri      m08       seviri_m08           0.0     2     0
   seviribufr     seviri      m09       seviri_m09           0.0     2     0
   seviribufr     seviri      m10       seviri_m10           0.0     2     0
   seviribufr     seviri      m11       seviri_m11           0.0     2     0
   iasibufr       iasi        metop-b   iasi_metop-b         0.0     2     0
   iasibufr       iasi        metop-c   iasi_metop-c         0.0     2     0
   gomebufr       gome        metop-b   gome_metop-b         0.0     2     0
   atmsbufr       atms        npp       atms_npp             0.0     2     0
   atmsbufr       atms        n20       atms_n20             0.0     2     0
   atmsbufr       atms        n21       atms_n21             0.0     2     0
   crisbufr       cris        npp       cris_npp             0.0     2     0
   crisfsbufr     cris-fsr    npp       cris-fsr_npp         0.0     2     0 
   crisfsbufr     cris-fsr    n20       cris-fsr_n20         0.0     2     0 
   crisfsbufr     cris-fsr    n21       cris-fsr_n21         0.0     2     0 
   abibufr        abi         g16       abi_g16              0.0     2     0
   mlsbufr        mls30       aura      mls30_aura           0.0     0     0
   oscatbufr      uv          null      uv                   0.0     0     0
   prepbufr       mta_cld     null      mta_cld              1.0     0     0
   prepbufr       gos_ctp     null      gos_ctp              1.0     0     0
   refInGSI       rad_ref     null      rad_ref              1.0     0     0
   lghtInGSI      lghtn       null      lghtn                1.0     0     0
   larcInGSI      larccld     null      larccld              1.0     0     0
   abibufr        abi         g18       abi_g18              0.0     2     0
::
 &SUPEROB_RADAR
   del_azimuth=5.,del_elev=.25,del_range=5000.,del_time=.5,elev_angle_max=5.,minnum=50,range_max=100000., l2superob_only=.false.,
 /
 &LAG_DATA
 /
 &HYBRID_ENSEMBLE
   l_hyb_ens=${ifhyb},
   uv_hyb_ens=.true.,
   q_hyb_ens=${q_hyb_ens},
   aniso_a_en=.false.,generate_ens=.false.,
   n_ens=${nummem},
   l_both_fv3sar_gfs_ens=${l_both_fv3sar_gfs_ens},n_ens_gfs=${nummem_gfs},n_ens_fv3sar=${nummem_fv3sar},
   weight_ens_gfs=${weight_ens_gfs},weight_ens_fv3sar=${weight_ens_fv3sar},
   beta_s0=${beta1_inv},s_ens_h=${ens_h},s_ens_v=${ens_v},
   regional_ensemble_option=${regional_ensemble_option},
   pseudo_hybens = .false.,
   grid_ratio_ens = ${grid_ratio_ens},
   l_ens_in_diff_time=.true.,
   ensemble_path='',
   i_en_perts_io=${i_en_perts_io},
   jcap_ens=574,
   fv3sar_bg_opt=${fv3lam_bg_type},
   readin_localization=${readin_localization},
   parallelization_over_ensmembers=${ens_fast_read},
   nsclgrp=${nsclgrp},l_timloc_opt=.false.,ngvarloc=${ngvarloc},naensloc=${naensloc},
   r_ensloccov4tim=${r_ensloccov4tim},r_ensloccov4var=${r_ensloccov4var},r_ensloccov4scl=${r_ensloccov4scl},
   global_spectral_filter_sd=.false.,assign_vdl_nml=${assign_vdl_nml},vdl_scale=${vdl_scale},
   vloc_varlist(1,1)='sf ',vloc_varlist(2,1)='w  ',vloc_varlist(3,1)='sf ',vloc_varlist(4,1)='w  ',
   vloc_varlist(1,2)='vp ',vloc_varlist(2,2)='qr ',vloc_varlist(3,2)='vp ',vloc_varlist(4,2)='qr ',
   vloc_varlist(1,3)='ps ',vloc_varlist(2,3)='qs ',vloc_varlist(3,3)='ps ',vloc_varlist(4,3)='qs ',
   vloc_varlist(1,4)='t  ',vloc_varlist(2,4)='qi ',vloc_varlist(3,4)='t  ',vloc_varlist(4,4)='qi ',
   vloc_varlist(1,5)='q  ',vloc_varlist(2,5)='qg ',vloc_varlist(3,5)='q  ',vloc_varlist(4,5)='qg ',
   vloc_varlist(1,6)='sst',vloc_varlist(2,6)='ql ',vloc_varlist(3,6)='sst',vloc_varlist(4,6)='ql ',
   vloc_varlist(1,7)='stl',vloc_varlist(2,7)='dbz',vloc_varlist(3,7)='stl',vloc_varlist(4,7)='dbz',
   vloc_varlist(1,8)='sti',vloc_varlist(2,8)='aaa',vloc_varlist(3,8)='sti',vloc_varlist(4,8)='aaa',
 /
 &RAPIDREFRESH_CLDSURF
   dfi_radar_latent_heat_time_period=20.0,
   metar_impact_radius=10.0,
   metar_impact_radius_lowCloud=4.0,
   l_gsd_terrain_match_surfTobs=.true.,
   l_sfcobserror_ramp_t=.true.,
   l_sfcobserror_ramp_q=.true.,
   l_PBL_pseudo_SurfobsT=.false.,
   l_PBL_pseudo_SurfobsQ=.false.,
   l_PBL_pseudo_SurfobsUV=.false.,
   pblH_ration=0.4,
   pps_press_incr=40.0,
   l_gsd_limit_ocean_q=.true.,
   l_pw_hgt_adjust=.true.,
   l_limit_pw_innov=.true.,
   max_innov_pct=0.1,
   l_cleanSnow_WarmTs=.true.,
   r_cleanSnow_WarmTs_threshold=5.0,
   l_conserve_thetaV=.true.,
   i_conserve_thetaV_iternum=3,
   l_gsd_soilTQ_nudge=${ifsoilnudge},
   l_cld_bld=.true.,
   l_numconc=.true.,
   l_closeobs=.true.,
   cld_bld_hgt=1200.0,
   build_cloud_frac_p=0.50,
   clear_cloud_frac_p=0.10,
   iclean_hydro_withRef_allcol=1,
   i_use_2mQ4B=${i_use_2mQ4B},
   i_use_2mT4B=${i_use_2mT4B},
   i_gsdcldanal_type=0,
   i_gsdsfc_uselist=1,
   i_lightpcp=1,
   i_sfct_gross=1,
   i_coastline=3,
   i_gsdqc=2,
 /
 &CHEM
  laeroana_fv3smoke=${laeroana_fv3smoke},
  berror_fv3_cmaq_regional=${berror_fv3_cmaq_regional},
 /
 &NST
 /
 &SINGLEOB_TEST
   maginnov=1.0,magoberr=0.8,oneob_type='t',
   oblat=38.,oblon=279.,obpres=500.,obdattim=2020040500,
   obhourset=0.,
 /
"
