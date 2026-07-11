#!/usr/bin/env bash
# Maintainer: William Canin <hello.williamcanin@gmail.com>

# --- VARIABLES ---
PKGVER="0.1.0"
PKGNAME="tildr"
REPO="orbitbits/tildr"
BRANCH="main"
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

if [ "$(id -u)" -eq 0 ]; then error "Do not run as root or sudo"; exit 1; fi

# --- URLs ---
_github_base="https://github.com/${REPO}"
_raw_base="https://raw.githubusercontent.com/${REPO}/${BRANCH}"
_release_base="${_github_base}/releases/download/v${PKGVER}"
_man_base="${_raw_base}/docs/man/dist"

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
download_sources() {
  local pkgdir="${BUILD_DIR}/${PKGNAME}_${PKGVER}_amd64"

  download "${_release_base}/tildr-${PKGVER}-linux-x86_64" \
    "${pkgdir}/usr/bin/tildr" "binary" || return 1
  chmod 755 "${pkgdir}/usr/bin/tildr"

  download "${_man_base}/tildr.1" \
    "${pkgdir}/usr/share/man/man1/tildr.1" "tildr.1" || return 1
  download "${_man_base}/tildr-config.1" \
    "${pkgdir}/usr/share/man/man1/tildr-config.1" "tildr-config.1" || return 1
  download "${_man_base}/tildr-commands.1" \
    "${pkgdir}/usr/share/man/man1/tildr-commands.1" "tildr-commands.1" || return 1
  download "${_man_base}/tildr-security.1" \
    "${pkgdir}/usr/share/man/man1/tildr-security.1" "tildr-security.1" || return 1
  download "${_man_base}/tildr-plugins.1" \
    "${pkgdir}/usr/share/man/man1/tildr-plugins.1" "tildr-plugins.1" || return 1

  download "${_raw_base}/tools/plugins/nautilus/tildr.py" \
    "${pkgdir}/usr/share/nautilus-python/extensions/tildr.py" "Nautilus plugin" || return 1
  download "${_raw_base}/tools/plugins/dolphin/tildr.desktop" \
    "${pkgdir}/usr/share/kio/servicemenus/tildr.desktop" "Dolphin plugin" || return 1

  download "${_raw_base}/LICENSE" \
    "${pkgdir}/usr/share/doc/${PKGNAME}/copyright" "LICENSE" || return 1
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

# --- Generate DEBIAN/conffiles ---
generate_conffiles() {
  local pkgdir="${BUILD_DIR}/${PKGNAME}_${PKGVER}_amd64"
  # No conffiles for this package
  touch "${pkgdir}/DEBIAN/conffiles"
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
    generate_conffiles
    build_deb
    ;;
  install)
    setup_deb_dirs
    download_sources
    generate_control
    generate_postinst
    generate_prerm
    generate_conffiles
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
