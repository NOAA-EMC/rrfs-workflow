/*
 * (C) Crown Copyright 2023-2024 Met Office
 *
 * This software is licensed under the terms of the Apache Licence Version 2.0
 * which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
 */

#pragma once

#include <algorithm>
#include <map>
#include <memory>
#include <sstream>
#include <string>
#include <vector>

#include "eckit/config/Configuration.h"
#include "eckit/config/LocalConfiguration.h"
#include "eckit/exception/Exceptions.h"

#include "oops/base/FieldSets.h"
#include "oops/base/Geometry.h"
#include "oops/base/Increment.h"
#include "oops/base/instantiateCovarFactory.h"
#include "oops/base/ModelSpaceCovarianceBase.h"
#include "oops/base/State.h"
#include "oops/base/Variables.h"
#include "oops/mpi/mpi.h"
#include "oops/runs/Application.h"
#include "oops/util/ConfigFunctions.h"
#include "oops/util/DateTime.h"
#include "oops/util/FieldSetHelpers.h"
#include "oops/util/Logger.h"
#include "oops/util/parameters/OptionalParameter.h"
#include "oops/util/parameters/Parameter.h"
#include "oops/util/parameters/Parameters.h"
#include "oops/util/parameters/RequiredParameter.h"

#include "saber/blocks/SaberParametricBlockChain.h"
#include "saber/oops/ErrorCovarianceParameters.h"
#include "saber/oops/Utilities.h"

