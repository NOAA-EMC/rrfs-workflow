# (C) Copyright 2022 UCAR.
#
# This software is licensed under the terms of the Apache Licence Version 2.0
# which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.

# Unit tests for filters

add_subdirectory(actions)
add_subdirectory(obsfunctions)


ufo_add_test( NAME    test_ufo_amsua_seaice_qc
              TIER    1
              ECBUILD
              COMMAND ${CMAKE_BINARY_DIR}/bin/test_ObsFilters.x
              ARGS    "${CMAKE_CURRENT_SOURCE_DIR}/amsua_seaice_qc.yaml"
              MPI     1
              LIBS    ufo
              LABELS  filters
              WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/../../../ )
#
ufo_add_test( NAME    test_ufo_assign_error_using_where
              TIER    1
              ECBUILD
              COMMAND ${CMAKE_BINARY_DIR}/bin/test_ObsFilters.x
              ARGS    "${CMAKE_CURRENT_SOURCE_DIR}/assign_error_using_where.yaml"
              MPI     1
              LIBS    ufo
              LABELS  filters
              WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/../../../ )
#
ufo_add_test( NAME    test_ufo_ensemblestatistics
              TIER    1
              ECBUILD
              COMMAND ${CMAKE_BINARY_DIR}/bin/test_EnsembleObsFilters.x
              ARGS    "${CMAKE_CURRENT_SOURCE_DIR}/ensemblestatistics.yaml"
              MPI     8
              LIBS    ufo
              LABELS  filters
              WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/../../../ )
#
ufo_add_test( NAME    test_ufo_ensemblestatistics_channels
              TIER    1
              ECBUILD
              COMMAND ${CMAKE_BINARY_DIR}/bin/test_EnsembleObsFilters.x
              ARGS    "${CMAKE_CURRENT_SOURCE_DIR}/ensemblestatistics_channels.yaml"
              MPI     8
              LIBS    ufo
              LABELS  filters
              WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/../../../ )
#
ufo_add_test( NAME    test_ufo_filter_stage
              TIER    1
              ECBUILD
              COMMAND ${CMAKE_BINARY_DIR}/bin/test_ObsFilters.x
              ARGS    "${CMAKE_CURRENT_SOURCE_DIR}/filter_stage.yaml"
              MPI     1
              LIBS    ufo
              LABELS  filters
              WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/../../../ )
#
ufo_add_test( NAME    test_ufo_filter_stage_mpi
              TIER    1
              ECBUILD
              COMMAND ${CMAKE_BINARY_DIR}/bin/test_ObsFilters.x
              ARGS    "${CMAKE_CURRENT_SOURCE_DIR}/filter_stage.yaml"
              MPI     2
              LIBS    ufo
              LABELS  filters
              WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/../../../ )
#
ufo_add_test( NAME    test_ufo_gnssrobendmetoffice_qc
              TIER    1
              ECBUILD
              COMMAND ${CMAKE_BINARY_DIR}/bin/test_ObsFilters.x
              ARGS    "${CMAKE_CURRENT_SOURCE_DIR}/gnssrobendmetoffice_qc.yaml"
              MPI     1
              LIBS    ufo
              LABELS  filters
              WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/../../../ )
#
ufo_add_test( NAME    test_ufo_gnssrobendmetoffice_qc_profile
              TIER    1
              ECBUILD
              COMMAND ${CMAKE_BINARY_DIR}/bin/test_ObsFilters.x
              ARGS    "${CMAKE_CURRENT_SOURCE_DIR}/gnssrobendmetoffice_qc_profile.yaml"
              MPI     1
              LIBS    ufo
              LABELS  filters
              WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/../../../ )
#
ufo_add_test( NAME    test_ufo_gnssrobendmetoffice_obserror
              TIER    1
              ECBUILD
              COMMAND ${CMAKE_BINARY_DIR}/bin/test_ObsFilters.x
              ARGS    "${CMAKE_CURRENT_SOURCE_DIR}/gnssrobendmetoffice_obserror.yaml"
              MPI     1
              LIBS    ufo
              LABELS  filters
              WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/../../../ )
#
ufo_add_test( NAME    test_ufo_gnssrorefmetoffice_qc
              TIER    1
              ECBUILD
              COMMAND ${CMAKE_BINARY_DIR}/bin/test_ObsFilters.x
              ARGS    "${CMAKE_CURRENT_SOURCE_DIR}/gnssrorefmetoffice_qc.yaml"
              MPI     1
              LIBS    ufo
              LABELS  filters
              WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/../../../ )
#
ufo_add_test( NAME    test_ufo_gnssrobndnbam_qc
              TIER    1
              ECBUILD
              COMMAND ${CMAKE_BINARY_DIR}/bin/test_ObsFilters.x
              ARGS    "${CMAKE_CURRENT_SOURCE_DIR}/gnssrobndnbam_qc.yaml"
              MPI     1
              LIBS    ufo
              LABELS  filters
              WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/../../../ )
#
ufo_add_test( NAME    test_ufo_gnssrobndnbam_qc_geos
              TIER    1
              ECBUILD
              COMMAND ${CMAKE_BINARY_DIR}/bin/test_ObsFilters.x
              ARGS    "${CMAKE_CURRENT_SOURCE_DIR}/gnssrobndnbam_qc_geos.yaml"
              MPI     1
              LIBS    ufo
              LABELS  filters
              WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/../../../ )
#
ufo_add_test( NAME    test_ufo_gnssrobndnbam_qc_action_obserr_inflation
              TIER    1
              ECBUILD
              COMMAND ${CMAKE_BINARY_DIR}/bin/test_ObsFilters.x
              ARGS    "${CMAKE_CURRENT_SOURCE_DIR}/gnssrobndnbam_qc_action_obserr_inflation.yaml"
              MPI     1
              LIBS    ufo
              LABELS  filters
              WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/../../../ )
#
ufo_add_test( NAME    test_ufo_gnssro_obs_error
              TIER    1
              ECBUILD
              COMMAND ${CMAKE_BINARY_DIR}/bin/test_ObsFilters.x
              ARGS    "${CMAKE_CURRENT_SOURCE_DIR}/gnssro_obs_error.yaml"
              MPI     1
              LIBS    ufo
              LABELS  filters
              WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/../../../ )

#
ufo_add_test( NAME    test_ufo_gnssro_super_refraction_check
              TIER    1
              ECBUILD
              COMMAND ${CMAKE_BINARY_DIR}/bin/test_ObsFilters.x
              ARGS    "${CMAKE_CURRENT_SOURCE_DIR}/gnssro_super_refraction_check.yaml"
              MPI     1
              LIBS    ufo
              LABELS  filters
              WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/../../../ )
#
ufo_add_test( NAME    test_ufo_metar_qc_filters
              TIER    1
              ECBUILD
              COMMAND ${CMAKE_BINARY_DIR}/bin/test_ObsFilters.x
              ARGS    "${CMAKE_CURRENT_SOURCE_DIR}/metar_qc_filters.yaml"
              MPI     1
              LIBS    ufo
              LABELS  filters
              WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/../../../ )
