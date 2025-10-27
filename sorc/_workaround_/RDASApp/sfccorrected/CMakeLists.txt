# (C) Crown Copyright 2024, Met Office
# (C) Copyright 2024 UCAR
#
# This software is licensed under the terms of the Apache Licence Version 2.0
# which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.

set ( sfccorrected_files
    EvalSurfacePressure.h
    EvalSurfacePressure.cc
    EvalSurfaceTemperature.h
    EvalSurfaceTemperature.cc
    EvalSurfaceHumidity.h
    EvalSurfaceHumidity.cc
    EvalSurfaceWind.h
    EvalSurfaceWind.cc
    ObsSfcCorrected.h
    ObsSfcCorrected.cc
    ObsSfcCorrectedParameters.h
    SurfaceOperatorBase.h
    SurfaceOperatorBase.cc
)

PREPEND( _p_sfccorrected_files     "operators/sfccorrected"     ${sfccorrected_files} )

set ( sfccorrected_src_files
      ${_p_sfccorrected_files}
      PARENT_SCOPE
)
