/*
 * (C) Crown Copyright 2024, Met Office
 * (C) Copyright 2024 UCAR
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
  UKMO,   /// WRFDA method uses model surface and level 1 data.
  WRFDA,  /// UKMO method uses model surface and 2000m data.
  GSL     /// GSL method uses model surface and level 1 data.
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


/// Enum type for GSL lapse rate options, only used when SfcCorrectionType is set to GSL
enum class GslLapseRateOption {
  Constant,       /// Use a constant lapse rate value
  Local,          /// Calculate lapse rate locally from model levels
  NoAdjustment    /// No temperature adjustment
};
struct GslLapseRateOptionParameterTraitsHelper {
  typedef GslLapseRateOption EnumType;
  static constexpr char enumTypeName[] = "GslLapseRateOption";
  static constexpr util::NamedEnumerator<GslLapseRateOption> namedValues[] = {
    { GslLapseRateOption::Constant, "Constant" },
    { GslLapseRateOption::Local, "Local" },
    { GslLapseRateOption::NoAdjustment, "NoAdjustment" }
  };
};

}  // namespace ufo

namespace oops {

/// Extraction of SfcCorrectionType parameters from config
template <>
struct ParameterTraits<ufo::SfcCorrectionType> :
    public EnumParameterTraits<ufo::SfcCorrectionTypeParameterTraitsHelper>
{};

/// Extraction of GslLapseRateOption parameters from config
template <>
struct ParameterTraits<ufo::GslLapseRateOption> :
    public EnumParameterTraits<ufo::GslLapseRateOptionParameterTraitsHelper>
{};

}  // namespace oops

namespace ufo {

/**
 * GSL-specific correction parameters
 * Only used when SfcCorrectionType is set to GSL
 */
class GslCorrectionParameters : public oops::Parameters {
  OOPS_CONCRETE_PARAMETERS(GslCorrectionParameters, Parameters)

 public:
  /// Lapse rate calculation method
  oops::Parameter<GslLapseRateOption> temperatureLapseRateOption{
    "temperature lapse rate option",
    "Method to determine lapse rate for surface temperature correction ('Constant' or 'Local' or 'NoAdjustment')",
    GslLapseRateOption::Local,
    this};

  /// Constant lapse rate value (K/km)
  /// Only used when lapseRateOption = Constant
  oops::Parameter<float> temperatureLapseRateValue{
    "temperature lapse rate",
    "Fixed lapse rate (K/km) used to adjust observed surface temperature\n"
    "to model surface level. Only used when temperature lapse rate option = Constant.\n"
    "Default: 9.8 K/km (standard adiabatic lapse rate)",
    9.8,
    this
  };

  /// Local lapse rate calculation parameters
  /// Only used when lapseRateOption = Local
  oops::Parameter<int> temperatureLocalLapseRateLevel{
    "temperature local lapse rate level",
    "Highest model level used to calculate local lapse rate\n"
    "Only used when temperature lapse rate option = Local",
    5,
    this
  };

  /// Apply thresholds to local lapse rate
  /// Only used when lapseRateOption = Local
  oops::Parameter<bool> temperatureLapseRateThreshold{
    "temperature lapse rate threshold",
    "Apply min/max thresholds to calculated local lapse rate.\n"
    "Only used when temperature lapse rate option = Local",
    true,
    this
  };

  /// Minimum threshold for local lapse rate (K/km)
  /// Only used when lapseRateOption = Local and applyThreshold = true
  oops::Parameter<float> minThreshold{
    "min threshold",
    "Minimum lapse rate (K/km) allowed when calculated locally.\n"
    "Only used when temperature lapse rate option = Local and "
    "temperature lapse rate threshold = true",
    0.5,
    this
  };

  /// Maximum threshold for local lapse rate (K/km)
  /// Only used when lapseRateOption = Local and applyThreshold = true
  oops::Parameter<float> maxThreshold{
    "max threshold",
    "Maximum lapse rate (K/km) allowed when calculated locally.\n"
    "Only used when temperature lapse rate option = Local and "
    "temperature lapse rate threshold = true",
    10.0,
    this
  };
};

/// Configuration options recognized by the SfcCorrected operator.
class ObsSfcCorrectedParameters : public ObsOperatorParametersBase {
  OOPS_CONCRETE_PARAMETERS(ObsSfcCorrectedParameters, ObsOperatorParametersBase)

 public:
  oops::OptionalParameter<std::vector<ufo::Variable>> variables{
      "variables",
      "List of variables to be simulated which must be a subset of the simulated variables "
      "in the ObsSace",
      this};

  oops::Parameter<std::string> geovarGeomZ{
      "geovar_geomz",
      "Model variable for height of vertical levels, geopotential heights will be converted",
      "height_above_mean_sea_level",
      this};

  oops::Parameter<std::string> geovarSfcGeomZ{
      "geovar_sfc_geomz",
      "Model variable for surface height, geopotential heights will be converted",
      "height_above_mean_sea_level_at_surface",
      this};

  oops::Parameter<std::string> obsHeightName{
      "station_altitude",
      "stationElevation",
      this};

  oops::Parameter<SfcCorrectionType> correctionType{
      "correction scheme to use",
      "Scheme used for correction ('WRFDA' or 'UKMO' or 'GSL')",
      SfcCorrectionType::WRFDA,
      this};

  /// GSL-specific configuration parameters
  /// Only used when correctionType = GSL
  oops::OptionalParameter<GslCorrectionParameters> gslParams{
    "gsl parameters",
    "GSL-specific surface correction parameters.\n"
    "Only used when correction_scheme = GSL",
    this};
};

// -----------------------------------------------------------------------------

}  // namespace ufo

#endif  // UFO_OPERATORS_SFCCORRECTED_OBSSFCCORRECTEDPARAMETERS_H_
