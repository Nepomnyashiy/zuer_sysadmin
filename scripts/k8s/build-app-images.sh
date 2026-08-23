#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 3 || $# -gt 4 ]]; then
  echo "Usage: $0 <app> <registry> <tag> [--build-only|--push-only]" >&2
  exit 2
fi

app="$1"
registry="$2"
tag="$3"
mode="${4:-}"

if [[ -n "$mode" && "$mode" != "--build-only" && "$mode" != "--push-only" ]]; then
  echo "Unsupported mode: $mode" >&2
  exit 2
fi

case "$app" in
  barber)
    root="/run/media/nsadmin/godny_soft/soft/barber"
    images=(
      "$root/backend|$registry/barber/backend:$tag"
      "$root/frontend|$registry/barber/frontend:$tag"
    )
    ;;
  anaconda)
    root="${ANACONDA_SOURCE_ROOT:-/run/media/nsadmin/godny_soft/site/anaconda_site}"
    images=(
      "$root|$registry/anaconda/site:$tag"
    )
    ;;
  kolos)
    root="/run/media/nsadmin/godny_soft/soft/kolos_web"
    images=(
      "$root/kolos-backend|$registry/kolos/backend:$tag"
      "$root/kolos-frontend|$registry/kolos/frontend:$tag"
    )
    ;;
  black-mamba)
    root="/run/media/nsadmin/godny_soft/soft/black_mamba"
    images=(
      "$root/app/backend|$registry/black-mamba/bm-api:$tag"
      "$root/app/hermes|$registry/black-mamba/hermes-gateway:$tag"
    )
    ;;
  *)
    echo "Unknown app: $app" >&2
    exit 2
    ;;
esac

for item in "${images[@]}"; do
  context="${item%%|*}"
  image="${item##*|}"

  if [[ "$mode" != "--push-only" ]]; then
    echo "Building $image from $context"
    docker build -t "$image" "$context"
  fi

  if [[ "$mode" != "--build-only" ]]; then
    echo "Pushing $image"
    docker push "$image"
  fi
done
