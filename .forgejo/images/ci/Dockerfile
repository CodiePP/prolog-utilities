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
FROM debian:trixie-slim@sha256:a72b4433de1cf7d6bae0c4cee74d0547f58601a643b3375f070c51600d63b6b2

LABEL org.opencontainers.image.title="prolog-utilities CI" \
      org.opencontainers.image.description="SWI-Prolog, GNU Prolog, libcurl and libpq for building and testing prolog-utilities"

ENV DEBIAN_FRONTEND=noninteractive

# toolchain, SWI-Prolog, libcurl, libpq and GNU Prolog (checksum verified)
COPY install-deps.sh /tmp/install-deps.sh
RUN /tmp/install-deps.sh \
 && apt-get install -y --no-install-recommends \
        git git-lfs \
        docker-cli \
        docker-buildx \
 && rm -rf /var/lib/apt/lists/* /tmp/install-deps.sh

# Debian 13 contains only node v20, but we need >= v22 so we install v24.
COPY --from=node:24-trixie-slim@sha256:af02d57b57719b9657a45199a79264a9437940cd55b3c7b3fc99615654f124a0 /usr/local/bin/node /usr/local/bin/node

# The built GNU Prolog libraries (libpltoolbox-Linux.a, libplregexp-Linux.a, ...)
# from the published image, for projects that link them with gplc and run in
# this image. The same per-architecture build is used on amd64 and arm64.
# Needs ghcr.io/codiepp/prolog-utilities to be published before this image is built.
COPY --from=ghcr.io/codiepp/prolog-utilities:latest /home/user/lib/gprolog /opt/lib/gprolog
