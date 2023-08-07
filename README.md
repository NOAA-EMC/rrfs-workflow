# rrfs-workflow

Workflow for the Rapid Refresh Forecast System (RRFS)


## Build

1. Clone the `dev-sci` branch of the authoritative repository:
```
git clone -b dev-sci https://github.com/NOAA-EMC/rrfs-workflow
```

2. Check out the external components:
```
cd rrfs-workflow
./manage_externals/checkout_externals
```

3. Build the RRFS workflow:
```
./devbuild.sh -p=[machine]
```
where `[machine]` is `wcoss2`, `hera`, `orion`, or `jet`.

## Engineering Test (non-DA)

1. Load the python environment:

- WCOSS2:
```
source versions/run.ver.wcoss2
module use modulefiles
module load wflow_wcoss2
```

- Hera, Orion, or Jet:
```
module use modulefiles
module load wflow_[machine]
conda activate workflow_tools
```
where `[machine]` is `hera`, `orion`, or `jet`.

2. Copy the pre-defined configuration file:
```
cd ush
cp sample_configs/non-DA_eng/config.nonDA.community.[machine].sh config.sh
```
where `[machine]` is `wcoss2`, `hera`, `orion`, or `jet`. Note that you may need to change `ACCOUNT` in `config.sh`.

3. Generate the workflow:
```
./generate_FV3LAM_wflow.sh
```

4. Launch the workflow:
```
cd ../../expt_dirs/test_nonDA_community
./launch_FV3LAM_wflow.sh
```


## Engineering Test (DA)

1. Load the python environment:

- WCOSS2:
```
source versions/run.ver.wcoss2
module use modulefiles
module load wflow_wcoss2
```

- Hera, Orion, or Jet:
```
module use modulefiles
module load wflow_[machine]
conda activate workflow_tools
```
where `[machine]` is `hera`, `orion`, or `jet`.

2. Copy the pre-defined configuration file:
```
cd ush
cp sample_configs/DA_eng/config.DA.[type].[machine].sh config.sh
```
where `[type]`=`para` on `[machine]`=`wcoss2` or `[type]`=`retro` on `[machine]`=`hera`. 

Notes) 
- You may need to change `ACCOUNT` in `config.sh`.
- For the real-time test run on WCOSS2, you should replace `DATE_FIRST_CYCL`, `DATE_LAST_CYCL`, `CYCLEMONTH`, and `CYCLEDAY` with those of Today's date.

3. Generate the workflow:
```
./generate_FV3LAM_wflow.sh
```

4. Launch the workflow:
```
cd ../../expt_dirs/rrfs_test_da
./launch_FV3LAM_wflow.sh
```

5. Launch specific tasks manually:
- On Hera: `config.DA.retro.hera.sh`
```
rocotoboot -w FV3LAM_wflow.xml -d FV3LAM_wflow.db -v 10 -c 202207200600 -t get_extrn_lbcs
rocotoboot -w FV3LAM_wflow.xml -d FV3LAM_wflow.db -v 10 -c 202207201200 -t get_extrn_lbcs
rocotoboot -w FV3LAM_wflow.xml -d FV3LAM_wflow.db -v 10 -c 202207201800 -t get_extrn_lbcs
rocotoboot -w FV3LAM_wflow.xml -d FV3LAM_wflow.db -v 10 -c 202207201500 -t get_extrn_ics
```
Once the above tasks are complete,
```
rocotoboot -w FV3LAM_wflow.xml -d FV3LAM_wflow.db -v 10 -c 202207200300 -t prep_cyc_spinup
```

- On WCOSS2: `config.DA.para.wcoss2.sh` (in case of today=20230726)
```
rocotoboot -w FV3LAM_wflow.xml -d FV3LAM_wflow.db -v 10 -c 202307260000 -t get_extrn_lbcs
rocotoboot -w FV3LAM_wflow.xml -d FV3LAM_wflow.db -v 10 -c 202307260600 -t get_extrn_lbcs
rocotoboot -w FV3LAM_wflow.xml -d FV3LAM_wflow.db -v 10 -c 202307261200 -t get_extrn_lbcs
rocotoboot -w FV3LAM_wflow.xml -d FV3LAM_wflow.db -v 10 -c 202307261800 -t get_extrn_lbcs (only when data is available)
rocotoboot -w FV3LAM_wflow.xml -d FV3LAM_wflow.db -v 10 -c 202307260300 -t get_extrn_ics 
rocotoboot -w FV3LAM_wflow.xml -d FV3LAM_wflow.db -v 10 -c 202307261500 -t get_extrn_ics (only when data is available)
```

Note that you may need to run `rocotoboot` for the task `prep_cyc_spinup` at 04z sequentially if it is not launched:
```
rocotoboot -w FV3LAM_wflow.xml -d FV3LAM_wflow.db -v 10 -c 202307260400 -t prep_cyc_spinup
```

Note that you may need to force the completion of the task `cldanl_nonvar_prod` when it fails:
```
rocotocomplete -w FV3LAM_wflow.xml -d FV3LAM_wflow.db -v 10 -c 202307260000 -t cldanl_nonvar_prod
```


6. Check the status of your run with `rocotostat`:
```
rocotostat -w FV3LAM_wflow.xml -d FV3LAM_wflow.db -v 10 > test.log
```
Note that you can open the log file `log.lauch_FV3LAM_wflow` for the entire history but it is sometimes too long.

