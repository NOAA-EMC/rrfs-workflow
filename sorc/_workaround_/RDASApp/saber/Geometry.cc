/*
 * (C) Copyright 2022 UCAR.
 *
 * This software is licensed under the terms of the Apache Licence Version 2.0
 * which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
 */

#include "saber/interpolation/Geometry.h"

#include <cmath>
#include <sstream>

#include "atlas/field.h"
#include "atlas/functionspace.h"
#include "atlas/grid.h"
#include "atlas/meshgenerator.h"
#include "atlas/util/Geometry.h"
#include "atlas/util/KDTree.h"
#include "atlas/util/Point.h"

#include "atlas/grid/detail/spacing/gaussian/Latitudes.h"

#include "eckit/exception/Exceptions.h"

#include "oops/util/FunctionSpaceHelpers.h"
#include "oops/util/Logger.h"


namespace {
const std::string GsiGridKey = "custom grid matching gsi";  // NOLINT(runtime/string)
const std::string GsiPartitionerKey = "custom partitioner matching gsi";  // NOLINT(runtime/string)
}  // namespace

namespace saber {
namespace interpolation {

namespace detail {
std::vector<int> computeS2NCheckerboardPartition(const atlas::RegularGrid & rg,
                                                 const int ntasks, const int nbands) {
  // Number of MPI tasks (=partitions) per band
  if (ntasks % nbands != 0) {
    atlas::throw_Exception("number of bands doesn't divide number of tasks", Here());
  }

  const auto map_1d_point_to_1d_partition = [&](const int npoints,
                                                const int npartitions) -> std::vector<int> {
    const int npart = npoints / npartitions;
    const int nremain = npoints % npartitions;
    std::vector<int> mapping(npoints);
    int i = 0;
    for (int p = 0; p < npartitions; ++p) {
      const int npoints_this_part = npart + (p < nremain ? 1 : 0);
      for (int count = 0; count < npoints_this_part; ++count) {
        mapping[i] = p;
        ++i;
      }
    }
    ASSERT(i == npoints);
    return mapping;
  };

  const int nx = rg.nx();
  const int ny = rg.ny();
  const size_t parts_per_band = ntasks / nbands;

  const auto band = map_1d_point_to_1d_partition(ny, nbands);
  const auto part_in_band = map_1d_point_to_1d_partition(nx, parts_per_band);

  std::vector<int> partition(rg.size());
  for (atlas::idx_t j = 0; j < ny; ++j) {
    for (atlas::idx_t i = 0; i < nx; ++i) {
      partition[rg.index(i, j)] = band[j] * parts_per_band + part_in_band[i];
    }
  }
  return partition;
}

constexpr double deg2rad(double deg) { return deg * M_PI / 180.0; }
constexpr double rad2deg(double rad) { return rad * 180.0 / M_PI; }

void setupGsiMatchingGrid(const eckit::Configuration & config,
                          const eckit::mpi::Comm & comm,
                          atlas::Grid & grid,
                          atlas::FunctionSpace & functionSpace,
                          atlas::FieldSet & fieldSet) {
  const std::string grid_type = config.getString(GsiGridKey + ".type");
  ASSERT(grid_type == "gaussian" || grid_type == "latlon" || grid_type == "rotated_lonlat");
  const int nlats = config.getInt(GsiGridKey + ".lats");  // pole to pole
  const int nlons = config.getInt(GsiGridKey + ".lons");
  const double lat_start = config.has(GsiGridKey + ".lat_start") ? config.getDouble(GsiGridKey + ".lat_start") : 0.0;
  const double lat_end = config.has(GsiGridKey + ".lat_end") ? config.getDouble(GsiGridKey + ".lat_end") : 0.0;
  const double lon_start = config.has(GsiGridKey + ".lon_start") ? config.getDouble(GsiGridKey + ".lon_start") : 0.0;
  const double lon_end = config.has(GsiGridKey + ".lon_end") ? config.getDouble(GsiGridKey + ".lon_end") : 0.0;
  const double north_pole_lat = config.has(GsiGridKey + ".north_pole_lat") ? config.getDouble(GsiGridKey + ".north_pole_lat") : 0.0;
  const double north_pole_lon = config.has(GsiGridKey + ".north_pole_lon") ? config.getDouble(GsiGridKey + ".north_pole_lon") : 0.0;


  const auto gsi_gaussian_points = [](const int N) -> std::vector<double> {
    ASSERT(N % 2 == 0);  // code below would need verification, probably fixing, in odd case
    std::vector<double> result(N);
    // north-to-south order, following atlas's default
    result[0] = 90.0;
    atlas::grid::spacing::gaussian::gaussian_latitudes_npole_spole((N-2)/2, result.data()+1);
    result[N-1] = -90.0;
    // flip sign to obtain south-to-north order, following GSI's default
    for (auto & r : result) {
      r *= -1.0;
    }
    return result;
  };

  const auto build_xspace_config = [&](const std::string & grid_type) -> eckit::LocalConfiguration {
    eckit::LocalConfiguration lc{};
    if (grid_type == "rotated_lonlat") {
      lc.set("type", "linear");
      lc.set("N", nlons);
      lc.set("start", lon_start);
      lc.set("end", lon_end);
    } else {
      lc.set("type", "linear");
      lc.set("N", nlons);
      lc.set("interval", std::vector<double>{{0.0, 360.0}});
      lc.set("endpoint", false);
    }
    return lc;
  };

  const auto build_yspace_config = [&](const std::string & grid_type) -> eckit::LocalConfiguration {
    eckit::LocalConfiguration lc{};
    if (grid_type == "rotated_lonlat") {
      lc.set("type", "linear");
      lc.set("N", nlats);
      lc.set("start", lat_start);
      lc.set("end", lat_end);
    } else if (grid_type == "gaussian") {
      lc.set("type", "custom");
      lc.set("N", nlats);
      lc.set("values", gsi_gaussian_points(nlats));
    } else {
      lc.set("type", "linear");
      lc.set("N", nlats);
      lc.set("interval", std::vector<double>{{-90.0, 90.0}});
    }
    return lc;
  };

  const auto build_projection_config = [&](const std::string & grid_type) -> eckit::LocalConfiguration {
    eckit::LocalConfiguration lc{};
    lc.set("type", "rotated_lonlat");
    lc.set("north_pole", std::vector<double>{{north_pole_lon, north_pole_lat}});
    return lc;
  };

  eckit::LocalConfiguration testconfig{};
  testconfig.set("type", "structured");
  testconfig.set("xspace", build_xspace_config(grid_type));
  testconfig.set("yspace", build_yspace_config(grid_type));
  if (grid_type == "rotated_lonlat") testconfig.set("projection", build_projection_config(grid_type));
  grid = atlas::Grid{testconfig};

  const atlas::RegularGrid rg{grid};
  ASSERT(rg);

  const int ntasks = comm.size();
  const int nbands = config.getInt(GsiPartitionerKey + ".bands");
  ASSERT(nbands >= 1 && nbands <= ntasks);
  std::vector<int> partition = computeS2NCheckerboardPartition(rg, ntasks, nbands);

  const atlas::grid::Distribution distribution(ntasks, partition.size(), partition.data());
  const unsigned halo = config.getUnsigned("halo", 1);
  functionSpace = atlas::functionspace::StructuredColumns(grid, distribution,
                                                          atlas::option::halo(halo));

  // Get rotated_lonlat on the Earth coordinate
  if (grid_type == "rotated_lonlat") {
    atlas::Field lonlatField = functionSpace.lonlat();
    auto lonlatView = atlas::array::make_view<double, 2>(lonlatField);
    for (int j = 0; j < lonlatView.shape(0); ++j) {
      double rlon = lonlatView(j, 0);
      double rlat = lonlatView(j, 1);
      double rlon0 = north_pole_lon - 180.0;
      double rlat0 = north_pole_lat - 90.0;

      double xtt = std::cos(deg2rad(rlat)) * std::cos(deg2rad(rlon));
      double ytt = std::cos(deg2rad(rlat)) * std::sin(deg2rad(rlon));
      double ztt = std::sin(deg2rad(rlat));

      double  xt = xtt*std::cos(deg2rad(rlat0)) - ztt*std::sin(deg2rad(rlat0));
      double  yt = ytt;
      double  zt = xtt*std::sin(deg2rad(rlat0)) + ztt*std::cos(deg2rad(rlat0));

      double   x = xt*std::cos(deg2rad(rlon0)) - yt*std::sin(deg2rad(rlon0));
      double   y = xt*std::sin(deg2rad(rlon0)) + yt*std::cos(deg2rad(rlon0));
      double   z = zt;

      lonlatView(j, 0) = rad2deg(std::atan2(y,x));
      lonlatView(j, 1) = rad2deg(std::asin(z));
    }
    lonlatField.set_dirty();
  }

  // Using atlas::mpi::Scope in the call to atlas::functionspace::StructuredColumns
  // may have reverted the default communicator to the world communicator.
  // We set back the default communicator to `comm` to fix this.
  eckit::mpi::setCommDefault(comm.name().c_str());

  fieldSet.clear();  // return empty
}
}  // namespace detail

// -----------------------------------------------------------------------------

Geometry::Geometry(const eckit::Configuration & config,
                   const eckit::mpi::Comm & comm)
  : comm_(comm), halo_(1)
{
  if (config.has(GsiGridKey) != config.has(GsiPartitionerKey)) {
    throw eckit::BadParameter("Must specify GSI-matching grid AND partitioner, OR neither");
  }

  if (config.has(GsiGridKey)) {
    // Here we've requested a particular grid and MPI partitioner setup. This can be used to
    // recreate the GSI grid and MPI partition, though not the GSI grid point ordering on each MPI
    // task. This is useful for the GSI saber block, but could be moved into the generic OOPS
    // utilities if desired elsewhere. We do this with custom code because GSI orders its grid
    // points (and MPI partitions) from south-to-north whereas atlas orders its grid points
    // (and partitions) from north-to-south.
    detail::setupGsiMatchingGrid(config, comm_, grid_, functionSpace_, fieldSet_);
  } else {
    // Generic case
    atlas::Mesh mesh;
    util::setupFunctionSpace(comm_, config, grid_, partitioner_, mesh, functionSpace_, fieldSet_);
  }

  if (config.has("halo")) {
    halo_ = config.getUnsigned("halo");
  }

  // Print summary
  this->print(oops::Log::info());
}

// -----------------------------------------------------------------------------

void Geometry::print(std::ostream & os) const {
  std::string prefix;
  if (os.rdbuf() == oops::Log::info().rdbuf()) {
    prefix = "Info     : ";
  }
  os << prefix <<  "Interpolation geometry grid:" << std::endl;
  os << prefix << "- name: " << grid_.name() << std::endl;
  os << prefix << "- size: " << grid_.size() << std::endl;
  if (partitioner_) {
    os << prefix << "Partitioner:" << std::endl;
    os << prefix << "- type: " << partitioner_.type() << std::endl;
  }
  os << prefix << "Function space:" << std::endl;
  os << prefix << "- type: " << functionSpace_.type() << std::endl;
  os << prefix << "- halo: " << halo_ << std::endl;
}

// -----------------------------------------------------------------------------

}  // namespace interpolation
}  // namespace saber
