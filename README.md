# rrfs-workflow

Workflow for the Rapid Refresh Forecast System (RRFS)

Team Charter (draft): https://docs.google.com/document/d/1uLbPx-pOWp7eECz_7VHRt_tQyD8PLFdrwo8dr4oMgjo/edit?usp=sharing

## Build

1. Clone the `dev-sci` branch of the authoritative repository:
```
git clone -b dev-sci https://github.com/NOAA-EMC/rrfs-workflow
```

2. Move to the `sorc` directory:
```
cd rrfs-workflow/sorc
```

3. Build the RRFS workflow:
```
./app_build.sh --extrn
```
The above command is equal to:
```
./manage_externals/checkout_externals
./app_build.sh -p=[machine]
```
where `[machine]` is `wcoss2`, `hera`, `jet`, `orion`, or `hercules`.

4. Move to the home directory (rrfs-workflow):
```
cd ..
```

## Engineering Tests

See the RRFS-Workflow User's guide:
https://chanhoo-rrfs-workflow.readthedocs.io/en/latest/index.html
