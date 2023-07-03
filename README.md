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


