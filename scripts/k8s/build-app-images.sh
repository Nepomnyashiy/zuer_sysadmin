#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 3 || $# -gt 4 ]]; then
  echo "Usage: $0 <app> <registry> <tag> [--build-only]" >&2
  exit 2
fi

app="$1"
registry="$2"
tag="$3"
build_only="${4:-}"

case "$app" in
  barber)
    root="/run/media/nsadmin/godny_soft/soft/barber"
    images=(
      "$root/backend|$registry/barber/backend:$tag"
      "$root/frontend|$registry/barber/frontend:$tag"
    )
    ;;
  anaconda)
    root="/run/media/nsadmin/godny_soft/soft/kip-service/anaconda_mvp"
    images=(
      "$root/anaconda_api|$registry/anaconda/api:$tag"
      "$root/anaconda_web|$registry/anaconda/web:$tag"
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
  echo "Building $image from $context"
  docker build -t "$image" "$context"
  if [[ "$build_only" != "--build-only" ]]; then
    echo "Pushing $image"
    docker push "$image"
  fi
done

