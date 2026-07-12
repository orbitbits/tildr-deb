#!/usr/bin/env bash
# Maintainer: William Canin <hello.williamcanin@gmail.com>
set -euo pipefail

# --- VARIABLES ---
# PKGVER can be injected by CI (e.g. from a repository_dispatch payload).
# Falls back to the version pinned in debian/changelog for local/manual builds.
# Strips leading 'v' if present (e.g. "v0.1.0" → "0.1.0").
PKGVER="${PKGVER:-$(head -1 debian/changelog | grep -oP '\(.*?\)' | tr -d '()')}"
PKGVER="${PKGVER#v}"
PKGNAME="tildr"
REPO="orbitbits/tildr"
TAG="v${PKGVER}"
BUILD_DIR="debbuild"

# --- UI ---
info()    { printf "\033[0;36m-> %s\033[0m\n" "$1"; }
error()   { printf "\033[0;31mx %s\033[0m\n" "$1"; }
success() { printf "\033[0;32m* %s\033[0m\n" "$1"; }
warn()    { printf "\033[0;33m! %s\033[0m\n" "$1"; }

# --- Checks ---
[ "$(uname -s)" != "Linux" ] && { error "Linux only"; exit 1; }
[ "$(uname -m)" != "x86_64" ] && { error "Only x86_64 supported"; exit 1; }
command -v git >/dev/null || { error "git is required"; exit 1; }
command -v dpkg-deb >/dev/null || { error "dpkg-deb not found. Install: apt install dpkg-dev"; exit 1; }

if [ "$(id -u)" -eq 0 ] && [ -z "${CI:-}" ]; then
  error "Do not run as root or sudo"
  exit 1
fi

# --- URLs ---
# NOTE: sources are pinned to the release tag (${TAG}), never to "main".
# This guarantees the package always matches exactly what was released,
# even if the main branch has moved on since then.
_github_base="https://github.com/${REPO}"
_release_base="${_github_base}/releases/download/${TAG}"
_tarball_url="https://api.github.com/repos/${REPO}/tarball/${TAG}"
_binary_name="${PKGNAME}-${PKGVER}-linux-x86_64"

# --- Create debbuild structure ---
setup_deb_dirs() {
  local pkgdir="${BUILD_DIR}/${PKGNAME}_${PKGVER}_amd64"
  mkdir -p "${pkgdir}/DEBIAN"
  mkdir -p "${pkgdir}/usr/bin"
  mkdir -p "${pkgdir}/usr/share/man/man1"
  mkdir -p "${pkgdir}/usr/share/nautilus-python/extensions"
  mkdir -p "${pkgdir}/usr/share/kio/servicemenus"
  mkdir -p "${pkgdir}/usr/share/doc/${PKGNAME}"
}

# --- Download with error handling ---
download() {
  local url="$1"
  local dest="$2"
  local label="$3"

  info "Downloading ${label}..."
  if ! curl -sLf "${url}" -o "${dest}"; then
    error "Failed to download ${label}"
    return 1
  fi
}

# --- Download sources ---
# Binary comes from the GitHub release; man pages, plugins and LICENSE
# are extracted from the auto-generated source tarball for the tag.
download_sources() {
  local pkgdir="${BUILD_DIR}/${PKGNAME}_${PKGVER}_amd64"

  download "${_release_base}/${_binary_name}" \
    "${pkgdir}/usr/bin/tildr" "release binary (${_binary_name})" || {
    error "Could not find ${_binary_name} on the ${TAG} release."
    error "Make sure the Tildr release workflow publishes a linux binary"
    error "for this version before retrying."
    return 1
  }
  chmod 755 "${pkgdir}/usr/bin/tildr"

  local tmp_tarball
  tmp_tarball=$(mktemp -d)

  download "${_tarball_url}" \
    "${tmp_tarball}/source.tar.gz" "source tarball (${TAG})" || {
    error "Could not download source tarball for ${TAG}."
    rm -rf "${tmp_tarball}"
    return 1
  }

  info "Extracting source tarball..."
  tar -xzf "${tmp_tarball}/source.tar.gz" -C "${tmp_tarball}" || {
    error "Failed to extract source tarball"
    rm -rf "${tmp_tarball}"
    return 1
  }

  local src_root
  src_root=$(find "${tmp_tarball}" -mindepth 1 -maxdepth 1 -type d -name "*-${REPO##*/}-*" | head -1)
  if [ -z "${src_root}" ]; then
    error "Could not locate extracted source directory inside tarball"
    rm -rf "${tmp_tarball}"
    return 1
  fi

  local man_files=(
    "tildr.1"
    "tildr-config.1"
    "tildr-commands.1"
    "tildr-security.1"
    "tildr-plugins.1"
  )
  for mf in "${man_files[@]}"; do
    if [ -f "${src_root}/docs/man/dist/${mf}" ]; then
      cp "${src_root}/docs/man/dist/${mf}" "${pkgdir}/usr/share/man/man1/${mf}"
    else
      error "Man page ${mf} not found in source tarball"
      rm -rf "${tmp_tarball}"
      return 1
    fi
  done

  if [ -f "${src_root}/tools/plugins/nautilus/tildr.py" ]; then
    cp "${src_root}/tools/plugins/nautilus/tildr.py" "${pkgdir}/usr/share/nautilus-python/extensions/tildr.py"
  else
    error "Nautilus plugin not found in source tarball"
    rm -rf "${tmp_tarball}"
    return 1
  fi

  if [ -f "${src_root}/tools/plugins/dolphin/tildr.desktop" ]; then
    cp "${src_root}/tools/plugins/dolphin/tildr.desktop" "${pkgdir}/usr/share/kio/servicemenus/tildr.desktop"
  else
    error "Dolphin plugin not found in source tarball"
    rm -rf "${tmp_tarball}"
    return 1
  fi

  if [ -f "${src_root}/LICENSE" ]; then
    cp "${src_root}/LICENSE" "${pkgdir}/usr/share/doc/${PKGNAME}/copyright"
  else
    error "LICENSE not found in source tarball"
    rm -rf "${tmp_tarball}"
    return 1
  fi

  rm -rf "${tmp_tarball}"
}

