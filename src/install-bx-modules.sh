#!/bin/bash

# Check if at least one argument is passed
if [ "$#" -lt 1 ]; then
  echo "Usage: $0 module1 module2 module3 ..."
  exit 1
fi

# Get the list of modules from input arguments
modules=("$@")

# Install modules in parallel
echo "Installing the following modules: ${modules[*]}"
echo "${modules[@]}" | xargs -n 1 install-bx-module

# Exit with the status of the last command
exit $?
