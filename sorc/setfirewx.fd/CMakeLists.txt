cmake_minimum_required(VERSION 3.15)

project(
  setfirewx
  VERSION 1.0
  LANGUAGES Fortran)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake")

find_package(MPI REQUIRED)
#find_package(NetCDF REQUIRED COMPONENTS Fortran)
if(OPENMP)
  find_package(OpenMP REQUIRED COMPONENTS Fortran)
endif()

list(APPEND src_setfirewx setfirewx.f)

add_compile_options(-free)

add_executable(setfirewx ${src_setfirewx})
target_link_libraries(setfirewx PRIVATE MPI::MPI_Fortran)

if(OpenMP_Fortran_FOUND)
  target_link_libraries(setfirewx PRIVATE OpenMP::OpenMP_Fortran)
endif()

install(
  TARGETS setfirewx
  EXPORT ${PROJECT_NAME}Exports
  RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
  LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
  ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR})

if(CMAKE_Fortran_COMPILER_ID MATCHES "^(Intel)$")
  set(CMAKE_Fortran_FLAGS
  "-g -traceback -fp-model precise -assume noold_ldout_format")
   set(CMAKE_Fortran_FLAGS_RELEASE "-O2")
   set(CMAKE_Fortran_FLAGS_DEBUG "-O0")

endif()
