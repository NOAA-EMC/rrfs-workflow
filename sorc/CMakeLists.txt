# This is the main cmake file for RRFS-workflow.

cmake_minimum_required(VERSION 3.15)

# Set the project name and version.
project(rrfs-workflow VERSION 1.0 LANGUAGES C CXX Fortran)

find_package(MPI REQUIRED COMPONENTS C CXX Fortran)

# Set extended version info.
SET(RRFS_VERSION_MAJOR 1)
SET(RRFS_VERSION_MINOR 0)
SET(RRFS_VERSION_PATCH 0)
SET(RRFS_VERSION_NOTE "-development")
SET(RRFS_VERSION ${RRFS_VERSION_MAJOR}.${RRFS_VERSION_MINOR}.${RRFS_VERSION_PATCH}${RRFS_VERSION_NOTE})

# A function used to create autotools-style 'yes/no' definitions.
# If a variable is set, it 'yes' is returned. Otherwise, 'no' is returned.
# Also creates a version of the ret_val prepended with 'NC',
# when feature is true, which is used to generate rrfs-worklfow_meta.h.
FUNCTION(is_disabled feature ret_val)
  IF(${feature})
    SET(${ret_val} "no" PARENT_SCOPE)
  ELSE()
    SET(${ret_val} "yes" PARENT_SCOPE)
    SET("RRFS_${ret_val}" 1 PARENT_SCOPE)
  ENDIF(${feature})
ENDFUNCTION()

FUNCTION(is_enabled feature ret_val)
  IF(${feature})
    SET(${ret_val} "yes" PARENT_SCOPE)
    SET("RRFS_${ret_val}" 1 PARENT_SCOPE)
  ELSE()
    SET(${ret_val} "no" PARENT_SCOPE)
    SET("RRFS_${ret_val}" 0 PARENT_SCOPE)
  ENDIF(${feature})
ENDFUNCTION()

# Turn on testing.
enable_testing()
include(CTest)

# Default bin directory
if(NOT DEFINED CMAKE_INSTALL_BINDIR)
  set(CMAKE_INSTALL_BINDIR bin)
endif()

#####
# Configure and print the rrfs-workflow.settings file.
#####

# Determine the configure date.
IF(DEFINED ENV{SOURCE_DATE_EPOCH})
  EXECUTE_PROCESS(
    COMMAND "date" "-u" "-d" "@$ENV{SOURCE_DATE_EPOCH}"
    OUTPUT_VARIABLE CONFIG_DATE
    )
ELSE()
  EXECUTE_PROCESS(
    COMMAND date
    OUTPUT_VARIABLE CONFIG_DATE
    )
ENDIF()
IF(CONFIG_DATE)
  string(STRIP ${CONFIG_DATE} CONFIG_DATE)
ENDIF()

# Get system configuration, Use it to determine osname, os release, cpu. These
# will be used when committing to CDash.
find_program(UNAME NAMES uname)
IF(UNAME)
  macro(getuname name flag)
    exec_program("${UNAME}" ARGS "${flag}" OUTPUT_VARIABLE "${name}")
  endmacro(getuname)
  getuname(osname -s)
  getuname(osrel  -r)
  getuname(cpu    -m)
ENDIF()

# Set variables.
SET(host_cpu "${cpu}")
SET(host_vendor "${osname}")
SET(host_os "${osrel}")
SET(abs_top_builddir "${CMAKE_CURRENT_BINARY_DIR}")
SET(abs_top_srcdir "${CMAKE_CURRENT_SOURCE_DIR}")

SET(CC_VERSION "${CMAKE_C_COMPILER}")

# Set values for .settings file.
SET(CFLAGS "${CMAKE_C_FLAGS} ${CMAKE_C_FLAGS_${CMAKE_BUILD_TYPE}}")
SET(CPPFLAGS "${CMAKE_CPP_FLAGS} ${CMAKE_CPP_FLAGS_${CMAKE_BUILD_TYPE}}")
SET(LDFLAGS "${CMAKE_SHARED_LINKER_FLAGS} ${CMAKE_SHARED_LINKER_FLAGS_${CMAKE_BUILD_TYPE}}")
SET(prefix ${CMAKE_INSTALL_PREFIX})

# Determine output yes/no values.
is_disabled(BUILD_SHARED_LIBS enable_static)
is_enabled(BUILD_SHARED_LIBS enable_shared)
is_enabled(STATUS_PARALLEL HAS_PARALLEL)

# Generate file from template.
CONFIGURE_FILE("${CMAKE_CURRENT_SOURCE_DIR}/rrfs-workflow.settings.in" "${CMAKE_CURRENT_BINARY_DIR}/rrfs-workflow.settings" @ONLY)

