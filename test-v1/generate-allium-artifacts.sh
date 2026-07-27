#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "${script_dir}/.." && pwd)"
generated_dir="${repo_root}/test-v1/generated"

command -v allium >/dev/null
command -v jq >/dev/null
mkdir -p "${generated_dir}"

specs=(
  "root:spec/little-ant.allium"
  "domain:spec/little-ant/domain.allium"
  "material:spec/little-ant/material.allium"
  "judgment:spec/little-ant/judgment.allium"
  "execution:spec/little-ant/execution.allium"
  "selection:spec/little-ant/selection.allium"
  "interaction:spec/little-ant/interaction.allium"
  "integration:spec/little-ant/integration.allium"
  "migration-v0-v1:spec/little-ant/migration-v0-v1.allium"
)

for entry in "${specs[@]}"; do
  name="${entry%%:*}"
  source_file="${entry#*:}"
  allium plan "${repo_root}/${source_file}" \
    | jq -S . >"${generated_dir}/${name}.plan.json"
  allium model "${repo_root}/${source_file}" \
    | jq -S . >"${generated_dir}/${name}.model.json"
done
