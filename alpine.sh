#!/bin/bash

docker run --rm -it \
	-v ./src:/opt/installer \
	-w /opt/installer \
	alpine sh