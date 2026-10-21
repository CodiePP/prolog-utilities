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
      org.opencontainers.image.description="SWI-Prolog, GNU Prolog, libcurl and libpq for building and testing prolog-utilities"

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        build-essential \
        pkg-config \
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

# bookworm's docker.io has no buildx plugin (docker-buildx is trixie+), but
# image.yaml runs `docker buildx` in this image. Pinned, checksum verified.
ARG BUILDX_VERSION=0.38.1
ARG TARGETARCH
RUN case "${TARGETARCH}" in \
        amd64) sum=e25d5cd675092bb5d1d03632fdc46cdf3fede7b514dc5f023a105e00d3ce5ad4 ;; \
        arm64) sum=3b83b3731916ba433feccaaa689fe5bcdc81c641d92c8e6c2ea865dfa141c97a ;; \
        *) echo "unsupported TARGETARCH: ${TARGETARCH}" >&2; exit 1 ;; \
    esac && \
    mkdir -p /usr/libexec/docker/cli-plugins && \
    curl -fsSL -o /usr/libexec/docker/cli-plugins/docker-buildx \
        "https://github.com/docker/buildx/releases/download/v${BUILDX_VERSION}/buildx-v${BUILDX_VERSION}.linux-${TARGETARCH}" && \
    echo "${sum}  /usr/libexec/docker/cli-plugins/docker-buildx" | sha256sum -c - && \
    chmod 755 /usr/libexec/docker/cli-plugins/docker-buildx

 ARG GPROLOG_VERSION=1.5.0
 RUN wget -q https://ftp.gnu.org/gnu/gprolog/gprolog-${GPROLOG_VERSION}.tar.gz && \
     tar xzf gprolog-${GPROLOG_VERSION}.tar.gz && \
     cd gprolog-${GPROLOG_VERSION}/src && \
     ./configure && \
     make && \
     make install && \
     cd / && rm -rf gprolog-${GPROLOG_VERSION} gprolog-${GPROLOG_VERSION}.tar.gz
