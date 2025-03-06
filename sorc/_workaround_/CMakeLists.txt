# (C) Copyright 2017-2022 UCAR.
#
# This software is licensed under the terms of the Apache Licence Version 2.0
# which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
include(ufo_functions)

add_subdirectory( basis )
add_subdirectory( errors )
add_subdirectory( filters )
add_subdirectory( fov )
add_subdirectory( obslocalization )
add_subdirectory( predictors )
add_subdirectory( profile )
add_subdirectory( superob )
add_subdirectory( utils )
add_subdirectory( variabletransforms )

# Operators
add_subdirectory( operators/aerosols )
add_subdirectory( operators/atmvertinterplay )
add_subdirectory( operators/atmsfcinterp )
add_subdirectory( operators/columnretrieval )
add_subdirectory( operators/backgrounderroridentity )
add_subdirectory( operators/backgrounderrorvertinterp )
add_subdirectory( operators/categoricaloper )
add_subdirectory( operators/compositeoper )
if( crtm_FOUND )
    add_subdirectory( operators/crtm )
endif()
add_subdirectory( operators/gnssro )
add_subdirectory( operators/groundgnss )
add_subdirectory( operators/identity )
add_subdirectory( operators/insitupm )
add_subdirectory( operators/logarithm )
add_subdirectory( operators/marine )
if(oasim_FOUND)
    add_subdirectory( operators/oasim)
endif()
add_subdirectory( operators/product )
add_subdirectory( operators/radardopplerwind )
add_subdirectory( operators/radarradialvelocity )
add_subdirectory( operators/radarreflectivity)
if( rttov_FOUND )
    add_subdirectory( operators/rttov )
    add_subdirectory( operators/rttovcpp )
endif()
add_subdirectory( operators/sattcwv )
add_subdirectory( operators/scatwind )
add_subdirectory( operators/sfcpcorrected )
add_subdirectory( operators/sfccorrected )
add_subdirectory( operators/timeoper )
add_subdirectory( operators/vertinterp )
add_subdirectory( operators/lightning )
add_subdirectory( operators/windspeed )


# Base files

list( APPEND ufo_src_files
    Fortran.h
    AnalyticInit.cc
    AnalyticInit.h
    GeoVaLs.cc
    GeoVaLs.h
    GeoVaLs.interface.F90
    GeoVaLs.interface.h
    instantiateObsErrorFactory.h
    instantiateObsFilterFactory.h
    instantiateObsLocFactory.h
    LinearObsBiasOperator.cc
    LinearObsBiasOperator.h
    LinearObsOperator.cc
    LinearObsOperator.h
    LinearObsOperatorBase.cc
    LinearObsOperatorBase.h
    ObsBias.cc
    ObsBias.h
    ObsBiasCovariance.cc
    ObsBiasCovariance.h
    ObsBiasIncrement.cc
    ObsBiasIncrement.h
    ObsBiasOperator.cc
    ObsBiasOperator.h
    ObsBiasParameters.h
    ObsBiasPreconditioner.cc
    ObsBiasPreconditioner.h
    ObsDiagnostics.cc
    ObsDiagnostics.h
    ObsFilter.cc
    ObsFilter.h
    ObsFilterBase.cc
    ObsFilterBase.h
    ObsFilterParametersBase.h
    ObsFilters.cc
    ObsFilters.h
    ObsOperator.cc
    ObsOperator.h
    ObsOperatorBase.cc
    ObsOperatorBase.h
    ObsOperatorParametersBase.h
    ObsTraits.h
    SampledLocations.cc
    SampledLocations.h
    sampled_locations_f.cc
    sampled_locations_f.h
    ScopedDefaultGeoVaLFormatChange.h
    ufo_geovals_mod.F90
    ufo_sampled_locations_mod.F90
    ufo_variables_mod.F90
    ufo_constants_mod.F90
)


