# Shared build image for the CI and IT workflows: toolchain plus everything the
# modules link against, so the jobs do not install packages on every run.
#
# - node is needed because the workflows use actions/checkout.
# - Debian bookworm on purpose: GCC 12 only warns about the incompatible
#   pointer in pl_toolbox/src/lowlevelroutines.c; GCC 14 (trixie) makes it an
#   error. Revisit once that is fixed.
#
# Build/push with ci/build-image.sh or the image.yaml workflow.
#FROM node:20-bookworm
FROM debian:bookworm-slim

LABEL org.opencontainers.image.title="prolog-utilities CI" \
      org.opencontainers.image.description="SWI-Prolog, GNU Prolog, libcurl, libpq and autotools for building and testing prolog-utilities"

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        build-essential \
        pkg-config \
        autoconf \
        automake \
        m4 \
        nodejs \
        git \
        curl \
        wget \
        ca-certificates \
        docker.io \
        swi-prolog-nox \
        libcurl4-openssl-dev \
        libpq-dev \
        libssl-dev \
        zlib1g-dev \
        postgresql-client \
 && rm -rf /var/lib/apt/lists/*

 ARG GPROLOG_VERSION=1.5.0
 RUN wget -q https://ftp.gnu.org/gnu/gprolog/gprolog-${GPROLOG_VERSION}.tar.gz && \
     tar xzf gprolog-${GPROLOG_VERSION}.tar.gz && \
     cd gprolog-${GPROLOG_VERSION}/src && \
     ./configure && \
     make && \
     make install && \
     cd / && rm -rf gprolog-${GPROLOG_VERSION} gprolog-${GPROLOG_VERSION}.tar.gz
