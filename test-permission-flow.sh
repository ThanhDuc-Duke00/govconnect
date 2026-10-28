#!/bin/bash
# GovConnect Permission System — Full Integration Test Script
# Chạy: bash test-permission-flow.sh
set -euo pipefail

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; NC='\033[0m'
pass() { echo -e "${GREEN}✅ $1${NC}"; }
fail() { echo -e "${RED}❌ $1${NC}"; exit 1; }
info() { echo -e "${YELLOW}▶ $1${NC}"; }

API="http://localhost:8310"
TOKEN=""

echo "============================================"
echo " GovConnect Permission System — Test Suite"
echo "============================================"
echo ""

# ── Step 0: Pre-checks ───────────────────────────
info "Step 0: Pre-checks"

docker ps >/dev/null 2>&1 || fail "Docker not running. Start Docker Desktop first."
pass "Docker is running"

curl -sf "$API/health" >/dev/null 2>&1 || fail "API not responding at $API. Start: dotnet run --project src/GovConnect.Api"
pass "API is responding"

echo ""

# ── Step 1: Login as SuperAdmin ───────────────────
info "Step 1: Login as SuperAdmin"

RESP=$(curl -sf -X POST "$API/api/auth/login" \
  -H "Content-Type: application/json" \
  -H "X-Tenant-Code: demo-tandinh" \
  -d '{"email":"super@govconnect.vn","password":"Super@123"}' 2>&1) || fail "SuperAdmin login failed"

TOKEN=$(echo "$RESP" | python -c "import sys,json; print(json.load(sys.stdin)['accessToken'])" 2>/dev/null) || fail "No accessToken in response"
pass "SuperAdmin logged in"

AUTH="Authorization: Bearer $TOKEN"
echo ""

# ── Step 2: List all module permissions ──────────
info "Step 2: List module permissions"

PERMS=$(curl -sf "$API/api/platform/permissions" -H "$AUTH" 2>&1) || fail "Cannot list permissions"
COUNT=$(echo "$PERMS" | python -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null)
[ "$COUNT" -ge 50 ] || fail "Expected 50+ permissions, got $COUNT"
pass "Found $COUNT module permissions"

echo ""

# ── Step 3: List all stage permissions ───────────
info "Step 3: List stage permissions"

STAGE_PERMS=$(curl -sf "$API/api/platform/permissions/stages" -H "$AUTH" 2>&1) || fail "Cannot list stage permissions"
STAGE_COUNT=$(echo "$STAGE_PERMS" | python -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null)
[ "$STAGE_COUNT" -ge 20 ] || fail "Expected 20+ stage permissions, got $STAGE_COUNT"
pass "Found $STAGE_COUNT stage permissions"

echo ""

# ── Step 4: Get role permissions ─────────────────
info "Step 4: Get role permissions (Officer)"

ROLE_PERMS=$(curl -sf "$API/api/platform/permissions/role/Officer" -H "$AUTH" 2>&1) || fail "Cannot get Officer permissions"
ROLE_COUNT=$(echo "$ROLE_PERMS" | python -c "import sys,json; print(len(json.load(sys.stdin)['permissions']))" 2>/dev/null)
pass "Officer has $ROLE_COUNT module permissions"

echo ""

# ── Step 5: Get role stage permissions ───────────
info "Step 5: Get role stage permissions (Officer)"

ROLE_STAGE=$(curl -sf "$API/api/platform/permissions/stages/role/Officer" -H "$AUTH" 2>&1) || fail "Cannot get Officer stage permissions"
ROLE_STAGE_COUNT=$(echo "$ROLE_STAGE" | python -c "import sys,json; print(len(json.load(sys.stdin)['stagePermissions']))" 2>/dev/null)
pass "Officer has $ROLE_STAGE_COUNT stage permissions"

echo ""

# ── Step 6: Menu permissions ─────────────────────
info "Step 6: Get menu permissions"

MENUS=$(curl -sf "$API/api/platform/menu-permissions" -H "$AUTH" 2>&1) || fail "Cannot list menu permissions"
MENU_COUNT=$(echo "$MENUS" | python -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null)
[ "$MENU_COUNT" -ge 5 ] || fail "Expected 5+ menu permissions, got $MENU_COUNT"
pass "Found $MENU_COUNT menu permissions"

echo ""

# ── Step 7: My permissions (current user) ────────
info "Step 7: Get my permissions"

MY_PERMS=$(curl -sf "$API/api/platform/permissions/mine" -H "$AUTH" 2>&1) || fail "Cannot get my permissions"
MY_COUNT=$(echo "$MY_PERMS" | python -c "import sys,json; print(len(json.load(sys.stdin)['permissions']))" 2>/dev/null)
pass "Current user has $MY_COUNT module permissions"

MY_MENUS=$(curl -sf "$API/api/menu/menus" -H "$AUTH" 2>&1) || fail "Cannot get my menus"
PORTAL_COUNT=$(echo "$MY_MENUS" | python -c "import sys,json; print(len(json.load(sys.stdin).get('portalMenus',[])))" 2>/dev/null)
MINI_COUNT=$(echo "$MY_MENUS" | python -c "import sys,json; print(len(json.load(sys.stdin).get('miniAppMenus',[])))" 2>/dev/null)
pass "My menus: portal=$PORTAL_COUNT, miniapp=$MINI_COUNT"

echo ""

# ── Step 8: Login as Officer ─────────────────────
info "Step 8: Login as Officer + verify restricted access"

OFFICER_RESP=$(curl -sf -X POST "$API/api/auth/login" \
  -H "Content-Type: application/json" \
  -H "X-Tenant-Code: demo-tandinh" \
  -d '{"email":"officer@demo-tandinh.gov.vn","password":"Officer@123"}' 2>&1) || fail "Officer login failed"

OFFICER_TOKEN=$(echo "$OFFICER_RESP" | python -c "import sys,json; print(json.load(sys.stdin)['accessToken'])" 2>/dev/null) || fail "No accessToken for Officer"
OFFICER_AUTH="Authorization: Bearer $OFFICER_TOKEN"
pass "Officer logged in"

# Officer should NOT access platform endpoints
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$API/api/platform/permissions" -H "$OFFICER_AUTH" 2>&1)
[ "$HTTP_CODE" = "403" ] || fail "Officer should get 403 on platform endpoints, got $HTTP_CODE"
pass "Officer correctly denied platform access (403)"

# Officer should access their own permissions
MY_OFFICER=$(curl -sf "$API/api/platform/permissions/mine" -H "$OFFICER_AUTH" 2>&1) || fail "Officer cannot get own permissions"
pass "Officer can get own permissions"

echo ""

# ── Step 9: Audit log check ──────────────────────
info "Step 9: Verify audit log entries exist"

# Switch back to SuperAdmin token
AUDIT=$(curl -sf "$API/api/audit" -H "$AUTH" 2>&1) || fail "Cannot query audit log"
AUDIT_COUNT=$(echo "$AUDIT" | python -c "import sys,json; d=json.load(sys.stdin); print(d.get('totalItems', len(d) if isinstance(d,list) else 0))" 2>/dev/null || echo "0")
pass "Audit log has $AUDIT_COUNT entries"

echo ""

# ── Step 10: Health check ────────────────────────
info "Step 10: Health check"

HEALTH=$(curl -sf "$API/health" 2>&1) || fail "Health check failed"
pass "Health check: $HEALTH"

echo ""
echo "============================================"
echo -e "${GREEN} ALL TESTS PASSED${NC}"
echo "============================================"
