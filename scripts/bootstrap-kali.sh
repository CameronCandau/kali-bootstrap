#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
payload_server_spec="${PAYLOAD_SERVER_SPEC:-payload-server}"
artifact_locker_spec="${ARTIFACT_LOCKER_SPEC:-artifact-locker}"
pentest_automation_repo="${PENTEST_AUTOMATION_REPO:-https://github.com/CameronCandau/Pentest-Automation.git}"
pentest_automation_dir="${PENTEST_AUTOMATION_DIR:-$HOME/.local/share/pentest-automation-src}"
artifact_locker_repository="${ARTIFACT_LOCKER_REPOSITORY:-public.ecr.aws/o7l3z5i2/artifact-locker}"
payloads_dir="${PAYLOADS_DIR:-$HOME/tools/payloads}"
backup_suffix=".pre-kali-bootstrap-$(date '+%Y%m%d-%H%M%S')"

ensure_base_packages() {
  sudo apt-get update
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
    ca-certificates \
    curl \
    git \
    i3-wm \
    lightdm \
    pipx \
    python3-venv \
    xz-utils
}

install_nix() {
  if command -v nix >/dev/null 2>&1; then
    return 0
  fi

  if [ -f "$HOME/.nix-profile/etc/profile.d/nix.sh" ] || [ -f /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]; then
    return 0
  fi

  if [ -d /nix ] && [ ! -w /nix ]; then
    sudo chown -R "$USER":"$(id -gn)" /nix
  fi

  sh <(curl -L https://nixos.org/nix/install) --no-daemon
}

load_nix() {
  if [ -f "$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then
    . "$HOME/.nix-profile/etc/profile.d/nix.sh"
    return 0
  fi

  if [ -f /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]; then
    . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
    return 0
  fi

  printf 'Unable to locate Nix profile script\n' >&2
  exit 1
}

load_home_manager_session() {
  if [ -f "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh" ]; then
    set +u
    . "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh"
    set -u
  fi

  export PATH="$HOME/.nix-profile/bin:$HOME/.local/bin:$PATH"
}

set_default_shell() {
  local bash_shell
  local current_shell

  bash_shell="$(command -v bash)"
  current_shell="$(getent passwd "$USER" | cut -d: -f7)"

  if [ -n "${bash_shell}" ] && [ "${current_shell}" != "${bash_shell}" ]; then
    chsh -s "${bash_shell}"
  fi
}

clone_or_update_repo() {
  local repo_url="$1"
  local repo_dir="$2"

  if [ ! -d "${repo_dir}/.git" ]; then
    git clone "${repo_url}" "${repo_dir}"
    return 0
  fi

  local repo_status
  repo_status="$(git -C "${repo_dir}" status --porcelain)"
  if [ -z "${repo_status}" ]; then
    git -C "${repo_dir}" pull --ff-only
  else
    printf 'Skipping repo update because local modifications exist in %s\n' "${repo_dir}" >&2
  fi
}

install_pipx_tool() {
  local spec="$1"
  local binary="$2"

  if command -v "${binary}" >/dev/null 2>&1; then
    return 0
  fi

  pipx install "$spec"
}

bootstrap_artifact_locker() {
  local artifact_dir="$HOME/.local/share/artifact-locker"

  if artifact-locker --help 2>&1 | rg -q 'bootstrap'; then
    artifact-locker bootstrap \
      --repository "${artifact_locker_repository}" \
      --artifact-dir "${payloads_dir}"
    return 0
  fi

  artifact-locker init

  mkdir -p "${artifact_dir}"
  cat > "${artifact_dir}/config.json" <<EOF
{
  "local_artifact_dir": "${payloads_dir}",
  "oci_repository": "${artifact_locker_repository}"
}
EOF

  artifact-locker pull
}

backup_managed_paths() {
  local path
  local managed_paths=(
    "$HOME/.bashrc"
    "$HOME/.profile"
    "$HOME/.xsessionrc"
    "$HOME/.zprofile"
    "$HOME/.tmux.conf"
    "$HOME/.vimrc"
    "$HOME/.config/tmux/scripts"
    "$HOME/.config/nvim"
    "$HOME/.config/yazi"
    "$HOME/.config/xfce4/terminal"
    "$HOME/.config/i3"
    "$HOME/.config/i3status"
    "$HOME/.config/rofi"
    "$HOME/.config/starship.toml"
    "$HOME/.config/wallpapers"
  )
  local legacy_paths=(
    "$HOME/.wezterm.lua"
    "$HOME/.config/lf"
    "$HOME/.config/neofetch"
    "$HOME/.config/opindex"
    "$HOME/.config/artifact-catalog"
  )

  for path in "${managed_paths[@]}"; do
    if [ -L "${path}" ]; then
      rm -f "${path}"
      continue
    fi

    if [ -e "${path}" ]; then
      mv "${path}" "${path}${backup_suffix}"
    fi
  done

  for path in "${legacy_paths[@]}"; do
    if [ -L "${path}" ]; then
      rm -f "${path}"
      continue
    fi

    if [ -e "${path}" ]; then
      mv "${path}" "${path}${backup_suffix}"
    fi
  done
}

disable_custom_tmux_config() {
  local tmux_config="$HOME/.tmux.conf"

  if [ -L "${tmux_config}" ]; then
    rm -f "${tmux_config}"
    return 0
  fi

  if [ -e "${tmux_config}" ]; then
    mv "${tmux_config}" "${tmux_config}${backup_suffix}"
  fi
}

remove_legacy_picom() {
  sudo apt-get purge -y picom || true

  if [ -L "$HOME/.config/picom" ]; then
    rm -f "$HOME/.config/picom"
  fi

  if [ -d "$HOME/.config/picom" ]; then
    rm -rf "$HOME/.config/picom"
  fi
}

run_home_manager() {
  local override_args=()

  if [ -d "${repo_root}/../dotfiles" ]; then
    override_args=(
      --override-input
      dotfiles
      "path:${repo_root}/../dotfiles"
    )
  fi

  nix --extra-experimental-features 'nix-command flakes' \
    run github:nix-community/home-manager/release-25.11 -- \
    switch -b hm-backup \
    "${override_args[@]}" \
    --flake "path:${repo_root}#kali"
}

configure_display_manager() {
  sudo systemctl disable --now greetd seatd || true
  sudo apt-get purge -y greetd tuigreet seatd || true
  sudo rm -f /etc/greetd/config.toml
  sudo rm -f /usr/local/bin/start-niri-session
  sudo rm -f /usr/local/share/wayland-sessions/niri.desktop
  sudo rm -f /usr/share/wayland-sessions/niri.desktop
  sudo systemctl enable lightdm
  sudo systemctl restart lightdm || true
}

ensure_base_packages
install_nix
load_nix

export NIX_CONFIG="experimental-features = nix-command flakes"

set_default_shell
backup_managed_paths
disable_custom_tmux_config
remove_legacy_picom
run_home_manager

load_home_manager_session

install_pipx_tool "${artifact_locker_spec}" artifact-locker
install_pipx_tool "${payload_server_spec}" payload-server
install_pipx_tool "penelope-shell-handler" penelope
install_pipx_tool "updog" updog

clone_or_update_repo "${pentest_automation_repo}" "${pentest_automation_dir}"
PREFIX="$HOME/.local" "${pentest_automation_dir}/install.sh"

bootstrap_artifact_locker

pentest-check
configure_display_manager