# --- Generate DEBIAN/control ---
generate_control() {
  local pkgdir="${BUILD_DIR}/${PKGNAME}_${PKGVER}_amd64"

  cat > "${pkgdir}/DEBIAN/control" <<EOF
Package: ${PKGNAME}
Version: ${PKGVER}
Section: utils
Priority: optional
Architecture: amd64
Depends: git, less
Recommends: nautilus-python, dolphin
Maintainer: William Canin <hello.williamcanin@gmail.com>
Homepage: https://orbitbits.com/tildr
Description: Declarative CLI for managing your Linux HOME directory
 Tildr is a declarative CLI tool for managing your Linux HOME directory
 using symlinks and Git. It provides a simple way to dotfile management
 across multiple machines.
 .
 Features include: init, add, apply, status, list, sync, restore,
 unlink, and more. Supports Nautilus and Dolphin file manager plugins.
Installed-Size: $(du -sk "${pkgdir}" | cut -f1)
EOF
}

# --- Generate DEBIAN/postinst ---
generate_postinst() {
  local pkgdir="${BUILD_DIR}/${PKGNAME}_${PKGVER}_amd64"

  cat > "${pkgdir}/DEBIAN/postinst" <<'POSTINST'
#!/bin/sh
set -e
if [ "$1" = "configure" ]; then
  # Compress man pages if not already compressed
  if command -v gzip >/dev/null 2>&1; then
    for f in /usr/share/man/man1/tildr*.1; do
      if [ -f "$f" ] && [ ! -f "${f}.gz" ]; then
        gzip -9 "$f"
      fi
    done
  fi
fi
POSTINST
  chmod 755 "${pkgdir}/DEBIAN/postinst"
}

# --- Generate DEBIAN/prerm ---
generate_prerm() {
  local pkgdir="${BUILD_DIR}/${PKGNAME}_${PKGVER}_amd64"

  cat > "${pkgdir}/DEBIAN/prerm" <<'PRERM'
#!/bin/sh
set -e
if [ "$1" = "remove" ]; then
  # Remove compressed man pages
  rm -f /usr/share/man/man1/tildr*.1.gz
fi
PRERM
  chmod 755 "${pkgdir}/DEBIAN/prerm"
}

# --- Build DEB ---
build_deb() {
  info "Building DEB package..."
  local pkgdir="${BUILD_DIR}/${PKGNAME}_${PKGVER}_amd64"
  local deb_file="${BUILD_DIR}/${PKGNAME}_${PKGVER}_amd64.deb"

  dpkg-deb --build "${pkgdir}" "${deb_file}"
  expectation $? success "Success! DEB build complete"
}

# --- Install DEB ---
install_deb() {
  info "Building and installing DEB package..."
  local pkgdir="${BUILD_DIR}/${PKGNAME}_${PKGVER}_amd64"
  local deb_file="${BUILD_DIR}/${PKGNAME}_${PKGVER}_amd64.deb"

  dpkg-deb --build "${pkgdir}" "${deb_file}"
  expectation $? success "Build complete. Installing..."

  if [ -f "$deb_file" ]; then
    info "Installing: ${deb_file}"
    sudo dpkg -i "${deb_file}"
    expectation $? success "Success! Install complete"
  else
    error "DEB file not found"
    exit 1
  fi
}

# --- Lint DEB ---
lint_deb() {
  if ! command -v lintian >/dev/null 2>&1; then
    warn "lintian not found. Install: apt install lintian"
    return 1
  fi

  local deb_file="${BUILD_DIR}/${PKGNAME}_${PKGVER}_amd64.deb"
  if [ ! -f "$deb_file" ]; then
    warn "No DEB found. Run 'make build' first."
    return 1
  fi

  info "Linting DEB package..."
  lintian "$deb_file"
  expectation $? success "Lint passed"
}

# --- Clean ---
clean_build() {
  info "Cleaning build files..."
  rm -rf "${BUILD_DIR}"
  expectation $? success "Clean complete"
}

# --- Expectation helper ---
expectation() {
  local status=$1
  local cmd=$2
  local msg=$3

  if [ "$status" -eq 0 ]; then
    "$cmd" "$msg"
  fi
}

# --- Menu ---
case "${1:-}" in
  build)
    setup_deb_dirs
    download_sources
    generate_control
    generate_postinst
    generate_prerm
    build_deb
    ;;
  install)
    setup_deb_dirs
    download_sources
    generate_control
    generate_postinst
    generate_prerm
    install_deb
    ;;
  lint)
    lint_deb
    ;;
  clean)
    clean_build
    ;;
  *)
    error "Unknown command: $1"
    printf "Usage: %s [build|install|lint|clean]\n" "$0"
    exit 1
    ;;
esac