#
ufo_add_test( NAME    test_ufo_obserror_assign_unittests
              TIER    1
              ECBUILD
              SOURCES ../../../mains/TestObsErrorAssign.cc
              ARGS    "${CMAKE_CURRENT_SOURCE_DIR}/obserror_assign_unittests.yaml"
              MPI     1
              LIBS    ufo
              LABELS  filters
              WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/../../../ )
#
ufo_add_test( NAME    test_ufo_obsfilterdata
              TIER    1
              ECBUILD
              SOURCES ../../../mains/TestObsFilterData.cc
              ARGS    "${CMAKE_CURRENT_SOURCE_DIR}/obsfilterdata.yaml"
              MPI     1
              LIBS    ufo
              LABELS  filters
              WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/../../../ )
#
ufo_add_test( NAME    test_ufo_ompsnp_npp_qc_L127
              TIER    1
              ECBUILD
              COMMAND ${CMAKE_BINARY_DIR}/bin/test_ObsFilters.x
              ARGS    "${CMAKE_CURRENT_SOURCE_DIR}/ompsnp_npp_qc_L127.yaml"
              MPI     4
              LIBS    ufo
              LABELS  filters
              WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/../../../ )
#
ufo_add_test( NAME    test_ufo_print_filter_data
              TIER    1
              ECBUILD
              COMMAND ${CMAKE_BINARY_DIR}/bin/test_ObsFilters.x
              ARGS    "${CMAKE_CURRENT_SOURCE_DIR}/print_filter_data.yaml"
              MPI     1
              LIBS    ufo
              LABELS  filters
              WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/../../../ )
#
ufo_add_test( NAME    test_ufo_print_filter_data_MPI2
              TIER    1
              ECBUILD
              COMMAND ${CMAKE_BINARY_DIR}/bin/test_ObsFilters.x
              ARGS    "${CMAKE_CURRENT_SOURCE_DIR}/print_filter_data.yaml"
              MPI     2
              LIBS    ufo
              LABELS  filters
              WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/../../../ )
#
ufo_add_test( NAME    test_ufo_print_filter_data_MPI3
              TIER    1
              ECBUILD
              COMMAND ${CMAKE_BINARY_DIR}/bin/test_ObsFilters.x
              ARGS    "${CMAKE_CURRENT_SOURCE_DIR}/print_filter_data.yaml"
              MPI     3
              LIBS    ufo
              LABELS  filters
              WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/../../../ )
#
ufo_add_test( NAME    test_ufo_print_filter_data_inefficient_distribution
              TIER    1
              ECBUILD
              COMMAND ${CMAKE_BINARY_DIR}/bin/test_ObsFilters.x
              ARGS    "${CMAKE_CURRENT_SOURCE_DIR}/print_filter_data_inefficient_distribution.yaml"
              MPI     1
              LIBS    ufo
              LABELS  filters
              WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/../../../ )
#
ufo_add_test( NAME    test_ufo_print_filter_data_MPI2_rank0
              TIER    1
              ECBUILD
              COMMAND ${CMAKE_BINARY_DIR}/bin/test_ObsFilters.x
              ARGS    "${CMAKE_CURRENT_SOURCE_DIR}/print_filter_data_MPI2_rank0.yaml"
              MPI     2
              LIBS    ufo
              LABELS  filters
              WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/../../../ )
#
ufo_add_test( NAME    test_ufo_print_filter_data_time_window_selection
              TIER    1
              ECBUILD
              COMMAND ${CMAKE_BINARY_DIR}/bin/test_ObsFilters.x
              ARGS    "${CMAKE_CURRENT_SOURCE_DIR}/print_filter_data_time_window_selection.yaml"
              MPI     1
              LIBS    ufo
              LABELS  filters
              WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/../../../ )
#
ufo_add_test( NAME    test_ufo_print_filter_data_time_window_selection_MPI2
              TIER    1
              ECBUILD
              COMMAND ${CMAKE_BINARY_DIR}/bin/test_ObsFilters.x
              ARGS    "${CMAKE_CURRENT_SOURCE_DIR}/print_filter_data_time_window_selection.yaml"
              MPI     2
              LIBS    ufo
              LABELS  filters
              WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/../../../ )
#
ufo_add_test( NAME    test_ufo_processwhere
              TIER    1
              ECBUILD
              SOURCES ../../../mains/TestProcessWhere.cc
              ARGS    "${CMAKE_CURRENT_SOURCE_DIR}/processwhere.yaml"
              MPI     1
              LIBS    ufo
              LABELS  filters
              WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/../../../ )
#
ufo_add_test( NAME    test_ufo_qc_acceptlist
              TIER    1
              ECBUILD
              COMMAND ${CMAKE_BINARY_DIR}/bin/test_ObsFilters.x
              ARGS    "${CMAKE_CURRENT_SOURCE_DIR}/qc_acceptlist.yaml"
              MPI     1
              LIBS    ufo
              LABELS  filters
              WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/../../../ )
#
ufo_add_test( NAME    test_ufo_qc_backgroundcheck
              TIER    1
              ECBUILD
              COMMAND ${CMAKE_BINARY_DIR}/bin/test_ObsFilters.x
              ARGS    "${CMAKE_CURRENT_SOURCE_DIR}/qc_backgroundcheck.yaml"
              MPI     1
              LIBS    ufo
              LABELS  filters
              WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/../../../ )
#
ufo_add_test( NAME    test_ufo_qc_backgroundcheck_ensemblestatistics
              TIER    1
              ECBUILD
              COMMAND ${CMAKE_BINARY_DIR}/bin/test_EnsembleObsFilters.x
              ARGS    "${CMAKE_CURRENT_SOURCE_DIR}/qc_backgroundcheck_ensemblestatistics.yaml"
              MPI     8
              LIBS    ufo
              LABELS  filters
              WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/../../../ )
#
ufo_add_test( NAME    test_ufo_qc_bayesianbackgroundqcflags
              TIER    1
              ECBUILD
              COMMAND ${CMAKE_BINARY_DIR}/bin/test_ObsFilters.x
              ARGS    "${CMAKE_CURRENT_SOURCE_DIR}/qc_bayesianbackgroundqcflags.yaml"
              MPI     1
              LIBS    ufo
              LABELS  filters
              WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/../../../ )
#
ufo_add_test( NAME    test_ufo_qc_bayesian_background_check
              TIER    1
              ECBUILD
              COMMAND ${CMAKE_BINARY_DIR}/bin/test_ObsFilters.x
              ARGS    "${CMAKE_CURRENT_SOURCE_DIR}/qc_bayesian_background_check.yaml"
              MPI     1
              LIBS    ufo
              LABELS  filters
              WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/../../../ )
#
ufo_add_test( NAME    test_ufo_qc_boundscheck
              TIER    1
              ECBUILD
              COMMAND ${CMAKE_BINARY_DIR}/bin/test_ObsFilters.x
              ARGS    "${CMAKE_CURRENT_SOURCE_DIR}/qc_boundscheck.yaml"
              MPI     1
              LIBS    ufo
              LABELS  filters
              WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/../../../ )
