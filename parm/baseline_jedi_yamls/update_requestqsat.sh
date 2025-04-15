#!/bin/bash

git checkout -- *.yaml

sed -i '/request_saturation_specific_humidity_geovals/d' *yaml
sed -Ei 's|(obsfile: )(data/obs/ioda_[a-zA-Z0-9]{6}\.nc)|\1"\2"|' *yaml
