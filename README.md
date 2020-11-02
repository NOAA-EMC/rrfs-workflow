# UFS Short-Range Weather Application for GSL dev1

The UFS Short-Range Weather Application (UFS SR Wx App) provides an end-to-end system to run
pre-processing tasks, the regional UFS Weather Model, and the Unified Post Processor (UPP). 

## Official Documentation
For the most up-to-date instructions on how to clone the repository, build the code, and run the workflow, see:

https://github.com/ufs-community/ufs-srweather-app/wiki/Getting-Started


# Modifications for the RRFS_dev1

This branch supports additional features for running real-time RRFS runs
at GSL on Jet. The branch's default configuration has not been tested on
other RDHPCS platforms.

This branch supports the following features:

 - Real-time support in the XML
 - A real-time config file.
 - NCL Graphics Rocoto jobs, jobs, and scripts for the web graphics
 - A slight modification on the standard NCO configuration for logs
 - Additional grib2 files
 - FV3_HRRR physics (workflow components enabled)
 - A different vertical configuration -- L65_20mb

# Repo Directory Structure

The following is the directory structure of the ufs-srweather-app and
regional_workflow repositories.

    ufs-srweather-app/
    ├── docs
    │   └── UsersGuide
    ├── exec              # Installed executables
    ├── fix
    │   ├── fix_am        # Linked during build. Soon to be DEPRECATED.
    │   └── fix_fv3       # DEPRECATED
    ├── manage_externals  # Utility for gathering git submodules
    ├── regional_workflow # See details below.
    └── src               # Source code
        ├── EMC_post
        ├── logs
        ├── UFS_UTILS_chgres_grib2
        ├── UFS_UTILS_develop
        └── ufs_weather_model

    regional_workflow/
    ├── docs
    │   └── UsersGuide
    ├── env           # DEPRECATED and recently removed
    ├── jobs          # Job cards - bash scripts that call ex-scripts
    ├── modulefiles
    │   ├── codes     # DEPRECATED and recently removed
    │   └── tasks     # Module files loaded at run time
    ├── scripts       # EX Scripts - bash scripts to run components
    ├── sorc          # DEPRECATED
    ├── tests         # Workflow E2E test configuration files
    │   └── baseline_configs
    └── ush           # Utility scripts
        ├── bash_utils
        ├── NCL       # Not used at GSL
        ├── Python    # Not used at GSL
        ├── rocoto    # Not used!
        ├── templates # Files for XML, model, UPP, etc.
        └── wrappers  # Not used -- running in stand-alone mode

# Getting started

## Running an experiment

There are a handful of steps below that are required to build the code,
configure an experiment, and run the experiment. Please ensure that each
is successful before moving onto the next.


### Building

Building need be done only once if no source code is changed.

- Clone the ufs-srweather-app repository.
```
    clone https://github.com/NOAA-GSD/ufs-srweather-app.git gsd-srweather-app
    cd gsd-srweather-app
    git checkout feature/RRFS_dev1
```
- And retrieve the externals.

```
    ./manage_externals/checkout_externals
```

- Build the code.

```
    cd ufs-srweather-app/src/
    ./build_all.sh
```


### Linking fix files

The files need to be linked for each new clone. The configuration step
below will fail verbosely if this step has been skipped.

    cd ufs-srweather-app/regional_workflow
    mkdir fix
    cd fix
    ln -sf /mnt/lfs4/BMC/nrtrr/RRFS/fix/fix_am.20201001 fix_am
    ln -sf /mnt/lfs4/BMC/nrtrr/RRFS/fix/fix_lam.20201001 fix_lam

### Configuring

The configuring steps below should be run when any of these files need
to be updated consistently with each other:

 - Module files staged in regional_workflow/modulefiles
 - Scripts and templates staged in regional_workflow/ush:
   - FV3 input.nml
   - config.sh
   - setup.sh
   - config_defaults.sh
   - Rocoto XML

> Note: Any value set by var_defns.sh, which is a product of the
> configuration stage, overrides any environment variables with
> identical names set in the Rocoto XML.

#### User-specific settings
Before running the RRFS_dev1 configuration, you will need to change your
output directories by editing the config file:

    cd ufs-srweather-app/regional_workflow/ush
    vi config.sh.RRFS_dev1

Inside the config file, ensure that you are point to your preferred user
space for the following variables:

    EXPT_BASEDIR
    ARCHIVEDIR
    STMP
    PTMP

You will also likely want to change the dates over which to run:

    DATE_FIRST_CYCL
    DATE_LAST_CYCL

The configure script should then be linked to the expected name:

    ln -sf config.sh.RRFS_dev1 config.sh


#### Retro runs

The workflow automatically cleans and archives the real time runs, and is
not guaranteed to work with retro runs. You may want to take a look at
the logic for cleaning and archiving in the respective scripts level to
modify as needed. Alternative, turn off those events by removing them
from the XML.

    cd ufs-srweather-app/regional_workflow/ush/templates
    vi FV3LAM_wflow.xml

Manually comment or delete the following tasks:

    CLEAN_TN
    ARCHIVE_TN

You may also want to remove the NCL graphics metatasks:

    RUN_NCL_TN
    RUN_NCL_ZIP_TN


## Build the workflow


Before proceeding with this section, make sure you have successfully
done the following:

  - Built the source code
  - Linked the fix files
  - Modified and linked the configure file
  - Modified the XML template to your needs

You will need to activate a conda environment to generate the experiment
directory that contains the XML, namelists, etc.

### Load the conda environment:

    module use -a /contrib3/miniconda3/modulefiles
    module load miniconda3
    conda activate regional_workflow

### Configure the experiment:

    cd ufs-srweather-app/regional_workflow/ush
    ./generate_FV3LAM_wflow.sh

With successful completion of the above script, you will get directions
on how to edit your Cron table to add the Rocoto job.


# Contributing

## Git Workflow

We use a Forking Workflow with GitHub. See [this
Tutorial](https://www.atlassian.com/git/tutorials/comparing-workflows/forking-workflow)
for more information.

All development should be done in a branch of your personal fork, then
contributed back to the feature/RRFS_dev1 branch through a Pull Request
on GitHub.

## Pull Requests

Pull Requests for real-time development branches are reviewed by the
AVID Team to ensure configuration and compatibility with the scientific
plans within the Division.

## Scripts and configuration layer

While we maintain some differences from the Authoritative repository
code base from which we started, an effort will be made to reduce the
differences as much as possible.

If major changes are needed, and could be useful to the wider UFS SR
Weather App community, please consider contributing them to that
repository first.

# Contact Info

For questions related to code management, contributing to the AVID
real-time runs, or running real time runs:

| Name | Email |
| ---- | :---- |
| Christina Holt | Christina.Holt@NOAA.gov |
| Trevor Alcott  | Trevor.Alcott@NOAA.gov  |

For science and programmatic questions related to RRFS runs at AVID:

| Name | Email |
| ---- | :---- |
| Curtis Alexander | Curtis.Alexander@NOAA.gov |
| Stephen Weygandt | Stephen.Weygandt@NOAA.gov |