#
ufo_add_test( NAME    test_ufo_qc_creatediagnosticflags
              TIER    1
              ECBUILD
              COMMAND ${CMAKE_BINARY_DIR}/bin/test_ObsFilters.x
              ARGS    "${CMAKE_CURRENT_SOURCE_DIR}/qc_creatediagnosticflags.yaml"
              MPI     1
              LIBS    ufo
              LABELS  filters
              WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/../../../ )
#
ufo_add_test( NAME    test_ufo_function_copy_flags_from_extended_to_original_space
              TIER    1
              ECBUILD
              COMMAND ${CMAKE_BINARY_DIR}/bin/test_ObsFilters.x
              ARGS    "${CMAKE_CURRENT_SOURCE_DIR}/qc_copy_flags_from_ext_to_orig_space.yaml"
              MPI     1
              LIBS    ufo
              LABELS  filters
              WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/../../../ )
#
ufo_add_test( NAME    test_ufo_qc_defer_to_post
              TIER    1
              ECBUILD
              COMMAND ${CMAKE_BINARY_DIR}/bin/test_ObsFilters.x
              ARGS    "${CMAKE_CURRENT_SOURCE_DIR}/qc_defer_to_post.yaml"
              MPI     1
              LIBS    ufo
              LABELS  filters
              WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/../../../ )
#
ufo_add_test( NAME    test_ufo_qc_derivative_dpdt
              TIER    1
              ECBUILD
              COMMAND ${CMAKE_BINARY_DIR}/bin/test_ObsFilters.x
              ARGS    "${CMAKE_CURRENT_SOURCE_DIR}/qc_derivative_dpdt.yaml"
              MPI     1
              LIBS    ufo
              LABELS  filters
              WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/../../../ )
#
ufo_add_test( NAME    test_ufo_qc_derivative_dxdt
              TIER    1
              ECBUILD
              COMMAND ${CMAKE_BINARY_DIR}/bin/test_ObsFilters.x
              ARGS    "${CMAKE_CURRENT_SOURCE_DIR}/qc_derivative_dxdt.yaml"
              MPI     1
              LIBS    ufo
              LABELS  filters
              WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/../../../ )
#
ufo_add_test( NAME    test_ufo_qc_differencecheck
              TIER    1
              ECBUILD
              COMMAND ${CMAKE_BINARY_DIR}/bin/test_ObsFilters.x
              ARGS    "${CMAKE_CURRENT_SOURCE_DIR}/qc_differencecheck.yaml"
              MPI     1
              LIBS    ufo
              LABELS  filters
              WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/../../../ )
#
ufo_add_test( NAME    test_ufo_qc_finalcheck
              TIER    1
              ECBUILD
              COMMAND ${CMAKE_BINARY_DIR}/bin/test_ObsFilters.x
              ARGS    "${CMAKE_CURRENT_SOURCE_DIR}/qc_finalcheck.yaml"
              MPI     1
              LIBS    ufo
              LABELS  filters
              WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/../../../ )
#
ufo_add_test( NAME    test_ufo_qc_gauss_thinning
              TIER    1
              ECBUILD
              COMMAND ${CMAKE_BINARY_DIR}/bin/test_ObsFilters.x
              ARGS    "${CMAKE_CURRENT_SOURCE_DIR}/qc_gauss_thinning.yaml"
              MPI     4
              LIBS    ufo
              LABELS  filters
              WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/../../../ )
#
ufo_add_test( NAME    test_ufo_qc_gauss_thinning_mean
              TIER    1
              ECBUILD
              COMMAND ${CMAKE_BINARY_DIR}/bin/test_ObsFilters.x
              ARGS    "${CMAKE_CURRENT_SOURCE_DIR}/qc_gauss_thinning_mean.yaml"
              MPI     4
              LIBS    ufo
              LABELS  filters
              WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/../../../ )
#
ufo_add_test( NAME    test_ufo_qc_gauss_thinning_mean_error
              TIER    1
              ECBUILD
              COMMAND ${CMAKE_BINARY_DIR}/bin/test_ObsFilters.x
              ARGS    "${CMAKE_CURRENT_SOURCE_DIR}/qc_gauss_thinning_mean_error.yaml"
              MPI     2
              LIBS    ufo
              LABELS  filters
              WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/../../../ )
#
ufo_add_test( NAME    test_ufo_qc_gauss_thinning_median
              TIER    1
              ECBUILD
              COMMAND ${CMAKE_BINARY_DIR}/bin/test_ObsFilters.x
              ARGS    "${CMAKE_CURRENT_SOURCE_DIR}/qc_gauss_thinning_median.yaml"
              MPI     4
              LIBS    ufo
              LABELS  filters
              WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/../../../ )
#
ufo_add_test( NAME    test_ufo_qc_gauss_thinning_ops
              TIER    1
              ECBUILD
              COMMAND ${CMAKE_BINARY_DIR}/bin/test_ObsFilters.x
              ARGS    "${CMAKE_CURRENT_SOURCE_DIR}/qc_gauss_thinning_ops.yaml"
              MPI     1
              LIBS    ufo
              LABELS  filters
              WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/../../../ )
#
ufo_add_test( NAME    test_ufo_qc_gauss_thinning_records_are_single_obs
              TIER    1
              ECBUILD
              COMMAND ${CMAKE_BINARY_DIR}/bin/test_ObsFilters.x
              ARGS    "${CMAKE_CURRENT_SOURCE_DIR}/qc_gauss_thinning_records_are_single_obs.yaml"
              MPI     4
              LIBS    ufo
              LABELS  filters
              WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/../../../ )
#
ufo_add_test( NAME    test_ufo_qc_gauss_thinning_satrad
              TIER    1
              ECBUILD
              SOURCES ../../../mains/TestGaussianThinning.cc
              ARGS    "${CMAKE_CURRENT_SOURCE_DIR}/qc_gauss_thinning_satrad.yaml"
              MPI     1
              LIBS    ufo
              LABELS  filters
              WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/../../../ )
#
ufo_add_test( NAME    test_ufo_qc_gauss_thinning_unittests
              TIER    1
              ECBUILD
              SOURCES ../../../mains/TestGaussianThinning.cc
              ARGS    "${CMAKE_CURRENT_SOURCE_DIR}/qc_gauss_thinning_unittests.yaml"
              MPI     1
              LIBS    ufo
              LABELS  filters
              WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/../../../ )
#
ufo_add_test( NAME    test_ufo_qc_grosserrorwholereport
              TIER    1
              ECBUILD
              COMMAND ${CMAKE_BINARY_DIR}/bin/test_ObsFilters.x
              ARGS    "${CMAKE_CURRENT_SOURCE_DIR}/qc_grosserrorwholereport.yaml"
              MPI     1
              LIBS    ufo
              LABELS  filters
              WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/../../../ )
#
ufo_add_test( NAME    test_ufo_qc_historycheck
              TIER    1
              ECBUILD
              COMMAND ${CMAKE_BINARY_DIR}/bin/test_ObsFilters.x
              ARGS    "${CMAKE_CURRENT_SOURCE_DIR}/qc_historycheck.yaml"
              MPI     1
              LIBS    ufo
              LABELS  filters
              WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/../../../ )
