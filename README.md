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
cp sample_configs/[machine]/config.nonDA.community.hera.sh config.sh
```
where `[machine]` is `hera` or `wcoss2`. Note that you may need to change `ACCOUNT` in `config.sh`.

3. Generate the workflow:
```
./generate_FV3LAM_wflow.sh
```

4. Launch the workflow:
```
cd ../../expt_dir/test_nonDA_community
./launch_FV3LAM_wflow.sh
```


