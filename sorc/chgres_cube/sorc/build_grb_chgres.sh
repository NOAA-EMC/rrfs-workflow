#! /usr/bin/env bash
set -eux

source ./machine-setup.sh > /dev/null 2>&1
cwd=`pwd`

USE_PREINST_LIBS=${USE_PREINST_LIBS:-"false"}
if [ $USE_PREINST_LIBS = true ]; then
  export MOD_PATH=/scratch3/NCEPDEV/nwprod/lib/modulefiles
  source ../../../modulefiles/fv3sar_worfklow/grb_chgres.$target
else
  export MOD_PATH=${cwd}/lib/modulefiles
  if [ $target = wcoss_cray ]; then
    source ../modulefiles/fv3sar_workflow/grb_chgres.${target}_userlib > /dev/null 2>&1
  else
    source ../../../modulefiles/fv3sar_workflow/grb_chgres.$target
  fi
fi

# Check final exec folder exists
if [ ! -d "../../../exec" ]; then
  mkdir ../../../exec
fi

#
# --- Chgres part
#
#cd grb_chgres.fd

export FCMP=${FCMP:-ftn}
export FCMP95=$FCMP

export FFLAGSM="-O0 -g -traceback -r8 -i4 -convert big_endian -check bounds -warn unused -assume byterecl"
export RECURS=

if [ $target = cheyenne ]; then

  export SFCIODIR=/gpfs/fs1/work/kavulich/FV3/rocoto_pp_workflow/ncep_libs/sfcio/v1.0.0/src/ifort/
  export SFCIO_LIB4=${SFCIODIR}
  export SFCIO_INC4="${SFCIODIR}/include/sfcio_1.0.0_4/"
  export LANDSFCUTIL_DIR=/gpfs/fs1/work/kavulich/FV3/rocoto_pp_workflow/ncep_libs/landsfcutil/v2.1.0/landsfcutil/v2.1.0/
  export LANDSFCUTIL_INCd="${LANDSFCUTIL_DIR}/include/landsfcutil_v2.1.0_d/"
  export LANDSFCUTIL_LIBd="${LANDSFCUTIL_DIR}"
  export SIGIODIR=/gpfs/fs1/work/kavulich/FV3/rocoto_pp_workflow/ncep_libs/sigio/v2.0.1/src/sigio_v2.0.1/
  export SIGIO_INC4="${SIGIODIR}/include"
  export SIGIO_LIB4="${SIGIODIR}/lib"
  export NEMSIODIR=/gpfs/fs1/work/kavulich/FV3/rocoto_pp_workflow/ncep_libs/nemsio/v2.2.3/src
  export NEMSIO_INC="${NEMSIODIR}/intel_18.0.1/include/nemsio_v2.2.3/"
  export NEMSIO_LIB="${NEMSIODIR}/intel_18.0.1/"
  export NEMSIOGFSDIR=/gpfs/fs1/work/kavulich/FV3/rocoto_pp_workflow/ncep_libs/nemsiogfs/v2.0.1
  export NEMSIOGFS_INC="${NEMSIOGFSDIR}/include/nemsiogfs_v2.0.1/"
  export NEMSIOGFS_LIB="${NEMSIOGFSDIR}"

  export LDFLAGSM=${LDFLAGSM:-"-qopenmp -auto"}
  export OMPFLAGM=${OMPFLAGM:-"-qopenmp -auto"}
  export INCS="-I${NETCDF}/include -I${NCEPLIB_DIR}/include -I${SIGIO_INC4} -I${LANDSFCUTIL_INCd} -I${SFCIO_INC4} -I${NEMSIO_INC} -I${NEMSIOGFS_INC}"

  export LIBSM="-L${NCEPLIB_DIR}/lib -L${LANDSFCUTIL_LIBd} -L${SFCIO_LIB4} -L${NEMSIO_LIB} -L${NEMSIOGFS_LIB} -llandsfcutil_v2.1.0_d -lsfcio_1.0.0_4 -lnemsiogfs_v2.0.1 -lnemsio_v2.2.3 -lbacio_4 -lw3emc_d -lw3nco_d -lip_d -lsp_v2.0.2_d -lsigio_v2.0.1_4 -L${NETCDF}/lib -lnetcdff -lnetcdf"

  make -f Makefile clobber
  make -f Makefile
  make -f Makefile install

else

  export LDFLAGSM=${LDFLAGSM:-"-qopenmp -auto"}
  export OMPFLAGM=${OMPFLAGM:-"-qopenmp -auto"}
  #export INCS="-I${SFCIO_INC4} -I${LANDSFCUTIL_INCd} \
  #             -I${NEMSIO_INC} -I${NEMSIOGFS_INC} -I${GFSIO_INC4} -I${IP_INCd} ${NETCDF_INCLUDE} -I${WGRIB2API_INC}"
  export INCS="-I${NEMSIO_INC} ${NETCDF_INCLUDE} -I${WGRIB2API_INC} -I${SFCIO_INC4} -I${SIGIO_INC4}"
  #export LIBSM="${GFSIO_LIB4} \
  #              ${NEMSIOGFS_LIB} \
  #              ${NEMSIO_LIB} \
  #              ${SIGIO_LIB4} \
  #              ${SFCIO_LIB4} \
  #              ${LANDSFCUTIL_LIBd} \
  #              ${IP_LIBd} \
  #              ${SP_LIBd} \
  #              ${W3EMC_LIBd} \
  #              ${W3NCO_LIBd} \
  #              ${BACIO_LIB4} \
  #              ${NETCDF_LDFLAGS_F} \
  #		${WGRIB2API_LIB} \
  #		${WGRIB2_LIB}" 

  export LIBSM="${NEMSIO_LIB} \
	  	${W3NCO_LIBd} \
		${BACIO_LIB4} \
		${SP_LIBd} \
		${NETCDF_LDFLAGS_F} \
		${WGRIB2API_LIB} \
   		${WGRIB2_LIB} \
		${SIGIO_LIB4} \
		${SFCIO_LIB4}"
  	        
		
  #make -f makefile clobber
  make -f Makefile
  #make -f makefile install
 # make -f makefile clobber
 cd ../../../exec
 ln -s ../../sorc/global_chgres.exe .
fi

exit
