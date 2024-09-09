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
./app_build.sh --extrn --nogtg --noifi
```
The above command is equal to:
```
./manage_externals/checkout_externals
./app_build.sh -p=[machine]
```
where `[machine]` is `wcoss2`, `hera`, `jet`, `orion`, or `hercules`.  The `--nogtg` and `--noifi` flags avoid compilation of GTG and IFI components respectively, which only select users can compile.

4. Move to the home directory (rrfs-workflow):
```
cd ..
```

## Engineering Tests

See the RRFS-Workflow User's guide:
https://chanhoo-rrfs-workflow.readthedocs.io/en/latest/index.html

## Disclaimer

```
The United States Department of Commerce (DOC) GitHub project code is
provided on an "as is" basis and the user assumes responsibility for
its use. DOC has relinquished control of the information and no longer
has responsibility to protect the integrity, confidentiality, or
availability of the information. Any claims against the Department of
Commerce stemming from the use of its GitHub project will be governed
by all applicable Federal law. Any reference to specific commercial
products, processes, or services by service mark, trademark,
manufacturer, or otherwise, does not constitute or imply their
endorsement, recommendation or favoring by the Department of
Commerce. The Department of Commerce seal and logo, or the seal and
logo of a DOC bureau, shall not be used in any manner to imply
endorsement of any commercial product or activity by DOC or the United
States Government.