#
ufo_add_test( NAME    test_ufo_qc_historycheck_mpi
              TIER    1
              ECBUILD
              COMMAND ${CMAKE_BINARY_DIR}/bin/test_ObsFilters.x
              ARGS    "${CMAKE_CURRENT_SOURCE_DIR}/qc_historycheck.yaml"
              MPI     4
              LIBS    ufo
              LABELS  filters
              WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/../../../ )
#
ufo_add_test( NAME    test_ufo_qc_historycheck_unittests
              TIER    1
              ECBUILD
              SOURCES ../../../mains/TestHistoryCheck.cc
              ARGS    "${CMAKE_CURRENT_SOURCE_DIR}/qc_historycheck_unittests.yaml"
              MPI     1
              LIBS    ufo
              LABELS  filters
              WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/../../../ )
#
ufo_add_test( NAME    test_ufo_qc_met_office_buddy_check
              TIER    1
              ECBUILD
              COMMAND ${CMAKE_BINARY_DIR}/bin/test_ObsFilters.x
              ARGS    "${CMAKE_CURRENT_SOURCE_DIR}/qc_met_office_buddy_check.yaml"
              MPI     4
              LIBS    ufo
              LABELS  filters
              WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/../../../ )
#
ufo_add_test( NAME    test_ufo_qc_met_office_buddy_check_unittests
              TIER    1
              ECBUILD
              SOURCES ../../../mains/TestMetOfficeBuddyCheck.cc
              ARGS    "${CMAKE_CURRENT_SOURCE_DIR}/qc_met_office_buddy_check_unittests.yaml"
              MPI     1
              LIBS    ufo
              LABELS  filters
              WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/../../../ )
#
ufo_add_test( NAME    test_ufo_qc_met_office_buddy_pair_finder
              TIER    1
              ECBUILD
              SOURCES ../../../mains/TestMetOfficeBuddyPairFinder.cc
              ARGS    "${CMAKE_CURRENT_SOURCE_DIR}/qc_met_office_buddy_pair_finder.yaml"
              MPI     1
              LIBS    ufo
              LABELS  filters
              WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/../../../ )
#
ufo_add_test( NAME    test_ufo_qc_met_office_pressure_consistency_check
              TIER    1
              ECBUILD
              COMMAND ${CMAKE_BINARY_DIR}/bin/test_ObsFilters.x
              ARGS    "${CMAKE_CURRENT_SOURCE_DIR}/qc_met_office_pressure_consistency_check.yaml"
              MPI     2
              LIBS    ufo
              LABELS  filters
              WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/../../../ )
#
ufo_add_test( NAME    test_ufo_qc_modelbestfitpressure
              TIER    1
              ECBUILD
              COMMAND ${CMAKE_BINARY_DIR}/bin/test_ObsFilters.x
              ARGS    "${CMAKE_CURRENT_SOURCE_DIR}/qc_modelbestfitpressure.yaml"
              MPI     1
              LIBS    ufo
              LABELS  filters
              WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/../../../ )
#
ufo_add_test( NAME    test_ufo_qc_modelobthreshold
              TIER    2
              ECBUILD
              COMMAND ${CMAKE_BINARY_DIR}/bin/test_ObsFilters.x
              ARGS    "${CMAKE_CURRENT_SOURCE_DIR}/qc_modelobthreshold.yaml"
              MPI     1
              LIBS    ufo
              LABELS  filters
              WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/../../../ )
#
ufo_add_test( NAME    test_ufo_qc_multichannel_thinning
              TIER    1
              ECBUILD
              COMMAND ${CMAKE_BINARY_DIR}/bin/test_ObsFilters.x
              ARGS    "${CMAKE_CURRENT_SOURCE_DIR}/qc_multichannel_thinning.yaml"
              MPI     1
              LIBS    ufo
              LABELS  filters
              WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/../../../ )
#
ufo_add_test( NAME    test_ufo_qc_oceancolor_preqc
              TIER    1
              ECBUILD
              COMMAND ${CMAKE_BINARY_DIR}/bin/test_ObsFilters.x
              ARGS    "${CMAKE_CURRENT_SOURCE_DIR}/qc_oceancolor_preqc.yaml"
              MPI     1
              LIBS    ufo
              LABELS  filters
              WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/../../../ )
#
if( ${gsw_FOUND} )
    ufo_add_test( NAME    test_ufo_qc_ocean_vertical_stability_check
                  TIER    1
                  ECBUILD
                  COMMAND ${CMAKE_BINARY_DIR}/bin/test_ObsFilters.x
                  ARGS    "${CMAKE_CURRENT_SOURCE_DIR}/qc_ocean_vertical_stability_check.yaml"
                  MPI     4
                  LIBS    ufo
                  LABELS  filters
                  WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/../../../ )
endif( ${gsw_FOUND} )
#
ufo_add_test( NAME    test_ufo_qc_poisson_disk_thinning
              TIER    1
              ECBUILD
              COMMAND ${CMAKE_BINARY_DIR}/bin/test_ObsFilters.x
              ARGS    "${CMAKE_CURRENT_SOURCE_DIR}/qc_poisson_disk_thinning.yaml"
              MPI     2
              LIBS    ufo
              LABELS  filters
              WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/../../../ )
#
ufo_add_test( NAME    test_ufo_qc_poisson_disk_thinning_parallel
              TIER    1
              ECBUILD
              SOURCES ../../../mains/TestParallelPoissonDiskThinning.cc
              ARGS    "${CMAKE_CURRENT_SOURCE_DIR}/qc_poisson_disk_thinning_parallel.yaml"
              MPI     2
              LIBS    ufo
              LABELS  filters
              WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/../../../ )
#
ufo_add_test( NAME    test_ufo_qc_poisson_disk_thinning_unittests
              TIER    1
              ECBUILD
              SOURCES ../../../mains/TestPoissonDiskThinning.cc
              ARGS    "${CMAKE_CURRENT_SOURCE_DIR}/qc_poisson_disk_thinning_unittests.yaml"
              MPI     1
              LIBS    ufo
              LABELS  filters
              WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/../../../ )
#
ufo_add_test( NAME    test_ufo_qc_met_office_duplicate_check
              TIER    1
              ECBUILD
              COMMAND ${CMAKE_BINARY_DIR}/bin/test_ObsFilters.x
              ARGS    "${CMAKE_CURRENT_SOURCE_DIR}/qc_met_office_duplicate_check.yaml"
              MPI     1
              LIBS    ufo
              LABELS  filters
              WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/../../../ )
#
ufo_add_test( NAME    test_ufo_qc_met_office_duplicate_check_parallel
              TIER    1
              ECBUILD
              COMMAND ${CMAKE_BINARY_DIR}/bin/test_ObsFilters.x
              ARGS    "${CMAKE_CURRENT_SOURCE_DIR}/qc_met_office_duplicate_check.yaml"
              MPI     4
              LIBS    ufo
              LABELS  filters
              WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/../../../ )
