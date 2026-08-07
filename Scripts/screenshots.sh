#!/bin/bash
# Writes the App Store screenshots for every language into
# fastlane/screenshots/<language>/ at 1320 × 2868 (iPhone 6.9").
#
# Drop real cutout PNGs into fastlane/screenshots/source/ to use them instead of
# the drawn stand-ins.
set -euo pipefail
cd "$(dirname "$0")/.."

# TEST_RUNNER_ prefix: xcodebuild only forwards variables named that way into the
# test process. A plain export never reaches the test and it silently skips.
TEST_RUNNER_GENERATE_STORE_SCREENSHOTS=1 xcodebuild test \
  -workspace FoodDiary.xcworkspace \
  -scheme FoodDiary \
  -destination 'id=3B1E5795-617D-4955-8048-0CC8AD03BE95' \
  -skipMacroValidation \
  -only-testing:FeatureKitTests/StoreScreenshotGenerator \
  2>&1 | grep -E "Store screenshots|  [a-z-]+/[0-9]|error:|TEST (SUCCEEDED|FAILED)"
