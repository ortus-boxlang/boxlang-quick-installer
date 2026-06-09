# BoxLang Quick Installer – Integration Test Dockerfile
#
# Tests compiled MatchBox binaries in clean Linux environments.
# Supports Ubuntu and Alpine via build arg.
#
# Usage:
#   docker build --build-arg BASE_IMAGE=ubuntu:24.04 -t boxlang-test-ubuntu -f Dockerfile .
#   docker build --build-arg BASE_IMAGE=alpine:3.20  -t boxlang-test-alpine  -f Dockerfile .
#   docker run --rm boxlang-test-ubuntu
#
# Prerequisites: compile .bxs → native binaries first (see tests/integration/build.sh)
#   or let build.sh handle the full pipeline.

ARG BASE_IMAGE=ubuntu:24.04
FROM ${BASE_IMAGE}

ARG BASE_IMAGE=ubuntu:24.04

RUN case "${BASE_IMAGE}" in \
      alpine*) \
        apk add --no-cache bash openjdk21 curl tar ;; \
      *) \
        apt-get update && \
        DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
          openjdk-21-jre-headless curl ca-certificates && \
        rm -rf /var/lib/apt/lists/* ;; \
    esac

ENV BVM_HOME=/home/tester/.bvm \
    HOME=/home/tester \
    TERM=xterm-256color

RUN mkdir -p ${BVM_HOME}/bin ${BVM_HOME}/versions ${BVM_HOME}/cache

COPY dist/linux-x64/ ${BVM_HOME}/bin/
RUN chmod +x ${BVM_HOME}/bin/*

COPY src/ /opt/boxlang/src/
COPY tests/integration/run_tests.sh /opt/boxlang/
RUN chmod +x /opt/boxlang/run_tests.sh

WORKDIR /opt/boxlang

ENTRYPOINT ["/opt/boxlang/run_tests.sh"]