#
ufo_add_test( NAME    test_ufo_qc_preqc
              TIER    1
              ECBUILD
              COMMAND ${CMAKE_BINARY_DIR}/bin/test_ObsFilters.x
              ARGS    "${CMAKE_CURRENT_SOURCE_DIR}/qc_preqc.yaml"
              MPI     1
              LIBS    ufo
              LABELS  filters
              WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/../../../ )
#
ufo_add_test( NAME    test_ufo_qc_preqc_halo
              TIER    1
              ECBUILD
              COMMAND ${CMAKE_BINARY_DIR}/bin/test_ObsFilters.x
              ARGS    "${CMAKE_CURRENT_SOURCE_DIR}/qc_preqc_halo.yaml"
              MPI     4
              LIBS    ufo
              LABELS  filters
              WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/../../../ )
#
ufo_add_test( NAME    test_ufo_qc_processamvqi
              TIER    1
              ECBUILD
              COMMAND ${CMAKE_BINARY_DIR}/bin/test_ObsFilters.x
              ARGS    "${CMAKE_CURRENT_SOURCE_DIR}/qc_processamvqi.yaml"
              MPI     2
              LIBS    ufo
              LABELS  filters
              WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/../../../ )
#
ufo_add_test( NAME    test_ufo_qc_average_obs_to_mod_levels
              TIER    1
              ECBUILD
              COMMAND ${CMAKE_BINARY_DIR}/bin/test_ObsFilters.x
              ARGS    "${CMAKE_CURRENT_SOURCE_DIR}/qc_profile_average_obs_to_mod_levels.yaml"
              MPI     1
              LIBS    ufo
              LABELS  filters
              WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/../../../ )
#
ufo_add_test( NAME    test_ufo_qc_profile_background_check
              TIER    1
              ECBUILD
              COMMAND ${CMAKE_BINARY_DIR}/bin/test_ObsFilters.x
              ARGS    "${CMAKE_CURRENT_SOURCE_DIR}/qc_profile_background_check.yaml"
              MPI     1
              LIBS    ufo
              LABELS  filters
              WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/../../../ )
#
ufo_add_test( NAME    test_ufo_qc_profile_fewobs_check
              TIER    1
              ECBUILD
              COMMAND ${CMAKE_BINARY_DIR}/bin/test_ObsFilters.x
              ARGS    "${CMAKE_CURRENT_SOURCE_DIR}/qc_profile_fewobs_check.yaml"
              MPI     1
              LIBS    ufo
              LABELS  filters
              WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/../../../ )
#
ufo_add_test( NAME    test_ufo_qc_profile_unflagobs_check
              TIER    1
              ECBUILD
              COMMAND ${CMAKE_BINARY_DIR}/bin/test_ObsFilters.x
              ARGS    "${CMAKE_CURRENT_SOURCE_DIR}/qc_profile_unflagobs_check.yaml"
              MPI     1
              LIBS    ufo
              LABELS  filters
              WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/../../../ )
#
ufo_add_test( NAME    test_ufo_qc_spike_and_step_check
              TIER    1
              ECBUILD
              COMMAND ${CMAKE_BINARY_DIR}/bin/test_ObsFilters.x
              ARGS    "${CMAKE_CURRENT_SOURCE_DIR}/qc_spike_and_step_check.yaml"
              MPI     4
              LIBS    ufo
              LABELS  filters
              WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/../../../ )
#
ufo_add_test( NAME    test_ufo_qc_stuckcheck
              TIER    1
              ECBUILD
              COMMAND ${CMAKE_BINARY_DIR}/bin/test_ObsFilters.x
              ARGS    "${CMAKE_CURRENT_SOURCE_DIR}/qc_stuckcheck.yaml"
              MPI     4
              LIBS    ufo
              LABELS  filters
              WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/../../../ )
#
ufo_add_test( NAME    test_ufo_qc_stuckcheck_unittests
              TIER    1
              ECBUILD
              SOURCES ../../../mains/TestStuckCheck.cc
              ARGS    "${CMAKE_CURRENT_SOURCE_DIR}/qc_stuckcheck_unittests.yaml"
              MPI     1
              LIBS    ufo
              LABELS  filters
              WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/../../../ )
#
ufo_add_test( NAME    test_ufo_qc_thinning
              TIER    1
              ECBUILD
              COMMAND ${CMAKE_BINARY_DIR}/bin/test_ObsFilters.x
              ARGS    "${CMAKE_CURRENT_SOURCE_DIR}/qc_thinning.yaml"
              MPI     1
              LIBS    ufo
              LABELS  filters
              WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/../../../ )
#
ufo_add_test( NAME    test_ufo_qc_temporal_thinning
              TIER    1
              ECBUILD
              COMMAND ${CMAKE_BINARY_DIR}/bin/test_ObsFilters.x
              ARGS    "${CMAKE_CURRENT_SOURCE_DIR}/qc_temporal_thinning.yaml"
              MPI     2
              LIBS    ufo
              LABELS  filters
              WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/../../../ )
#
ufo_add_test( NAME    test_ufo_qc_temporal_thinning_records_are_single_obs
              TIER    1
              ECBUILD
              COMMAND ${CMAKE_BINARY_DIR}/bin/test_ObsFilters.x
              ARGS    "${CMAKE_CURRENT_SOURCE_DIR}/qc_temporal_thinning_records_are_single_obs.yaml"
              MPI     4
              LIBS    ufo
              LABELS  filters
              WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/../../../ )
#
ufo_add_test( NAME    test_ufo_qc_temporal_thinning_unittests
              TIER    1
              ECBUILD
              SOURCES ../../../mains/TestTemporalThinning.cc
              ARGS    "${CMAKE_CURRENT_SOURCE_DIR}/qc_temporal_thinning_unittests.yaml"
              MPI     1
              LIBS    ufo
              LABELS  filters
              WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/../../../ )
#
ufo_add_test( NAME    test_ufo_qc_trackcheck
              TIER    1
              ECBUILD
              COMMAND ${CMAKE_BINARY_DIR}/bin/test_ObsFilters.x
              ARGS    "${CMAKE_CURRENT_SOURCE_DIR}/qc_trackcheck.yaml"
              MPI     4
              LIBS    ufo
              LABELS  filters
              WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/../../../ )
#
ufo_add_test( NAME    test_ufo_qc_trackcheckship
              TIER    1
              ECBUILD
              COMMAND ${CMAKE_BINARY_DIR}/bin/test_ObsFilters.x
              ARGS    "${CMAKE_CURRENT_SOURCE_DIR}/qc_trackcheckship.yaml"
              MPI     4
              LIBS    ufo
              LABELS  filters
              WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/../../../ )
#
ufo_add_test( NAME    test_ufo_qc_trackcheck_unittests
              TIER    1
              ECBUILD
              SOURCES ../../../mains/TestTrackCheck.cc
              ARGS    "${CMAKE_CURRENT_SOURCE_DIR}/qc_trackcheck_unittests.yaml"
              MPI     1
              LIBS    ufo
              LABELS  filters
              WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/../../../ )
