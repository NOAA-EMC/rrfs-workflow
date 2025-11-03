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
3. If you run cold start forecasts only and don't need data assimilation, run `./build.all noda`.

# 2. Setup and run experiments:
### 2.1. copy and modify exp.setup
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

If you get any errors when running `setup_rocoto.py`, it is mostly because the currently loaded Python does not have required packages (such as 'dateutil').    
You can use the Python environment included in rrfs-workflow by running
```
source ../workflow/ush/load_bokeh.sh
```
and then run `setup_rocoto.py` again.  
If the above source command fails to load a working Python environment, it usually means there is a module conflict. You may do `module purge` and/or start over from a clean terminal window.
       
### 2.3 run and monitor experiments
Currently, rrfs-workflow supports the [`rocoto`](https://christopherwharrop.github.io/rocoto/) workflow management system. All tasks are defined in the `rrfs.xml` file under `EXPDIR`, which is created in the previous step.    
There are two ways to run `rrfs.xml` and monitor its progress. Use either one based on your preference.    

#### 2.3.1 Use the `qrocoto` utilities (recommended for retro runs)
The [`qrocoto`](https://github.com/RRFSx/qrocoto/wiki/qrocoto) utilities are included in rrfs-workflow and ready to use under `EXPDIR/qrocoto`.    

Go to `EXPDIR`,    
(a) load the `qrocoto` module    
```
source qrocoto/load_qrocoto.sh
```    
(b) Enter `rrun` to launch the experiment (i.e., submit jobs)        
We will need to execute `rrun` continously every a while to proceed from one task to the next task, one cycle to the next cycle.   

To reduce manual effort, we can execute `bkg_rrun` at the command line instead. This utility will execute the `rrun` command continously every 1 minute. _(Bonus: we may put `bkg_rrun` in a [TMUX](https://github.com/tmux/tmux/wiki) or a [SCREEN](https://www.gnu.org/software/screen/manual/screen.html) window so that `bkg_rrun` continues to run even we lose network connection or close the terminal)_     

(c) Execute `rstat` to check workflow status, `rcheck YYYYMMDDHH task` to check details of a given task (such as why a task has not been submitted), `taskinfo YYYYMMDDHH task` to quickly get the location of the corresponding log file, STMP and COMROOT directories of a task.    

**NOTE:**
- Check [README.md](../workflow/ush/qrocoto/README.md) or [detailed instructions](https://github.com/rrfsx/qrocoto/wiki/qrocoto) for more information about `qrocoto`.
- If you get an error message, such as `Lmod has detected the following error...` or `...command not found...`, it means the rocoto module is NOT available in your current environment.    

Do as follows to solve the issue:    
[Orion/Hercules]    
```
module load contrib
```
[Gaea]
```
module use /ncrc/proj/epic/rocoto/modulefiles
```
[Derecho]
```
module use /glade/work/epicufsrt/contrib/derecho/modulefiles
```

#### 2.3.2 Use `run_rocoto.sh` and crontab
We can also use `./run_rocoto.sh` to launch the experiment.    
Add a crontab entry similar to the following to run the experiment continuously.
```
*/5 * * * * /home/role.rtrr/RRFS/1.0.1/conus3km/run_rocoto.sh
```
# 3. Others
The workflow depends on the environmental variables. If your environment defines and exports rrfs-workflow-specific environmental variables in an unexpected way or your environment is corrupt, the setup step may fail or generate incorrect `rrfs.xml`. Starting from a fresh terminal or `module purge` usually solves the problem.


