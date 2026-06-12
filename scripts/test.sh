#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

bash -n "${repo_root}/install.sh"
bash -n "${repo_root}/scripts/bootstrap-kali.sh"

printf 'kali-bootstrap test: ok\n'