#
ufo_add_test( NAME    test_ufo_qc_trackcheckship_unittests
              TIER    1
              ECBUILD
              SOURCES ../../../mains/TestTrackCheckShip.cc
              ARGS    "${CMAKE_CURRENT_SOURCE_DIR}/qc_trackcheckship_unittests.yaml"
              MPI     1
              LIBS    ufo
              LABELS  filters
              WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/../../../ )
#
ufo_add_test( NAME    test_ufo_qc_trackcheckship_mainloop_unittests
              TIER    1
              ECBUILD
              SOURCES ../../../mains/TestTrackCheckShipMainLoop.cc
              ARGS    "${CMAKE_CURRENT_SOURCE_DIR}/qc_trackcheckship_mainloop_unittests.yaml"
              MPI     1
              LIBS    ufo
              LABELS  filters
              WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/../../../ )
#
ufo_add_test( NAME    test_ufo_qc_variableassignment
              TIER    1
              ECBUILD
              COMMAND ${CMAKE_BINARY_DIR}/bin/test_ObsFilters.x
              ARGS    "${CMAKE_CURRENT_SOURCE_DIR}/qc_variableassignment.yaml"
              MPI     1
              LIBS    ufo
              LABELS  filters
              WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/../../../ )
#
ufo_add_test( NAME    test_ufo_satname
              TIER    1
              ECBUILD
              COMMAND ${CMAKE_BINARY_DIR}/bin/test_ObsFilters.x
              ARGS    "${CMAKE_CURRENT_SOURCE_DIR}/satname.yaml"
              MPI     1
              LIBS    ufo
              LABELS  filters
              WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/../../../ )
#
ufo_add_test( NAME    test_ufo_satwind_inversion_correction
              TIER    1
              ECBUILD
              COMMAND ${CMAKE_BINARY_DIR}/bin/test_ObsFilters.x
              ARGS    "${CMAKE_CURRENT_SOURCE_DIR}/satwind_inversion_correction.yaml"
              MPI     2
              LIBS    ufo
              LABELS  filters
              WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/../../../ )
#
ufo_add_test( NAME    test_ufo_iasi_qc
              TIER    1
              ECBUILD
              COMMAND ${CMAKE_BINARY_DIR}/bin/test_ObsFilters.x
              ARGS    "${CMAKE_CURRENT_SOURCE_DIR}/iasi_qc.yaml"
              MPI     1
              LIBS    ufo
              LABELS  filters
              WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/../../../ )
#
ufo_add_test( NAME    test_ufo_superob
              TIER    1
              ECBUILD
              COMMAND ${CMAKE_BINARY_DIR}/bin/test_ObsFilters.x
              ARGS    "${CMAKE_CURRENT_SOURCE_DIR}/superob.yaml"
              MPI     1
              LIBS    ufo
              LABELS  filters
              WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/../../../ )
#
ufo_add_test( NAME    test_ufo_superob_4PE
              TIER    1
              ECBUILD
              COMMAND ${CMAKE_BINARY_DIR}/bin/test_ObsFilters.x
              ARGS    "${CMAKE_CURRENT_SOURCE_DIR}/superob.yaml"
              MPI     4
              LIBS    ufo
              LABELS  filters
              WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/../../../ )
#
ufo_add_test( NAME    test_ufo_superob_radar
              TIER    1
              ECBUILD
              COMMAND ${CMAKE_BINARY_DIR}/bin/test_ObsFilters.x
              ARGS    "${CMAKE_CURRENT_SOURCE_DIR}/superob_radar.yaml"
              MPI     1
              LIBS    ufo
              LABELS  filters
              WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/../../../ )
#
ufo_add_test( NAME    test_ufo_superob_radar_4PE
              TIER    1
              ECBUILD
              COMMAND ${CMAKE_BINARY_DIR}/bin/test_ObsFilters.x
              ARGS    "${CMAKE_CURRENT_SOURCE_DIR}/superob_radar.yaml"
              MPI     4
              LIBS    ufo
              LABELS  filters
              WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/../../../ )
#
ufo_add_test( NAME    test_parameter_substitution
              TIER    1
              ECBUILD
              COMMAND ${CMAKE_BINARY_DIR}/bin/test_ObsFilters.x
              ARGS    "${CMAKE_CURRENT_SOURCE_DIR}/parameter_substitution.yaml"
              MPI     1
              LIBS    ufo
              LABELS  filters
              WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/../../../ )
#
ufo_add_test( NAME    test_ufo_polygon_check
              TIER    1
              ECBUILD
              COMMAND ${CMAKE_BINARY_DIR}/bin/test_ObsFilters.x
              ARGS    "${CMAKE_CURRENT_SOURCE_DIR}/polygon_check.yaml"
              MPI     1
              LIBS    ufo
              LABELS  filters
              WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/../../../ )

# Filters that require CRTM in ObsOperator

if( crtm_FOUND )
#
    ufo_add_test( NAME    test_ufo_airs_qc_filters
                  TIER    2
                  ECBUILD
                  COMMAND ${CMAKE_BINARY_DIR}/bin/test_ObsFilters.x
                  ARGS    "${CMAKE_CURRENT_SOURCE_DIR}/airs_qc_filters.yaml"
                  MPI     1
                  LIBS    ufo
                  LABELS  crtm filters
                  WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/../../../ )
#
    ufo_add_test( NAME    test_ufo_amsr2_qc
                  TIER    1
                  ECBUILD
                  COMMAND ${CMAKE_BINARY_DIR}/bin/test_ObsFilters.x
                  ARGS    "${CMAKE_CURRENT_SOURCE_DIR}/amsr2_qc.yaml"
                  MPI     1
                  LIBS    ufo
                  LABELS  crtm filters
                  WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/../../../ )
#
    ufo_add_test( NAME    test_ufo_amsr2_qc_halo
                  TIER    2
                  ECBUILD
                  COMMAND ${CMAKE_BINARY_DIR}/bin/test_ObsFilters.x
                  ARGS    "${CMAKE_CURRENT_SOURCE_DIR}/amsr2_qc_halo.yaml"
                  MPI     4
                  LIBS    ufo
                  LABELS  crtm filters
                  WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/../../../ )
#
    ufo_add_test( NAME    test_ufo_amsua_qc
                  TIER    1
                  ECBUILD
                  COMMAND ${CMAKE_BINARY_DIR}/bin/test_ObsFilters.x
                  ARGS    "${CMAKE_CURRENT_SOURCE_DIR}/amsua_qc.yaml"
                  MPI     1
                  LIBS    ufo
                  LABELS  crtm filters
                  WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/../../../ )
#
    ufo_add_test( NAME    test_ufo_amsua_allsky_gfs_gsi_qc
                  TIER    1
                  ECBUILD
                  COMMAND ${CMAKE_BINARY_DIR}/bin/test_ObsFilters.x
                  ARGS    "${CMAKE_CURRENT_SOURCE_DIR}/amsua_allsky_gfs_gsi_qc.yaml"
                  MPI     1
                  LIBS    ufo
                  LABELS  crtm filters
                  WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/../../../ )
