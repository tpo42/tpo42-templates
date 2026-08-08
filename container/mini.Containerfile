# tpo42 mini QA fleet — the fast, non-build checks named in lefthook.yml.
#
# Sourcing order, in this order and for these reasons:
#   1. distro package        — maintained and patched by someone else, no pinning work
#   2. pinned prebuilt binary — for what Debian does not carry; never built from source
#   3. pip                   — only for the remaining gaps
# Building from source is what this whole migration exists to avoid: a formatter that
# pulls a compiler on every update is not a quality gate, it is a tax.
#
# Domain tools (asciidoctor, docToolchain, asciidoc-linter) are deliberately absent.
# They need version integrity with the documentation build and live in their own images.
#
# The ARG pins below are what replaces pre-commit's `autoupdate`, which the migration
# gives up. Nothing bumps them automatically — see docker-compose.yml.
# Release asset names drift; verify them when bumping. hadolint went from
# hadolint-linux-x86_64 at 2.14.0 to the same name at 2.15.1, gitleaks uses `x64`
# where everyone else writes `amd64`, and dclint ships a glibc and a musl build.

FROM debian:trixie-slim

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# --- 1. distro ---------------------------------------------------------------
# yamllint (YAML), jq (JSON), file/libmagic (type detection beyond extensions),
# git (lefthook needs it), curl + ca-certificates (for step 2), python3-pip (step 3).
# hadolint DL3008 is ignored in .hadolint.yaml: pinning apt versions here would block
# Debian security updates, which is the wrong trade for a linting image.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        file \
        git \
        jq \
        python3-pip \
        yamllint \
    && rm -rf /var/lib/apt/lists/*

# --- 3. pip: the gaps Debian does not package --------------------------------
# check-jsonschema carries the SchemaStore definitions for workflow and action files.
# It checks structure where actionlint checks semantics — expressions, runner labels,
# action inputs. Neither subsumes the other, so both are wired.
RUN pip install --no-cache-dir --break-system-packages \
        'gitlint~=0.19' \
        'check-jsonschema~=0.37'

# --- 2. pinned prebuilt binaries ---------------------------------------------
ARG EC_VERSION="3.11.1"
ARG ACTIONLINT_VERSION="1.7.12"
ARG GITLEAKS_VERSION="8.30.1"
ARG HADOLINT_VERSION="2.15.1"
ARG DCLINT_VERSION="3.1.0"

# `set -eu` only: pipefail already comes from the SHELL instruction above, and repeating
# it here makes shellcheck read the block as POSIX sh, where the option does not exist.
RUN set -eu; \
    curl -fsSL "https://github.com/editorconfig-checker/editorconfig-checker/releases/download/v${EC_VERSION}/ec-linux-amd64.tar.gz" \
        | tar -xz -C /tmp \
    && install -m0755 /tmp/bin/ec-linux-amd64 /usr/local/bin/ec \
    && rm -rf /tmp/bin; \
    curl -fsSL "https://github.com/rhysd/actionlint/releases/download/v${ACTIONLINT_VERSION}/actionlint_${ACTIONLINT_VERSION}_linux_amd64.tar.gz" \
        | tar -xz -C /tmp actionlint \
    && install -m0755 /tmp/actionlint /usr/local/bin/actionlint \
    && rm -f /tmp/actionlint; \
    curl -fsSL "https://github.com/gitleaks/gitleaks/releases/download/v${GITLEAKS_VERSION}/gitleaks_${GITLEAKS_VERSION}_linux_x64.tar.gz" \
        | tar -xz -C /tmp gitleaks \
    && install -m0755 /tmp/gitleaks /usr/local/bin/gitleaks \
    && rm -f /tmp/gitleaks; \
    curl -fsSL -o /usr/local/bin/hadolint \
        "https://github.com/hadolint/hadolint/releases/download/v${HADOLINT_VERSION}/hadolint-linux-x86_64" \
    && chmod 0755 /usr/local/bin/hadolint; \
    curl -fsSL -o /usr/local/bin/dclint \
        "https://github.com/zavoloklom/docker-compose-linter/releases/download/v${DCLINT_VERSION}/dclint-bullseye-amd64" \
    && chmod 0755 /usr/local/bin/dclint

# Fail the build when an asset name drifted, rather than the next commit.
RUN ec --version \
    && actionlint --version \
    && gitleaks version \
    && hadolint --version \
    && dclint --version \
    && yamllint --version \
    && gitlint --version \
    && check-jsonschema --version \
    && jq --version

# git refuses to operate on a bind-mounted worktree owned by another uid unless it is
# marked safe. The fleet always works on /workspace.
RUN git config --system --add safe.directory /workspace

ARG USER_UID="1000"
ARG USER_GID="1000"
RUN groupadd --gid "${USER_GID}" tpo42 \
    && useradd --uid "${USER_UID}" --gid "${USER_GID}" --create-home --shell /bin/bash tpo42

USER ${USER_UID}:${USER_GID}
WORKDIR /workspace
