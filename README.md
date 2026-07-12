<!-- markdownlint-disable MD033 -->
<!-- markdownlint-disable MD041 -->

<p align="center">
  <img style="border-radius: 5px;" src="https://raw.githubusercontent.com/orbitbits/tildr/refs/heads/main/.github/brand/logo-text/compact/tildr-variation-3.svg" alt="Tildr" width="180"/>
</p>

<h2 align="center">Declarative CLI for managing your Linux HOME directory.</h2>

## Installation (Ubuntu / Debian)

### Via Repository (Recommended)

```sh
# Import GPG key
curl -fsSL https://orbitbits.com/tildr-deb/tildr-deb-pub.gpg | sudo gpg --dearmor -o /usr/share/keyrings/tildr.gpg

# Add repository
echo "deb [signed-by=/usr/share/keyrings/tildr.gpg] https://orbitbits.com/tildr-deb/ stable main" | sudo tee /etc/apt/sources.list.d/tildr.list

# Install
sudo apt update && sudo apt install tildr
```

### Via Direct DEB Download

Download the `.deb` file from [releases](https://github.com/orbitbits/tildr/releases) and install:

```sh
sudo dpkg -i ./tildr_*.deb
sudo apt install -f  # Fix dependencies if needed
```

---

## Maintainer workflow

### Prerequisites

```sh
sudo apt install dpkg-dev devscripts lintian curl git gnupg
```

### Build package

```sh
make build
```

### Install package local (test)

```sh
make install
```

> Note: Always test with `make install` before publishing.

### Lint DEB package

```sh
make lint
```

### Show current version

```sh
make version
```

### Generate local repo (test)

```sh
make publish-repo
```

This creates a local APT repo structure in `repo/` for testing.

### Clean all build files

```sh
make clean
```

---

## Publishing a release

Releases are **fully automatic**. Every Saturday at 00:00 UTC a cron job
checks [orbitbits/tildr](https://github.com/orbitbits/tildr) for new
releases. When a new tag is detected, the workflow automatically:

1. Builds DEBs for Ubuntu Noble
2. Creates a GitHub Release with the DEBs attached
3. Publishes the APT repository to GitHub Pages

No manual intervention needed — just release on `tildr` and this repo
picks it up within a week.

### Manual trigger

You can also trigger the workflow manually from the Actions tab
(`workflow_dispatch`) to build immediately without waiting for the cron.

### Publishing to official Debian/Ubuntu

The flow above only covers **this repo's own releases** (distributed via
your own GitHub Pages repo). Submitting to the official Debian/Ubuntu
repositories goes through Debian's own review (ITP) and upload process,
and is intentionally **not** automated here — that step stays manual.

---

## GitHub Secrets (for maintainers)

| Secret            | Description                     |
|-------------------|---------------------------------|
| `GPG_PRIVATE_KEY` | GPG private key (ASCII-armored) |
| `GPG_PASSPHRASE`  | GPG key passphrase              |

Export your key:
```sh
gpg --export -a 'Your Key Name'
```

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for development setup, build workflow, and how to publish manually.

---

## Git helpers

```sh
make push          # push to all remotes
make push-lease    # push --force-with-lease to all remotes
```

---

## Templates in this repository

* `debian/control` — DEB package metadata
* `debian/rules` — debhelper build rules
* `debian/changelog` — Package changelog
* `debian/copyright` — Copyright and license info
* `debian/install` — File installation mappings
* `debian/tildr.manpages` — Man pages to install
* `tools/main.sh` — Build script with download, setup, and packaging logic
* `tools/publish-repo.sh` — Local APT repo generation script
* `.github/workflows/build-deb.yml` — CI build workflow (push/PR)
* `.github/workflows/release-from-tildr.yml` — Auto-release from tildr (weekly cron)
* `.github/workflows/publish-repo.yml` — APT repo publication to GitHub Pages
* `repo/tildr.list` — APT sources list configuration file

---

## Notes

* This repository does **not** contain the source code.
* The build script downloads the binary directly from GitHub releases.
* Always test with `make install` before publishing.

---

## Supported distros

* Ubuntu 24.04 LTS (Noble)
* Debian 12 (Bookworm)
* Any Debian-based distro with `dpkg`

---

## Official page

https://orbitbits.com/tildr/

---

&copy; [OrbitBits](https://orbitbits.com) - All rights reserved.
