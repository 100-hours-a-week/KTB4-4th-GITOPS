#!/usr/bin/env bash
set -euo pipefail

expected_context="arn:aws:eks:ap-northeast-2:919551759796:cluster/needu-v3-dev"
if [[ "$(kubectl config current-context)" != "$expected_context" ]]; then
  echo "Expected kubectl context: $expected_context" >&2
  exit 1
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

helm repo add argo https://argoproj.github.io/argo-helm --force-update
helm repo update argo
helm upgrade --install argocd argo/argo-cd \
  --version 10.9.6 \
  --namespace argocd \
  --create-namespace \
  --values "$script_dir/values.yaml" \
  --wait \
  --timeout 10m
