#!/bin/bash

# Safe test runner for AutoRip2MKV-Mac
# Runs specific test suites with a timeout to prevent hangs

set -o pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$PROJECT_DIR"

TIMEOUT_SECONDS=60

echo "🧪 Running Phase 1 Tests with Timeout Protection..."
echo "=================================================="

# macOS has no GNU `timeout`; run in the background and kill it on expiry.
swift test --verbose --filter "UHDDetectionTests|ResolutionAnalysisTests" > test_results.log 2>&1 &
TEST_PID=$!
( sleep "$TIMEOUT_SECONDS" && kill "$TEST_PID" 2>/dev/null && touch .test_timed_out ) &
WATCHDOG_PID=$!

wait "$TEST_PID"
TEST_EXIT=$?
kill "$WATCHDOG_PID" 2>/dev/null
cat test_results.log

if [ -f .test_timed_out ]; then
    rm -f .test_timed_out
    echo "❌ Tests timed out after ${TIMEOUT_SECONDS} seconds"
    exit 1
elif [ $TEST_EXIT -ne 0 ]; then
    echo "❌ Tests failed with exit code $TEST_EXIT"
    exit 1
else
    echo "✅ Tests completed successfully"
fi

# Extract summary
echo ""
echo "📊 Test Summary:"
grep -E "Test Suite|passed|failed" test_results.log || echo "No summary found"
