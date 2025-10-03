/*
 * (C) Crown Copyright 2025, GSL
 *
 * This software is licensed under the terms of the Apache Licence Version 2.0
 * which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
 */

#include <string>
#include <vector>

#include "ufo/operators/sfccorrected/EvalSurfaceHumidity.h"

#include "eckit/exception/Exceptions.h"
#include "ioda/ObsSpace.h"
#include "oops/util/Logger.h"
#include "ufo/GeoVaLs.h"
#include "ufo/utils/Constants.h"
#include "ufo/utils/VertInterp.interface.h"
#include "ufo/variabletransforms/Formulas.h"

namespace ufo {

namespace {
SurfaceOperatorMaker<specificHumidity_GSL> makerQ2M_GSL_("specificHumidity_GSL");
}  // namespace

// ----------------------------------------
// Humidity operator using GSL method
// ----------------------------------------

specificHumidity_GSL::specificHumidity_GSL(const std::string & name,
                                           const Parameters_ & params)
  : SurfaceOperatorBase(name, params)
{
  oops::Variables vars;
  vars.push_back(oops::Variable(params_.geovarGeomZ.value()));
  vars.push_back(oops::Variable(params_.geovarSfcGeomZ.value()));
  vars.push_back(oops::Variable("water_vapor_mixing_ratio_wrt_moist_air_at_2m"));
  requiredVars_ += vars;
}

void specificHumidity_GSL::simobs(const ufo::GeoVaLs & gv,
                                  const ioda::ObsSpace & obsdb,
                                  std::vector<float> & hofx) const {
  oops::Log::trace() << "specificHumidityAt2M_GSL::simobs starting" << std::endl;
  
  // Setup parameters used throughout
  const size_t nobs = obsdb.nlocs();
  const float missing = util::missingValue<float>();

  // Create arrays needed
  std::vector<float> obs_height(nobs), model_Q_surface(nobs);

  // Read other data in
  gv.get(model_Q_surface, oops::Variable("water_vapor_mixing_ratio_wrt_moist_air_at_2m"));
  obsdb.get_db("MetaData", params_.obsHeightName.value(), obs_height);

  // Loop to calculate hofx
  for (size_t iloc = 0; iloc < nobs; ++iloc) {
    hofx[iloc] = missing;
    if (obs_height[iloc] != missing && model_Q_surface[iloc] != missing) {
      // Use 2m Q as background
      hofx[iloc] = model_Q_surface[iloc];
    }
  }

  oops::Log::trace() << "specificHumidityAt2M_GSL::simobs complete" << std::endl;
}

void specificHumidity_GSL::settraj() const {
  throw eckit::Exception("specificHumidity_GSL::settraj not yet implemented");
}

void specificHumidity_GSL::TL() const {
  throw eckit::Exception("specificHumidity_GSL::TL not yet implemented");
}

void specificHumidity_GSL::AD() const {
  throw eckit::Exception("specificHumidity_GSL::AD not yet implemented");
}

}  // namespace ufo
