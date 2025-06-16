/*
 * (C) Crown Copyright 2024, Met Office
 *
 * This software is licensed under the terms of the Apache Licence Version 2.0
 * which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
 */

#include <string>
#include <vector>

#include "ufo/operators/sfccorrected/EvalSurfaceTemperature.h"

#include "eckit/exception/Exceptions.h"
#include "ioda/ObsSpace.h"
#include "oops/util/Logger.h"
#include "ufo/GeoVaLs.h"
#include "ufo/utils/Constants.h"
#include "ufo/utils/VertInterp.interface.h"
#include "ufo/variabletransforms/Formulas.h"

namespace ufo {

namespace {
SurfaceOperatorMaker<airTemperature_WRFDA> makerT2M_WRFDA_("airTemperature_WRFDA");
SurfaceOperatorMaker<airTemperature_UKMO> makerT2M_UKMO_("airTemperature_UKMO");
SurfaceOperatorMaker<airTemperature_GSL> makerT2M_GSL_("airTemperature_GSL");
}  // namespace

// ----------------------------------------
// Temperature operator using WRFDA method
// ----------------------------------------
airTemperature_WRFDA::airTemperature_WRFDA(const std::string & name,
                                                   const Parameters_ & params)
    : SurfaceOperatorBase(name, params)
{
  oops::Variables vars;
  vars.push_back(oops::Variable(params_.geovarGeomZ.value()));
  vars.push_back(oops::Variable(params_.geovarSfcGeomZ.value()));
  vars.push_back(oops::Variable("air_temperature"));
  requiredVars_ += vars;
}

void airTemperature_WRFDA::simobs(const ufo::GeoVaLs & gv,
                                      const ioda::ObsSpace & obsdb,
                                      std::vector<float> & hofx) const {
  oops::Log::trace() << "airTemperature_WRFDA::simobs starting" << std::endl;

  // Setup parameters used throughout
  const size_t nobs = obsdb.nlocs();
  const float missing = util::missingValue<float>();
  std::vector<float> obs_lats(nobs);
  obsdb.get_db("MetaData", "latitude", obs_lats);

  // Create arrays needed
  std::vector<float> model_height_level1(nobs), model_height_surface(nobs),
                     model_T_level1(nobs), obs_height(nobs);

  // Get level 1 height.  If geopotential then convert to geometric height.
  const oops::Variable geomz_var = oops::Variable(params_.geovarGeomZ.value());
  const int surface_level_index = gv.nlevs(geomz_var) - 1;
  gv.getAtLevel(model_height_level1, geomz_var, surface_level_index);
  if (params_.geovarGeomZ.value().find("geopotential") != std::string::npos) {
    oops::Log::trace()  << "ObsSfcCorrected::simulateObs_WRFDA do geopotential"
                        << " conversion for model level 1" << std::endl;
    for (size_t iloc = 0; iloc < nobs; ++iloc) {
      model_height_level1[iloc] = formulas::Geopotential_to_Geometric_Height(obs_lats[iloc],
          model_height_level1[iloc]);
    }
  }

  // Get surface height.  If geopotential then convert to geometric height.
  gv.get(model_height_surface, oops::Variable(params_.geovarSfcGeomZ.value()));
  if (params_.geovarSfcGeomZ.value().find("geopotential") != std::string::npos) {
    oops::Log::trace()  << "ObsSfcCorrected::simulateObs_WRFDA do geopotential"
                        << " conversion for model surface level" << std::endl;
    for (size_t iloc = 0; iloc < nobs; ++iloc) {
      model_height_surface[iloc] = formulas::Geopotential_to_Geometric_Height(obs_lats[iloc],
          model_height_surface[iloc]);
    }
  }

  // Read other data in
  oops::Variable model_T_var = oops::Variable("air_temperature");
  gv.getAtLevel(model_T_level1, model_T_var, surface_level_index);
  obsdb.get_db("MetaData", params_.obsHeightName.value(), obs_height);

  // Loop to calculate hofx
  std::vector<float> model_T_surface(nobs);
  for (size_t iloc = 0; iloc < nobs; ++iloc) {
    hofx[iloc] = missing;
    if (obs_height[iloc] != missing && model_T_level1[iloc] != missing &&
        model_height_level1[iloc] != missing && model_height_surface[iloc] != missing) {
      // Find model surface T using lowest T in model temperature profile
      model_T_surface[iloc] = model_T_level1[iloc] +
              ufo::Constants::Lclr * (model_height_level1[iloc] - model_height_surface[iloc]);
      // Correct to observation height
      hofx[iloc] = model_T_surface[iloc] +
                   ufo::Constants::Lclr * (model_height_surface[iloc] - obs_height[iloc]);
    }
  }

  oops::Log::trace() << "airTemperature_WRFDA::simobs complete" << std::endl;
}

void airTemperature_WRFDA::settraj() const {
  throw eckit::Exception("airTemperature_WRFDA::settraj not yet implemented");
}

void airTemperature_WRFDA::TL() const {
  throw eckit::Exception("airTemperature_WRFDA::TL not yet implemented");
}

void airTemperature_WRFDA::AD() const {
  throw eckit::Exception("airTemperature_WRFDA::AD not yet implemented");
}

// ----------------------------------------
// Temperature operator using UKMO method
// ----------------------------------------

airTemperature_UKMO::airTemperature_UKMO(const std::string & name,
                                                 const Parameters_ & params)
  : SurfaceOperatorBase(name, params)
{
  oops::Variables vars;
  vars.push_back(oops::Variable(params_.geovarGeomZ.value()));
  vars.push_back(oops::Variable(params_.geovarSfcGeomZ.value()));
  vars.push_back(oops::Variable("air_temperature"));
  vars.push_back(oops::Variable("air_pressure"));
  vars.push_back(oops::Variable("air_pressure_at_surface"));
  requiredVars_ += vars;
}

void airTemperature_UKMO::simobs(const ufo::GeoVaLs & gv,
                                     const ioda::ObsSpace & obsdb,
                                     std::vector<float> & hofx) const {
  oops::Log::trace() << "airTemperature_UKMO::simobs starting" << std::endl;

  // Create oops::Variable needed
  const oops::Variable model_height_var = oops::Variable(params_.geovarGeomZ.value());
  const oops::Variable model_p_var = oops::Variable("air_pressure");
  const oops::Variable model_p_surface_var = oops::Variable("air_pressure_at_surface");
  const oops::Variable model_T_var = oops::Variable("air_temperature");

  // Setup parameters used throughout
  const size_t nobs = obsdb.nlocs();
  const float missing = util::missingValue<float>();
  const double height_used = 2000.0;
  const int model_nlevs = gv.nlevs(model_p_var);
  const double T_exponent = ufo::Constants::rd * ufo::Constants::Lclr / ufo::Constants::grav;

  // Create arrays needed
  std::vector<float> model_height_surface(nobs), model_p_surface(nobs),
      obs_height(nobs), lats(nobs);
  std::vector<double> model_p_2000m(nobs), model_T_2000m(nobs);
  obsdb.get_db("MetaData", "latitude", lats);
  bool convertLevel1GeopotentialHeight = false;

  // Get level 1 height.  If geopotential then convert to geometric height.
  if (params_.geovarGeomZ.value().find("geopotential") != std::string::npos) {
    oops::Log::trace()  << "ObsSfcCorrected::simulateObs do geopotential conversion profile"
                       << std::endl;
    convertLevel1GeopotentialHeight = true;
  }

  // Get surface height.  If geopotential then convert to geometric height.
  gv.get(model_height_surface, oops::Variable(params_.geovarSfcGeomZ.value()));
  if (params_.geovarSfcGeomZ.value().find("geopotential") != std::string::npos) {
    oops::Log::trace()  << "ObsSfcCorrected::simulateObs do geopotential conversion surface"
                       << std::endl;
    for (size_t iloc = 0; iloc < nobs; ++iloc) {
      model_height_surface[iloc] = formulas::Geopotential_to_Geometric_Height(lats[iloc],
         model_height_surface[iloc]);
    }
  }

  // Read data in
  gv.get(model_p_surface, model_p_surface_var);
  obsdb.get_db("MetaData", params_.obsHeightName.value(), obs_height);

  // Loop to calculate hofx
  double model_T_surface;
  std::vector<double> profile_height(model_nlevs);
  std::vector<double> profile_pressure(model_nlevs);
  std::vector<double> profile_T(model_nlevs);
  int index = 0;
  double weight = 0.0;
  for (size_t iloc = 0; iloc < nobs; ++iloc) {
    hofx[iloc] = missing;
    if (obs_height[iloc] != missing && model_p_surface[iloc] != missing &&
        model_height_surface[iloc] != missing) {
      // Get model data at this location
      gv.getAtLocation(profile_height, model_height_var, iloc);
      gv.getAtLocation(profile_pressure, model_p_var, iloc);
      gv.getAtLocation(profile_T, model_T_var, iloc);
      // Convert geopotential to geometric height if needed
      if (convertLevel1GeopotentialHeight) {
        for (size_t i = 0; i < model_nlevs; ++i) {
          profile_height[i] = formulas::Geopotential_to_Geometric_Height(lats[iloc],
            profile_height[i]);
        }
      }
      vert_interp_weights_f90(model_nlevs, height_used, profile_height.data(), index, weight);

      // Vertical interpolation to get model pressure and temperature at 2000 m
      vert_interp_apply_f90(model_nlevs, profile_pressure.data(),
                            model_p_2000m[iloc], index, weight);
      vert_interp_apply_f90(model_nlevs, profile_T.data(),
                            model_T_2000m[iloc], index, weight);
      // Find model surface T using lowest T in model temperature profile
      model_T_surface = model_T_2000m[iloc] *
        std::pow((model_p_surface[iloc] / model_p_2000m[iloc]), T_exponent);
      // Correct to observation height
      hofx[iloc] = model_T_surface +
        ufo::Constants::Lclr * (model_height_surface[iloc] - obs_height[iloc]);
    }
  }
  oops::Log::trace() << "airTemperature_UKMO::simobs complete" << std::endl;
}

void airTemperature_UKMO::settraj() const {
  throw eckit::Exception("airTemperature_UKMO::settraj not yet implemented");
}

void airTemperature_UKMO::TL() const {
  throw eckit::Exception("airTemperature_UKMO::TL not yet implemented");
}

void airTemperature_UKMO::AD() const {
  throw eckit::Exception("airTemperature_UKMO::AD not yet implemented");
}

// ----------------------------------------
// Temperature operator using GSL method
// ----------------------------------------

airTemperature_GSL::airTemperature_GSL(const std::string & name,
                                               const Parameters_ & params)
  : SurfaceOperatorBase(name, params)
{
  oops::Variables vars;
  vars.push_back(oops::Variable(params_.geovarGeomZ.value()));
  vars.push_back(oops::Variable(params_.geovarSfcGeomZ.value()));
  vars.push_back(oops::Variable("air_temperature"));
  vars.push_back(oops::Variable("air_temperature_at_2m"));
  requiredVars_ += vars;
}

void airTemperature_GSL::simobs(const ufo::GeoVaLs & gv,
                                    const ioda::ObsSpace & obsdb,
                                    std::vector<float> & hofx) const {
  oops::Log::trace() << "airTemperature_GSL::simobs starting" << std::endl;

  // Setup parameters used throughout
  const size_t nobs = obsdb.nlocs();
  const float missing = util::missingValue<float>();

  // Create arrays needed
  std::vector<float> lapse_rate(nobs), obs_height(nobs),
                     model_height_surface(nobs), model_T_surface(nobs);

  // Check if GSL parameters exist
  if (!params_.gslParams.value()) {
    throw eckit::UserError("GSL correction requires gsl_parameters to be provided", Here());
  }

  const auto& gsl_params = params_.gslParams.value().get();

  switch (gsl_params.temperatureLapseRateOption.value()) {
    case GslLapseRateOption::Constant: {
      const float lapse_rate_value = gsl_params.temperatureLapseRateValue.value() / 1000.0f;  // Convert K/km to K/m
      lapse_rate = std::vector<float>(nobs, lapse_rate_value);
      break;
    }
    case GslLapseRateOption::Local: {
      // Create arrays need
      std::vector<float> model_height_level1(nobs),  model_height_toplayer(nobs),
                         model_T_level1(nobs), model_T_toplayer(nobs);

      // Get level 1 height.  If geopotential then convert to geometric height.
      const oops::Variable geomz_var = oops::Variable(params_.geovarGeomZ.value());
      const int surface_level_index = gv.nlevs(geomz_var) - 1;
      gv.getAtLevel(model_height_level1, geomz_var, surface_level_index);
      if (params_.geovarGeomZ.value().find("geopotential") != std::string::npos) {
          oops::Log::trace()  << "ObsSfcCorrected::simulateObs do geopotential conversion profile" << std::endl;
      }

      // Get top layer height.  If geopotential then convert to geometric height.
      int toplayer_level_index;
      const int local_highest_level = gsl_params.temperatureLocalLapseRateLevel.value();
      if (surface_level_index == 0) {
          toplayer_level_index = local_highest_level - 1;
      } else {
          toplayer_level_index = surface_level_index - local_highest_level + 1;
      }
      gv.getAtLevel(model_height_toplayer, geomz_var, toplayer_level_index);
      if (params_.geovarSfcGeomZ.value().find("geopotential") != std::string::npos) {
          oops::Log::trace()  << "ObsSfcCorrected::simulateObs do geopotential conversion surface" << std::endl;
      }

      // Read other data in
      oops::Variable model_T_var = oops::Variable("air_temperature");
      gv.getAtLevel(model_T_level1, model_T_var, surface_level_index);
      gv.getAtLevel(model_T_toplayer, model_T_var, toplayer_level_index);

      // Calculate lapse rate
      for (int iobs = 0; iobs < nobs; ++iobs) {
          if (model_height_toplayer[iobs] != missing && model_height_level1[iobs] != missing) {
              lapse_rate[iobs] = (model_T_level1[iobs] - model_T_toplayer[iobs]) /
                                 (model_height_toplayer[iobs] - model_height_level1[iobs]);
          } else {
               lapse_rate[iobs] = missing;
          }
          if (gsl_params.temperatureLapseRateThreshold.value() && lapse_rate[iobs] != missing) {
             const float minthresh = gsl_params.minThreshold.value()/1000.;
             const float maxthresh = gsl_params.maxThreshold.value()/1000.;
             lapse_rate[iobs] = std::clamp(lapse_rate[iobs], minthresh, maxthresh);
          }
      }
      break;
    }
    case GslLapseRateOption::NoAdjustment: {
      lapse_rate = std::vector<float>(nobs, 0.0f);
      break;
    }
  }

  // Get surface height.  If geopotential then convert to geometric height.
  gv.get(model_height_surface, oops::Variable(params_.geovarSfcGeomZ.value()));
  if (params_.geovarSfcGeomZ.value().find("geopotential") != std::string::npos) {
      oops::Log::trace()  << "ObsSfcCorrected::simulateObs do geopotential conversion surface" << std::endl;
  }

  // Read other data in
  gv.get(model_T_surface, oops::Variable("air_temperature_at_2m"));
  obsdb.get_db("MetaData", params_.obsHeightName.value(), obs_height);

  // Loop to calculate hofx
  for (size_t iloc = 0; iloc < nobs; ++iloc) {
    hofx[iloc] = missing;
    if (obs_height[iloc] != missing && model_height_surface[iloc] != missing &&
        lapse_rate[iloc] != missing && model_T_surface[iloc] != missing) {
      // Correct to observation height
      hofx[iloc] = model_T_surface[iloc] +
                   lapse_rate[iloc] * (model_height_surface[iloc] - obs_height[iloc]);
    }
  }

  oops::Log::trace() << "airTemperature_GSL::simobs complete" << std::endl;
}

void airTemperature_GSL::settraj() const {
  throw eckit::Exception("airTemperature_GSL::settraj not yet implemented");
}

void airTemperature_GSL::TL() const {
  throw eckit::Exception("airTemperature_GSL::TL not yet implemented");
}

void airTemperature_GSL::AD() const {
  throw eckit::Exception("airTemperature_GSL::AD not yet implemented");
}

}  // namespace ufo
