# rrfs-workflow

This repository contains the workflow code for the [Rapid Refresh
Forecast System
(RRFS)](https://gsl.noaa.gov/focus-areas/unified_forecast_system/rrfs).

For more information see the [RRFS-Workflow User's
guide](https://chanhoo-rrfs-workflow.readthedocs.io/en/latest/index.html).

## Team

Code Manager: Matthew Pyle

For more information see the [Team
Charter](https://docs.google.com/document/d/1uLbPx-pOWp7eECz_7VHRt_tQyD8PLFdrwo8dr4oMgjo/edit?usp=sharing).

## Contents

The rrfs-workflow code is organized in the following subdirectories:

* doc - the User Guide documentation.
* ecf - the ecFlow contents which will drive the RRFS workflow in NWS
  operations.
* fix - static data.
* jobs - the main driver scripts (known as J-jobs) for each task. The
  workflow driver (either ecFlow or rocoto) submits these J-jobs.
* modulefiles - module files for NOAA HPC systems.
* parm - parameter files - generally namelists or configure files.
* scripts - the "ex scripts" - the primary script for a given task,
  and called by the J-job.
* sorc - all of the source codes that need to be built/compiled for
  use within the package.
* tests - unit tests for rrfs-workflow code.
* ush - the utility scripts - scripts typically called by the "ex
  scripts" to handle specific tasks, often repeatedly for different
  times or geographic regions.
* versions - shell scripts setting environment vars to the required
  versions of all dependencies, for building and for running
  rrfs-workflow.

These are in compliance with the [NCO implementation standard]
(https://www.nco.ncep.noaa.gov/idsb/implementation_standards/ImplementationStandards.v11.0.0.pdf).

## Build Instructions

1. Clone the `main` branch of the authoritative repository:
```
git clone https://github.com/NOAA-EMC/rrfs-workflow
```

2. Move to the `sorc` directory:
```
cd rrfs-workflow/sorc
```

3. Build the RRFS workflow:
```
./app_build.sh --extrn --nogtg --noifi
```
The above command is equal to:
```
./manage_externals/checkout_externals
./app_build.sh -p=[machine]
```
where `[machine]` is `wcoss2`, `hera`, `jet`, `orion`, or `hercules`.  The `--nogtg` and `--noifi` flags avoid compilation of GTG and IFI components respectively, which only select users can compile.

4. Move to the home directory (rrfs-workflow):
```
cd ..
```

5. Configure/build the workflow (see description of Engineering Tests in the [RRFS-Workflow User's
guide](https://chanhoo-rrfs-workflow.readthedocs.io/en/latest/index.html)
## Disclaimer

```
The United States Department of Commerce (DOC) GitHub project code is
provided on an "as is" basis and the user assumes responsibility for
its use. DOC has relinquished control of the information and no longer
has responsibility to protect the integrity, confidentiality, or
availability of the information. Any claims against the Department of
Commerce stemming from the use of its GitHub project will be governed
by all applicable Federal law. Any reference to specific commercial
products, processes, or services by service mark, trademark,
manufacturer, or otherwise, does not constitute or imply their
endorsement, recommendation or favoring by the Department of
Commerce. The Department of Commerce seal and logo, or the seal and
logo of a DOC bureau, shall not be used in any manner to imply
endorsement of any commercial product or activity by DOC or the United
States Government.

