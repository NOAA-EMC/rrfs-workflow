# RDASApp and JEDI build

RDASApp is configured as an external component in `sorc/Externals.cfg` at the
pinned revision recorded in `versions/build.ver`. The normal build driver is `sorc/app_build.sh`.

From the workflow root, run the first build with:

```bash
cd sorc
./app_build.sh --extrn --workaround
```

`--extrn` checks out the configured external packages. In this workflow it
refreshes all configured externals, including RDASApp, so use it for an initial
checkout or when the external checkouts need to be refreshed.

For normal iterative development, keep the existing external checkouts and
build products:

```bash
./app_build.sh --continue --workaround
```

The `--continue` option reuses the existing build directories. RDASApp is also
configured without its force-clean option, so unchanged components are not
rebuilt unnecessarily.

To remove the existing build products and configure a clean build without
checking out the externals again, use:

```bash
./app_build.sh --remove --workaround
```

The `--workaround` option copies the branch's local RDASApp workaround sources
and configurations before building. Use it for validation and baseline
experiments. Omit it for a build without those local workarounds.

A regular build using already checked-out externals can be run with:

```bash
./app_build.sh
```

Platform and compiler options are optional; the build uses the detected NOAA
HPC environment and its defaults. They can be supplied explicitly when needed,
for example `--platform=ursa --compiler=intel`.

RDASApp and JEDI executables are installed directly under the workflow's
`exec/` directory. Build output is streamed to the terminal and retained in
timestamped files under `logs/`; set `LOG_DIR=/path/to/logs` to use another log
directory.