#
    ufo_add_test( NAME    test_ufo_amsua_allsky_gsi_qc
                  TIER    1
                  ECBUILD
                  COMMAND ${CMAKE_BINARY_DIR}/bin/test_ObsFilters.x
                  ARGS    "${CMAKE_CURRENT_SOURCE_DIR}/amsua_allsky_gsi_qc.yaml"
                  MPI     1
                  LIBS    ufo
                  LABELS  crtm filters
                  WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/../../../ )
#
    ufo_add_test( NAME    test_ufo_amsua_qc_clwretmw
                  TIER    1
                  ECBUILD
                  COMMAND ${CMAKE_BINARY_DIR}/bin/test_ObsFilters.x
                  ARGS    "${CMAKE_CURRENT_SOURCE_DIR}/amsua_qc_clwretmw.yaml"
                  MPI     1
                  LIBS    ufo
                  LABELS  crtm filters
                  WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/../../../ )
#
    ufo_add_test( NAME    test_ufo_amsua_qc_filters
                  TIER    1
                  ECBUILD
                  COMMAND ${CMAKE_BINARY_DIR}/bin/test_ObsFilters.x
                  ARGS    "${CMAKE_CURRENT_SOURCE_DIR}/amsua_qc_filters.yaml"
                  MPI     1
                  LIBS    ufo
                  LABELS  crtm filters
                  WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/../../../ )
#
    ufo_add_test( NAME    test_ufo_amsua_qc_filters_geos
                  TIER    1
                  ECBUILD
                  COMMAND ${CMAKE_BINARY_DIR}/bin/test_ObsFilters.x
                  ARGS    "${CMAKE_CURRENT_SOURCE_DIR}/amsua_qc_filters_geos.yaml"
                  MPI     1
                  LIBS    ufo
                  LABELS  crtm filters
                  WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/../../../ )
#
    ufo_add_test( NAME    test_ufo_amsua_qc_miss_val
                  TIER    1
                  ECBUILD
                  COMMAND ${CMAKE_BINARY_DIR}/bin/test_ObsFilters.x
                  ARGS    "${CMAKE_CURRENT_SOURCE_DIR}/amsua_qc_miss_val.yaml"
                  MPI     1
                  LIBS    ufo
                  LABELS  crtm filters
                  WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/../../../ )
#
    ufo_add_test( NAME    test_ufo_atms_qc_filters
                  TIER    1
                  ECBUILD
                  COMMAND ${CMAKE_BINARY_DIR}/bin/test_ObsFilters.x
                  ARGS    "${CMAKE_CURRENT_SOURCE_DIR}/atms_qc_filters.yaml"
                  MPI     1
                  LIBS    ufo
                  LABELS  crtm filters
                  WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/../../../ )
#
    ufo_add_test( NAME    test_ufo_atms_n20_qc_filters_geos
                  TIER    1
                  ECBUILD
                  COMMAND ${CMAKE_BINARY_DIR}/bin/test_ObsFilters.x
                  ARGS    "${CMAKE_CURRENT_SOURCE_DIR}/atms_n20_qc_filters_geos.yaml"
                  MPI     1
                  LIBS    ufo
                  LABELS  crtm filters
                  WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/../../../ )
#
    ufo_add_test( NAME    test_ufo_cris_qc
                  TIER    1
                  ECBUILD
                  COMMAND ${CMAKE_BINARY_DIR}/bin/test_ObsFilters.x
                  ARGS    "${CMAKE_CURRENT_SOURCE_DIR}/cris_qc.yaml"
                  MPI     1
                  LIBS    ufo
                  LABELS  crtm filters
                  WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/../../../ )
#
    ufo_add_test( NAME    test_ufo_cris_qc_filters
                  TIER    2
                  ECBUILD
                  COMMAND ${CMAKE_BINARY_DIR}/bin/test_ObsFilters.x
                  ARGS    "${CMAKE_CURRENT_SOURCE_DIR}/cris_qc_filters.yaml"
                  MPI     1
                  LIBS    ufo
                  LABELS  crtm filters
                  WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/../../../ )
#
    ufo_add_test( NAME    test_ufo_cris_qc_land
                  TIER    1
                  ECBUILD
                  COMMAND ${CMAKE_BINARY_DIR}/bin/test_ObsFilters.x
                  ARGS    "${CMAKE_CURRENT_SOURCE_DIR}/cris_qc_land.yaml"
                  MPI     1
                  LIBS    ufo
                  LABELS  crtm filters
                  WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/../../../ )
#
    ufo_add_test( NAME    test_ufo_amsr2_qc_filters
                  TIER    1
                  ECBUILD
                  COMMAND ${CMAKE_BINARY_DIR}/bin/test_ObsFilters.x
                  ARGS    "${CMAKE_CURRENT_SOURCE_DIR}/amsr2_skylab_filters.yaml"
                  MPI     1
                  LIBS    ufo
                  LABELS  crtm filters
                  WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/../../../
                  TEST_DEPENDS ufo_get_ufo_test_data ufo_get_crtm_test_data ) 
#
    ufo_add_test( NAME    test_ufo_tropics_qc_filters
                  TIER    1
                  ECBUILD
                  COMMAND ${CMAKE_BINARY_DIR}/bin/test_ObsFilters.x
                  ARGS    "${CMAKE_CURRENT_SOURCE_DIR}/tropics_skylab_filters.yaml"
                  MPI     1
                  LIBS    ufo
                  LABELS  crtm filters
                  WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/../../../ )
#
    ufo_add_test( NAME    test_ufo_gmi_skylab_filters
                  TIER    1
                  ECBUILD
                  COMMAND ${CMAKE_BINARY_DIR}/bin/test_ObsFilters.x
                  ARGS    "${CMAKE_CURRENT_SOURCE_DIR}/gmi_skylab_filters.yaml"
                  MPI     1
                  LIBS    ufo
                  LABELS  crtm filters
                  WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/../../../ )
#
    ufo_add_test( NAME    test_ufo_gmi_qc_filters
                  TIER    1
                  ECBUILD
                  COMMAND ${CMAKE_BINARY_DIR}/bin/test_ObsFilters.x
                  ARGS    "${CMAKE_CURRENT_SOURCE_DIR}/gmi_qc_filters.yaml"
                  MPI     1
                  LIBS    ufo
                  LABELS  crtm filters
                  WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/../../../ )
#
    ufo_add_test( NAME    test_ufo_gmi_qc_filters_geos
                  TIER    1
                  ECBUILD
                  COMMAND ${CMAKE_BINARY_DIR}/bin/test_ObsFilters.x
                  ARGS    "${CMAKE_CURRENT_SOURCE_DIR}/gmi_qc_filters_geos.yaml"
                  MPI     1
                  LIBS    ufo
                  LABELS  crtm filters
                  WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/../../../ )
#
    ufo_add_test( NAME    test_ufo_iasi_qc_filters
                  TIER    2
                  ECBUILD
                  COMMAND ${CMAKE_BINARY_DIR}/bin/test_ObsFilters.x
                  ARGS    "${CMAKE_CURRENT_SOURCE_DIR}/iasi_qc_filters.yaml"
                  MPI     1
                  LIBS    ufo
                  LABELS  crtm filters
                  WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/../../../ )
