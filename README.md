# nix-secrets

This repository manages secrets for my personal [Nix configurations](https://github.com/vipulog/nix-config) using [sops-nix](https://github.com/Mic92/sops-nix). It is designed to be imported as a flake input, providing a structured approach to secret management using `sops` with `age` keys.

## Table of Contents

- [Repository Structure](#repository-structure)
  - [Access Control](#access-control)
- [Usage](#usage)
  - [Flake Integration](#flake-integration)
  - [Referencing Secrets](#referencing-secrets)
- [Resources](#resources)

## Repository Structure

The repository is organized into two main parts:

- `modules/`: Nix flake modules for repository development (formatting, shells, hooks).
- `secrets/sops/`: Contains all encrypted secret files, organized by scope:
  - `shared.yaml`: Common to all machines and users.
  - `[user].yaml`: User-specific secrets (e.g., `tux.yaml`).
  - `[host].yaml`: Host-specific secrets (e.g., `igloo.yaml`).
  - `[user]_[host].yaml`: User secrets on a specific host (e.g., `tux_igloo.yaml`).

### Access Control

Access is defined in `.sops.yaml` using two types of `age` keys:

- **Host Keys**: Derived from the host's SSH key, allowing automatic decryption at runtime.
- **User Keys**: Unique key per user (or delegated `user_machine` keys).

Example `.sops.yaml`:

```yaml
keys:
  users: &users
    - &tux        age1...[tux_public_key]
    - &tux_igloo  age1...[tux_on_igloo_delegated_public_key]
  hosts: &hosts
    - &igloo      age1...[igloo_ssh_public_key]
    - &server     age1...[server_ssh_public_key]

creation_rules:
  # User-only secrets (decryptable only by the user's keys)
  - path_regex: ^secrets/sops/tux\.yaml$
    key_groups:
      - age:
          - *tux
          - *tux_igloo

  # Host-specific secrets (decryptable by the host key and main user)
  - path_regex: ^secrets/sops/igloo\.yaml$
    key_groups:
      - age:
          - *tux
          - *igloo

  # User-host secrets (decryptable by the user and delegated host key)
  - path_regex: ^secrets/sops/tux_igloo\.yaml$
    key_groups:
      - age:
          - *tux
          - *tux_igloo

  # Shared secrets (decryptable by all keys)
  - path_regex: ^secrets/sops/shared\.yaml$
    key_groups:
      - age:
          - *tux
          - *tux_igloo
          - *igloo
          - *server
```

## Usage

### Flake Integration

Add this repository as an input in your `flake.nix`:

```nix
{
  inputs.nix-secrets.url = "github:vipulog/nix-secrets/main?shallow=1";
}
```

### Referencing Secrets

Reference the encrypted files in your system configuration using the flake input path:

```nix
{ inputs, config, ... }: {
  sops = {
    defaultSopsFile = "${inputs.nix-secrets}/secrets/sops/igloo.yaml";
    # ... your sops-nix configuration
  };

  # Example: using a secret
  users.users.tux.hashedPasswordFile = config.sops.secrets."passwords/tux".path;
}
```

## Resources

Here are some helpful resources for the tools and concepts used in this repository:

- [NixOS Flakes](https://wiki.nixos.org/wiki/Flakes)
- [getsops/sops](https://github.com/getsops/sops)
- [FiloSottile/age](https://github.com/FiloSottile/age)
- [Mic92/sops-nix](https://github.com/Mic92/sops-nix)
- [OpenSSH Host Keys](https://wiki.archlinux.org/title/OpenSSH#Host_keys)
