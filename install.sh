#!/usr/bin/env bash

set -euo pipefail

repo_url="${KALI_BOOTSTRAP_REPO:-https://github.com/CameronCandau/kali-bootstrap.git}"
repo_ref="${KALI_BOOTSTRAP_REF:-main}"
repo_dir="${KALI_BOOTSTRAP_DIR:-$HOME/.local/share/kali-bootstrap}"

sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y git

if [ ! -d "${repo_dir}/.git" ]; then
  git clone --branch "${repo_ref}" --depth 1 "${repo_url}" "${repo_dir}"
else
  repo_status="$(git -C "${repo_dir}" status --porcelain)"
  if [ -z "${repo_status}" ]; then
    git -C "${repo_dir}" fetch origin "${repo_ref}"
    git -C "${repo_dir}" checkout "${repo_ref}"
    git -C "${repo_dir}" pull --ff-only
  else
    printf 'Skipping bootstrap repo update because local modifications exist in %s\n' "${repo_dir}" >&2
  fi
fi

exec bash "${repo_dir}/scripts/bootstrap-kali.sh"
