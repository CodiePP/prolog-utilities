# prolog-utilities: all modules built and installed for the user "user".
#
#   /home/user/prolog-utilities   the source tree, built (ci/build.sh)
#   /home/user/lib/sbcl           SWI-Prolog modules and foreign libraries
#   /home/user/lib/gprolog        GNU Prolog libraries for gplc
#
# ~/.config/swi-prolog/init.pl sets the sbcl search path, so
#   docker run --rm -it ghcr.io/<owner>/prolog-utilities
# starts swipl, where use_module(sbcl(curl)) etc. work. The toolchain stays
# in the image to rebuild or to link GNU Prolog programs.
#
# Built for linux/amd64 and linux/arm64 by .github/workflows/image.yml.
FROM ubuntu:26.04

LABEL org.opencontainers.image.title="prolog-utilities" \
      org.opencontainers.image.description="SWI-Prolog and GNU Prolog utilities: JSON, regexp, CGI, libcurl and PostgreSQL bridges" \
      org.opencontainers.image.licenses="GPL-3.0-or-later"

COPY ci/install-deps.sh /tmp/install-deps.sh
RUN /tmp/install-deps.sh \
 && rm -rf /var/lib/apt/lists/* /tmp/install-deps.sh \
 && useradd --create-home --shell /bin/bash user

USER user
WORKDIR /home/user

COPY --chown=user:user . prolog-utilities
RUN cd prolog-utilities \
 && ci/build.sh \
 && ci/test.sh \
 && ci/install.sh --init /home/user

CMD ["swipl"]
