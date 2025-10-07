/*
 * (C) Copyright 2025, GSL
 *
 * This software is licensed under the terms of the Apache Licence Version 2.0
 * which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
 */

#ifndef UFO_OPERATORS_SFCCORRECTED_EVALSURFACEHUMIDITY_H_
#define UFO_OPERATORS_SFCCORRECTED_EVALSURFACEHUMIDITY_H_

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

class specificHumidity_GSL : public SurfaceOperatorBase {
 public:
  explicit specificHumidity_GSL(const std::string &,
                                  const Parameters_ &);
  virtual ~specificHumidity_GSL() {}

  void simobs(const ufo::GeoVaLs &,
              const ioda::ObsSpace &,
              std::vector<float> &) const override;
  void settraj() const override;
  void TL() const override;
  void AD() const override;
};

}  // namespace ufo

#endif  // UFO_OPERATORS_SFCCORRECTED_EVALSURFACEHUMIDITY_H_
