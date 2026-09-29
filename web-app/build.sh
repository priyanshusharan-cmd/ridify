#!/usr/bin/env bash
# Build the existing app in isolation: never change frontend/ or its .env.
set -euo pipefail
web_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_dir="$(dirname "$web_dir")"
flutter_version="3.44.3"

: "${BACKEND_URL:?Set BACKEND_URL to the existing HTTPS backend origin before building.}"
# Only a public origin belongs in the browser bundle. Reject paths, credentials,
# query strings, and insecure production URLs before downloading the SDK.
BACKEND_URL="$(node "$web_dir/validate-url.cjs")"
export BACKEND_URL

if command -v flutter >/dev/null 2>&1; then
  flutter_bin="$(command -v flutter)"
else
  sdk_dir="$web_dir/.flutter-sdk/$flutter_version"
  if [[ ! -x "$sdk_dir/bin/flutter" ]]; then
    mkdir -p "$(dirname "$sdk_dir")"
    git clone --depth 1 --branch "$flutter_version" https://github.com/flutter/flutter.git "$sdk_dir"
  fi
  flutter_bin="$sdk_dir/bin/flutter"
fi

build_dir="$(mktemp -d "${TMPDIR:-/tmp}/ridify-web.XXXXXX")"
trap 'rm -rf "$build_dir"' EXIT
cp -R "$repo_dir/frontend/lib" "$repo_dir/frontend/assets" "$build_dir/"
cp "$repo_dir/frontend/pubspec.yaml" "$repo_dir/frontend/pubspec.lock" "$build_dir/"
cp -R "$web_dir/web" "$build_dir/web"
cp -R "$repo_dir/frontend/web/icons" "$build_dir/web/icons"
cp "$repo_dir/frontend/assets/icon.png" "$build_dir/web/favicon.png"
cp -R "$web_dir/test" "$build_dir/test"
# main.dart expects this asset. NEVER copy the developer's environment file.
printf 'BACKEND_URL=%s\n' "$BACKEND_URL" > "$build_dir/.env"

cd "$build_dir"
"$flutter_bin" pub get --enforce-lockfile
sdk_root="$(node -e 'const fs=require("fs"),p=require("path");process.stdout.write(p.dirname(p.dirname(fs.realpathSync(process.argv[1]))))' "$flutter_bin")"
RIDIFY_TEST_FONT="$sdk_root/bin/cache/artifacts/material_fonts/Roboto-Regular.ttf" "$flutter_bin" test --no-pub
"$flutter_bin" build web --release --no-pub --no-web-resources-cdn \
  --dart-define="BACKEND_URL=$BACKEND_URL"
# Publish only successful builds, with no source, private env, or native files.
mkdir -p "$web_dir/dist"
find "$web_dir/dist" -mindepth 1 -maxdepth 1 -exec rm -rf {} +
cp -R "$build_dir/build/web/." "$web_dir/dist/"
printf '\nWeb build ready: %s/dist\n' "$web_dir"
