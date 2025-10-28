/*
 * (C) Copyright 2025, GSL
 *
 * This software is licensed under the terms of the Apache Licence Version 2.0
 * which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
 */

#ifndef UFO_OPERATORS_SFCCORRECTED_EVALSURFACEWIND_H_
#define UFO_OPERATORS_SFCCORRECTED_EVALSURFACEWIND_H_

#include <string>
#include <vector>

#include "ufo/operators/sfccorrected/SurfaceOperatorBase.h"

/// Forward declarations
namespace oops {
  class Variables;
}

namespace ioda {
  class ObsSpace;
}

namespace ufo {

class GeoVaLs;

class windEastward_GSL : public SurfaceOperatorBase {
 public:
  explicit windEastward_GSL(const std::string &, const Parameters_ &);

  virtual ~windEastward_GSL() {}

  void simobs(const ufo::GeoVaLs &, 
              const ioda::ObsSpace &, 
              std::vector<float> &) const override;
  void settraj() const override;
  void TL() const override;
  void AD() const override;
};

class windNorthward_GSL : public SurfaceOperatorBase {
 public:
  explicit windNorthward_GSL(const std::string &, const Parameters_ &);

  virtual ~windNorthward_GSL() {}

  void simobs(const ufo::GeoVaLs &, 
              const ioda::ObsSpace &, 
              std::vector<float> &) const override;
  void settraj() const override;
  void TL() const override;
  void AD() const override;
};

}  // namespace ufo

#endif  // UFO_OPERATORS_SFCCORRECTED_EVALSURFACEWIND_H_
