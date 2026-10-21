# Shared build image for the CI and IT workflows: toolchain plus everything the
# modules link against, so the jobs do not install packages on every run.
#
# - Build context is ci/ (for install-deps.sh), not this directory.
# - Debian 13 (trixie), the same base as the GitHub image (../../../Dockerfile);
#   pinned by digest.
# - node is needed because the workflows use actions/checkout.
# - docker-cli and docker-buildx: image.yaml runs `docker buildx` here against a
#   remote daemon (DOCKER_HOST), so the daemon (docker.io) is not needed.
#
# Build/push with ci/build-image.sh or the image.yaml workflow.
FROM debian:trixie-slim@sha256:a29215f6a35e51e22adffa17f89e9d2ef06214e64a2bad10d765c46aea49f11f

LABEL org.opencontainers.image.title="prolog-utilities CI" \
      org.opencontainers.image.description="SWI-Prolog, GNU Prolog, libcurl and libpq for building and testing prolog-utilities"

ENV DEBIAN_FRONTEND=noninteractive

# toolchain, SWI-Prolog, libcurl, libpq and GNU Prolog (checksum verified)
COPY install-deps.sh /tmp/install-deps.sh
RUN /tmp/install-deps.sh \
 && apt-get install -y --no-install-recommends \
        nodejs \
        git \
        docker-cli \
        docker-buildx \
 && rm -rf /var/lib/apt/lists/* /tmp/install-deps.sh