list( APPEND ufo_src_files
    ${base_src_files}
    ${basis_src_files}
    ${errors_src_files}
    ${filters_src_files}

    ${utils_src_files}
    ${predictor_src_files}
    ${obslocalization_src_files}
    ${identity_src_files}
    ${logarithm_src_files}
    ${product_src_files}
    ${vertinterp_src_files}
    ${atmvertinterplay_src_files}
    ${atmsfcinterp_src_files}
    ${columnretrieval_src_files}
    ${crtm_src_files}
    ${rttov_src_files}
    ${rttovcpp_src_files}
    ${gnssro_src_files}
    ${insitupm_src_files}
    ${aerosols_src_files}
    ${sfcpcorrected_src_files}
    ${sfccorrected_src_files}
    ${radardopplerwind_src_files}
    ${radarradialvelocity_src_files}
    ${radarreflectivity_src_files}
    ${profile_src_files}
    ${groundgnss_src_files}
    ${variabletransforms_src_files}
    ${scatwind_src_files}
    ${sattcwv_src_files}
    ${compositeoper_src_files}
    ${backgrounderrorvertinterp_src_files}
    ${backgrounderroridentity_src_files}
    ${categoricaloper_src_files}
    ${fov_src_files}
    ${marine_src_files}
    ${oasim_src_files}
    ${timeoper_src_files}
    ${lightning_src_files}
    ${superob_src_files}
    ${windspeed_src_files}
)

## Create Library target
ecbuild_add_library( TARGET   ufo
                     SOURCES  ${ufo_src_files}
                     INSTALL_HEADERS LISTED
                     HEADER_DESTINATION ${INSTALL_INCLUDE_DIR}/${PROJECT_NAME}
                    )

# Mark Boost as a system library to silence compiler warnings from Boost headers
target_include_directories( ${PROJECT_NAME} SYSTEM PUBLIC ${Boost_INCLUDE_DIRS} )

## Link dependencies
target_link_libraries(ufo PUBLIC MPI::MPI_C MPI::MPI_CXX MPI::MPI_Fortran)
target_link_libraries(ufo PUBLIC Boost::boost)
target_link_libraries(ufo PUBLIC NetCDF::NetCDF_C NetCDF::NetCDF_Fortran)
target_link_libraries(ufo PUBLIC Eigen3::Eigen)
target_link_libraries(ufo PUBLIC gsl::gsl-lite)
target_link_libraries(ufo PUBLIC eckit)
target_link_libraries(ufo PUBLIC fckit)
target_link_libraries(ufo PUBLIC ioda)
target_link_libraries(ufo PUBLIC oops)

target_compile_options( ufo PRIVATE $<$<COMPILE_LANG_AND_ID:CXX,PGI,NVHPC>:-Wc,--pending_instantiations=128> )

# Optional dependencies
if(crtm_FOUND)
    target_link_libraries(ufo PUBLIC crtm)
endif()

if(geos-aero_FOUND)
    target_link_libraries(ufo PUBLIC geos-aero)
endif()

if(gsw_FOUND)
    target_link_libraries(ufo PUBLIC gsw)
    target_compile_definitions(ufo PUBLIC GSW_FOUND)
endif()

if(ropp-ufo_FOUND)
    target_link_libraries(ufo PUBLIC ropp-ufo)
endif()

if(rttov_FOUND)
    target_link_libraries(ufo PUBLIC rttov)
    target_compile_definitions(ufo PUBLIC RTTOV_FOUND)
endif()

if(oasim_FOUND)
    target_link_libraries(ufo PUBLIC oasim)
endif()


## Include paths
target_include_directories(ufo PUBLIC $<BUILD_INTERFACE:${PROJECT_SOURCE_DIR}/src>
                                      $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>)


## Fortran modules
set(MODULE_DIR ${PROJECT_NAME}/module)
set_target_properties(${PROJECT_NAME} PROPERTIES Fortran_MODULE_DIRECTORY ${CMAKE_BINARY_DIR}/${MODULE_DIR})
install(DIRECTORY ${CMAKE_BINARY_DIR}/${MODULE_DIR}/ DESTINATION ${CMAKE_INSTALL_LIBDIR}/${MODULE_DIR})
target_include_directories(${PROJECT_NAME} INTERFACE
                            $<BUILD_INTERFACE:${CMAKE_BINARY_DIR}/${MODULE_DIR}>
                            $<INSTALL_INTERFACE:${CMAKE_INSTALL_LIBDIR}/${MODULE_DIR}>)

