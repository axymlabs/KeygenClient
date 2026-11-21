#!/usr/bin/env bash
set -euo pipefail

developer_dir=/Applications/Xcode_27.2.app/Contents/Developer
test -x "$developer_dir/usr/bin/xcodebuild"
export DEVELOPER_DIR="$developer_dir"

sw_vers
xcode_version="$(xcodebuild -version)"
printf '%s\n' "$xcode_version"
test "$xcode_version" = $'Xcode 27.2\nBuild version 27B52'

sdk_version="$(xcrun --sdk iphoneos --show-sdk-version)"
printf 'iOS SDK %s\n' "$sdk_version"
test "$sdk_version" = 27.2
pod --version

printf 'DEVELOPER_DIR=%s\n' "$developer_dir" >> "${GITHUB_ENV:?Expected a GitHub Actions environment file}"
