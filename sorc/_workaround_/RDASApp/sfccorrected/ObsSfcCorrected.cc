/*
 * (C) Crown Copyright 2024, Met Office
 * (C) Copyright 2024 UCAR
 * 
 * This software is licensed under the terms of the Apache Licence Version 2.0
 * which can be obtained at http://www.apache.org/licenses/LICENSE-2.0. 
 */

#include <memory>
#include <ostream>
#include <utility>
#include <vector>

#include "ufo/operators/sfccorrected/ObsSfcCorrected.h"

#include "ioda/ObsVector.h"
#include "oops/base/Variables.h"
#include "ufo/filters/Variables.h"
#include "ufo/GeoVaLs.h"
#include "ufo/operators/sfccorrected/EvalSurfacePressure.h"
#include "ufo/operators/sfccorrected/EvalSurfaceTemperature.h"
#include "ufo/operators/sfccorrected/EvalSurfaceHumidity.h"
#include "ufo/operators/sfccorrected/EvalSurfaceWind.h"
#include "ufo/utils/OperatorUtils.h"

namespace ufo {

// -----------------------------------------------------------------------------
static ObsOperatorMaker<ObsSfcCorrected> makerSfcCorrected_("SfcCorrected");
// -----------------------------------------------------------------------------

ObsSfcCorrected::ObsSfcCorrected(const ioda::ObsSpace & odb,
                                 const Parameters_ & params)
  : ObsOperatorBase(odb), requiredVars_(), odb_(odb), params_(params)
{
  oops::Log::trace() << "ObsSfcCorrected constructor start." << std::endl;

  // Get the variables to simulate hofx for will be a subset of the assimilated variables
  getOperatorVariables(params_.variables.value(), odb.assimvariables(),
                       operatorVars_, operatorVarIndices_);

  // Get surface correction type as a string
  std::string methodname;
  for (util::NamedEnumerator<SfcCorrectionType> namedValue :
       SfcCorrectionTypeParameterTraitsHelper::namedValues) {
    if (namedValue.value == params_.correctionType.value()) {
      methodname = namedValue.name;
    }
  }

  std::string operatorname;
  // Create operators for each variable / surface correction type combination
  for (std::string var : operatorVars_.variables()) {
    operatorname = var + "_" + methodname;
    std::unique_ptr<SurfaceOperatorBase> oper =
        SurfaceOperatorFactory::create(operatorname, params_);
    requiredVars_ += oper->requiredVars();
    operators_.push_back(std::move(oper));
  }

  oops::Log::trace() << "ObsSfcCorrected operator " << operatorname << " constructed."
        << std::endl;
}

// -----------------------------------------------------------------------------

ObsSfcCorrected::~ObsSfcCorrected() {
  oops::Log::trace() << "ObsSfcCorrected destructor done" << std::endl;
}

// -----------------------------------------------------------------------------

void ObsSfcCorrected::simulateObs(const GeoVaLs & gv, ioda::ObsVector & ovec,
                             ObsDiagnostics & obsdiags, const QCFlags_t & qc_flags) const {
  oops::Log::trace() << "ObsSfcCorrected::simulateObs start." << std::endl;
  // Look over variables to calculate hofx
  std::vector<float> hofx(ovec.nlocs());
  for (size_t i = 0; i < operatorVars_.size(); ++i) {
     int jvar = operatorVarIndices_[i];
    // Calculate hofx
    operators_[i]->simobs(gv, odb_, hofx);

    // Populate the observation vector
    for (size_t jloc = 0; jloc < ovec.nlocs(); ++jloc) {
      const size_t idx = jloc * ovec.nvars() + jvar;
      ovec[idx] = hofx[jloc];
    }
  }
  oops::Log::trace() << "ObsSfcCorrected::simulateObs done." << std::endl;
}

// -----------------------------------------------------------------------------

void ObsSfcCorrected::print(std::ostream & os) const {
  os << "ObsSfcCorrected::print not implemented";
}

// -----------------------------------------------------------------------------

}  // namespace ufo
