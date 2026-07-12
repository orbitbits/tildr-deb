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

Download the `.deb` file from [releases](https://github.com/orbitbits/tildr-deb/tree/gh-pages/pool/main) and install:

```sh
sudo dpkg -i ./tildr_*.deb
sudo apt install -f  # Fix dependencies if needed
```

## Supported distros

* Ubuntu 24.04 LTS (Noble)
* Debian 12 (Bookworm)
* Any Debian-based distro with `dpkg`

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## Official page

[https://orbitbits.com/tildr](https://orbitbits.com/tildr)

---

&copy; [OrbitBits](https://orbitbits.com) - All rights reserved.
