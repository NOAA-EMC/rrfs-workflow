# 1. Build
```
which git-lfs 2>/dev/null ||  module load git-lfs
GIT_LFS_SKIP_SMUDGE=1 git clone -b rrfs-mpas-jedi --recursive https://github.com/NOAA-EMC/rrfs-workflow
cd rrfs-workflow/sorc
./build.all
```
Note: 
1. The first command is to make sure `git-lfs` is loaded as it is required for cloning RDASApp
2. `GIT_LFS_SKIP_SMUDGE=1` is to skip downloading git-lfs binary data used by JEDI ctests, which is NOT needed by rrfs-workflow.  
   This will avoid intermittent RDASApp checkout failures when JCSDA repositories exceed their LFS budget.
3. If you run cold start forecasts only and don't need data assimilation, you can `vi build.all` and comment out this line `./build.rdas &> ./log.build.rdas 2>&1 &` before running `./build.all`

# 2. Setup and run experiments:
### 2.1. cat/copy and modify exp.setup
```
cd workflow
# find the target exp setup template file, copy it. Here we use exp.conus12km as an example:
cp exp/exp.conus12km exp.conus12km
vi exp.conus12km # modify as needed; usually need to change OPSROOT, ACCOUNT, QUEUE, PARTITION
```
In retro runs, for simplicity, `OPSROOT` provides a top directory for `COMROOT`, `DATAROOT` and `EXPDIR`. But this is NOT a must and you may set them separately without a shared top directory.
    
Refer to [this guide](https://github.com/NOAA-EMC/rrfs-workflow/wiki/deploy-a-realtime-run-in-Jet) for setting up realtime runs. Note: realtime runs under role accounts should be coordinated with the POC of each realtime run.

### 2.2 setup_rocoto.py
```
# Here we use exp.conus12km as an example:
./setup_rocoto.py exp.conus12km
```   
    
This Python script creates an experiment directory (i.e. `EXPDIR`), writes out a runtime version of `exp.setup` under EXPDIR, and  then copies runtime config files to `EXPDIR`.  
If you get errors when running `setup_rocoto.py`, it is usually due to a low Python version.  
You may run `source ../workflow/ush/load_bokeh.sh` to load a working Python environment and then run the command again.
       
### 2.3 run and monitor experiments using rocoto commands

Go to `EXPDIR`, open `rrfs.xml`, and make sure it has all the required tasks and settings.
    
Use `./run_rocoto.sh` to run the experiment. Add an entry to your crontab similar to the following to run the experiment continuously.
```
*/5 * * * * /home/role.rtrr/RRFS/1.0.1/conus3km/run_rocoto.sh
```
Check the first few tasks/cycles to make sure everything works well. 

The handy rocoto tool `qrocoto` is available under EXPDIR, run  
```
source qrocoto/load_qrocoto.sh
```
to load qrocoto to the current environment.  
Now you can use all handy rocoto commands to run/check the workflow, such as `rstat`, `rrun`, etc  
Check [README.md](../workflow/ush/qrocoto/README.md) or [detailed instructions](https://github.com/rrfsx/qrocoto/wiki/qrocoto) for more details.
  
### note
The workflow depends on the environmental variables. If your environment defines and exports rrfs-workflow-specific environmental variables in an unexpected way or your environment is corrupt, the setup step may fail or generate unexpected results. Check the `rrfs.xml` file before `run_rocoto.sh`. Starting from a fresh terminal or `module purge` usually solves the above problem.


