/*
 * (C) Copyright 2024 UCAR
 *
 * This software is licensed under the terms of the Apache Licence Version 2.0
 * which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
 */

#ifndef UFO_OPERATORS_SFCCORRECTED_OBSSFCCORRECTED_INTERFACE_H_
#define UFO_OPERATORS_SFCCORRECTED_OBSSFCCORRECTED_INTERFACE_H_

#include "ufo/Fortran.h"

namespace eckit {
  class Configuration;
}

namespace ioda {
  class ObsSpace;
}

namespace oops {
  class Variables;
}

namespace ufo {

/// Interface to Fortran UFO sfccorrected routines

extern "C" {

// -----------------------------------------------------------------------------
//  SfcCorrected observation operator
// -----------------------------------------------------------------------------

  /// \param operatorVars
  ///   Variables to be simulated by this operator.
  /// \param operatorVarIndices
  ///   Indices of the variables from \p operatorVar in the list of all simulated
  ///   variables in the ObsSpace.
  /// \param numOperatorVarIndices
  ///   Size of the \p operatorVarIndices array (must be the same as the number of variables in
  ///   \p operatorVars).
  /// \param[out] requiredVars
  ///   GeoVaLs required for the simulation of the variables \p operatorVars.
  ///
  /// Example: if the list of simulated variables in the ObsSpace is
  /// [airTemperature, windNorthward, windEastward] and \p operatorVars is
  /// [windNorthward, windEastward], then \p operatorVarIndices should be set to [1, 2].

// -----------------------------------------------------------------------------

  void ufo_sfccorrected_setup_f90(F90hop &, const eckit::Configuration &,
                                   const oops::ObsVariables&operatorVars,
                                   const int *operatorVarIndices, const int numOperatorVarIndices,
                                   oops::Variables &requiredVars);
  void ufo_sfccorrected_delete_f90(F90hop &);
  void ufo_sfccorrected_simobs_f90(const F90hop &, const F90goms &, const ioda::ObsSpace &,
                               const int &, const int &, double &);

// -----------------------------------------------------------------------------

}  // extern C

}  // namespace ufo
#endif  // UFO_OPERATORS_SFCCORRECTED_OBSSFCCORRECTED_INTERFACE_H_
