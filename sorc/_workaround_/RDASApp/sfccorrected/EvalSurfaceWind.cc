/*
 * (C) Crown Copyright 2024, Met Office
 *
 * This software is licensed under the terms of the Apache Licence Version 2.0
 * which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
 */

#include <string>
#include <vector>

#include "ufo/operators/sfccorrected/EvalSurfaceWind.h"

#include "eckit/exception/Exceptions.h"
#include "ioda/ObsSpace.h"
#include "oops/util/Logger.h"
#include "ufo/GeoVaLs.h"
#include "ufo/utils/Constants.h"
#include "ufo/utils/VertInterp.interface.h"
#include "ufo/variabletransforms/Formulas.h"

namespace ufo {

namespace {
SurfaceOperatorMaker<windEastward_GSL>  makerU10_GSL("windEastward_GSL");
SurfaceOperatorMaker<windNorthward_GSL> makerV10_GSL("windNorthward_GSL");
}  // namespace

// ----------------------------------------
// Zonal Wind operator using GSL method
// ----------------------------------------

windEastward_GSL::windEastward_GSL(const std::string & name,
                                   const Parameters_ & params)
  : SurfaceOperatorBase(name, params)
{
  oops::Variables vars;
  vars.push_back(oops::Variable(params_.geovarGeomZ.value()));
  vars.push_back(oops::Variable(params_.geovarSfcGeomZ.value()));
  vars.push_back(oops::Variable("eastward_wind_at_10m"));
  requiredVars_ += vars;
}

void windEastward_GSL::simobs(const ufo::GeoVaLs & gv,
                              const ioda::ObsSpace & obsdb,
                              std::vector<float> & hofx) const {
  oops::Log::trace() << "windEastwardAt10M_GSL::simobs starting" << std::endl;
  
  // Setup parameters used throughout
  const size_t nobs = obsdb.nlocs();
  const float missing = util::missingValue<float>();

  // Create arrays needed
  std::vector<float> obs_height(nobs), model_U10_surface(nobs);

  // Read other data in
  gv.get(model_U10_surface, oops::Variable("eastward_wind_at_10m"));
  obsdb.get_db("MetaData", params_.obsHeightName.value(), obs_height);

  // Loop to calculate hofx
  for (size_t iloc = 0; iloc < nobs; ++iloc) {
    hofx[iloc] = missing;
    if (obs_height[iloc] != missing && model_U10_surface[iloc] != missing) {
      // Use 10m eastward wind as background
      hofx[iloc] = model_U10_surface[iloc];
    }
  }

  oops::Log::trace() << "windEastwardAt10M_GSL::simobs complete" << std::endl;
}

void windEastward_GSL::settraj() const {
  throw eckit::Exception("windEastwardAt10M_GSL::settraj not yet implemented");
}

void windEastward_GSL::TL() const {
  throw eckit::Exception("windEastwardAt10M_GSL::TL not yet implemented");
}

void windEastward_GSL::AD() const {
  throw eckit::Exception("windEastwardAt10M_GSL::AD not yet implemented");
}

// ----------------------------------------
// Meridional Wind operator using GSL method
// ----------------------------------------

windNorthward_GSL::windNorthward_GSL(const std::string & name,
                                     const Parameters_ & params)
  : SurfaceOperatorBase(name, params)
{
  oops::Variables vars;
  vars.push_back(oops::Variable(params_.geovarGeomZ.value()));
  vars.push_back(oops::Variable(params_.geovarSfcGeomZ.value()));
  vars.push_back(oops::Variable("northward_wind_at_10m"));
  requiredVars_ += vars;
}

void windNorthward_GSL::simobs(const ufo::GeoVaLs & gv,
                               const ioda::ObsSpace & obsdb,
                               std::vector<float> & hofx) const {
  oops::Log::trace() << "windNorthwardAt10M_GSL::simobs starting" << std::endl;

  // Setup parameters used throughout
  const size_t nobs = obsdb.nlocs();
  const float missing = util::missingValue<float>();

  // Create arrays needed
  std::vector<float> obs_height(nobs), model_V10_surface(nobs);

  // Read other data in
  gv.get(model_V10_surface, oops::Variable("northward_wind_at_10m"));
  obsdb.get_db("MetaData", params_.obsHeightName.value(), obs_height);

  // Loop to calculate hofx
  for (size_t iloc = 0; iloc < nobs; ++iloc) {
    hofx[iloc] = missing;
    if (obs_height[iloc] != missing && model_V10_surface[iloc] != missing) {
      // Use 10m northward wind as background
      hofx[iloc] = model_V10_surface[iloc];
    }
  }

  oops::Log::trace() << "windNorthwardAt10M_GSL::simobs complete" << std::endl;
}

void windNorthward_GSL::settraj() const {
  throw eckit::Exception("windNorthwardAt10M_GSL::settraj not yet implemented");
}

void windNorthward_GSL::TL() const {
  throw eckit::Exception("windNorthwardAt10M_GSL::TL not yet implemented");
}

void windNorthward_GSL::AD() const {
  throw eckit::Exception("windNorthwardAt10M_GSL::AD not yet implemented");
}

}  // namespace ufo
