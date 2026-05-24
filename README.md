# nix-secrets

This repository manages secrets for my personal [Nix configurations](https://github.com/vipulog/nix-config) using [sops-nix](https://github.com/Mic92/sops-nix).

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Repository Structure](#repository-structure)
  - [Access Control](#access-control)
- [Usage](#usage)
  - [Flake Integration](#flake-integration)
  - [NixOS Configuration](#nixos-configuration)
  - [Home Manager Configuration](#home-manager-configuration)

## Overview

This repository is designed to be imported as a flake input into my personal Nix configurations, providing a structured approach to secret management using `sops` with `age` keys.

## Prerequisites

Before using this repository, you should already be familiar with the following tools and concepts:

- **Nix flakes**: how flake inputs and outputs work, and how to reference them in NixOS or Home Manager configurations.
- **SOPS (Secrets OPerationS)**: the basic workflow for encrypting and decrypting files using `sops`.
- **age**: understanding how `age` keys work, including the difference between recipients and private keys.
- **sops-nix**: how it integrates with NixOS and Home Manager to transparently decrypt secrets.
- **SSH host keys**: familiarity with their purpose and location (e.g., `/etc/ssh/ssh_host_ed25519_key`).

If you’re new to any of these, read the following resources first:

- [NixOS Flakes](https://nixos.wiki/wiki/Flakes)
- [mozilla/sops](https://github.com/mozilla/sops)
- [FiloSottile/age](https://github.com/FiloSottile/age)
- [Mic92/sops-nix](https://github.com/Mic92/sops-nix)
- [OpenSSH Host Keys](https://wiki.archlinux.org/title/OpenSSH#Host_keys)

## Repository Structure

All secrets in this repository are encrypted with `sops` and are stored under:

- **Path**: `secrets/sops/`

The secret files are organized by their intended scope:

- `shared.yaml`: Secrets common to all machines and users.
- `[user].yaml`: Secrets specific to a user (e.g., `vipul.yaml`).
- `[host].yaml`: Secrets specific to a host machine (e.g., `laptop.yaml`).
- `[user]_[host].yaml`: Secrets for a specific user on a particular machine (e.g., `vipul_laptop.yaml`).

### Access Control

Access control to these secret files is managed through a key-based system powered by `age`. The central `.sops.yaml` file defines which keys can decrypt which secret files.

These keys are organized into two main categories:

- **User Keys**: Each user has a unique `age` key.

  - Some users may have _delegated_ keys for use on specific machines (e.g. `user_machine` keys).

  - The `vipul` key is included in all encryption rules, effectively granting administrative access to every secret.

- **Host Keys**: Each host’s `age` recipient is derived from its SSH host key, allowing the system to decrypt secrets automatically at runtime.

Example `.sops.yaml`:

```yaml
creation_rules:
  # Rule 1: Secrets for the 'laptop' host
  # Encrypted by the laptop's host key.
  # The 'vipul' key is included in all rules to ensure the administrator can
  # always manage and decrypt any secret.
  - path_regex: secrets/sops/laptop\.yaml$
    age:
      - age1...[vipul_public_key]
      - age1...[laptop_ssh_public_key]

  # Rule 2: Secrets for user 'alice' on the 'laptop'
  # Encrypted by both the user's main key and a delegated key for this machine.
  # This separation is ideal for secrets managed by Home Manager that should
  # only be accessible to 'alice' on this specific host.
  - path_regex: secrets/sops/alice_laptop\.yaml$
    age:
      - age1...[vipul_public_key]
      - age1...[alice_public_key]
      - age1...[alice_on_laptop_delegated_public_key]

  # Rule 3: Shared secrets
  # Encrypted by all host and user keys to ensure that any authorized system
  # or user can access these values. Useful for shared tokens, credentials,
  # or service configuration shared across environments.
  - path_regex: secrets/sops/shared\.yaml$
    age:
      - age1...[vipul_public_key]
      - age1...[alice_public_key]
      - age1...[laptop_ssh_public_key]
      - age1...[alice_on_laptop_delegated_public_key]
      - age1...[server_ssh_public_key]

```

## Usage

### Flake Integration

To use this repository in your Nix configuration, add it as an input in your `flake.nix`:

```nix
{
  inputs = {
    # ... other inputs
    nix-secrets.url = "github:vipulog/nix-secrets/main?shallow=1";
    nix-secrets.inputs.nixpkgs.follows = "nixpkgs";

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # ... other inputs
  };
}
```

### NixOS Configuration

**1. Enable `sops-nix` for the Host**

First, import the `sops-nix` module in your NixOS configuration. Then, configure it to use the host's specific secret file and its SSH host key for decryption.

For a host named `laptop`:

```nix
{ inputs, ... }:
let
  sopsFolder = inputs.nix-secrets + "/secrets/sops";
in {
  imports = [ inputs.sops-nix.nixosModules.sops ];

  sops = {
    # Path to the default secrets file for this host
    defaultSopsFile = "${sopsFolder}/laptop.yaml";

    # Allow the host to decrypt its secrets using its SSH key
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
  };
}
```

**2. Accessing Secrets in Your Configuration**

Once `sops-nix` is enabled, you can reference the secrets in your configuration.

**Example: Using a host-specific secret**

Let's assume your `secrets/sops/laptop.yaml` file contains a password hash for the user `vipul`:

```yaml
# secrets/sops/laptop.yaml
passwords:
    vipul: "some-encrypted-password-hash-here"
```

You can use this secret to set the user's password:

```nix
{ config, ... }: {
  sops.secrets."passwords/vipul".neededForUsers = true;
  users.users.vipul.hashedPasswordFile = config.sops.secrets."passwords/vipul".path;
}
```

**Example: Using a secret from other sops fie**

To use secrets from a file other than the default, specify the `sopsFile` attribute explicitly.

Assuming your `secrets/sops/shared.yaml` contains:

```yaml
# secrets/sops/shared.yaml
nix-access-tokens: "some-encrypted-nix-token"
```

You would access it like this:

```nix
{ config, inputs, ... }:
let
  sopsFolder = inputs.nix-secrets + "/secrets/sops";
in
{
  sops.secrets."nix-access-tokens".sopsFile = "${sopsFolder}/shared.yaml";

  nix.extraOptions = ''
    !include ${config.sops.secrets."nix-access-tokens".path}
  '';
}
```

### Home Manager Configuration

There are two primary methods for enabling `sops-nix` in Home Manager, depending on whether the host system is managed by NixOS.

**Method 1: Secret Handover from NixOS (Recommended)**

This method uses the NixOS configuration to securely decrypt and place the user's private `age` key into their home directory, where Home Manager can then access it.

**1. Store the User's Private Key as a Secret**

First, ensure the user's private `age` key is itself encrypted in a sops file. For this example, let's assume it's in `vipul_laptop.yaml`:

```yaml
# secrets/sops/vipul_laptop.yaml
keys:
    age:
        vipul_laptop: "AGE-SECRET-KEY-..."
```

**2. Configure the Handover in NixOS**

In your NixOS configuration, define the key as a secret and set its path and ownership. This tells `sops-nix` to decrypt the key and write it to a file that the user owns.

```nix
# in your NixOS configuration for 'laptop'
{ config, ... }:
let
  userCfg = config.users.users.vipul;
in
{
  sops.secrets."keys/age/vipul_laptop" = {
    owner = userCfg.name;
    inherit (userCfg) group;
    path = "${userCfg.home}/.config/sops/age/keys.txt";
  };
}
```

**3. Configure Home Manager to Use the Key**

Finally, configure `sops-nix` in your Home Manager setup to use the key file that NixOS provisioned.

```nix
# in your Home Manager configuration for 'vipul' on 'laptop'
{ inputs, config, ... }:
let
  inherit (config.home) homeDirectory;
  sopsFolder = inputs.nix-secrets + "/secrets/sops";
in
{
  imports = [ inputs.sops-nix.homeManagerModules.sops ];

  sops = {
    defaultSopsFile = "${sopsFolder}/vipul_laptop.yaml";
    age.keyFile = "${homeDirectory}/.config/sops/age/keys.txt";
  };
}
```

**Method 2: Standalone Home Manager Setup**

If you are not using NixOS, you can configure `sops-nix` by manually placing the private `age` key in the required location.

**1. Create the Key File Manually**

On the target machine, create the file `~/.config/sops/age/keys.txt`. Paste your raw private key into this file and save it. Ensure the file has restrictive permissions (e.g., `chmod 600`).

**2. Configure Home Manager**

Your Home Manager configuration will then be almost identical to the handover method, as it points to the same file path.

```nix
# in your standalone Home Manager configuration
{ inputs, config, ... }:
let
  inherit (config.home) homeDirectory;
  sopsFolder = inputs.nix-secrets + "/secrets/sops";
in
{
  imports = [ inputs.sops-nix.homeManagerModules.sops ];

  sops = {
    defaultSopsFile = "${sopsFolder}/vipul_laptop.yaml"; # Or another default
    age.keyFile = "${homeDirectory}/.config/sops/age/keys.txt";
  };
}
```
