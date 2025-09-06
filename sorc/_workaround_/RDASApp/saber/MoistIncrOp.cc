/*
 * (C) Crown Copyright 2022-2025 Met Office
 *
 * This software is licensed under the terms of the Apache Licence Version 2.0
 * which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
 */

#include "saber/vader/MoistIncrOp.h"

#include <netcdf.h>

#include <algorithm>
#include <memory>
#include <string>
#include <vector>

#include "atlas/array.h"
#include "atlas/field.h"

#include "eckit/exception/Exceptions.h"

#include "mo/constants.h"

#include "oops/base/FieldSet3D.h"
#include "oops/base/Variables.h"
#include "oops/util/AtlasArrayUtil.h"
#include "oops/util/FieldSetHelpers.h"
#include "oops/util/FieldSetOperations.h"
#include "oops/util/for_each.h"
#include "oops/util/missingValues.h"
#include "oops/util/Timer.h"

#include "saber/blocks/SaberOuterBlockBase.h"
#include "saber/oops/Utilities.h"
#include "saber/vader/movader_covstats_interface.h"

namespace saber {
namespace vader {

namespace {

auto calcMedian(std::vector<double> x) {
  // Sort the vector
  std::sort(x.begin(), x.end());

  double median(util::missingValue<double>());

  // Check if the number of elements is odd
  if (x.size() % 2 != 0) {
    median = x[x.size() / 2];
  } else {
    // If the number of elements is even, return the average
    // of the two middle elements
    median = (x[(x.size() - 1) / 2] + x[x.size() / 2]) / 2.0;
  }

  return median;
}

// function to calculate linear regression coefficient (with zero intercept)
auto linregrcoeff(const std::vector<double> x, const std::vector<double> y) {
  // check x and y have same number of elements
  if (x.size() != y.size()) {
      throw eckit::UserError("Input vectors should have same number of elements!", Here());
  }

  // check x and y have at least 2 elements
  if (x.size() < 2) {
    throw eckit::UserError("Input vectors should have at least two data points", Here());
  }

  std::vector<double> xinc(x);
  const double xmean = std::accumulate(xinc.begin(), xinc.end(), 0.0) / xinc.size();
  for (auto& element : xinc) {
    element -= xmean;
  }
  std::vector<double> yinc(y);
  const double ymean = std::accumulate(yinc.begin(), yinc.end(), 0.0) / yinc.size();
  for (auto& element : yinc) {
    element -= ymean;
  }

  const double covxy = std::inner_product(xinc.begin(), xinc.end(), yinc.begin(), 0.0);
  const double varx = std::inner_product(xinc.begin(), xinc.end(), xinc.begin(), 0.0);

  double regrcoefval(util::missingValue<double>());
  if (varx > 0.0) {
    regrcoefval = covxy/varx;
  } else {
    oops::Log::info() << "var(x): " << varx << " size(x): " << x.size() << std::endl;
    throw eckit::UserError("variance of x must be different from zero!", Here());
  }

  return regrcoefval;
}

void writeOutputMIOToNetcdf(std::vector<std::vector<double>> qclIncRegrArr,
                            std::vector<std::vector<double>> qcfIncRegrArr,
                            std::vector<std::vector<std::size_t>> numQclIncArr,
                            std::vector<std::vector<std::size_t>> numQcfIncArr,
                            const std::string ncfilepath) {
  const std::vector<std::string> dimNames{"bin", "level"};
  const std::vector<atlas::idx_t> dimSizes{mo::constants::mioBins, mo::constants::mioLevs};

  const oops::Variables vars(std::vector<std::string>{"qcl_coef", "qcf_coef",
                                                      "num_qcl_data", "num_qcf_data"});
  const std::vector<std::vector<std::string>> dimNamesForEveryVar{{"bin", "level"},
                                                                  {"bin", "level"},
                                                                  {"bin", "level"},
                                                                  {"bin", "level"}};

  std::vector<int> netcdfGeneralIDs;
  std::vector<int> netcdfDimIDs;
  std::vector<int> netcdfVarIDs;
  std::vector<std::vector<int>> netcdfDimVarIDs;

  // create a fieldset with fields that are ordered consistently with
  // the ordering of the "moisture incrementing operator file" specified in the yaml file.
  // In particular, here the arrays are written as the transpose of the arrays
  // in MIO_coefficients.nc file, as the latter is then read by the Fortran netcdf library,
  // i.e. in column-major rather than in row-major format.
  atlas::FieldSet miocoef_fset;
  for (const oops::Variable & var : vars) {
    auto Fld = atlas::Field(var.name(),
                            atlas::array::make_datatype<double>(),
                            atlas::array::make_shape({dimSizes[0],
                                                      dimSizes[1]}));
    auto fview = atlas::array::make_view<double, 2>(Fld);
    for (std::size_t ibin = 0; ibin < mo::constants::mioBins; ibin++) {
      for (std::size_t jl = 0; jl < mo::constants::mioLevs; ++jl) {
        if (var.name() == "qcl_coef") {
          fview(ibin, jl) = qclIncRegrArr[jl][ibin];
        } else if (var.name() == "qcf_coef") {
          fview(ibin, jl) = qcfIncRegrArr[jl][ibin];
        } else if (var.name() == "num_qcl_data") {
          fview(ibin, jl) = static_cast<double>(numQclIncArr[jl][ibin]);
        } else if (var.name() == "num_qcf_data") {
          fview(ibin, jl) = numQcfIncArr[jl][ibin];
        }
      }
    }
    miocoef_fset.add(Fld);
  }

  eckit::LocalConfiguration netcdfMetaData;
  for (const oops::Variable & var : vars) {
    util::setAttribute<std::string>(
      netcdfMetaData, var.name(), "statistics_type", "string", "moisture incrementing operator");
  }

  util::atlasArrayWriteHeader(ncfilepath,
                              dimNames,
                              dimSizes,
                              vars,
                              dimNamesForEveryVar,
                              netcdfMetaData,
                              netcdfGeneralIDs,
                              netcdfDimIDs,
                              netcdfVarIDs,
                              netcdfDimVarIDs);
  std::size_t t(0);
  for (const atlas::Field & fld : miocoef_fset) {
    auto fview = atlas::array::make_view<const double, 2>(fld);
    util::atlasArrayWriteData(netcdfGeneralIDs,
                              netcdfVarIDs[t],
                              fview);
    ++t;
  }

  if (nc_close(netcdfGeneralIDs[0])) throw eckit::Exception("NetCDF closing error",
                                                            Here());
}

Eigen::MatrixXd createMIOCoeff(const std::string mioFileName,
                               const std::string s) {
  oops::Log::trace() << "[createMIOCoeff] starting ..." << std::endl;
  Eigen::MatrixXd mioCoeff(static_cast<std::size_t>(::mo::constants::mioLevs),
                           static_cast<std::size_t>(::mo::constants::mioBins));

  std::vector<double> valuesvec(::mo::constants::mioLookUpLength, 0);

  oldCovMIOStats_f90(static_cast<int>(mioFileName.size()),
                    mioFileName.c_str(),
                    static_cast<int>(s.size()),
                    s.c_str(),
                    static_cast<int>(::mo::constants::mioBins),
                    static_cast<int>(::mo::constants::mioLevs),
                    valuesvec[0]);

  for (int j = 0; j < static_cast<int>(::mo::constants::mioLevs); ++j) {
    for (int i = 0; i < static_cast<int>(::mo::constants::mioBins); ++i) {
      // Fortran returns column major order, but C++ needs row major
      mioCoeff(j, i) = valuesvec[i * ::mo::constants::mioLevs+j];
    }
  }
  oops::Log::trace() << "[createMIOCoeff] ... exit" << std::endl;
  return mioCoeff;
}


void eval_mio_fields_nl(const std::string & mio_path, atlas::FieldSet & augStateFlds) {
  oops::Log::trace() << "[eval_mio_fields_nl()] starting ..." << std::endl;

  using View = atlas::array::LocalView<double, 1>;
  using ConstView = atlas::array::LocalView<const double, 1>;
  const atlas::idx_t numLevels = augStateFlds["rht"].shape(1);

  Eigen::MatrixXd mioCoeffCl = createMIOCoeff(mio_path, "qcl_coef");
  Eigen::MatrixXd mioCoeffCf = createMIOCoeff(mio_path, "qcf_coef");

  // Note:
  // - We use for_each_column so that we can explicitly loop over the column and
  //   use the vertical index into the Eigen matrices; if more parallelism is
  //   necessary, this could be rewritten in terms of for_each_index
  // - We capture the Eigen matrices by reference as they are large objects; if
  //   capture-by-value becomes required (GPU offloading, for example), then we
  //   could wrap the Eigen matrices in an atlas::Array and capture the ArrayView
  //   by value in the functor
  util::for_each_column(
      [=, &mioCoeffCl, &mioCoeffCf](ConstView rht,
                                    ConstView cl,
                                    ConstView cf,
                                    View cleff,
                                    View cfeff) {
        for (int jl = 0; jl < numLevels; ++jl) {
          if (jl < static_cast<int>(::mo::constants::mioLevs)) {
            // Ternary false branch has std::max inside the static_cast to make sure a small
            // negative integer does not underflow to a giant positive size_t.
            const size_t ibin = (rht(jl) > ::mo::constants::rHTLastBinLowerLimit) ?
                                 ::mo::constants::mioBins - 1 :
                                 static_cast<size_t>(std::max(
                                       floor(rht(jl) / ::mo::constants::rHTBin), 0.0));
            const double ceffdenom = (1.0 - cl(jl) * cf(jl));

            if (ceffdenom > ::mo::constants::tol) {
              const double clcf = cl(jl) * cf(jl);
              cleff(jl) = mioCoeffCl(jl, ibin) * (cl(jl) - clcf) / ceffdenom;
              cfeff(jl) = mioCoeffCf(jl, ibin) * (cf(jl) - clcf) / ceffdenom;
            } else {
              cleff(jl) = 0.5;
              cfeff(jl) = 0.5;
            }
          } else {
            cleff(jl) = 0.0;
            cfeff(jl) = 0.0;
          }
        }
      },
      augStateFlds["rht"],
      augStateFlds["liquid_cloud_volume_fraction_in_atmosphere_layer"],
      augStateFlds["ice_cloud_volume_fraction_in_atmosphere_layer"],
      augStateFlds["cleff"],
      augStateFlds["cfeff"]);

  augStateFlds["cleff"].set_dirty();
  augStateFlds["cfeff"].set_dirty();

  oops::Log::trace() << "[eval_mio_fields_nl()] ... exit" << std::endl;
}

const char specific_humidity_mo[] = "water_vapor_mixing_ratio_wrt_moist_air_and_condensed_water";

// ------------------------------------------------------------------------------------------------
void eval_moisture_incrementing_operator_tl(atlas::FieldSet & incFlds,
                                            const atlas::FieldSet & augStateFlds) {
  oops::Log::trace() << "[eval_moisture_incrementing_operator_tl()] starting ..."
                     << std::endl;

  util::for_each_value(
      [](const double qsat,
         const double dlsvpdT,
         const double cleff,
         const double cfeff,
         const double qtInc,
         const double temperInc,
         double & qclInc,
         double & qcfInc,
         double & qInc) {
        const double maxCldInc = qtInc - qsat * dlsvpdT * temperInc;
        qclInc = cleff * maxCldInc;
        qcfInc = cfeff * maxCldInc;
        qInc = qtInc - qclInc - qcfInc;
      },
      augStateFlds["qsat"],
      augStateFlds["dlsvpdT"],
      augStateFlds["cleff"],
      augStateFlds["cfeff"],
      incFlds["qt"],
      incFlds["air_temperature"],
      incFlds["cloud_liquid_water_mixing_ratio_wrt_moist_air_and_condensed_water"],
      incFlds["cloud_ice_mixing_ratio_wrt_moist_air_and_condensed_water"],
      incFlds[specific_humidity_mo]);

  incFlds["cloud_liquid_water_mixing_ratio_wrt_moist_air_and_condensed_water"].set_dirty();
  incFlds["cloud_ice_mixing_ratio_wrt_moist_air_and_condensed_water"].set_dirty();
  incFlds[specific_humidity_mo].set_dirty();

  oops::Log::trace() << "[eval_moisture_incrementing_operator_tl()] ... done"
                     << std::endl;
}

// ------------------------------------------------------------------------------------------------
void eval_moisture_incrementing_operator_ad(atlas::FieldSet & hatFlds,
                             const atlas::FieldSet & augStateFlds) {
  oops::Log::trace() << "[eval_moisture_incrementing_operator_ad()] starting ..."
                     << std::endl;

  util::for_each_value(
      [](const double qsat,
         const double dlsvpdT,
         const double cleff,
         const double cfeff,
         double & temperHat,
         double & qtHat,
         double & qHat,
         double & qclHat,
         double & qcfHat) {
        const double qsatdlsvpdT = qsat * dlsvpdT;
        temperHat += ((cleff + cfeff) * qHat - cleff * qclHat - cfeff * qcfHat) * qsatdlsvpdT;
        qtHat += cleff * qclHat + cfeff * qcfHat + (1.0 - cleff - cfeff) * qHat;
        qHat = 0.0;
        qclHat = 0.0;
        qcfHat = 0.0;
      },
      augStateFlds["qsat"],
      augStateFlds["dlsvpdT"],
      augStateFlds["cleff"],
      augStateFlds["cfeff"],
      hatFlds["air_temperature"],
      hatFlds["qt"],
      hatFlds[specific_humidity_mo],
      hatFlds["cloud_liquid_water_mixing_ratio_wrt_moist_air_and_condensed_water"],
      hatFlds["cloud_ice_mixing_ratio_wrt_moist_air_and_condensed_water"]);

  hatFlds["air_temperature"].set_dirty();
  hatFlds[specific_humidity_mo].set_dirty();
  hatFlds["qt"].set_dirty();
  hatFlds["cloud_liquid_water_mixing_ratio_wrt_moist_air_and_condensed_water"].set_dirty();
  hatFlds["cloud_ice_mixing_ratio_wrt_moist_air_and_condensed_water"].set_dirty();

  oops::Log::trace() << "[eval_moisture_incrementing_operator_ad()] ... done"
                     << std::endl;
}

// ------------------------------------------------------------------------------------------------
void eval_total_water_tl(atlas::FieldSet & incFlds,
                         const atlas::FieldSet & augStateFlds) {
  oops::Log::trace() << "[eval_total_water_tl()] starting ..." << std::endl;

  util::for_each_value(
      [](const double qInc,
         const double qclInc,
         const double qcfInc,
         double & qtInc) {
        qtInc = qInc + qclInc + qcfInc;
      },
      incFlds[specific_humidity_mo],
      incFlds["cloud_liquid_water_mixing_ratio_wrt_moist_air_and_condensed_water"],
      incFlds["cloud_ice_mixing_ratio_wrt_moist_air_and_condensed_water"],
      incFlds["qt"]);

  incFlds["qt"].set_dirty();

  oops::Log::trace() << "[eval_total_water_tl()] ... done" << std::endl;
}

}  // namespace

// -----------------------------------------------------------------------------

static SaberOuterBlockMaker<MoistIncrOp> makerMoistIncrOp_("mo_moistincrop");

// -----------------------------------------------------------------------------

MoistIncrOp::MoistIncrOp(const oops::GeometryData & outerGeometryData,
                         const oops::Variables & outerVars,
                         const eckit::Configuration & covarConf,
                         const Parameters_ & params,
                         const oops::FieldSet3D & xb,
                         const oops::FieldSet3D & fg)
  : SaberOuterBlockBase(params, xb.validTime()),
    innerGeometryData_(outerGeometryData),
    innerVars_(getUnionOfInnerActiveAndOuterVars(params, outerVars)),
    activeOuterVars_(params.activeOuterVars(outerVars)),
    innerOnlyVars_(getInnerOnlyVars(params, outerVars)),
    augmentedStateFieldSet_(),
    blockparams_(params)
{
  oops::Log::trace() << classname() << "::MoistIncrOp starting" << std::endl;

  const oops::Variables stateVariables = params.mandatoryStateVars();
  augmentedStateFieldSet_.clear();
  for (const auto & s : stateVariables.variables()) {
    augmentedStateFieldSet_.add(xb.fieldSet()[s]);
  }
  // create fields for temporary variables required here (populated in
  // eval_mio_fields_nl)
  const oops::Variables extraStateVariables({oops::Variable{"cleff"},
                                             oops::Variable{"cfeff"}});
  const size_t nlev = xb["qsat"].levels();
  for (const auto & s : extraStateVariables.variables()) {
    atlas::Field field = outerGeometryData.functionSpace()->createField<double>(
                         atlas::option::name(s) | atlas::option::levels(nlev));
    augmentedStateFieldSet_.add(field);
  }

  eval_mio_fields_nl(params.mio_file, augmentedStateFieldSet_);

  oops::Log::trace() << classname() << "::MoistIncrOp done" << std::endl;
}

// -----------------------------------------------------------------------------

MoistIncrOp::~MoistIncrOp() {
  oops::Log::trace() << classname() << "::~MoistIncrOp starting" << std::endl;
  util::Timer timer(classname(), "~MoistIncrOp");
  oops::Log::trace() << classname() << "::~MoistIncrOp done" << std::endl;
}

// -----------------------------------------------------------------------------

void MoistIncrOp::multiply(oops::FieldSet3D & fset) const {
  oops::Log::trace() << classname() << "::multiply starting" << std::endl;
  // Allocate output fields if they are not already present, e.g when randomizing.
  allocateMissingFields(fset, activeOuterVars_, activeOuterVars_,
                        innerGeometryData_.functionSpace());

  // Populate output fields.
  eval_moisture_incrementing_operator_tl(fset.fieldSet(), augmentedStateFieldSet_);

  // Remove inner-only variables
  fset.removeFields(innerOnlyVars_);
  oops::Log::trace() << classname() << "::multiply done" << std::endl;
}

// -----------------------------------------------------------------------------

void MoistIncrOp::multiplyAD(oops::FieldSet3D & fset) const {
  oops::Log::trace() << classname() << "::multiplyAD starting" << std::endl;
  // Allocate inner-only variables
  checkFieldsAreNotAllocated(fset, innerOnlyVars_);
  allocateMissingFields(fset, innerOnlyVars_, innerOnlyVars_,
                        innerGeometryData_.functionSpace());

  eval_moisture_incrementing_operator_ad(fset.fieldSet(), augmentedStateFieldSet_);
  oops::Log::trace() << classname() << "::multiplyAD done" << std::endl;
}

// -----------------------------------------------------------------------------

void MoistIncrOp::leftInverseMultiply(oops::FieldSet3D & fset) const {
  oops::Log::trace() << classname() << "::leftInverseMultiply starting" << std::endl;
  if (!fset.has("air_temperature")) {
    oops::Log::error() << "The inverse of the moisture incrementing operator "
          << "is not correctly defined if air_temperature is not provided "
          << "as an input." << std::endl;
    throw eckit::UserError("Please only use leftInverseMultiply of the mo_moistincrop block "
                           "within the mo_super_mio block.", Here());
  }
  //   Allocate inner-only variables except air temperature
  oops::Variables innerOnlyVarsForInversion(innerOnlyVars_);
  innerOnlyVarsForInversion -= innerOnlyVarsForInversion["air_temperature"];
  checkFieldsAreNotAllocated(fset, innerOnlyVarsForInversion);
  allocateMissingFields(fset, innerOnlyVarsForInversion, innerOnlyVarsForInversion,
                        innerGeometryData_.functionSpace());

  eval_total_water_tl(fset.fieldSet(), augmentedStateFieldSet_);
  oops::Log::trace() << classname() << "::leftInverseMultiply done" << std::endl;
}

// -----------------------------------------------------------------------------

void MoistIncrOp::directCalibration(const oops::FieldSets & fsets) {
  oops::Log::trace() << classname() << "::directCalibration starting" << std::endl;

  const atlas::idx_t numLevels = augmentedStateFieldSet_["rht"].shape(1);
  std::vector<std::vector<double>> qclIncMIOLevBinRegrCoefArr(numLevels,
                                                              std::vector<double>
                                                              (mo::constants::mioBins));
  std::vector<std::vector<std::size_t>> numQclIncArr(numLevels, std::vector<std::size_t>
                                                (mo::constants::mioBins));
  std::vector<std::vector<double>> qcfIncMIOLevBinRegrCoefArr(numLevels,
                                                              std::vector<double>
                                                              (mo::constants::mioBins));
  std::vector<std::vector<std::size_t>> numQcfIncArr(numLevels, std::vector<std::size_t>
                                                (mo::constants::mioBins));

  const size_t nb_mpi_ranks = innerGeometryData_.comm().size();
  const double msvald = util::missingValue<double>();

  // total relative humidity
  const auto rhtView = atlas::array::make_view<const double, 2>(augmentedStateFieldSet_["rht"]);

  // MIO coefficients (already included in cleff and cfeff)
  Eigen::MatrixXd mioCoeffCl = createMIOCoeff(blockparams_.mio_file, "qcl_coef");
  Eigen::MatrixXd mioCoeffCf = createMIOCoeff(blockparams_.mio_file, "qcf_coef");

  for (atlas::idx_t jl = 0; jl < static_cast<atlas::idx_t>(mo::constants::mioLevs); ++jl) {
    // vector of mioBins rows and variable number of columns
    std::vector<std::vector<double>> qclIncBinVec(mo::constants::mioBins);
    std::vector<std::vector<double>> qclIncMIOBinVec(mo::constants::mioBins);
    std::vector<std::vector<double>> qcfIncBinVec(mo::constants::mioBins);
    std::vector<std::vector<double>> qcfIncMIOBinVec(mo::constants::mioBins);
    // ensemble members
    for (std::size_t jj = 0; jj < fsets.size(); ++jj) {
      const auto & fset = fsets[jj].fieldSet();

      if (!(fset.has("air_temperature") && fset.has("qt"))) {
        oops::Log::error() << "Error: air temperature and qt should have been populated beforehand."
                           << std::endl;
        throw eckit::UserError("Please only use the mo_super_mio super block for direct calibration"
                               "of the mo_moistincrop block.", Here());
      }

      // copy fieldset from current ensemble member so I can compare
      // new (i.e. from MIO) qcl field against original
      atlas::FieldSet fset_copy = util::copyFieldSet(fset);

      // I need to create a new qcl_inc Atlas field from qt_inc and t_inc according to the MIO TL
      eval_moisture_incrementing_operator_tl(fset_copy, augmentedStateFieldSet_);

      const auto qclIncMIOView = atlas::array::make_view<const double, 2>
                  (fset_copy["cloud_liquid_water_mixing_ratio_wrt_moist_air_and_condensed_water"]);
      const auto qclIncView = atlas::array::make_view<const double, 2>
                  (fset["cloud_liquid_water_mixing_ratio_wrt_moist_air_and_condensed_water"]);
      const auto qcfIncMIOView = atlas::array::make_view<const double, 2>
                  (fset_copy["cloud_ice_mixing_ratio_wrt_moist_air_and_condensed_water"]);
      const auto qcfIncView = atlas::array::make_view<const double, 2>
                  (fset["cloud_ice_mixing_ratio_wrt_moist_air_and_condensed_water"]);

      for (atlas::idx_t jn = 0; jn < augmentedStateFieldSet_["rht"].shape(0); ++jn) {
        // Ternary false branch has std::max inside the static_cast to make sure a small negative
        // integer does not underflow to a giant positive size_t.
        const std::size_t ibin = (rhtView(jn, jl) > mo::constants::rHTLastBinLowerLimit) ?
                                  mo::constants::mioBins - 1 :
                                  static_cast<std::size_t>(std::max(floor(rhtView(jn, jl) /
                                                           mo::constants::rHTBin), 0.0));

        if (std::abs(qclIncMIOView(jn, jl)) > 0.0) {
          qclIncBinVec[ibin].push_back(qclIncView(jn, jl));  //  local buffer
          // the multiplicative mioCoeffCl needs to be removed from qclIncMIO
          // as this is included in cleff.
          // Note mioCoeffCl(jl, ibin) must be non-zero if inside this if-block
          qclIncMIOBinVec[ibin].push_back(qclIncMIOView(jn, jl) /
                                          mioCoeffCl(jl, ibin));   //  local buffer
        }
        if (std::abs(qcfIncMIOView(jn, jl)) > 0.0) {
          qcfIncBinVec[ibin].push_back(qcfIncView(jn, jl));  //  local buffer
          // the multiplicative mioCoeffCf needs to be removed from qcfIncMIO
          // as this is included in cfeff.
          // note mioCoeffCf(jl, ibin) must be non-zero if inside this if-block
          qcfIncMIOBinVec[ibin].push_back(qcfIncMIOView(jn, jl) /
                                          mioCoeffCf(jl, ibin));  //  local buffer
        }
      }
    }

    // At model level jl, gather regression data points
    // and calculate linear regression for each rh bin
    for (std::size_t ibin = 0; ibin < mo::constants::mioBins; ibin++) {
      eckit::mpi::Buffer<double> buffer_qclIncBinVec(nb_mpi_ranks);  //  global buffer
      eckit::mpi::Buffer<double> buffer_qclIncMIOBinVec(nb_mpi_ranks);  //  global buffer
      eckit::mpi::Buffer<double> buffer_qcfIncBinVec(nb_mpi_ranks);  //  global buffer
      eckit::mpi::Buffer<double> buffer_qcfIncMIOBinVec(nb_mpi_ranks);  //  global buffer

      // MPI stuff
      oops::Log::info() << "local size qcl: " << qclIncBinVec[ibin].size()
                         << " local size qcf: " << qcfIncBinVec[ibin].size()
                         << " ranks: " << nb_mpi_ranks << std::endl;
      innerGeometryData_.comm().allGatherv(qclIncBinVec[ibin].begin(), qclIncBinVec[ibin].end(),
                                           buffer_qclIncBinVec);
      innerGeometryData_.comm().allGatherv(qclIncMIOBinVec[ibin].begin(),
                                           qclIncMIOBinVec[ibin].end(), buffer_qclIncMIOBinVec);
      innerGeometryData_.comm().allGatherv(qcfIncBinVec[ibin].begin(),
                                           qcfIncBinVec[ibin].end(), buffer_qcfIncBinVec);
      innerGeometryData_.comm().allGatherv(qcfIncMIOBinVec[ibin].begin(),
                                           qcfIncMIOBinVec[ibin].end(), buffer_qcfIncMIOBinVec);
      oops::Log::info() << "global size qcl: " << buffer_qclIncBinVec.buffer.size()
                         << " global size qcf: " << buffer_qcfIncBinVec.buffer.size()
                         << std::endl;

      numQclIncArr[jl][ibin] = buffer_qclIncBinVec.buffer.size();
      if (numQclIncArr[jl][ibin] > 1) {
        qclIncMIOLevBinRegrCoefArr[jl][ibin] = linregrcoeff(buffer_qclIncMIOBinVec.buffer,
                                                            buffer_qclIncBinVec.buffer);
      } else {
        qclIncMIOLevBinRegrCoefArr[jl][ibin] = msvald;  // RMDI
      }
      oops::Log::info() << "[qcl] jl ibin num linregrcoeff: " << jl << " "
                         << ibin << " " << numQclIncArr[jl][ibin] << " "
                         << qclIncMIOLevBinRegrCoefArr[jl][ibin] << std::endl;
      numQcfIncArr[jl][ibin] = buffer_qcfIncBinVec.buffer.size();
      if (numQcfIncArr[jl][ibin] > 1) {
        qcfIncMIOLevBinRegrCoefArr[jl][ibin] = linregrcoeff(buffer_qcfIncMIOBinVec.buffer,
                                                            buffer_qcfIncBinVec.buffer);
      } else {
        qcfIncMIOLevBinRegrCoefArr[jl][ibin] = msvald;  // RMDI
      }
      oops::Log::info() << "[qcf] jl ibin num linregrcoeff: " << jl << " "
                         << ibin << " " << numQcfIncArr[jl][ibin] << " "
                         << qcfIncMIOLevBinRegrCoefArr[jl][ibin] << std::endl;
    }
  }

  const std::size_t root(0);

  if (oops::mpi::world().rank() == root) {
    // remove missing value from coefficients with choice of values
    // and set output file
    const auto & calibparams = blockparams_.calibrationParams.value();
    enum class FillVal{zero, one, median};
    auto assign_fillval = [](std::string valstr){
      if (valstr == std::string("zero")) {
        return FillVal::zero;
      } else if (valstr == std::string("one")) {
        return FillVal::one;
      } else if (valstr == std::string("median")) {
        return FillVal::median;
      } else {
        throw eckit::UserError(
                       "MIO coefficient filling value can only be zero, one or median!", Here());
      }
    };

    // calibration parameters must be provided
    ASSERT(calibparams != boost::none);
    std::string mio_calib_output_file;
    const auto fillvalstr = calibparams.value().getString("coefficient filling value", "median");
    const auto fillval = assign_fillval(fillvalstr);
    oops::Log::trace() << "MIO coeff filling value: " << fillvalstr << std::endl;
    if (calibparams.value().has("output file")) {
      mio_calib_output_file = calibparams.value().getString("output file");
    } else {
      throw eckit::BadParameter("calibration output file must be specified");
    }

    std::vector<double> qclIncCoefVals;
    for (std::size_t jl = 0; jl < mo::constants::mioLevs; ++jl) {
      for (std::size_t ibin = 0; ibin < mo::constants::mioBins; ibin++) {
        if (qclIncMIOLevBinRegrCoefArr[jl][ibin] != msvald) {
          qclIncCoefVals.push_back(qclIncMIOLevBinRegrCoefArr[jl][ibin]);
        }
      }
    }
    const auto qclMedianCoeff = calcMedian(qclIncCoefVals);
    oops::Log::info() << "qcl median coeff: " << qclMedianCoeff << std::endl;

    std::vector<double> qcfIncCoefVals;
    for (std::size_t jl = 0; jl < mo::constants::mioLevs; ++jl) {
      for (std::size_t ibin = 0; ibin < mo::constants::mioBins; ibin++) {
        if (qcfIncMIOLevBinRegrCoefArr[jl][ibin] != msvald) {
          qcfIncCoefVals.push_back(qcfIncMIOLevBinRegrCoefArr[jl][ibin]);
        }
      }
    }
    const auto qcfMedianCoeff = calcMedian(qcfIncCoefVals);
    oops::Log::info() << "qcl median coeff: " << qcfMedianCoeff << std::endl;

    for (std::size_t jl = 0; jl < mo::constants::mioLevs; ++jl) {
      for (std::size_t ibin = 0; ibin < mo::constants::mioBins; ibin++) {
        if (qclIncMIOLevBinRegrCoefArr[jl][ibin] == msvald) {
          switch (fillval) {
          case FillVal::zero:
            qclIncMIOLevBinRegrCoefArr[jl][ibin] = 0.0;
            break;
          case FillVal::one:
            qclIncMIOLevBinRegrCoefArr[jl][ibin] = 1.0;
            break;
          case FillVal::median:
            qclIncMIOLevBinRegrCoefArr[jl][ibin] = qclMedianCoeff;
            break;
          }
        }
        if (qcfIncMIOLevBinRegrCoefArr[jl][ibin] == msvald) {
          switch (fillval) {
          case FillVal::zero:
            qcfIncMIOLevBinRegrCoefArr[jl][ibin] = 0.0;
            break;
          case FillVal::one:
            qcfIncMIOLevBinRegrCoefArr[jl][ibin] = 1.0;
            break;
          case FillVal::median:
            qcfIncMIOLevBinRegrCoefArr[jl][ibin] = qcfMedianCoeff;
            break;
          }
        }
      }
    }

    // write netcdf array
    writeOutputMIOToNetcdf(qclIncMIOLevBinRegrCoefArr,
                           qcfIncMIOLevBinRegrCoefArr,
                           numQclIncArr,
                           numQcfIncArr,
                           mio_calib_output_file);
  }

  oops::Log::trace() << classname() << "::directCalibration done" << std::endl;
}

// -----------------------------------------------------------------------------

void MoistIncrOp::print(std::ostream & os) const {
  os << classname();
}

// -----------------------------------------------------------------------------

}  // namespace vader
}  // namespace saber
