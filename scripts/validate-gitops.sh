#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

ruby scripts/check-gitops-files.rb

render_dir="$(mktemp -d)"
trap 'rm -rf "$render_dir"' EXIT

for environment_dir in environments/*; do
  [[ -d "$environment_dir" ]] || continue
  environment="${environment_dir##*/}"

  for values_file in "$environment_dir"/*.yaml; do
    [[ -f "$values_file" ]] || continue
    application="${values_file##*/}"
    application="${application%.yaml}"

    case "$application" in
      backend-image|alb-controller) continue ;;
    esac

    values=(-f "$values_file")
    if [[ "$application" != "frontend" && "$application" != "ai-fastapi" ]]; then
      backend_image="$environment_dir/backend-image.yaml"
      if [[ ! -f "$backend_image" ]]; then
        echo "Missing shared backend values: $backend_image" >&2
        exit 1
      fi
      values=(-f "$backend_image" -f "$values_file")
    fi

    echo "Validating $environment/$application"
    helm lint charts/application "${values[@]}"
    helm template "$application" charts/application "${values[@]}" \
      > "$render_dir/$environment-$application.yaml"
  done
done

while IFS= read -r -d '' kustomization; do
  directory="${kustomization%/*}"
  echo "Rendering $directory"
  kubectl kustomize "$directory" > "$render_dir/$(echo "$directory" | tr / -).yaml"
done < <(find platform kubernetes -name kustomization.yaml -print0)

echo "GitOps configuration validation passed"
