<!-- markdownlint-disable MD033 -->
<!-- markdownlint-disable MD041 -->

# Contributing to tildr-deb

## Prerequisites

```sh
# Ubuntu / Debian
sudo apt install -y dpkg-dev devscripts lintian curl git make gnupg

# Verify
dpkg-deb --version
make --version
```

## Project structure

```
tildr-deb/
├── debian/                     # Debian packaging files
│   ├── control                 # Package metadata
│   ├── rules                   # debhelper build rules
│   ├── changelog               # Package changelog
│   ├── copyright               # Copyright and license
│   ├── install                 # File installation mappings
│   ├── tildr.manpages          # Man pages to install
│   └── tildr.docs              # Documentation files
├── Makefile                    # Build commands
├── tools/
│   ├── main.sh                 # Build script (download, package, lint)
│   └── publish-repo.sh         # Local repo generation for testing
├── repo/
│   └── tildr.list              # APT sources list template
└── .github/workflows/
    ├── build-deb.yml           # CI build (push/PR)
    ├── release-from-tildr.yml  # Auto-release (weekly cron)
    └── publish-repo.yml        # Manual publish trigger
```

## Local development workflow

### 1. Build the DEB

```sh
make build
```

This downloads the binary and man pages from the latest tildr release on
GitHub, then builds the DEB. The output is in `debbuild/`.

### 2. Install locally (test)

```sh
make install
```

Builds and installs the DEB via `dpkg`. Use this to verify the package
works before publishing.

### 3. Lint the DEB package

```sh
make lint
```

Validates the built `.deb` with lintian.

### 4. Generate local repo (test)

```sh
make publish-repo
```

Creates a local APT repository in `repo/` for testing.

#### Test the local repo

```sh
# Start a local server
make serve   # or: bash tools/publish-repo.sh serve

# In another terminal, add the repo and install
echo "deb [signed-by=/usr/share/keyrings/tildr.gpg] http://localhost:8080/ stable main" | sudo tee /etc/apt/sources.list.d/tildr.list
sudo apt update && sudo apt install tildr
```

### 5. Clean

```sh
make clean
```

## Publishing a DEB manually

If you need to publish a release **without waiting for the Saturday cron**:

### Option A: Trigger the workflow from GitHub UI

1. Go to **Actions** → **Release from Tildr**
2. Click **Run workflow**
3. (workflow_dispatch does not require a tag input — it auto-detects the
   latest tildr release)

### Option B: Create a release directly

If the DEBs are already built locally:

```sh
# 1. Build
make build

# 2. Create GitHub release and upload DEBs
gh release create v0.1.0 \
  --title "Release v0.1.0" \
  --generate-notes \
  debbuild/*.deb
```

The `publish-repo.yml` workflow will pick up the new release
automatically and deploy to GitHub Pages.

## Commit conventions

This project follows [Conventional Commits](https://www.conventionalcommits.org/):

```
feat: add new feature
fix: correct something
docs: update documentation
chore: maintenance tasks
refactor: restructure code
```

## Workflows

| Workflow | Trigger | What it does |
|----------|---------|-------------|
| `build-deb.yml` | push/PR to main | Builds DEBs for Ubuntu Noble, runs lint |
| `release-from-tildr.yml` | cron (Saturday) + manual | Checks for new tildr release, builds + publishes if new |
| `publish-repo.yml` | release published | Downloads DEBs, generates metadata, signs, deploys to Pages |

## GitHub Secrets

| Secret | Description |
|--------|-------------|
| `GPG_PRIVATE_KEY` | GPG private key (ASCII-armored) for signing |
| `GPG_PASSPHRASE` | Passphrase for the GPG key |

Export your key (used only for local/manual verification — CI now exports
by fingerprint automatically, see `publish-repo.yml`):

```sh
gpg --export -a "$(gpg --list-secret-keys --with-colons | awk -F: '/^fpr:/{print $10; exit}')" > tildr-deb-pub.gpg
```

## APT repository structure (after publish)

```
https://orbitbits.com/tildr-deb/  (also reachable at https://orbitbits.github.io/tildr-deb/)
├── tildr-deb-pub.gpg
├── pool/
│   └── main/
│       └── tildr_0.1.0_amd64.deb
├── dists/
│   └── stable/
│       ├── InRelease
│       ├── Release
│       ├── Release.gpg
│       └── main/
│           └── binary-amd64/
│               ├── Packages
│               └── Packages.gz
```

## Supported Ubuntu versions

* Ubuntu 24.04 LTS (Noble)

---

&copy; [OrbitBits](https://orbitbits.com) - All rights reserved.
