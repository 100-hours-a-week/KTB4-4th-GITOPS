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

for application_file in platform/autoscaling/*/application.yaml; do
  [[ -f "$application_file" ]] || continue

  IFS=$'\t' read -r repo_url chart version release_name namespace < <(
    ruby -ryaml -e '
      application = YAML.load_file(ARGV[0])
      source = application.fetch("spec").fetch("source")
      destination = application.fetch("spec").fetch("destination")
      helm = source.fetch("helm")
      puts [
        source.fetch("repoURL"),
        source.fetch("chart"),
        source.fetch("targetRevision"),
        helm.fetch("releaseName"),
        destination.fetch("namespace"),
      ].join("\t")
    ' "$application_file"
  )

  values_file="$render_dir/$(echo "$application_file" | tr / -)-values.yaml"
  ruby -ryaml -e '
    application = YAML.load_file(ARGV[0])
    print application.fetch("spec").fetch("source").fetch("helm").fetch("values")
  ' "$application_file" > "$values_file"

  echo "Rendering $release_name from $repo_url"
  helm template "$release_name" "$chart" \
    --repo "$repo_url" \
    --version "$version" \
    --namespace "$namespace" \
    --kube-version 1.36.0 \
    -f "$values_file" \
    > "$render_dir/$release_name.yaml"
done

echo "GitOps configuration validation passed"
