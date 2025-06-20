/*
 * (C) Crown Copyright 2024, Met Office
 *
 * This software is licensed under the terms of the Apache Licence Version 2.0
 * which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
 */

#ifndef UFO_OPERATORS_SFCCORRECTED_EVALSURFACETEMPERATURE_H_
#define UFO_OPERATORS_SFCCORRECTED_EVALSURFACETEMPERATURE_H_

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

class airTemperature_WRFDA : public SurfaceOperatorBase {
 public:
  explicit airTemperature_WRFDA(const std::string &,
                                    const Parameters_ &);
  virtual ~airTemperature_WRFDA() {}

  void simobs(const ufo::GeoVaLs &,
              const ioda::ObsSpace &,
              std::vector<float> &) const override;
  void settraj() const override;
  void TL() const override;
  void AD() const override;
};

class airTemperature_UKMO : public SurfaceOperatorBase {
 public:
  explicit airTemperature_UKMO(const std::string &,
                                   const Parameters_ &);
  virtual ~airTemperature_UKMO() {}

  void simobs(const ufo::GeoVaLs &,
              const ioda::ObsSpace &,
              std::vector<float> &) const override;
  void settraj() const override;
  void TL() const override;
  void AD() const override;
};

class airTemperature_GSL : public SurfaceOperatorBase {
 public:
  explicit airTemperature_GSL(const std::string &,
                                  const Parameters_ &);
  virtual ~airTemperature_GSL() {}

  void simobs(const ufo::GeoVaLs &,
              const ioda::ObsSpace &,
              std::vector<float> &) const override;
  void settraj() const override;
  void TL() const override;
  void AD() const override;
};

}  // namespace ufo

#endif  // UFO_OPERATORS_SFCCORRECTED_EVALSURFACETEMPERATURE_H_
