#!/usr/bin/env bash
# Resolve SPM packages and generate the Xcode project/workspace from Tuist.
# Used by Fastlane lanes and CI before any xcodebuild invocation.
set -euo pipefail

cd "$(dirname "$0")/.."

# Native Xcode package integration resolves packages during `generate`
# (there is no Tuist/Package.swift, so `tuist install` is intentionally not run).
tuist generate --no-open
