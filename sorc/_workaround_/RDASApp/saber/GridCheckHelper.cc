/*
 * (C) Copyright 2025 UCAR
 *
 * This software is licensed under the terms of the Apache Licence Version 2.0
 * which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
 */

#include "saber/gsi/utils/GridCheckHelper.h"

#include "atlas/array.h"
#include "atlas/functionspace.h"

#include "eckit/exception/Exceptions.h"


namespace saber::gsi {

std::vector<double> functionspaceToGridChecks(const atlas::FunctionSpace & fspace) {
  std::vector<double> gridChecks{};
  const atlas::functionspace::StructuredColumns sc(fspace);
  if (sc) {
    const int jb = sc.j_begin();
    const int je = sc.j_end();
    const int ib = sc.i_begin(jb);
    const int ie = sc.i_end(jb);
    if ((ib != sc.i_begin(je - 1)) || (ie != sc.i_end(je - 1))) {
      throw eckit::Exception(
        "The FunctionSpace passed to functionspaceToGridChecks does not have a regular "
        "checkerboard partition, i.e., i_begin or i_end are not constant with j.");
    }
    const int ny = je - jb;  // je is one-past-the-end so no need to add +1 to count
    const int nx = ie - ib;  // ie is one-past-the-end so no need to add +1 to count
    gridChecks.resize(2 + ny + nx);
    gridChecks[0] = static_cast<double>(nx);
    gridChecks[1] = static_cast<double>(ny);
    auto lonlatView = atlas::array::make_view<double, 2>(sc.lonlat());
    for (int i = ib; i < ie; ++i) {
      const int index = sc.index(i, jb);
      gridChecks[2 + (i - ib)] = lonlatView(index, 0);
    }
    for (int j = jb; j < je; ++j) {
      const int index = sc.index(ie-1, j);
      gridChecks[2 + nx + (j - jb)] = lonlatView(index, 1);
    }
  } else {
    throw eckit::Exception(
      "The FunctionSpace passed to functionspaceToGridChecks is not StructuredColumns");
  }
  return gridChecks;
}

}  // namespace saber::gsi