namespace saber {

/// \brief 1) It first uses a vector of strings to successively dive into
///           the appropriate subconfiguration from a top level configuration
///           object.
///        2) It then takes this subconfiguration and reorders the keys
///           into a fixed order.
///        3) It then takes the values of each of the sorted keys and
///           concatenates them into a single string
///        4) All instances of the string "stringPattern" within the LocalConfiguration
///           conf are replaced by the concatenated string. The value "stringPattern"
///           is extracted from the configuration using the "patternNameKey".
void setConcatenatedString(const eckit::Configuration & fullConf,
                           const std::vector<std::string> & keyTags,
                           const std::string & patternNameKey,
                           eckit::LocalConfiguration & conf) {
  eckit::LocalConfiguration subconf(fullConf);
  for (const std::string& s : keyTags) {
    subconf = subconf.getSubConfiguration(s);
  }

  std::string vals("");
  std::vector<std::string> sortedKeys(subconf.keys());
  std::sort(sortedKeys.begin(), sortedKeys.end(),
            [](const std::string a, const std::string b) {return a > b; });

  for (const std::string& s : sortedKeys) {
    std::string val;
    subconf.get(s, val);
    vals.append(val);
  }

  if (conf.has(patternNameKey)) {
    const std::string stringPattern = conf.getString(patternNameKey);
    util::seekAndReplace(conf, stringPattern, vals);
  }
}

/// \brief Parameters for filtering a single perturbation
template <typename MODEL> class FilterParameters :
  public oops::Parameters {
  OOPS_CONCRETE_PARAMETERS(FilterParameters, oops::Parameters)

 public:
  typedef ErrorCovarianceParameters<MODEL>           ErrorCovarianceParameters_;
  /// Note that the parameters here are not actually used in the code
  /// They are here to express the intent of these variables.
  /// Later on in the code we use eckit::LocalConfiguration and check whether
  /// each key is in the configuration - if it is we use its value, otherwise
  /// it is set to "false".
  oops::Parameter<bool> residualFromFilter{
    "use residual from filter", false, this};
  oops::Parameter<bool> residualIncrementFromOtherBands{
    "residual increment from previous bands", false, this};

  // This will give the parameters associated with an ErrorCovariance model
  // and can be used to provide a filtering operation.
  oops::OptionalParameter<ErrorCovarianceParameters_> filter{"filter", this};
};

// -----------------------------------------------------------------------------

/// \brief Write parameters for single filtered perturbation
template <typename MODEL> class OutputWriteParameters :
  public oops::Parameters {
  OOPS_CONCRETE_PARAMETERS(OutputWriteParameters, oops::Parameters)

 public:
  typedef ErrorCovarianceParameters<MODEL>                   ErrorCovarianceParameters_;

  // This is there to get ErrorCovarianceParameters and in particular
  // saber blocks that can be used for diagnostic purposes.
  oops::OptionalParameter<ErrorCovarianceParameters_> diagnosticOnlyBlock{
    "diagnostic only block", this};

  /// Write parameters using generic oops::util::writeFieldSet writer
  oops::OptionalParameter<eckit::LocalConfiguration>
    genericWrite{"generic write", this};

  /// Write parameters using model increment writer
  oops::OptionalParameter<eckit::LocalConfiguration>
    modelWrite{"model write", this};
};

// -----------------------------------------------------------------------------

template <typename MODEL> class BandParameters :
  public oops::Parameters {
  OOPS_CONCRETE_PARAMETERS(BandParameters, oops::Parameters)

 public:
  typedef FilterParameters<MODEL>                   FilterParameters_;
  typedef OutputWriteParameters<MODEL>              outputParameters_;

  oops::RequiredParameter<FilterParameters_> band{"band", this};
  oops::OptionalParameter<outputParameters_> output{"output", this};
};

// -----------------------------------------------------------------------------

/// \brief Top-level options taken by the ProcessPerts application.
template <typename MODEL> class ProcessPertsParameters :
  public oops::Parameters {
  OOPS_CONCRETE_PARAMETERS(ProcessPertsParameters, oops::Parameters)

 public:
  typedef BandParameters<MODEL>                          BandParameters_;

  /// Geometry parameters.
  oops::RequiredParameter<eckit::LocalConfiguration> geometry{"geometry", this};

  /// Background parameters.
  oops::RequiredParameter<eckit::LocalConfiguration> background{"background", this};

  oops::RequiredParameter<oops::Variables> inputVariables{"input variables", this};

  oops::RequiredParameter<std::vector<BandParameters_>> bands{"bands", this};

  /// Where to read input ensemble: From states or perturbations
  oops::OptionalParameter<eckit::LocalConfiguration> ensemble{"ensemble", this};
  oops::OptionalParameter<eckit::LocalConfiguration> ensemblePert{"ensemble pert", this};
};

// -----------------------------------------------------------------------------

template <typename MODEL> class ProcessPerts : public oops::Application {
  typedef oops::ModelSpaceCovarianceBase<MODEL>             CovarianceBase_;
  typedef oops::CovarianceFactory<MODEL>                    CovarianceFactory_;
  typedef oops::Geometry<MODEL>                             Geometry_;
  typedef oops::Increment<MODEL>                            Increment_;
  typedef oops::State<MODEL>                                State_;
  typedef oops::State4D<MODEL>                              State4D_;
  typedef ProcessPertsParameters<MODEL>                     ProcessPertsParameters_;

 public:
// -----------------------------------------------------------------------------
  explicit ProcessPerts(const eckit::mpi::Comm & comm = eckit::mpi::comm()) :
    Application(comm) {
    instantiateCovarFactory<MODEL>();
  }
// -----------------------------------------------------------------------------
  virtual ~ProcessPerts() {}
// -----------------------------------------------------------------------------

  int execute(const eckit::Configuration & fullConfig) const override {
    // Deserialize parameters
    ProcessPertsParameters_ params;
    params.deserialize(fullConfig);

    // Define space and time communicators
    const eckit::mpi::Comm * commSpace = &this->getComm();
    const eckit::mpi::Comm * commTime = &oops::mpi::myself();

    // Setup geometry
    const Geometry_ geom(params.geometry, *commSpace, *commTime);

    // Setup background
    const State4D_ xx(geom, params.background, *commTime);
    oops::FieldSet4D fsetXb(xx);
    oops::FieldSet4D fsetFg(xx);

    // Setup time
    const util::DateTime time = xx[0].validTime();

    oops::Variables incVars = params.inputVariables;

    // Initialize outer variables
    const std::vector<std::size_t> vlevs = geom.variableSizes(incVars);
    for (std::size_t i = 0; i < vlevs.size() ; ++i) {
      incVars[i].setLevels(vlevs[i]);
    }

    std::vector<util::DateTime> dates;
    std::vector<int> ensmems;
    oops::FieldSets fsetEns(dates, oops::mpi::myself(), ensmems, oops::mpi::myself());
    oops::FieldSets dualResFsetEns(dates, oops::mpi::myself(),
                                            ensmems, oops::mpi::myself());
    eckit::LocalConfiguration covarConf;
    covarConf.set("iterative ensemble loading", false);
    covarConf.set("inverse test", false);
    covarConf.set("adjoint test", false);
    covarConf.set("square-root test", false);
    covarConf.set("covariance model", "SABER");
    covarConf.set("time covariance", "");

    // Yaml validation
    // TODO(Mayeul): Move this do an override of deserialize
    if (((params.ensemble.value() == boost::none) &&
        (params.ensemblePert.value() == boost::none)) ||
        ((params.ensemble.value() != boost::none) &&
        (params.ensemblePert.value() != boost::none)))
    {
      throw eckit::UserError(
       "Require either input states or input perturbations to be set in yaml",
       Here());
    }

    // Read input ensemble
    const bool iterativeEnsembleLoading = false;
    eckit::LocalConfiguration ensembleConf(fullConfig);
    eckit::LocalConfiguration outputEnsConf;
    oops::FieldSets fsetEnsI = readEnsemble<MODEL>(geom,
                                                   incVars,
                                                   xx, xx,
                                                   ensembleConf,
                                                   iterativeEnsembleLoading,
                                                   outputEnsConf);
    int nincrements = fsetEnsI.ens_size();

    const std::size_t nbands = params.bands.value().size();
    const std::vector<eckit::LocalConfiguration> bandsConfs
      = fullConfig.getSubConfigurations("bands");

    // need to create a vectors of saber block chains to use later
    std::map<std::size_t, eckit::LocalConfiguration> diagBlockConfs;
    std::map<std::size_t, eckit::LocalConfiguration> filterCovBlockConfs;
    std::map<std::size_t, eckit::LocalConfiguration> genericWriteConfs;
    std::map<std::size_t, eckit::LocalConfiguration> modelWriteConfs;
    std::vector<bool> calcResidualIncrement;
    std::vector<bool> calcComplement;

    std::size_t b(0);
    for (const auto & bandConf : bandsConfs) {
      eckit::LocalConfiguration bConf = bandConf.getSubConfiguration("band");
      if (bConf.has("filter")) {
        eckit::LocalConfiguration fConf = bConf.getSubConfiguration("filter");
        filterCovBlockConfs[b] = fConf;
      }
      calcResidualIncrement.push_back(
        bConf.getBool("residual increment from previous bands", false) );
      calcComplement.push_back(
        bConf.getBool("use residual from filter", false) );

      if (bandConf.has("output")) {
        eckit::LocalConfiguration oConf = bandConf.getSubConfiguration("output");
        if (oConf.has("diagnostic only block")) {
          eckit::LocalConfiguration dConf = oConf.getSubConfiguration("diagnostic only block");
          diagBlockConfs[b] = dConf;
        }
        if (oConf.has("generic write")) {
          eckit::LocalConfiguration gConf = oConf.getSubConfiguration("generic write");
          genericWriteConfs[b] = gConf;
        }
        if (oConf.has("model write")) {
          eckit::LocalConfiguration mConf = oConf.getSubConfiguration("model write");
          modelWriteConfs[b] = mConf;
        }
      }
      b++;
    }

    std::vector<std::unique_ptr<SaberParametricBlockChain>> saberFilterBlocks;
    for (const auto & [key, value] : filterCovBlockConfs) {
      saberFilterBlocks.push_back(
        std::make_unique<SaberParametricBlockChain>(geom, geom,
                                                    incVars, fsetXb, fsetFg,
                                                    fsetEns, dualResFsetEns,
                                                    covarConf,
                                                    value));
    }

    std::vector<std::unique_ptr<SaberParametricBlockChain>> saberDiagnosticBlocks;
    for (const auto & [key, value] : diagBlockConfs) {
      saberDiagnosticBlocks.push_back(
        std::make_unique<SaberParametricBlockChain>(geom, geom,
                                                    incVars, fsetXb, fsetFg,
                                                    fsetEns, dualResFsetEns,
                                                    covarConf,
                                                    value));
    }

    //  Loop over perturbations
    for (int jm = 0; jm < nincrements; ++jm) {
      oops::FieldSet3D fsetI(fsetEnsI[jm]);
      oops::FieldSet4D fset4dDxI(fsetI);

      oops::Log::test() << "Norm of perturbation: "
                        << "member " << jm+1
                        << ": " << fsetI.norm(fsetI.variables()) << std::endl;

      oops::FieldSet3D fsetSum(fsetI.validTime(), fsetI.commGeom());
      fsetSum.allocateOnly(fsetI.fieldSet());
      fsetSum.zero();
      oops::FieldSet4D fset4dDxSum(fsetSum);

      for (std::size_t b = 0; b < nbands; ++b) {
        //  Copy perturbation
        oops::FieldSet3D fset(fsetI.validTime(), fsetI.commGeom());
        fset.deepCopy(fsetI.fieldSet());

        oops::FieldSet4D fset4dDx(fset);

        // Apply filter blocks
        if (auto it{filterCovBlockConfs.find(b)}; it != std::end(filterCovBlockConfs)) {
          const std::size_t idx = std::distance(std::begin(filterCovBlockConfs), it);
          saberFilterBlocks[idx]->filter(fset4dDx);
          if (calcComplement[b]) {
            fset4dDx[0] -= fset4dDxI[0];
            fset4dDx[0] *= -1.0;
          }
        }

        // residual increment
        if (calcResidualIncrement[b]) {
          fset4dDx[0] -= fset4dDxSum[0];
        }

        fset4dDxSum += fset4dDx;

        oops::Log::test() << "Norm of band perturbation: "
                          << "member " << jm+1 << ": band " << b+1
                          << ": " << fset4dDx[0].norm(fset4dDx[0].variables())
                          << std::endl;


        // Apply diagnostic blocks
        if (auto it{diagBlockConfs.find(b)}; it != std::end(diagBlockConfs)) {
          const std::size_t idx = std::distance(std::begin(diagBlockConfs), it);
          saberDiagnosticBlocks[idx]->filter(fset4dDx);
        }

        if (auto it{genericWriteConfs.find(b)}; it != std::end(genericWriteConfs)) {
          eckit::LocalConfiguration gconf = it->second;
          util::setMember(gconf, jm+1);
          setConcatenatedString(fullConfig,
                                std::vector<std::string>{"geometry", "grid"},
                                "grid pattern",
                                gconf);
          util::writeFieldSet(geom.getComm(), gconf, fset4dDx[0].fieldSet());
        }

        if (auto it{modelWriteConfs.find(b)}; it != std::end(modelWriteConfs)) {
          eckit::LocalConfiguration mconf = it->second;

          // Should be on the model geometry!
          auto pert = Increment_(geom,
                                 fset4dDx[0].variables(),
                                 time);
          pert.zero();
          pert.fromFieldSet(fset4dDx[0].fieldSet());

          util::setMember(mconf, jm+1);
          pert.write(mconf);
        }
      }
    }

    return 0;
  }
// -----------------------------------------------------------------------------
 private:
  std::string appname() const override {
    return "oops::ProcessPerts<" + MODEL::name() + ">";
  }
};

}  // namespace saber
