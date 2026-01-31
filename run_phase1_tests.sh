#!/bin/bash

# Safe test runner for AutoRip2MKV-Mac
# Runs specific test suites with a timeout to prevent hangs

set -e

PROJECT_DIR="/Users/gregmoyle/Documents/GitHub/AutoRip2MKV-Mac"
cd "$PROJECT_DIR"

echo "🧪 Running Phase 1 Tests with Timeout Protection..."
echo "=================================================="

# Run tests with a 60-second timeout
timeout 60s swift test \
    --verbose \
    --filter "UHDDetectionTests or ResolutionAnalysisTests" 2>&1 | tee test_results.log

TEST_EXIT=$?

if [ $TEST_EXIT -eq 124 ]; then
    echo "❌ Tests timed out after 60 seconds"
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
