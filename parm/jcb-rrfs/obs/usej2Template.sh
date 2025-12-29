#!/bin/bash

for myyaml in *.yaml.j2; do
  sed -i -e "s/@emptyObsSpaceAction@/{{emptyObsSpaceAction}}/g" -e "s/@analysisDate@/{{analysisDate}}/g" ${myyaml}
done
