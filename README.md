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

3. Check out the external components:
```
./manage_externals/checkout_externals
```

4. Build the RRFS workflow:
```
./app_build.sh
```
Alternatively, the above command can be followed by the platform (machine) name as follows:
```
./app_build.sh -p=[machine]
```
where `[machine]` is `wcoss2`, `hera`, `jet`, or `orion`.

5. Move to the home directory (rrfs-workflow):
```
cd ..
```

## Engineering Tests

See the RRFS-Workflow User's guide:
https://chanhoo-rrfs-workflow.readthedocs.io/en/latest/index.html
