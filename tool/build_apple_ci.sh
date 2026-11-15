#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ "${1:-}" == upload ]]; then
  platform="${2:?ios or macos}"
  case "$platform" in ios) ext=ipa;; macos) ext=pkg;; *) exit 2;; esac
  export API_PRIVATE_KEYS_DIR="${RUNNER_TEMP:?}/apple-release-signing"
  shopt -s nullglob
  packages=("build/$platform/app-store/"*."$ext")
  [[ ${#packages[@]} -eq 1 ]] || { echo 'Expected exactly one signed package'; exit 1; }
  xcrun altool --upload-app --type "$platform" --file "${packages[0]}" \
    --apiKey "${APP_STORE_CONNECT_KEY_ID:?}" --apiIssuer "${APP_STORE_CONNECT_ISSUER_ID:?}"
  exit
fi
platform="${1:-}"
case "$platform" in ios) destination='generic/platform=iOS';; macos) destination='generic/platform=macOS';; *) exit 2;; esac
signing_dir="${RUNNER_TEMP:?}/apple-release-signing"
read -r version build < <(python3 tool/release_version.py check)
key_id="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["key_id"])' "$signing_dir/config.json")"
issuer_id="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["issuer_id"])' "$signing_dir/config.json")"
auth=(-allowProvisioningUpdates -authenticationKeyPath "$signing_dir/AuthKey_${key_id}.p8" -authenticationKeyID "$key_id" -authenticationKeyIssuerID "$issuer_id")
if [[ "$platform" == ios ]]; then
  flutter build ios --config-only --release --build-name "$version" --build-number "$build" --no-codesign
else
  flutter build macos --config-only --release --build-name "$version" --build-number "$build"
fi
archive="$PWD/build/$platform/archive/Runner.xcarchive"
output="$PWD/build/$platform/app-store"
xcodebuild -workspace "$platform/Runner.xcworkspace" -scheme Runner -configuration Release \
  -destination "$destination" -archivePath "$archive" \
  -clonedSourcePackagesDirPath "$PWD/build/$platform/SourcePackages" "${auth[@]}" \
  CURRENT_PROJECT_VERSION="$build" MARKETING_VERSION="$version" archive
shopt -s nullglob
bundles=("$archive/Products/Applications/"*.app)
[[ ${#bundles[@]} -eq 1 ]]
python3 tool/release_version.py check --bundle "${bundles[0]}"
xcodebuild -exportArchive -archivePath "$archive" -exportPath "$output" \
  -exportOptionsPlist "$platform/ExportOptions.plist" "${auth[@]}"
