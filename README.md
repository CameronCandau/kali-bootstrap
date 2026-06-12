# Kali Bootstrap

Standalone Nix-first bootstrap for disposable Kali VMs.

This repo keeps Kali as the base OS, keeps the official `lightdm` + `i3`
session path, and bootstraps the user-specific tooling that is not worth
rebuilding manually on every new VM.

Desktop ownership is split cleanly:

- shared desktop config comes from the `dotfiles` flake
- Kali-specific bootstrap/tooling stays here

The bootstrap installs:

- `i3` as the working session, with Xfce still available as fallback
- shared desktop files and packages from `dotfiles`
- `Payload-Server` from PyPI with `pipx`
- `Artifact-Locker` from PyPI with `pipx`
- `Pentest-Automation` from GitHub via its `install.sh`
- `penelope-shell-handler` and `updog` with `pipx`
- payload sync from `public.ecr.aws/o7l3z5i2/artifact-locker`

## Fresh Kali Usage

After this repo is published, the intended bootstrap command is:

```bash
curl -fsSL https://raw.githubusercontent.com/CameronCandau/kali-bootstrap/main/install.sh | bash
```

That one-liner:

1. installs `git`
2. clones this repo into `~/.local/share/kali-bootstrap`
3. runs `scripts/bootstrap-kali.sh`

If you already cloned the repo locally:

```bash
./scripts/bootstrap-kali.sh
```

This bootstrap is intended to be run as the default Kali user, `kali`.

## Environment Overrides

- `PAYLOAD_SERVER_SPEC`
- `ARTIFACT_LOCKER_SPEC`
- `PENTEST_AUTOMATION_REPO`
- `PENTEST_AUTOMATION_DIR`
- `ARTIFACT_LOCKER_REPOSITORY`
- `PAYLOADS_DIR`
- `KALI_BOOTSTRAP_REPO`
- `KALI_BOOTSTRAP_REF`
- `KALI_BOOTSTRAP_DIR`

Defaults:

- payload-server spec: `payload-server`
- artifact-locker spec: `artifact-locker`
- pentest-automation repo: `https://github.com/CameronCandau/Pentest-Automation.git`
- artifact locker OCI repo: `public.ecr.aws/o7l3z5i2/artifact-locker`

## Notes

- `dotfiles` is now the intended source of truth for the shared desktop
  layer rather than cloning and stowing a separate raw dotfiles repo on the VM.
- `artifact-locker` is installed from PyPI with `pipx`. If the installed PyPI
  version already has `artifact-locker bootstrap`, the script uses it. If not,
  the bootstrap falls back to the legacy `init + config.json + pull` flow.
- The machine should finish with `lightdm` active and `greetd` removed.
