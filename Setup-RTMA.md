# The RTMA application based on the ufs-srweather-app repository

A brief example to set up and run RTMA

## 1. clone the ufs-srweather-app repository as follows

```
  git clone https://github.com/NOAA-GSL/ufs-srweather-app RTMA
```
or
```
  git clone git@github.com:NOAA-GSL/ufs-srweather-app RTMA
  ```

## 2. checkout target branch/tag/hash
For example, checkout a branch:
```
  git checkout feature/RRFS_dev1
```
or checkout a tag:
```
  git checkout rtma.v0.3.0
```

## 3. Get external components
```
cd RTMA
./manage_externals/checkout_externals
```

## 4. build executables
```
cd RTMA
./devbuild.sh 
```

## 5. generate a RTMA workflow
```
cd RTMA
module use env
source env/build_jet_intel.env  (use other build files for different environments)
source env/wflow_jet.env (use other wflow files for different platforms)
cd regional_workflow/ush
cp config.sh.RTMA_NA_3km(or config.sh.RTMA_CONUS_3km)  config.sh
vi config.sh (modify EXPT_BASEDIR, STMP, PTMP and other variables accordingly)
./generate_FV3LAM_wflow.sh
```

## 6. run the RTMA workflow

Follow the instructions printed out from step 5 to set up a cron job to run the generated RTMA workflow

## 7. More
Reference the following documentation for more

https://github.com/NOAA-GSL/ufs-srweather-app/blob/feature/RRFS_dev1/Setup-RRFS.md

https://github.com/ufs-community/ufs-srweather-app/wiki/Getting-Started


