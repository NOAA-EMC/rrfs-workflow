/*
 * (C) Copyright 2021- UCAR
 * 
 * This software is licensed under the terms of the Apache Licence Version 2.0
 * which can be obtained at http://www.apache.org/licenses/LICENSE-2.0. 
 */

#include "ufo/operators/sfccorrected/ObsSfcCorrectedParameters.h"

namespace ufo {

// -----------------------------------------------------------------------------
// Required for enum Parameters
constexpr char SfcCorrectionTypeParameterTraitsHelper::enumTypeName[];
constexpr util::NamedEnumerator<SfcCorrectionType>
          SfcCorrectionTypeParameterTraitsHelper::namedValues[];

}  // namespace ufo
