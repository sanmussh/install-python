#!/usr/bin/env bash
set -Eeuo pipefail

DEFAULT_VERSION="3.14.6"
VERSION="$DEFAULT_VERSION"
PREFIX_BASE="/opt/python"
SET_DEFAULT="false"
KEEP_BUILD_DIR="false"
SKIP_DEPS="false"
UPGRADE_PIP="false"
BUILD_DIR=""

usage() {
  cat <<'EOF'
Install Python from official CPython source.

Usage:
  bash install-python.sh [options]

Options:
  --version VERSION     Python version to install. Default: 3.14.6
  --prefix PATH         Base install directory. Default: /opt/python
                        Final path will be PATH/VERSION.
  --set-default         Also create python and pip commands in /usr/local/bin.
                        Without this option, only pythonX.Y and pipX.Y are created.
  --skip-deps           Skip dependency installation.
  --upgrade-pip         Upgrade pip, setuptools, and wheel from PyPI after install.
  --keep-build-dir      Keep the temporary build directory.
  -h, --help            Show this help message.

Examples:
  bash install-python.sh
  bash install-python.sh --version 3.14.6
  bash install-python.sh --version 3.14.6 --set-default
  bash install-python.sh --version 3.14.6 --prefix /usr/local/python
EOF
}

log() {
  printf '\033[1;34m[INFO]\033[0m %s\n' "$*"
}

warn() {
  printf '\033[1;33m[WARN]\033[0m %s\n' "$*" >&2
}

die() {
  printf '\033[1;31m[ERROR]\033[0m %s\n' "$*" >&2
  exit 1
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Command not found: $1"
}

is_root() {
  [ "$(id -u)" -eq 0 ]
}

run_as_root() {
  if is_root; then
    "$@"
  else
    need_cmd sudo
    sudo "$@"
  fi
}

cleanup() {
  if [ -n "${BUILD_DIR:-}" ] && [ "$KEEP_BUILD_DIR" != "true" ] && [ -d "$BUILD_DIR" ]; then
    rm -rf "$BUILD_DIR"
  fi
}
trap cleanup EXIT

parse_args() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --version)
        [ "$#" -ge 2 ] || die "--version requires a value."
        VERSION="$2"
        shift 2
        ;;
      --prefix)
        [ "$#" -ge 2 ] || die "--prefix requires a value."
        PREFIX_BASE="${2%/}"
        shift 2
        ;;
      --set-default)
        SET_DEFAULT="true"
        shift
        ;;
      --skip-deps)
        SKIP_DEPS="true"
        shift
        ;;
      --upgrade-pip)
        UPGRADE_PIP="true"
        shift
        ;;
      --keep-build-dir)
        KEEP_BUILD_DIR="true"
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        die "Unknown option: $1"
        ;;
    esac
  done
}

validate_version() {
  [[ "$VERSION" =~ ^[0-9]+[.][0-9]+[.][0-9]+$ ]] || die "Version must look like 3.14.6."

  MAJOR="${VERSION%%.*}"
  REST="${VERSION#*.}"
  MINOR="${REST%%.*}"
  PY_ABI="${MAJOR}.${MINOR}"

  [ -n "$MAJOR" ] && [ -n "$MINOR" ] || die "Version must look like 3.14.6."
  [ "$MAJOR" = "3" ] || warn "This script is intended for Python 3.x, but got $VERSION."
}

detect_os() {
  if [ ! -r /etc/os-release ]; then
    die "Cannot detect Linux distribution because /etc/os-release is missing."
  fi

  # shellcheck disable=SC1091
  . /etc/os-release
  OS_ID="${ID:-}"
  OS_LIKE="${ID_LIKE:-}"
}

install_deps_debian() {
  log "Installing build dependencies with apt-get..."
  run_as_root apt-get update
  run_as_root apt-get install -y \
    build-essential pkg-config wget curl ca-certificates \
    libssl-dev zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev \
    libncursesw5-dev xz-utils tk-dev libffi-dev liblzma-dev \
    libgdbm-dev libgdbm-compat-dev uuid-dev libzstd-dev
}

install_deps_fedora() {
  local pkg_manager="$1"

  log "Installing build dependencies with $pkg_manager..."
  run_as_root "$pkg_manager" install -y \
    gcc gcc-c++ make pkgconfig wget curl ca-certificates tar gzip \
    openssl-devel zlib-devel bzip2-devel readline-devel sqlite-devel \
    ncurses-devel xz-devel tk-devel libffi-devel xz-libs \
    gdbm-devel libuuid-devel libzstd-devel
}

