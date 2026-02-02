/*
 * CC0 - No Copyright (Public Domain)
 * 
 * The person who associated a work with this deed has dedicated the work to the public domain by waiving all of his or her rights to the work worldwide under copyright law, including all related and neighboring rights, to the extent allowed by law.
 *
 * You can copy, modify, distribute and perform the work, even for commercial purposes, all without asking permission. See Other Information below.
 *
 * Other Information
 * In no way are the patent or trademark rights of any person affected by CC0, nor are the rights that other persons may have in the work or in how the work is used, such as publicity or privacy rights.
 *
 * The person who associated a work with this deed makes no warranties about the work, and disclaims liability for all uses of the work, to the fullest extent permitted by applicable law.
 *
 * When using or citing the work, you should not imply endorsement by the author or the affirmer.
 */

#include "ufo/filters/ObsPolygonCheck.h"

#include <iostream>
#include <sstream>
#include <string>
#include <vector>

#include <boost/geometry.hpp>
#include "ioda/ObsSpace.h"
#include "oops/util/Logger.h"

namespace ufo {

// -----------------------------------------------------------------------------

ObsPolygonCheck::ObsPolygonCheck(ioda::ObsSpace & obsdb, const Parameters_ & parameters,
                                 std::shared_ptr<ioda::ObsDataVector<int> > flags,
                                 std::shared_ptr<ioda::ObsDataVector<float> > obserr)
  : FilterBase(obsdb, parameters, flags, obserr), parameters_(parameters)
{
  oops::Log::trace() << "ObsPolygonCheck constructor" << std::endl;
}

// -----------------------------------------------------------------------------

ObsPolygonCheck::~ObsPolygonCheck() {
  oops::Log::trace() << "ObsPolygonCheck destructor" << std::endl;
}

// -----------------------------------------------------------------------------

void ObsPolygonCheck::applyFilter(const std::vector<bool> &apply,
                                  const Variables & filtervars,
                                  std::vector<std::vector<bool>> & flagged) const {
  oops::Log::trace() << "ObsPolygonCheck applyFilter start" << std::endl;

  namespace bg = boost::geometry;

  // point_t = a boost::geometry point as a longitude-latitude pair in degrees
  using point_t = bg::model::point<double, 2, bg::cs::geographic<bg::degree>>;

  // polygon_t = a closed polygon of those points
  using polygon_t = bg::model::polygon<point_t>;

  // Get from the parameters a point within the polygon.
  const point_t insidePoint(parameters_.inside_point_longitude.value(),
                            parameters_.inside_point_latitude.value());

  // Assemble a polygon from the list of longitudes and latitudes.
  polygon_t poly;
  const auto &vertex_latitudes = parameters_.vertex_latitudes.value();
  const auto &vertex_longitudes = parameters_.vertex_longitudes.value();
  const size_t nlon = vertex_longitudes.size();
  const size_t nlat = vertex_latitudes.size();
  if (nlon != nlat) {
    std::ostringstream what;
    what << "Mismatch between vertex longitude count (" << nlon
         << ") and vertex latitude count (" << nlat << ").";
    throw ObsPolygonLatLonSizeMismatch(what.str(), Here());
  }
  poly.outer().reserve(nlon);
  for (size_t i = 0; i < nlon; i++)
    poly.outer().emplace_back(vertex_longitudes[i], vertex_latitudes[i]);

  // Ask boost::geometry to correct common problems in the polygon definition.
  // As of boost 1.91, the only practical effect is to close open rings.
  // It will also correct the vertex ordering, but vertex ordering on a
  // sphere is ignored.
  bg::correct(poly);

  // Check for polygons that the boost::geometry library doesn't know how to handle.
  if (std::string reason; !bg::is_valid(poly, reason)) {
    std::ostringstream what;
    what << "ObsPolygonCheck: boost::geometry does not like your polygon (\"" << reason << "\")";
    throw ObsPolygonIsInvalid(what.str(), Here());
  }

  // Get the observation locations.
  std::vector <float> lats, lons;
  obsdb_.get_db("MetaData", "latitude", lats);
  obsdb_.get_db("MetaData", "longitude", lons);

  // Figure out which side is the inside by checking a point that is known to be inside.
  // As of version 1.91, boost::geometry ignores the clockwise vs. counterclockwise when
  // deciding which side of a polygon is the inside in spherical geometry. Hence,
  // we need this "inside point" to determine which side is the inside.
  const bool useThisSide = bg::within(insidePoint, poly);

  // Find all points that are on the opposite side from the "inside point"
  const size_t nlocs = obsdb_.nlocs();
  std::vector<bool> notInside(nlocs, true);
  size_t applyCount = 0;
  size_t insideCount = 0;
  for (size_t iloc = 0; iloc < nlocs; iloc++) {
    if (apply[iloc]) {
      applyCount++;
      const bool inside = useThisSide == bg::within(point_t(lons[iloc], lats[iloc]), poly);
      notInside[iloc] = !inside;
      if (inside)
        insideCount++;
    }
  }

  for (auto &vec : flagged)
    for (size_t iloc = 0; iloc < nlocs; iloc++)
      if (apply[iloc])
        vec[iloc] = notInside[iloc];

  oops::Log::trace() << "ObsPolygonCheck applyFilter complete (kept " << insideCount
                     << " of " << applyCount << " locations discarding "
                     << (applyCount - insideCount) << ")" << std::endl;
}

// -----------------------------------------------------------------------------

void ObsPolygonCheck::print(std::ostream & os) const {
  os << "ObsPolygonCheck: config = " << parameters_ << std::endl;
}

// -----------------------------------------------------------------------------

}  // namespace ufo
