/*
 * (C) Copyright 2023 NASA
 *
 * This software is licensed under the terms of the Apache Licence Version 2.0
 * which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
 */

#ifndef UFO_FILTERS_OBSFUNCTIONS_OBSERRORFACTORPRESSURECHECK_H_
#define UFO_FILTERS_OBSFUNCTIONS_OBSERRORFACTORPRESSURECHECK_H_

#include <memory>
#include <string>
#include <vector>

#include "oops/util/parameters/Parameter.h"
#include "oops/util/parameters/Parameters.h"
#include "oops/util/parameters/RequiredParameter.h"

#include "ufo/filters/obsfunctions/ObsFunctionBase.h"
#include "ufo/filters/Variables.h"

namespace ufo {

/// \brief Options controlling ObsErrorFactorSfcPressure ObsFunction
class ObsErrorFactorPressureCheckParameters : public oops::Parameters {
  OOPS_CONCRETE_PARAMETERS(ObsErrorFactorPressureCheckParameters, Parameters)

 public:
  /// Inflate variables
  oops::RequiredParameter<std::string> inflatevars{"variable", this};
  oops::RequiredParameter<float> infl_coeff{"inflation factor", this};
  oops::Parameter<std::string> adjusterr_name{"adjusted_error_name", "ObsErrorData", this};

  /// Name of the data group to which the observation error is applied (default: ObsErrorData)
  oops::Parameter<std::string> testObserr{"test_obserr", "ObsErrorData", this};

  /// Name of the data group to which the QC flag is applied  (default is QCflagsData)
  oops::Parameter<std::string> testQCflag{"test_qcflag", "QCflagsData", this};

  /// Alternative name of GeoVaLs variable: height_above_mean_sea_level_at_surface
  /// The code expects to find GeoVaLs/height_above_mean_sea_level_at_surface
  /// and GeoVaLs/height_above_mean_sea_level, however,
  /// some datasets may have GeoVaLs/height_above_mean_sea_level_at_surface
  /// and GeoVaLs/geopotential_height in its place.
  oops::Parameter<std::string> geovar_sfc_geomz{"geovar_sfc_geomz",
                                                "height_above_mean_sea_level_at_surface", this};

  /// Request saturation specific humidity from geovals (default false)
  /// Example: To request saturation specific humidity from geovals
  ///          request_saturation_specific_humidity_geovals: true
  oops::Parameter<bool> requestQSat{"request_saturation_specific_humidity_geovals", false, this};

  oops::Parameter<bool> obsErrorRamp{"surface observation error ramp", false, this};

  /// Surface wind obs are not reported with observation height (ZOB) in bufr/ioda,
  /// but there is MetaData/stationElevation. The SetSfcWndObsHeight parameter
  /// can be specified along with a user defined zob value (AssumedSfcWndObsHeight).
  ///
  /// Typically, obs_height = dstn + AssumedSfcWndObsHeight;
  /// where AssumedSfcWndObsHeight = 10 m and dstn is sationElevation, but there
  /// are exceptions. Therefore, there are additional options that can be used to
  /// change how the obs_height value is calculated as follows.
  ///
  /// 1) Default (no flags set):
  ///    obs_height = AssumedSfcWndObsHeight;
  ///
  /// 2) AddObsHeightToStationElevation: true
  ///    obs_height = dstn + AssumedSfcWndObsHeight;
  ///
  /// 3) UseStationElevationAsObsHeight: true
  ///    obs_height = dstn;
  ///    dstn = 0;

  oops::Parameter<bool> SetSfcWndObsHeight{"SetSfcWndObsHeight", false, this};
  oops::Parameter<bool> AddObsHeightToStationElevation{
      "AddObsHeightToStationElevation", false, this};
  oops::Parameter<bool> UseStationElevationAsObsHeight{
      "UseStationElevationAsObsHeight", false, this};
  oops::Parameter<float> AssumedSfcWndObsHeight{"AssumedSfcWndObsHeight", 0.0f, this};
};

/// This filter is to check an observation’s vertical relative positionn with
/// respect to a model's pressure or geometric height levels. If the reported
/// pressure or the geometric height is not within between the model's surface
/// pressure/geometric height and the model top, the obs error will be inflated as
/// in the following:
///
///    ratio_errors = (error+drpx+1.e6*rhgh+(inflation factor)*rlow)/error
///
/// where, rlow=max(sfcchk-dpres,zero) with sfcchk being the grid relative position of
/// model surface pressure/geometric height and dpres the grid relative position of the
/// observation's reported pressure/geometric height. rhgh=max(dpres-r0_001-nsig-1,zero) and
/// drpx is situation dependent.For example, drpx is zero if the observation is reported with
//  the pressure (e.g. satwind, radiosonde, etc). If the observation is reported with
/// the geometric height (e.g. Ascat), drpx is given a non-zero value depending on the grid
/// relative position of station's geometric height with respect to the model surface
/// geometric height as implemented in the GSI. The inflation factor 'inflation factor'
/// is a required parameter which is given 4.0 for wind type and 8.0 for both temperatue
/// and humidity in the GSI.
///
/// ### example configurations for windEastward: ###
///
///     - filter: Perform Action
///       filter variables:
///       - name: windEastward
///       where:
///       - variable:
///           name: ObsType/windEastward
///         is_in: 220-221
///       action:
///         name: inflate error
///         inflation variable:
///           name: ObsFunction/ObsErrorFactorPressureCheck
///           options:
///             variable: windEastward
///             inflation factor: 4.0
///             adjusted_error_name: GsiAdjustObsError
///
class ObsErrorFactorPressureCheck : public ObsFunctionBase<float> {
 public:
  static const std::string classname() {return "ObsErrorFactorPressureCheck";}

  explicit ObsErrorFactorPressureCheck(const eckit::Configuration &config);
  ~ObsErrorFactorPressureCheck();

  void compute(const ObsFilterData &, ioda::ObsDataVector<float> &) const;
  const ufo::Variables & requiredVariables() const;
 private:
  ufo::Variables invars_;
  std::unique_ptr<ObsErrorFactorPressureCheckParameters> options_;
};

// -----------------------------------------------------------------------------

}  // namespace ufo

#endif  // UFO_FILTERS_OBSFUNCTIONS_OBSERRORFACTORPRESSURECHECK_H_
