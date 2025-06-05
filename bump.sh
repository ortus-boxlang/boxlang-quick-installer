#!/bin/bash

INSTALLER_VERSION=$(jq -r '.INSTALLER_VERSION' version.json)
INSTALLER_VERSION=$(echo $INSTALLER_VERSION | awk -F. -v OFS=. '{$2++; $3=0; print}')
jq --arg new_version "$INSTALLER_VERSION" '.INSTALLER_VERSION = $new_version' version.json > version.json.tmp && mv version.json.tmp version.json