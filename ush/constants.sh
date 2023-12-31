# This file is always sourced by another script (i.e. it's never run in
# its own shell), so there's no need to put the #!/bin/some_shell on the
# first line.

# Pi.
pi_geom="3.14159265358979323846264338327"
# Degrees per radian.
degs_per_radian=$( bc -l <<< "360.0/(2.0*$pi_geom)" )
degs_per_radian="57.29577951308232087679"
# Radius of the Earth in meters.
radius_Earth="6371200.0"
SECS_PER_HOUR="3600.0"
