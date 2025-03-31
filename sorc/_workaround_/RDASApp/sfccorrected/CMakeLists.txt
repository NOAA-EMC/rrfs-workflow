# (C) Copyright 2017-2018 UCAR.
#
# This software is licensed under the terms of the Apache Licence Version 2.0
# which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.

set ( sfccorrected_files
    ObsSfcCorrected.h
    ObsSfcCorrected.cc
    ObsSfcCorrectedParameters.cc
    ObsSfcCorrectedParameters.h
    ObsSfcCorrected.interface.F90
    ObsSfcCorrected.interface.h
    ufo_sfccorrected_mod.F90
)

PREPEND( _p_sfccorrected_files     "operators/sfccorrected"     ${sfccorrected_files} )

set ( sfccorrected_src_files
      ${_p_sfccorrected_files}
      PARENT_SCOPE
)
