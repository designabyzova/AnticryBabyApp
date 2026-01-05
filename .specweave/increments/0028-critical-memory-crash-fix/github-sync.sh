#!/bin/bash

# Load GitHub token
GITHUB_TOKEN=$(grep GITHUB_TOKEN .env | cut -d'=' -f2 | tr -d ' ')

OWNER="designabyzova"
REPO="AnticryBabyApp"

echo "🔄 Creating GitHub milestone and issues for FS-028..."
echo ""

# Create milestone
echo "📋 Creating milestone..."
MILESTONE_RESPONSE=$(curl -s -X POST \
  -H "Authorization: Bearer $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github+json" \
  https://api.github.com/repos/$OWNER/$REPO/milestones \
  -d '{
    "title": "[FS-028] Critical Memory Crash Fix",
    "description": "Fix critical app crashes from excessive memory usage at 111MB. Update MemoryMonitor thresholds to realistic 80/90/100MB limits and implement cleanup handlers in all services.",
    "state": "open"
  }')

MILESTONE_NUMBER=$(echo "$MILESTONE_RESPONSE" | grep -o '"number":[0-9]*' | head -1 | cut -d':' -f2)

if [ -n "$MILESTONE_NUMBER" ]; then
  echo "✅ Milestone created: #$MILESTONE_NUMBER"
else
  echo "⚠️ Milestone creation response:"
  echo "$MILESTONE_RESPONSE" | head -10
fi

echo ""
echo "📝 Creating user story issues..."

# US-001: Update Memory Thresholds
echo "Creating US-001..."
curl -s -X POST \
  -H "Authorization: Bearer $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github+json" \
  https://api.github.com/repos/$OWNER/$REPO/issues \
  -d "{
    \"title\": \"[FS-028][US-001] Update Memory Thresholds to Realistic Values\",
    \"body\": \"**Feature**: FS-028\n**Priority**: P0\n**Estimate**: 2 hours\n\n## User Story\n\n**As a** user running the app for extended periods\n**I want** memory warnings to trigger at appropriate levels (80/90/100MB)\n**So that** cleanup actions happen before iOS kills the app\n\n## Acceptance Criteria\n\n- [ ] AC-US1-01: Normal threshold updated from 40MB to 80MB\n- [ ] AC-US1-02: Warning threshold updated from 45MB to 90MB\n- [ ] AC-US1-03: Critical threshold updated from 48MB to 100MB\n- [ ] AC-US1-04: Emergency threshold triggers at 100MB+\n- [ ] AC-US1-05: Existing tests updated for new thresholds\n\n## Related Files\n\n- \`BabyInCarApp/Services/MemoryMonitor.swift\`\n- \`BabyInCarApp/BabyInCarAppTests/Services/MemoryMonitorTests.swift\`\",
    \"labels\": [\"P0\", \"hotfix\", \"memory\"],
    \"milestone\": $MILESTONE_NUMBER
  }" > /dev/null

echo "✅ US-001 created"

# US-002: Implement Cleanup Handlers
echo "Creating US-002..."
curl -s -X POST \
  -H "Authorization: Bearer $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github+json" \
  https://api.github.com/repos/$OWNER/$REPO/issues \
  -d "{
    \"title\": \"[FS-028][US-002] Implement Cleanup Handlers in All Services\",
    \"body\": \"**Feature**: FS-028\n**Priority**: P0\n**Estimate**: 8 hours\n\n## User Story\n\n**As a** system managing memory\n**I want** all services to respond to cleanup notifications\n**So that** memory is actually freed when warnings occur\n\n## Acceptance Criteria\n\n- [ ] AC-US2-01: AudioEngine implements cleanup handler\n- [ ] AC-US2-02: SmartEmergencyQueue implements cleanup handler\n- [ ] AC-US2-03: BabyMoodLLMEngine implements cleanup handler\n- [ ] AC-US2-04: AdaptiveLearningEngine implements cleanup handler\n- [ ] AC-US2-05: CryDetectionService implements cleanup handler\n- [ ] AC-US2-06: All handlers respond to both critical and emergency levels\n\n## Services to Update\n\n- AudioEngine.swift\n- SmartEmergencyQueue.swift\n- BabyMoodLLMEngine.swift\n- AdaptiveLearningEngine.swift\n- CryDetectionService.swift\n- SmartCryResponseEngine.swift\",
    \"labels\": [\"P0\", \"hotfix\", \"memory\"],
    \"milestone\": $MILESTONE_NUMBER
  }" > /dev/null

echo "✅ US-002 created"

# US-003: Proactive Memory Management
echo "Creating US-003..."
curl -s -X POST \
  -H "Authorization: Bearer $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github+json" \
  https://api.github.com/repos/$OWNER/$REPO/issues \
  -d "{
    \"title\": \"[FS-028][US-003] Add Proactive Memory Management\",
    \"body\": \"**Feature**: FS-028\n**Priority**: P1\n**Estimate**: 4 hours\n\n## User Story\n\n**As a** system preventing memory accumulation\n**I want** services to proactively manage memory before warnings\n**So that** cleanup is gradual rather than emergency-driven\n\n## Acceptance Criteria\n\n- [ ] AC-US3-01: SmartEmergencyQueue reduces maxConcurrentLoadedTracks from 3 to 2\n- [ ] AC-US3-02: AudioEngine implements LRU cache with max 5 buffers\n- [ ] AC-US3-03: AI engines implement automatic history trimming at 50% capacity\n- [ ] AC-US3-04: CryDetectionService reuses ML model instances\n\n## Implementation\n\n- Update SmartEmergencyQueue constants\n- Add LRU cache to AudioEngine\n- Add auto-trim logic to AI engines\",
    \"labels\": [\"P1\", \"enhancement\", \"memory\"],
    \"milestone\": $MILESTONE_NUMBER
  }" > /dev/null

echo "✅ US-003 created"

# US-004: Comprehensive Testing
echo "Creating US-004..."
curl -s -X POST \
  -H "Authorization: Bearer $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github+json" \
  https://api.github.com/repos/$OWNER/$REPO/issues \
  -d "{
    \"title\": \"[FS-028][US-004] Comprehensive Memory Testing\",
    \"body\": \"**Feature**: FS-028\n**Priority**: P1\n**Estimate**: 6 hours\n\n## User Story\n\n**As a** developer maintaining code quality\n**I want** comprehensive memory tests\n**So that** memory issues are caught before release\n\n## Acceptance Criteria\n\n- [ ] AC-US4-01: Unit tests for new threshold values (80/90/100MB)\n- [ ] AC-US4-02: Integration tests verifying cleanup handlers\n- [ ] AC-US4-03: Integration tests measuring memory reduction\n- [ ] AC-US4-04: Performance tests with 80MB baseline\n- [ ] AC-US4-05: Memory profiling test for 5-minute session\n\n## Test Files\n\n- MemoryMonitorTests.swift\n- ServiceMemoryCleanupTests.swift (new)\n- MemoryProfilingTests.swift (new)\",
    \"labels\": [\"P1\", \"testing\", \"memory\"],
    \"milestone\": $MILESTONE_NUMBER
  }" > /dev/null

echo "✅ US-004 created"

echo ""
echo "═══════════════════════════════════════════════════════"
echo "✅ GitHub Sync Complete!"
echo "═══════════════════════════════════════════════════════"
echo ""
echo "Milestone: [FS-028] Critical Memory Crash Fix (#$MILESTONE_NUMBER)"
echo "Issues created: 4 user stories"
echo ""
echo "View on GitHub:"
echo "https://github.com/$OWNER/$REPO/milestone/$MILESTONE_NUMBER"
echo ""
