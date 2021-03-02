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
 - A different vertical configuration -- L65_20mb

# Repo Directory Structure

The following is the directory structure of the ufs-srweather-app and
regional_workflow repositories.

    ufs-srweather-app/
    ├── docs
    │   └── UsersGuide
    ├── env               # Files to set environment on supported platforms
    ├── exec              # Installed executables
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
    ├── env           # DEPRECATED and removed recently in community
    ├── jobs          # Job cards - bash scripts that call ex-scripts
    ├── modulefiles
    │   └── tasks     # Module files loaded at run time
    ├── scripts       # EX Scripts - bash scripts to run components
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
is successful before moving onto the next. The example shown here is for
building in your own working area on Jet, not the role account.

### Building

Building need be done only once if no source code is changed.

- Clone the ufs-srweather-app repository.
```
    git clone https://github.com/NOAA-GSL/ufs-srweather-app.git gsl-srweather-app
    cd gsl-srweather-app
    git checkout feature/RRFS_dev1
```
- And retrieve the externals.
```
    ./manage_externals/checkout_externals
```
- Source the build environment (must be in bash shell)
```
    bash # If your default shell is not bash
    source env/build_jet_intel.env
```
- Build the code (from top level SRW App).
```
    mkdir build
    cd build
    cmake .. -DCMAKE_INSTALL_PREFIX=..
    make -j 4 2>&1 | tee build.log
```

### Configuring

The configuring steps below should be run when any of these files need
to be updated consistently with each other:

 - Module files staged in regional_workflow/modulefiles
 - Scripts and templates staged in regional_workflow/ush:
   - FV3's input.nml
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

    cd regional_workflow/ush
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

The workflow automatically cleans and archives the real-time runs, and is
not guaranteed to work with retro runs. You may want to take a look at
the logic for cleaning and archiving in the respective scripts level to
modify as needed. Alternative, turn off those events by removing them
from the XML.

    cd regional_workflow/ush/templates
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
  - Modified and linked the configure file
  - Modified the XML template to your needs

You will need to activate a conda environment to generate the experiment
directory that contains the XML, namelists, etc.

### Load the conda environment:

    module use -a /contrib/miniconda3/modulefiles
    module load miniconda3
    conda activate regional_workflow


Alternatively, you can source an environment file from the App level:

    source env/wflow_jet.env


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

# Updating Real-time Runs

The AVID Team manages several real-time experiments on the Jet RDHPCS
platform. The deployment of the system for these runs is performed
manually, and they are run under a role account for easier Team
management. There is no specific user assigned to the local clones, so
the repository structures are "pull only".

Changes to the real-time runs should be made through the Pull Request
process and subsequently pulled into the relevant repositories upon
successfully merging with the appropriate feature branch, e.g.
feature/RRFS_dev1 in the regional_workflow repository.

Minor hot fixes are allowed to be made in-place for the real-time runs,
especially since many setting will be a result of the configuration
system. Any changes made in place should immediately be applied to the
code that generates the configuration system. A local test in user space
to ensure the correct result is also highly recommended.

All other changes should follow these steps:

 - Modify the code in a your own branch in your own fork.
 - Open a PR to the branch corresponding to the run you'd like to
   update.
 - Once the PR has been accepted and merged, sudo to role account and
   pull the changes to the local clone.
 - If any changes were made that result in changes to products of the
   ush/generate_FV3LAM_wflow.sh, rerun that script to update, or
   manually update (small changes only).
   - It's best to do this between cycles, if possible.

## Effects of changes
Changes to different parts of the system will require slightly different
actions to fully update the system.

### Changes to the XML

- XML changes that are very minor can be made manually reflecting the
  change to the template, which is committed to the repository.
- Extensive changes to the XML should be applied through a rebuild using
  the script ush/generate_FV3LAM_wflow.sh once the XML template has been
  through a PR.

### Changes to a configuration setting.

- The changes should be committed as changes to the configuration
  file(s), potentially config.sh.RRFS_dev1 and config.sh.RRFS_AK_dev1.
- It's a good idea to go through a PR first for these settings since so
  many of them have repercussions to XML and scripts.
- For minor changes, a manual update of the var_defns.sh file to reflect
  a config.sh change can be made.
- For significant modifications, regenerating var_defns.sh by re-running
  ush/generate_FV3LAM_wflow.sh will be necessary.

### Changes to a script

- For hot fixes made to jobs and scripts before a PR, there will be
  a conflict when pulling in your merged PR. To completely avoid this,
  do the PR first. Otherwise, just before you do `git pull` into
    regional_workflow, you will need to "checkout" all modified files:

```
    git status # see all modified files
    git checkout <filename> # discard changes to file; do for each
```

## Rules of Thumb

- Doing a PR first is *highly recommended*. Reviewed code is stronger
  code, and you run into fewer issues when pulling changes to the local
  clone.
- Ask for guidance if you are unclear what downstream effects some
  changes may have, or what real-time mods may be needed to get them
  implemented. Example: does changing config setting X impact run-time
  scripts and XML, or only the run-time environment?



# Contact Info

For questions related to code management, contributing to the AVID
real-time runs, or running real-time runs:

| Name | Email |
| ---- | :---- |
| Christina Holt | Christina.Holt@NOAA.gov |
| Trevor Alcott  | Trevor.Alcott@NOAA.gov  |
| Jaymes Kenyon  | Jaymes.Kenyon@NOAA.gov  |

For science and programmatic questions related to RRFS runs at AVID:

| Name | Email |
| ---- | :---- |
| Curtis Alexander | Curtis.Alexander@NOAA.gov |
| Stephen Weygandt | Stephen.Weygandt@NOAA.gov |
