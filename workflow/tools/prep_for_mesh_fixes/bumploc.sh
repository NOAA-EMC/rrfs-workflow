#!/usr/bin/env bash
#
# shellcheck disable=all
run_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
HOMErrfs="${run_dir}/../../.."

# replace ./mpasjedi_variational.x with mpasjedi_error_covariance_toolbox.x in exrrfs_jedivar.sh
sed -i -e 's#${MPI_RUN_CMD} ./mpasjedi_variational.x jedivar.yaml log.out#cp ${HOMErrfs}/workflow/tools/prep_for_mesh_fixes/bumploc.yaml .\n  ${MPI_RUN_CMD} ${HOMErrfs}/sorc/RDASApp/build/bin/mpasjedi_error_covariance_toolbox.x bumploc.yaml log.out\n  err_exit#' ${HOMErrfs}/scripts/exrrfs_jedivar.sh

git diff ${HOMErrfs}/scripts/exrrfs_jedivar.sh
echo -e "\n !! Done !! exrrfs_jedivar.sh has been modified."
echo "Go to expdir, run 'rboot 202405060000 jedivar' to generate bumploc files"
echo "Or run 'git checkout ../../../scripts/exrrfs_jedivar.sh' to revert changes"
