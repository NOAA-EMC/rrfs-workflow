#!/bin/bash

for myyaml in *.yaml; do
  mv ${myyaml} ${myyaml}.j2
done