# Install rrfs-workflow.settings file into same location as the app.
INSTALL(FILES "${CMAKE_BINARY_DIR}/rrfs-workflow.settings"
  DESTINATION ${CMAKE_INSTALL_BINDIR})

#####
# Create 'rrfs-workflow_meta.h' include file.
#####
configure_file(rrfs-workflow_meta.h.in rrfs-workflow_meta.h @ONLY)

FILE(COPY "${CMAKE_CURRENT_BINARY_DIR}/rrfs-workflow_meta.h" DESTINATION include)

add_custom_target(build DEPENDS pbuild)

include(ExternalProject)

# Options
option(BUILD_UFS "Build UFS weather model" ON)
option(BUILD_UFS_UTILS "Build UFS utilities" ON)
option(BUILD_UPP "Build UPP" ON)
option(BUILD_GSI "Build GSI" ON)
option(BUILD_RRFS_UTILS "Build RRFS utilities" ON)
option(BUILD_AQM_UTILS "Build AQM utilities" ON)
option(BUILD_IFI "Build IFI in UPP" ON)
option(BUILD_GTG "Build IFI in GTG" ON)
option(ENABLE_PARALLELRESTART "Build PARALLEL RESTART" OFF)
option(ENABLE_RRFS_WAR "Build PARALLEL RESTART" ON)

message(STATUS "BUILD_UFS ............... ${BUILD_UFS}")
message(STATUS "BUILD_UFS_UTILS ......... ${BUILD_UFS_UTILS}")
message(STATUS "BUILD_GSI ............... ${BUILD_GSI}")
message(STATUS "BUILD_UPP ............... ${BUILD_UPP}")
message(STATUS "BUILD_RRFS_UTILS ........ ${BUILD_RRFS_UTILS}")
message(STATUS "BUILD_NEXUS ............. ${BUILD_NEXUS}")
message(STATUS "BUILD_AQM_UTILS ......... ${BUILD_AQM_UTILS}")
message(STATUS "BUILD_IFI ............... ${BUILD_IFI}")
message(STATUS "BUILD_GTG ............... ${BUILD_GTG}")
message(STATUS "ENABLE_PARALLELRESTART ............... ${ENABLE_PARALLELRESTART}")
message(STATUS "ENABLE_RRFS_WAR ...................... ${ENABLE_RRFS_WAR}")

# Set dependency of ufs weather model only for coupled model
if (NOT APP)
  set(UFS_DEPEND "")
else()
  if (BUILD_UFS)
    set(UFS_DEPEND "ufs-weather-model")
  else()
    set(UFS_DEPEND "")
  endif()
endif()

# Build UFS weather model
if (BUILD_UFS)
  list(APPEND TARGET_LIST ufs-weather-model)

  if(NOT CCPP_SUITES)
    if(CPL_AQM)
      set(CCPP_SUITES "FV3_GFS_v16")
    else()
      set(CCPP_SUITES "FV3_HRRR,FV3_HRRR_gf,FV3_HRRR_gf_nogwd,FV3_RAP,FV3_GFS_v15_thompson_mynn_lam3km,FV3_RRFS_v1beta,FV3_GFS_v16,RRFSens_phy1,RRFSens_phy2,RRFSens_phy3,RRFSens_phy4,RRFSens_phy5,RRFS_sas,RRFS_sas_nogwd")

    endif()
  endif()
  
  if(NOT APP)
    set(APP "ATM")
  endif()
  
  if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE "Release")
  endif()
  
  list(APPEND UFS_WEATHER_MODEL_ARGS
    "-DCMAKE_INSTALL_PREFIX=${CMAKE_INSTALL_PREFIX}"
    "-DCCPP_SUITES=${CCPP_SUITES}"
    "-DCMAKE_C_COMPILER=${MPI_C_COMPILER}"
    "-DCMAKE_CXX_COMPILER=${MPI_CXX_COMPILER}"
    "-DCMAKE_Fortran_COMPILER=${MPI_Fortran_COMPILER}"
    "-DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}"
    "-DCMAKE_MODULE_PATH=${MAPL_ROOT}/share/MAPL/cmake"
    "-DNETCDF_DIR=$ENV{NETCDF}"
    "-D32BIT=ON"
    "-DCCPP_32BIT=ON"
    "-DENABLE_PARALLELRESTART=${ENABLE_PARALLELRESTART}"
    "-DENABLE_RRFS_WAR=${ENABLE_RRFS_WAR}"
    "-DMPI=ON" 
    "-DFASTER=ON"
    "-DINLINE_POST=ON"
    "-DAPP=${APP}"
  )
  
  string(TOUPPER "${CMAKE_BUILD_TYPE}" TOUPPER_CMAKE_BUILD_TYPE)
  if (TOUPPER_CMAKE_BUILD_TYPE MATCHES "DEBUG")
    list(APPEND UFS_WEATHER_MODEL_ARGS "-DDEBUG=ON")
  endif()
  
  if (BUILD_OPTIONS)
    string(REPLACE "," ";" BUILD_OPTIONS "${BUILD_OPTIONS}")
    foreach (option_on IN ITEMS ${BUILD_OPTIONS})
      list(APPEND UFS_WEATHER_MODEL_ARGS "-D${option_on}=ON")
    endforeach()
  endif()
  
  if (DISABLE_OPTIONS)
    string(REPLACE "," ";" DISABLE_OPTIONS "${DISABLE_OPTIONS}")
    foreach (option_off IN ITEMS ${DISABLE_OPTIONS})
      list(APPEND UFS_WEATHER_MODEL_ARGS "-D${option_off}=OFF")
    endforeach()
  endif()

  ExternalProject_Add(ufs-weather-model
    PREFIX ${CMAKE_CURRENT_BINARY_DIR}/ufs-weather-model
    SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/ufs-weather-model
    INSTALL_DIR ${CMAKE_INSTALL_PREFIX}
    CMAKE_ARGS ${UFS_WEATHER_MODEL_ARGS}
    INSTALL_COMMAND mkdir -p ${CMAKE_INSTALL_PREFIX}/${CMAKE_INSTALL_BINDIR} && cp ${CMAKE_CURRENT_BINARY_DIR}/ufs-weather-model/src/ufs-weather-model-build/ufs_model ${CMAKE_INSTALL_PREFIX}/${CMAKE_INSTALL_BINDIR}
    BUILD_ALWAYS TRUE
    STEP_TARGETS build
    )
