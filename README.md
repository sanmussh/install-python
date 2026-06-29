# install-python

One-command Python source installer for Linux.

This script downloads official CPython source code, installs build dependencies, compiles Python, installs it under `/opt/python/<version>` by default, and creates safe command links in `/usr/local/bin`.

## Quick Start

Install the default Python version:

```bash
curl -fsSL https://raw.githubusercontent.com/yourname/install-python/main/install-python.sh | bash
```

After installation, use:

```bash
python3.14
pip3.14
```

## Install a Specific Version

```bash
curl -fsSL https://raw.githubusercontent.com/yourname/install-python/main/install-python.sh | bash -s -- --version 3.14.6
```

## Make `python` and `pip` Point to the New Installation

By default, this script does not change `python` or `pip`.

If you want `python` and `pip` to point to the installed version, use:

```bash
curl -fsSL https://raw.githubusercontent.com/yourname/install-python/main/install-python.sh | bash -s -- --version 3.14.6 --set-default
```

This creates:

```text
/usr/local/bin/python -> /opt/python/3.14.6/bin/python3.14
/usr/local/bin/pip    -> /opt/python/3.14.6/bin/pip3.14
```

It does not delete or overwrite `/usr/bin/python`, `/usr/bin/python3`, or `/usr/bin/pip`.

## Set Default Later Without Reinstalling

If you first installed with the default behavior and later want `python` and `pip` to point to that existing installation, use:

```bash
curl -fsSL https://raw.githubusercontent.com/yourname/install-python/main/install-python.sh | bash -s -- --version 3.14.6 --set-default-only
```

This only creates command links. It does not download, build, or reinstall Python.

## Custom Install Directory

```bash
curl -fsSL https://raw.githubusercontent.com/yourname/install-python/main/install-python.sh | bash -s -- --version 3.14.6 --prefix /usr/local/python
```

The final install directory will be:

```text
/usr/local/python/3.14.6
```

## Safer Two-Step Install

If you want to inspect the script first:

```bash
curl -fsSL https://raw.githubusercontent.com/yourname/install-python/main/install-python.sh -o install-python.sh
bash install-python.sh --version 3.14.6
```

## Options

```text
--version VERSION     Python version to install. Default: 3.14.6
--prefix PATH         Base install directory. Default: /opt/python
--set-default         Also create python and pip commands in /usr/local/bin
--set-default-only    Only make python and pip point to an existing installation
--skip-deps           Skip dependency installation
--upgrade-pip         Upgrade pip, setuptools, and wheel from PyPI after install
--keep-build-dir      Keep the temporary build directory
-h, --help            Show help
```

## Where Things Are Installed

For Python `3.14.6`, the real installation is:

```text
/opt/python/3.14.6
```

The versioned command links are:

```text
/usr/local/bin/python3.14
/usr/local/bin/pip3.14
```

If `--set-default` is used, these links are also created:

```text
/usr/local/bin/python
/usr/local/bin/pip
```

## Supported Systems

The script supports common Linux distributions that use:

- `apt-get`, such as Ubuntu and Debian
- `dnf`, such as Fedora, modern RHEL, CentOS Stream, AlmaLinux, and Rocky Linux
- `yum`, such as older CentOS and RHEL systems

## Uninstall

For Python `3.14.6`, remove the install directory and command links:

```bash
sudo rm -rf /opt/python/3.14.6
sudo rm -f /usr/local/bin/python3.14 /usr/local/bin/pip3.14
```

If you used `--set-default`, also remove:

```bash
sudo rm -f /usr/local/bin/python /usr/local/bin/pip
```
