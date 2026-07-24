#!/usr/bin/env bash
# Resolve SPM packages and generate the Xcode project/workspace from Tuist.
# Used by Fastlane lanes and CI before any xcodebuild invocation.
set -euo pipefail

cd "$(dirname "$0")/.."

# Secrets.xcconfig is git-ignored, so it is absent on a fresh clone / CI.
# Project.swift references it, and Tuist fails its xcconfig lint if it is
# missing — seed it from the committed example. Real keys are injected
# separately; a blank key is fine (PlaceSearchClient uses mock data in v1).
if [ ! -f Configurations/Secrets.xcconfig ]; then
  cp Configurations/Secrets.example.xcconfig Configurations/Secrets.xcconfig
fi

# Native Xcode package integration resolves packages during `generate`
# (there is no Tuist/Package.swift, so `tuist install` is intentionally not run).
tuist generate --no-open