endif()

# Build UFS utilities
if(BUILD_UFS_UTILS)
  list(APPEND TARGET_LIST UFS_UTILS)

  list(APPEND UFS_UTILS_ARGS
    "-DCMAKE_INSTALL_PREFIX=${CMAKE_INSTALL_PREFIX}"
    "-DCMAKE_INSTALL_BINDIR=${CMAKE_INSTALL_BINDIR}"
    "-DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}"
    "-DBUILD_TESTING=OFF"
    "-DCHGRES=ON"
    "-DCPLD_GRIDGEN=OFF"
    "-DFRENCTOOLS=ON"
    "-DFVCOMTOOLS=ON"
    "-DGBLEVENTS=OFF"
    "-DGCYCLE=OFF"
    "-DGRIDTOOLS=ON"
    "-DICEBLEND=OFF"
    "-DOROG_MASK_TOOLS=ON"
    "-DSFC_CLIMO_GEN=ON"
    "-DSNOW2MDL=OFF"
    "-DVCOORD_GEN=OFF"
    "-DWEIGHT_GEN=OFF"    
  )

  ExternalProject_Add(UFS_UTILS
    DEPENDS ${UFS_DEPEND}
    PREFIX ${CMAKE_CURRENT_BINARY_DIR}/UFS_UTILS
    SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/UFS_UTILS
    INSTALL_DIR ${CMAKE_INSTALL_PREFIX}
    CMAKE_ARGS ${UFS_UTILS_ARGS}
    BUILD_ALWAYS TRUE
    STEP_TARGETS build
    )
endif()

# Build UPP
if (BUILD_UPP)
  list(APPEND TARGET_LIST UPP)

  list(APPEND UPP_ARGS
    "-DCMAKE_INSTALL_PREFIX=${CMAKE_INSTALL_PREFIX}"
    "-DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}"
    "-Dexec_dir=${CMAKE_INSTALL_BINDIR}"
    "-DINTERNAL_IFI=${BUILD_IFI}"
    "-DBUILD_WITH_GTG=${BUILD_GTG}"
  )

  ExternalProject_Add(UPP
    DEPENDS ${UFS_DEPEND}
    PREFIX ${CMAKE_CURRENT_BINARY_DIR}/UPP
    SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/UPP
    INSTALL_DIR ${CMAKE_INSTALL_PREFIX}
    CMAKE_ARGS ${UPP_ARGS}
    BUILD_ALWAYS TRUE
    STEP_TARGETS build
    )
endif()

# Build GSI
if (BUILD_GSI)
  list(APPEND TARGET_LIST GSI)

  list(APPEND GSI_ARGS
    "-DCMAKE_INSTALL_PREFIX=${CMAKE_INSTALL_PREFIX}"
    "-DCMAKE_INSTALL_BINDIR=${CMAKE_INSTALL_BINDIR}"
    "-DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}"
    "-DGSI_MODE=Regional"
    "-DENKF_MODE=FV3REG"
  )

  ExternalProject_Add(GSI
    PREFIX ${CMAKE_CURRENT_BINARY_DIR}/GSI
    SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/gsi
    INSTALL_DIR ${CMAKE_INSTALL_PREFIX}
    CMAKE_ARGS ${GSI_ARGS}
    BUILD_ALWAYS TRUE
    STEP_TARGETS build
    )
