#!/usr/bin/env bash
# Maintainer: William Canin <hello.williamcanin@gmail.com>
#
# Local script to test APT repository generation.
# This simulates what the GitHub Actions workflow does.
set -euo pipefail

# --- VARIABLES ---
BUILD_DIR="debbuild"
REPO_DIR="repo"
UBUNTU_CODENAMES="noble"

# --- UI ---
info()    { printf "\033[0;36m-> %s\033[0m\n" "$1"; }
error()   { printf "\033[0;31mx %s\033[0m\n" "$1"; }
success() { printf "\033[0;32m* %s\033[0m\n" "$1"; }

# --- Checks ---
[ "$(uname -s)" != "Linux" ] && { error "Linux only"; exit 1; }
command -v dpkg-scanpackages >/dev/null || { error "dpkg-scanpackages not found. Install: apt install dpkg-dev"; exit 1; }
command -v gpg >/dev/null || { error "gpg not found"; exit 1; }

if [ "$(id -u)" -eq 0 ] && [ -z "${CI:-}" ]; then
  error "Do not run as root or sudo"
  exit 1
fi

# --- Find DEB ---
find_deb() {
  local deb_file
  deb_file=$(find "${BUILD_DIR}" -name "*.deb" -type f 2>/dev/null | head -1)
  if [ -z "$deb_file" ]; then
    error "No DEB found in ${BUILD_DIR}. Run 'make build' first."
    exit 1
  fi
  echo "$deb_file"
}

# --- Setup repo structure ---
setup_repo() {
  info "Setting up repo structure..."
  mkdir -p "${REPO_DIR}/pool/main"
  for codename in $UBUNTU_CODENAMES; do
    mkdir -p "${REPO_DIR}/dists/${codename}/main/binary-amd64"
  done
}

# --- Copy DEBs ---
copy_debs() {
  local deb_file="$1"
  info "Copying DEB to repo..."
  cp "$deb_file" "${REPO_DIR}/pool/main/"
}

# --- Generate metadata ---
generate_metadata() {
  info "Generating repository metadata..."
  for codename in $UBUNTU_CODENAMES; do
    local dir="${REPO_DIR}/dists/${codename}/main/binary-amd64"
    if [ -d "$dir" ]; then
      dpkg-scanpackages --arch amd64 "${REPO_DIR}/pool/" /dev/null > "${dir}/Packages"
      gzip -9 -k -f "${dir}/Packages"
      # Create Release file
      cd "${REPO_DIR}" || exit
      cat > "dists/${codename}/Release" <<EOF
Origin: Tildr
Label: Tildr APT Repository
Suite: stable
Codename: ${codename}
Architectures: amd64
Components: main
Description: APT repository for Tildr
Date: $(date -Ru)
EOF
      cd - >/dev/null || exit
    fi
  done
}

# --- Sign packages ---
sign_packages() {
  info "Signing Packages files..."
  for codename in $UBUNTU_CODENAMES; do
    local packages_gz="${REPO_DIR}/dists/${codename}/main/binary-amd64/Packages.gz"
    if [ -f "$packages_gz" ]; then
      gpg --detach-sign --armor "$packages_gz"
    fi
  done
}

# --- Test server ---
test_server() {
  info "Starting test server on http://localhost:8080"
  info "Press Ctrl+C to stop"
  echo
  cd "${REPO_DIR}" || exit
  python3 -m http.server 8080
}

# --- Menu ---
case "${1:-}" in
  setup)
    setup_repo
    success "Repo structure created"
    ;;
  copy)
    DEB=$(find_deb)
    setup_repo
    copy_debs "$DEB"
    success "DEBs copied"
    ;;
  metadata)
    generate_metadata
    sign_packages
    success "Metadata generated and signed"
    ;;
  generate)
    DEB=$(find_deb)
    setup_repo
    copy_debs "$DEB"
    generate_metadata
    sign_packages
    success "Full repo generated"
    ;;
  serve)
    test_server
    ;;
  *)
    error "Unknown command: $1"
    printf "Usage: %s [setup|copy|metadata|generate|serve]\n" "$0"
    echo
    echo "  setup     - Create repo directory structure"
    echo "  copy      - Copy built DEB to repo"
    echo "  metadata  - Generate and sign repo metadata"
    echo "  generate  - Full pipeline (copy + metadata)"
    echo "  serve     - Start local test server on port 8080"
    exit 1
    ;;
esac
