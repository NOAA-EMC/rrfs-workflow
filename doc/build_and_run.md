# 1. Build
`git clone -b rrfs-mpas-jedi --recursive git@github.com:NOAA-EMC/rrfs-workflow.git`

`cd rrfs-workflow/sorc` and run the following command to build the system:
```
build.all
```

The above script compiles WPS, MPAS, MPASSIT, RDASApp and UPP simultaneously.  
Build logs for each component can be found under sorc/:
```
log.build.mpas
log.build.rdas
log.build.wps
log.build.mpassit
log.build.upp
```

Executables can be found under `exec/`:
```
ungrib.x
init_atmosphere_model.x
atmosphere_model.x
mpasjedi_variational.x
bufr2ioda.x
mpassit.x
upp.x
```

# 2. Setup and run experiments:
### 2.1. cat/copy and modify exp.setup
```
cd workflow
cat exp/exp.conus12km exp.setup
vi exp.setup # set up options as needed. Note: modify local.setup options near the end of the file
```
In retro runs, for simplicity, `OPSROOT` provides a top directory for `COMROOT`, `DATAROOT` and `EXPDIR`. But this is NOT a must and you may set them separately without a shared top directory.
    
Refer to [this guide](https://github.com/NOAA-EMC/rrfs-workflow/wiki/deploy-a-realtime-run-in-Jet) for setting up realtime runs. Note: realtime runs under role accounts should be coordinated with the POC of each realtime run.

### 2.2 setup_rocoto.py
```
./setup_rocoto.py
```   
    
This Python script creates an experiment directory (i.e. `EXPDIR`), writes out a runtime version of `exp.setup` under EXPDIR, and  then copies runtime config files from `HOMErrfs/parm` to `EXPDIR`.
       
### 2.3 run and monitor experiments using rocoto commands

Go to `EXPDIR`, open `rrfs.xml`, and make sure it has all the required tasks and settings.
    
Use `./run_rocoto.sh` to run the experiment. Add an entry to your crontab similar to the following to run the experiment continuously.
```
*/5 * * * * /home/role.rtrr/RRFS/1.0.1/conus3km/run_rocoto.sh
```
Check the first few tasks/cycles to make sure everything works well. You may use [this handy rocoto tool](https://github.com/rrfsx/qrocoto/wiki/qrocoto) to check the workflow running status.

### note
The workflow depends on the environmental variables. If your environment defines and exports rrfs-workflow-specific environmental variables in an unexpected way or your environment is corrupt, the setup step may fail or generate unexpected results. Check the `rrfs.xml` file before `run_rocoto.sh`. Starting from a fresh terminal or `module purge` usually solves the above problem.


