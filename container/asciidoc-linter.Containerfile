# asciidoc-linter — installed from the upstream repository, because there is no release,
# no PyPI package and no published image. This is accepted technical debt, recorded in
# req/release-plan.adoc phase P0 together with its exit condition: once upstream
# publishes tagged images, this file goes away and the image is consumed instead.
#
# We install from source rather than vendoring upstream's Dockerfile, so there is one
# fewer copy of someone else's recipe to keep in sync. Note that upstream's own
# Dockerfile still sits on python:3.9-slim; that is their pin, not ours.
#
# No ENTRYPOINT on purpose. lefthook jobs name their tool; the wrapper supplies only the
# environment, never the binary — otherwise the same lefthook.yml could not also run
# natively on a GitHub runner.
#
# ASCIIDOC_LINTER_REF tracks `main` because upstream has no tags. Set it to a commit for
# a reproducible rebuild; the image tag carries the version discipline either way, the
# same way ghcr.io/tpo42/adoc:0 already does.

FROM python:3.14-slim

ARG ASCIIDOC_LINTER_REF="main"

# hadolint DL3008 is ignored in .hadolint.yaml — see mini.Containerfile for the reason.
RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates git \
    && rm -rf /var/lib/apt/lists/* \
    && pip install --no-cache-dir \
        "git+https://github.com/docToolchain/asciidoc-linter.git@${ASCIIDOC_LINTER_REF}"

ARG USER_UID="1000"
ARG USER_GID="1000"

# One layer: smoke-check that the entry point exists, mark the bind-mounted worktree
# safe (git refuses one owned by another uid), and create the unprivileged user.
RUN asciidoc-linter --help > /dev/null \
    && git config --system --add safe.directory /workspace \
    && groupadd --gid "${USER_GID}" tpo42 \
    && useradd --uid "${USER_UID}" --gid "${USER_GID}" --create-home --shell /bin/bash tpo42

USER ${USER_UID}:${USER_GID}
WORKDIR /workspace