install_deps() {
  if [ "$SKIP_DEPS" = "true" ]; then
    warn "Skipping dependency installation."
    return
  fi

  if command -v apt-get >/dev/null 2>&1; then
    install_deps_debian
  elif command -v dnf >/dev/null 2>&1; then
    install_deps_fedora dnf
  elif command -v yum >/dev/null 2>&1; then
    install_deps_fedora yum
  else
    die "Unsupported package manager. Use --skip-deps and install build dependencies manually."
  fi
}

choose_downloader() {
  if command -v curl >/dev/null 2>&1; then
    DOWNLOADER="curl"
  elif command -v wget >/dev/null 2>&1; then
    DOWNLOADER="wget"
  else
    die "curl or wget is required."
  fi
}

download_python() {
  local tarball="Python-${VERSION}.tgz"
  local url="https://www.python.org/ftp/python/${VERSION}/${tarball}"

  BUILD_DIR="$(mktemp -d)"
  log "Using build directory: $BUILD_DIR"
  cd "$BUILD_DIR"

  log "Downloading $url"
  if [ "$DOWNLOADER" = "curl" ]; then
    curl -fL --retry 3 --connect-timeout 20 -o "$tarball" "$url"
  else
    wget -O "$tarball" "$url"
  fi

  log "Extracting $tarball"
  tar -xzf "$tarball"
  cd "Python-${VERSION}"
}

build_and_install() {
  local prefix="${PREFIX_BASE}/${VERSION}"

  log "Configuring Python $VERSION for install path: $prefix"
  ./configure \
    --prefix="$prefix" \
    --enable-optimizations \
    --with-lto

  log "Building Python. This can take a while..."
  make -j"$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 1)"

  log "Installing with make altinstall..."
  run_as_root make altinstall

  PYTHON_BIN="${prefix}/bin/python${PY_ABI}"
  PIP_BIN="${prefix}/bin/pip${PY_ABI}"

  [ -x "$PYTHON_BIN" ] || die "Python binary was not found after install: $PYTHON_BIN"

  log "Ensuring pip is available..."
  run_as_root "$PYTHON_BIN" -m ensurepip --upgrade

  if [ "$UPGRADE_PIP" = "true" ]; then
    log "Upgrading pip, setuptools, and wheel from PyPI..."
    run_as_root "$PYTHON_BIN" -m pip install --upgrade pip setuptools wheel
  fi

  if [ ! -x "$PIP_BIN" ]; then
    PIP_BIN="${prefix}/bin/pip3"
  fi
}

create_links() {
  local python_link="/usr/local/bin/python${PY_ABI}"
  local pip_link="/usr/local/bin/pip${PY_ABI}"

  log "Creating versioned command links..."
  run_as_root mkdir -p /usr/local/bin
  run_as_root ln -sfn "$PYTHON_BIN" "$python_link"

  if [ -x "$PIP_BIN" ]; then
    run_as_root ln -sfn "$PIP_BIN" "$pip_link"
  fi

  if [ "$SET_DEFAULT" = "true" ]; then
    log "Creating default python and pip command links in /usr/local/bin..."
    run_as_root ln -sfn "$PYTHON_BIN" /usr/local/bin/python
    if [ -x "$PIP_BIN" ]; then
      run_as_root ln -sfn "$PIP_BIN" /usr/local/bin/pip
    fi
  else
    warn "Default python command was not changed. Use --set-default if you want /usr/local/bin/python."
  fi
}

verify_install() {
  log "Verifying installation..."
  "$PYTHON_BIN" --version
  "$PYTHON_BIN" -m pip --version

  cat <<EOF

Installed successfully.

Install directory:
  ${PREFIX_BASE}/${VERSION}

Versioned commands:
  python${PY_ABI}
  pip${PY_ABI}

EOF

  if [ "$SET_DEFAULT" = "true" ]; then
    cat <<'EOF'
Default commands were enabled:
  python
  pip

EOF
  else
    cat <<EOF
Default commands were not changed.
To use this Python directly, run:
  python${PY_ABI}

To make python and pip point to this installation, reinstall with:
  bash install-python.sh --version ${VERSION} --set-default

EOF
  fi
}

main() {
  parse_args "$@"
  validate_version
  detect_os

  log "Detected OS: ${PRETTY_NAME:-$OS_ID}"
  log "Python version: $VERSION"
  log "Install base: $PREFIX_BASE"

  need_cmd id

  install_deps
  need_cmd tar
  need_cmd make
  choose_downloader
  download_python
  build_and_install
  create_links
  verify_install
}

main "$@"
