/*
 * (C) Copyright 2021- UCAR
 * 
 * This software is licensed under the terms of the Apache Licence Version 2.0
 * which can be obtained at http://www.apache.org/licenses/LICENSE-2.0. 
 */

#ifndef UFO_OPERATORS_SFCCORRECTED_OBSSFCCORRECTEDPARAMETERS_H_
#define UFO_OPERATORS_SFCCORRECTED_OBSSFCCORRECTEDPARAMETERS_H_

#include <string>
#include <vector>

#include "oops/util/parameters/OptionalParameter.h"
#include "oops/util/parameters/Parameter.h"
#include "oops/util/parameters/Parameters.h"
#include "ufo/filters/Variable.h"
#include "ufo/ObsOperatorParametersBase.h"
#include "ufo/utils/parameters/ParameterTraitsVariable.h"

namespace ufo {

/// enum type for surface correction type, and ParameterTraitsHelper for it
enum class SfcCorrectionType {
  UKMO, WRFDA, GSL
};
struct SfcCorrectionTypeParameterTraitsHelper {
  typedef SfcCorrectionType EnumType;
  static constexpr char enumTypeName[] = "SfcCorrectionType";
  static constexpr util::NamedEnumerator<SfcCorrectionType> namedValues[] = {
    { SfcCorrectionType::UKMO, "UKMO" },
    { SfcCorrectionType::WRFDA, "WRFDA" },
    { SfcCorrectionType::GSL, "GSL" }
  };
};

}  // namespace ufo

namespace oops {

/// Extraction of SfcCorrectionType parameters from config
template <>
struct ParameterTraits<ufo::SfcCorrectionType> :
    public EnumParameterTraits<ufo::SfcCorrectionTypeParameterTraitsHelper>
{};

}  // namespace oops

namespace ufo {

/// Configuration options recognized by the SfcCorrected operator.
class ObsSfcCorrectedParameters : public ObsOperatorParametersBase {
  OOPS_CONCRETE_PARAMETERS(ObsSfcCorrectedParameters, ObsOperatorParametersBase)

 public:
  /// An optional `variables` parameter, which controls which ObsSpace
  /// variables will be simulated. This option should only be set if this operator is used as a
  /// component of the Composite operator. If `variables` is not set, the operator will simulate
  /// all ObsSpace variables. Please see the documentation of the Composite operator for further
  /// details.
  oops::OptionalParameter<std::vector<ufo::Variable>> variables{
     "variables",
     "List of variables to be simulated",
     this};

  oops::Parameter<SfcCorrectionType> correctionType{"da_sfc_scheme",
     "Scheme used for surface temperature correction (UKMO, WRFDA or GSL)",
     SfcCorrectionType::UKMO, this};

  /// Note: "height" default value has to be consistent with var_geomz defined
  /// in ufo_variables_mod.F90
  oops::Parameter<std::string> geovarGeomZ{"geovar_geomz",
     "Model variable for height of vertical levels",
     "height_above_mean_sea_level", this};

  /// Note: "surface_altitude" default value has to be consistent with var_sfc_geomz
  /// in ufo_variables_mod.F90
  oops::Parameter<std::string> geovarSfcGeomZ{"geovar_sfc_geomz",
     "Model variable for surface height",
     "height_above_mean_sea_level_at_surface", this};

  /// Note: "station_altitude" default value is "stationElevation"
  oops::Parameter<std::string> ObsHeightName{"station_altitude", "stationElevation", this};
  
  /// Note: Only relevant if \c SfcCorrectionType is set to GSL, "lapse_rate_option" default value is "Local"
  oops::Parameter<std::string> LapseRateOption{"lapse_rate_option", "Lapse rate option for surface temperature correction (Constant, Local or NoAdjustment)", "Local", this};

  /// Note: Only relevant if \c SfcCorrectionType is set to GSL and \c LapseRateOption is set to "Constant", "lapse_rate" default value is adiabatic lapse rate 9.8 K/km
  oops::Parameter<float> LapseRateValue
    {"lapse_rate", 
     "The lapse rate (K/km) used to adjust the observed surface temperature to "
     "the model's surface level. Used if lapse rate option is set to constant, "
     "otherwise ignored.",
     9.8, 
     this};

  /// Note: Only relevant if \c SfcCorrectionType is set to GSL and \c LapseRateOption is set to "Local"
  oops::Parameter<int> LocalLapseRateLevel
    {"local_lapse_rate_level",
     "The highest model level used to calculate the local lapse rate, "
     "which adjusts the observed surface temperature to the model's surface level. "
     "Used if lapse rate option is set to local, otherwise ignored.",
     5,
     this};

  /// Should the local lapse rate be restricted to a specific range
  /// Note: Only relevant if \c SfcCorrectionType is set to GSL and \c LapseRateOption is set to "Local"
  oops::Parameter<bool> Threshold{"threshold", true, this};

  /// Note: Only relevant if \c SfcCorrectionType is set to GSL, \c LapseRateOption is set to "Local", and \c Threshold is set to true
  oops::Parameter<float> MinThreshold
    {"min_threshold",
     "The minimum lapse rate (K/km) can be applied to adjust the "
     "observed surface temperature to the model's surface level. "
     "Used if lapse rate option is set to local, otherwise ignored.",
     0.5,
     this};

  /// Note: Only relevant if \c SfcCorrectionType is set to GSL, \c LapseRateOption is set to "Local", and \c Threshold is set to true
  oops::Parameter<float> MaxThreshold
    {"max_threshold",
     "The maximum lapse rate (K/km) can be applied to adjust the "
     "observed surface temperature to the model's surface level. "
     "Used if lapse rate option is set to local, otherwise ignored.",
     10.0,
     this};
};

// -----------------------------------------------------------------------------

}  // namespace ufo
#endif  // UFO_OPERATORS_SFCCORRECTED_OBSSFCCORRECTEDPARAMETERS_H_
