
#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

ruby scripts/check-gitops-files.rb

render_dir="$(mktemp -d)"
trap 'rm -rf "$render_dir"' EXIT

chart_dir="$render_dir/charts"
mkdir -p "$chart_dir"

# 0. Vendor Helm Chart 무결성 검증
if [[ -d vendor/charts ]]; then
  echo "Checking vendored Helm Charts"

  if [[ ! -f vendor/charts/SHA256SUMS ]]; then
    echo "Missing vendor/charts/SHA256SUMS" >&2
    exit 1
  fi

  (
    cd vendor/charts
    shasum -a 256 --check SHA256SUMS
  )
fi

# 1. Application Helm Chart 검증
for environment_dir in environments/*; do
  [[ -d "$environment_dir" ]] || continue
  environment="${environment_dir##*/}"

  for values_file in "$environment_dir"/*.yaml; do
    [[ -f "$values_file" ]] || continue

    application="${values_file##*/}"
    application="${application%.yaml}"

    case "$application" in
      backend-image|alb-controller|argocd-values) continue ;;
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

# 2. Kustomize 검증
while IFS= read -r -d '' kustomization; do
  directory="${kustomization%/*}"

  echo "Rendering $directory"

  kubectl kustomize "$directory" \
    > "$render_dir/$(echo "$directory" | tr / -).yaml"

done < <(find platform kubernetes -name kustomization.yaml -print0)

# 3. 외부 Helm Chart 다운로드 함수
download_chart() {
  local repo_url="$1"
  local chart="$2"
  local version="$3"
  local chart_file="$chart_dir/$chart-$version.tgz"
  local vendor_file="$PWD/vendor/charts/$chart-$version.tgz"

  # Vendor Chart 우선 사용
  if [[ -f "$vendor_file" ]]; then
    echo "Using vendored chart: $vendor_file" >&2

    if ! helm show chart "$vendor_file" > /dev/null; then
      echo "Invalid vendored chart: $vendor_file" >&2
      return 1
    fi

    cp "$vendor_file" "$chart_file"
    printf '%s\n' "$chart_file"
    return 0
  fi

  # 다운로드된 Chart 캐시 확인
  if [[ -f "$chart_file" ]] && helm show chart "$chart_file" > /dev/null; then
    echo "Using cached chart: $chart_file" >&2
    printf '%s\n' "$chart_file"
    return 0
  fi

  rm -f "$chart_file"

  echo "Downloading $chart:$version from $repo_url" >&2

  # Helm Repository 다운로드
  for attempt in 1 2 3; do
    if helm pull "$chart" \
      --repo "$repo_url" \
      --version "$version" \
      --destination "$chart_dir" >&2; then

      if helm show chart "$chart_file" > /dev/null; then
        printf '%s\n' "$chart_file"
        return 0
      fi

      echo "Downloaded chart is invalid: $chart_file" >&2
    fi

    rm -f "$chart_file"

    echo "Helm download failed ($attempt/3): $chart:$version" >&2

    if [[ "$attempt" -lt 3 ]]; then
      sleep $((attempt * 3))
    fi
  done

  echo "Failed to download $chart:$version from $repo_url" >&2
  return 1
}

# 4. Autoscaling Helm Chart 검증
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

  echo "Validating $release_name ($version)"

  # Chart 다운로드 또는 Vendor Chart 사용
  chart_file="$(download_chart "$repo_url" "$chart" "$version")"

  # Helm Lint
  helm lint "$chart_file" \
    -f "$values_file"

  # Helm Template
  helm template "$release_name" "$chart_file" \
    --namespace "$namespace" \
    --kube-version 1.36.0 \
    -f "$values_file" \
    > "$render_dir/$release_name.yaml"

  echo "Validated: $release_name"
done

echo "GitOps configuration validation passed"