endif()

# Build rrfs_utl
if (BUILD_RRFS_UTILS)
  list(APPEND TARGET_LIST RRFS_UTILS)

  list(APPEND RRFS_UTILS_ARGS
    "-DCMAKE_INSTALL_PREFIX=${CMAKE_INSTALL_PREFIX}"
    "-DCMAKE_INSTALL_BINDIR=${CMAKE_INSTALL_BINDIR}"
    "-DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}"
    "-DFV3_ENSMEAN_RECENTER=ON"
    "-DADJUST_SOILTQ=ON"
    "-DBLENDING=ON"
    "-DBUFRSND=ON"
    "-DCLOUDANALYSIS=ON"
    "-DENS_MEAN_RECENTER=ON"
    "-DGEN_CS=ON"
    "-DLAKESURGERY=ON"
    "-DLARCCLD=ON"
    "-DLIGHTNING=ON"
    "-DMETARCLD=ON"
    "-DMOSAIC=ON"
    "-DPM=ON"
    "-DRADMON=ON"
    "-DREF2TTEN=ON"
    "-DRTMA_MINMAXTRH=ON"
    "-DUPDATE_BC=ON"
    "-DUPDATE_GVF=ON"
    "-DUPDATE_ICE=ON"
    "-DUPDATE_SNOW=ON"
    "-DUPDATE_SST=ON"
    "-DUSE_RAPHRRR_SFC=ON"
  )

  ExternalProject_Add(RRFS_UTILS
    PREFIX ${CMAKE_CURRENT_BINARY_DIR}/rrfs_utl
    SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/rrfs_utl
    INSTALL_DIR ${CMAKE_INSTALL_PREFIX}
    CMAKE_ARGS ${RRFS_UTILS_ARGS}
    BUILD_ALWAYS TRUE
    STEP_TARGETS build
    DEPENDS GSI
    )
endif()

# Build AQM-utils
if (BUILD_AQM_UTILS)
  list(APPEND TARGET_LIST AQM_UTILS)

  list(APPEND AQM_UTILS_ARGS
    "-DCMAKE_INSTALL_PREFIX=${CMAKE_INSTALL_PREFIX}"
    "-DCMAKE_INSTALL_BINDIR=${CMAKE_INSTALL_BINDIR}"
    "-DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}"
    "-DBUILD_POST_STAT=${BUILD_POST_STAT}"
    "-DGEFS2LBCS=ON"
    "-DAQM_POST_GRIB2=OFF"
    "-DAQM_POST_MAXI_GRIB2=OFF"
    "-DAQM_POST_BIAS_COR_GRIB2=OFF"
    "-DAQM_POST_MAXI_BIAS_COR_GRIB2=OFF"
    "-DAQM_BIAS_CORRECT=OFF"
    "-DAQM_BIAS_INTERPOLATE=OFF"
    "-DCONVERT_AIRNOW_CSV=OFF"
  )

  ExternalProject_Add(AQM-utils
    DEPENDS ${UFS_DEPEND}
    PREFIX ${CMAKE_CURRENT_BINARY_DIR}/AQM-utils
    SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/AQM-utils
    INSTALL_DIR ${CMAKE_INSTALL_PREFIX}
    CMAKE_ARGS ${AQM_UTILS_ARGS}
    BUILD_ALWAYS TRUE
    STEP_TARGETS build
  )
endif()

if (CPL_AQM)
  if (BUILD_NEXUS)
    list(APPEND TARGET_LIST NEXUS)

    list(APPEND NEXUS_ARGS
      "-DCMAKE_INSTALL_PREFIX=${CMAKE_INSTALL_PREFIX}"
      "-DCMAKE_INSTALL_BINDIR=${CMAKE_INSTALL_BINDIR}"
      "-DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}"
    )

    ExternalProject_Add(arl_nexus
      DEPENDS ${UFS_DEPEND}
      PREFIX ${CMAKE_CURRENT_BINARY_DIR}/arl_nexus
      SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/arl_nexus
      INSTALL_DIR ${CMAKE_INSTALL_PREFIX}
      CMAKE_ARGS ${NEXUS_ARGS}
      BUILD_ALWAYS TRUE
      STEP_TARGETS build
    )
  endif()
endif()

# add custom target for separate build and install
foreach(i ${TARGET_LIST})
    list(APPEND BUILD_LIST "${i}-build")
endforeach()

add_custom_target(pbuild DEPENDS ${BUILD_LIST})