#
    ufo_add_test( NAME    test_ufo_mhs_qc_filters_geos
                  TIER    1
                  ECBUILD
                  COMMAND ${CMAKE_BINARY_DIR}/bin/test_ObsFilters.x
                  ARGS    "${CMAKE_CURRENT_SOURCE_DIR}/mhs_qc_filters_geos.yaml"
                  MPI     1
                  LIBS    ufo
                  LABELS  crtm filters
                  WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/../../../ )
#
    ufo_add_test( NAME    test_ufo_qc_flags_true
              	  TIER    1
              	  ECBUILD
              	  COMMAND ${CMAKE_BINARY_DIR}/bin/test_ObsFilters.x
              	  ARGS    "${CMAKE_CURRENT_SOURCE_DIR}/abi_g16_qc_flags.yaml"
              	  MPI     1
              	  LIBS    ufo
              	  LABELS  filters
		  WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/../../../ )
endif( crtm_FOUND )

# Filters that require RTTOV in ObsOperator

if( ${rttov_FOUND} )
    ufo_add_test( NAME    test_ufo_amsr2_rttov_qc
                  TIER    1
                  ECBUILD
                  COMMAND ${CMAKE_BINARY_DIR}/bin/test_ObsFilters.x
                  ARGS    "${CMAKE_CURRENT_SOURCE_DIR}/amsr2_rttov_qc.yaml"
                  MPI     1
                  LIBS    ufo
                  LABELS  rttov filters
                  WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/../../../ )
#
    ufo_add_test( NAME    test_ufo_amsr2_rttov_ops_qc_rttovonedvarcheck
                  TIER    1
                  ECBUILD
                  COMMAND ${CMAKE_BINARY_DIR}/bin/test_ObsFilters.x
                  ARGS    "${CMAKE_CURRENT_SOURCE_DIR}/amsr2_rttov_ops_qc_rttovonedvarcheck.yaml"
                  MPI     1
                  LIBS    ufo
                  LABELS  rttov filters
                  WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/../../../ )
#
    ufo_add_test( NAME    test_ufo_atms_rttov_qc
                  TIER    1
                  ECBUILD
                  COMMAND ${CMAKE_BINARY_DIR}/bin/test_ObsFilters.x
                  ARGS    "${CMAKE_CURRENT_SOURCE_DIR}/atms_rttov_qc.yaml"
                  MPI     1
                  LIBS    ufo
                  LABELS  rttov filters
                  WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/../../../ )
#
    ufo_add_test( NAME    test_ufo_atms_rttov_ops_qc_rttovonedvarcheck
                  TIER    2
                  ECBUILD
                  COMMAND ${CMAKE_BINARY_DIR}/bin/test_ObsFilters.x
                  ARGS    "${CMAKE_CURRENT_SOURCE_DIR}/atms_rttov_ops_qc_rttovonedvarcheck.yaml"
                  MPI     1
                  LIBS    ufo
                  LABELS  rttov filters
                  WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/../../../ )
#
    ufo_add_test( NAME    test_ufo_iasi_rttov_ops_qc_rttovonedvarcheck
                  TIER    1
                  ECBUILD
                  COMMAND ${CMAKE_BINARY_DIR}/bin/test_ObsFilters.x
                  ARGS    "${CMAKE_CURRENT_SOURCE_DIR}/iasi_rttov_ops_qc_rttovonedvarcheck.yaml"
                  MPI     2
                  LIBS    ufo
                  LABELS  rttov filters
                  WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/../../../ )

    ufo_add_test( NAME    test_ufo_mtgirs_reconrad_obsop_check
                  TIER    1
                  ECBUILD
                  COMMAND ${CMAKE_BINARY_DIR}/bin/test_ObsFilters.x
                  ARGS    "${CMAKE_CURRENT_SOURCE_DIR}/mtgirs_reconrad_obsop_check.yaml"
                  MPI     1
                  LIBS    ufo
                  LABELS  rttov filters
                  WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/../../../ )
#
    ufo_add_test( NAME    test_ufo_ssmis_rttov_ops_qc_rttovonedvarcheck
                  TIER    1
                  ECBUILD
                  COMMAND ${CMAKE_BINARY_DIR}/bin/test_ObsFilters.x
                  ARGS    "${CMAKE_CURRENT_SOURCE_DIR}/ssmis_rttov_ops_qc_rttovonedvarcheck.yaml"
                  MPI     1
                  LIBS    ufo
                  LABELS  rttov filters
                  WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/../../../ )
#
    ufo_add_test( NAME    test_ufo_opr_atovs_rttovonedvar_multiplatform
                  TIER    2
                  ECBUILD
                  COMMAND ${CMAKE_BINARY_DIR}/bin/test_ObsFilters.x
                  ARGS    "${CMAKE_CURRENT_SOURCE_DIR}/atovs_rttovonedvar_multiplatform.yaml"
                  MPI     1
                  LIBS    ufo
                  LABELS  rttov filters
                  WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/../../../ )
#
    ufo_add_test( NAME    test_ufo_opr_atovs_rttovonedvar_transmittance
                  TIER    2
                  ECBUILD
                  COMMAND ${CMAKE_BINARY_DIR}/bin/test_ObsFilters.x
                  ARGS    "${CMAKE_CURRENT_SOURCE_DIR}/atovs_rttovonedvar_transmittance.yaml"
                  MPI     1
                  LIBS    ufo
                  LABELS  rttov filters
                  WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/../../../ )
#
    ufo_add_test( NAME    test_ufo_opr_atovs_rttovonedvar_transmittance_multiplatform
                  TIER    2
                  ECBUILD
                  COMMAND ${CMAKE_BINARY_DIR}/bin/test_ObsFilters.x
                  ARGS    "${CMAKE_CURRENT_SOURCE_DIR}/atovs_rttovonedvar_transmittance_multiplatform.yaml"
                  MPI     1
                  LIBS    ufo
                  LABELS  rttov filters
                  WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/../../../ )
endif( ${rttov_FOUND} )


# Filters that require ROPP in ObsOperator

if( ${ropp-ufo_FOUND} )

    ufo_add_test( NAME    test_ufo_gnssrobndropp1d_qc
                  TIER    1
                  ECBUILD
                  COMMAND ${CMAKE_BINARY_DIR}/bin/test_ObsFilters.x
                  ARGS    "${CMAKE_CURRENT_SOURCE_DIR}/gnssrobndropp1d_qc.yaml"
                  MPI     1
                  LIBS    ufo
                  LABELS  ropp-ufo filters
                  WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/../../../ )
endif( ${ropp-ufo_FOUND} )

ufo_add_test( NAME    test_ufo_preprocess
              TIER    1
              ECBUILD
              COMMAND ${CMAKE_BINARY_DIR}/bin/ufo_preprocess.x
              ARGS    "${CMAKE_CURRENT_SOURCE_DIR}/preprocess.yaml"
              MPI     1
              LIBS    ufo
              LABELS  filters
              WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/../../../ )
