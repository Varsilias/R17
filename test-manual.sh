#!/usr/bin/env bash
# Manual test script for the Creator Card API.
# Usage: BASE=http://localhost:8811 bash test-manual.sh
# Requires: curl, jq

BASE="${BASE:-http://localhost:8811}"

pass=0
fail=0

check() {
  local label="$1"
  local expected_status="$2"
  local response="$3"
  local http_status="$4"
  local expected_code="${5:-}"

  local ok=true

  if [ "$http_status" != "$expected_status" ]; then
    ok=false
  fi

  if [ -n "$expected_code" ]; then
    local actual_code
    actual_code=$(echo "$response" | jq -r '.code // empty' 2>/dev/null)
    if [ "$actual_code" != "$expected_code" ]; then
      ok=false
    fi
  fi

  if [ "$ok" = true ]; then
    echo "  PASS [$http_status] $label"
    ((pass++))
  else
    echo "  FAIL [$http_status expected $expected_status] $label"
    echo "       Response: $(echo "$response" | jq -c '.' 2>/dev/null || echo "$response")"
    ((fail++))
  fi
}

req() {
  local method="$1"
  local path="$2"
  local body="$3"
  local http_code
  local body_out

  if [ -n "$body" ]; then
    body_out=$(curl -s -o /tmp/_cc_body -w "%{http_code}" \
      -X "$method" "$BASE$path" \
      -H "Content-Type: application/json" \
      -d "$body")
  else
    body_out=$(curl -s -o /tmp/_cc_body -w "%{http_code}" \
      -X "$method" "$BASE$path")
  fi

  echo "$body_out /tmp/_cc_body"
}

run() {
  local method="$1"
  local path="$2"
  local body="$3"
  local http_code response

  if [ -n "$body" ]; then
    http_code=$(curl -s -o /tmp/_cc_body -w "%{http_code}" \
      -X "$method" "$BASE$path" \
      -H "Content-Type: application/json" \
      -d "$body")
  else
    http_code=$(curl -s -o /tmp/_cc_body -w "%{http_code}" \
      -X "$method" "$BASE$path")
  fi

  response=$(cat /tmp/_cc_body)
  echo "$http_code|$response"
}

split() {
  local result="$1"
  HTTP_STATUS="${result%%|*}"
  RESPONSE="${result#*|}"
}

echo ""
echo "========================================="
echo " Creator Card API - Manual Test Suite"
echo " Target: $BASE"
echo "========================================="

# =========================================================
echo ""
echo "----- SETUP: clear known test slugs (best-effort) -----"
# Delete any pre-existing test cards so tests start clean.
for slug in george-cooks ada-designs-things vip-rate-card my-draft-card; do
  curl -s -X DELETE "$BASE/creator-cards/$slug" \
    -H "Content-Type: application/json" \
    -d '{"creator_reference":"crt_8f2k1m9x4p7w3q5z"}' > /dev/null 2>&1
done

# =========================================================
echo ""
echo "----- GROUP 1: Create - happy paths -----"

# 1a. Full card with all optional fields
result=$(run POST /creator-cards '{
  "title": "George Cooks",
  "description": "George Cooks is a weekly cooking podcast by Chef George AmadiObi",
  "slug": "george-cooks",
  "creator_reference": "crt_8f2k1m9x4p7w3q5z",
  "links": [
    {"title": "YouTube Channel", "url": "https://youtube.com/@georgecooks"},
    {"title": "Instagram", "url": "https://instagram.com/georgecooks"}
  ],
  "service_rates": {
    "currency": "NGN",
    "rates": [
      {"name": "IG Story Post", "description": "One Instagram story mention", "amount": 5000000},
      {"name": "Recipe Feature", "description": "Featured recipe segment", "amount": 15000000}
    ]
  },
  "status": "published"
}')
split "$result"
check "1a. Create full public card (all fields)" 200 "$RESPONSE" "$HTTP_STATUS"
echo "     id=$(echo "$RESPONSE" | jq -r '.data.id // empty') slug=$(echo "$RESPONSE" | jq -r '.data.slug // empty')"
echo "     access_code field present: $(echo "$RESPONSE" | jq 'has("data") and (.data | has("access_code"))')"
echo "     _id absent: $(echo "$RESPONSE" | jq '.data | has("_id") | not')"

# 1b. Minimal required fields only (no slug -> auto-generate)
result=$(run POST /creator-cards '{
  "title": "Ada Designs Things",
  "creator_reference": "crt_a1b2c3d4e5f6g7h8",
  "status": "published"
}')
split "$result"
check "1b. Create card with auto-generated slug" 200 "$RESPONSE" "$HTTP_STATUS"
AUTO_SLUG=$(echo "$RESPONSE" | jq -r '.data.slug // empty')
echo "     auto-generated slug: $AUTO_SLUG"
echo "     expected base: ada-designs-things"

# 1c. Private card with access_code
result=$(run POST /creator-cards '{
  "title": "VIP Rate Card",
  "creator_reference": "crt_x9y8z7w6v5u4t3s2",
  "status": "published",
  "access_type": "private",
  "access_code": "A1B2C3"
}')
split "$result"
check "1c. Create private card with access_code" 200 "$RESPONSE" "$HTTP_STATUS"
echo "     access_code in response: $(echo "$RESPONSE" | jq -r '.data.access_code // empty')"

# 1d. Draft card
result=$(run POST /creator-cards '{
  "title": "My Draft Card",
  "creator_reference": "crt_d1r2a3f4t5x6y7z8",
  "status": "draft",
  "slug": "my-draft-card"
}')
split "$result"
check "1d. Create draft card" 200 "$RESPONSE" "$HTTP_STATUS"

# 1e. Public card - access_code explicitly null in response
result=$(run POST /creator-cards '{
  "title": "No Access Code Card",
  "creator_reference": "crt_n1o2a3c4c5e6s7s8",
  "status": "published",
  "access_type": "public",
  "slug": "no-access-code-card"
}')
split "$result"
check "1e. Public card has access_code: null in response" 200 "$RESPONSE" "$HTTP_STATUS"
echo "     access_code value: $(echo "$RESPONSE" | jq '.data.access_code')"

# 1f. All supported currencies
for currency in USD GBP GHS; do
  result=$(run POST /creator-cards "{
    \"title\": \"Currency Test $currency\",
    \"creator_reference\": \"crt_c1u2r3r4e5n6c7y8\",
    \"status\": \"published\",
    \"service_rates\": {
      \"currency\": \"$currency\",
      \"rates\": [{\"name\": \"Basic Rate\", \"amount\": 100, \"description\": \"A basic service\"}]
    }
  }")
  split "$result"
  check "1f. Create card with currency $currency" 200 "$RESPONSE" "$HTTP_STATUS"
done

# =========================================================
echo ""
echo "----- GROUP 2: Create - slug validation -----"

# 2a. Duplicate slug
result=$(run POST /creator-cards '{
  "title": "Another George",
  "slug": "george-cooks",
  "creator_reference": "crt_m1n2b3v4c5x6z7l8",
  "status": "published"
}')
split "$result"
check "2a. Duplicate slug returns SL02" 400 "$RESPONSE" "$HTTP_STATUS" "SL02"

# 2b. Slug too short (4 chars)
result=$(run POST /creator-cards '{
  "title": "Short Slug Test",
  "slug": "abcd",
  "creator_reference": "crt_s1h2o3r4t5s6l7g8",
  "status": "published"
}')
split "$result"
check "2b. Slug too short (4 chars) returns 400" 400 "$RESPONSE" "$HTTP_STATUS"

# 2c. Slug too long (51 chars)
result=$(run POST /creator-cards '{
  "title": "Long Slug Test",
  "slug": "this-slug-is-way-too-long-and-should-fail-validatin",
  "creator_reference": "crt_l1o2n3g4s5l6u7g8",
  "status": "published"
}')
split "$result"
check "2c. Slug too long (51 chars) returns 400" 400 "$RESPONSE" "$HTTP_STATUS"

# 2d. Slug with invalid characters (space)
result=$(run POST /creator-cards '{
  "title": "Invalid Slug Test",
  "slug": "invalid slug",
  "creator_reference": "crt_i1n2v3a4l5i6d7s8",
  "status": "published"
}')
split "$result"
check "2d. Slug with spaces returns 400" 400 "$RESPONSE" "$HTTP_STATUS"

# 2e. Slug with special chars
result=$(run POST /creator-cards '{
  "title": "Special Chars Test",
  "slug": "invalid@slug!",
  "creator_reference": "crt_i1n2v3a4l5i6d7s9",
  "status": "published"
}')
split "$result"
check "2e. Slug with @ and ! returns 400" 400 "$RESPONSE" "$HTTP_STATUS"

# =========================================================
echo ""
echo "----- GROUP 3: Create - access_code validation -----"

# 3a. Private card missing access_code
result=$(run POST /creator-cards '{
  "title": "Secret Card",
  "creator_reference": "crt_q1w2e3r4t5y6u7i8",
  "status": "published",
  "access_type": "private"
}')
split "$result"
check "3a. Private card without access_code returns AC01" 400 "$RESPONSE" "$HTTP_STATUS" "AC01"

# 3b. Public card with access_code
result=$(run POST /creator-cards '{
  "title": "Public With Code",
  "creator_reference": "crt_q1w2e3r4t5y6u7i9",
  "status": "published",
  "access_type": "public",
  "access_code": "A1B2C3"
}')
split "$result"
check "3b. Public card with access_code returns AC05" 400 "$RESPONSE" "$HTTP_STATUS" "AC05"

# 3c. No access_type + access_code (defaults to public)
result=$(run POST /creator-cards '{
  "title": "Implicit Public With Code",
  "creator_reference": "crt_q1w2e3r4t5y6u7j1",
  "status": "published",
  "access_code": "A1B2C3"
}')
split "$result"
check "3c. Omitted access_type + access_code returns AC05" 400 "$RESPONSE" "$HTTP_STATUS" "AC05"

# 3d. access_code not alphanumeric (has special char)
result=$(run POST /creator-cards '{
  "title": "Bad Code Card",
  "creator_reference": "crt_b1a2d3c4o5d6e7x8",
  "status": "published",
  "access_type": "private",
  "access_code": "A1B2!3"
}')
split "$result"
check "3d. access_code with special char returns 400" 400 "$RESPONSE" "$HTTP_STATUS"

# 3e. access_code too short (5 chars)
result=$(run POST /creator-cards '{
  "title": "Short Code Card",
  "creator_reference": "crt_s1h2o3r4t5c6o7d8",
  "status": "published",
  "access_type": "private",
  "access_code": "AB123"
}')
split "$result"
check "3e. access_code too short (5 chars) returns 400" 400 "$RESPONSE" "$HTTP_STATUS"

# 3f. access_code too long (7 chars)
result=$(run POST /creator-cards '{
  "title": "Long Code Card",
  "creator_reference": "crt_l1o2n3g4c5o6d7e8",
  "status": "published",
  "access_type": "private",
  "access_code": "AB12345"
}')
split "$result"
check "3f. access_code too long (7 chars) returns 400" 400 "$RESPONSE" "$HTTP_STATUS"

# =========================================================
echo ""
echo "----- GROUP 4: Create - field validation -----"

# 4a. Missing title
result=$(run POST /creator-cards '{
  "creator_reference": "crt_m1i2s3s4i5n6g7t8",
  "status": "published"
}')
split "$result"
check "4a. Missing title returns 400" 400 "$RESPONSE" "$HTTP_STATUS"

# 4b. Title too short (2 chars)
result=$(run POST /creator-cards '{
  "title": "AB",
  "creator_reference": "crt_t1i2t3l4e5s6h7t8",
  "status": "published"
}')
split "$result"
check "4b. Title too short (2 chars) returns 400" 400 "$RESPONSE" "$HTTP_STATUS"

# 4c. Title too long (101 chars)
result=$(run POST /creator-cards '{
  "title": "AAAAAAAAAABBBBBBBBBBCCCCCCCCCCDDDDDDDDDDEEEEEEEEEEFFFFFFFFFFGGGGGGGGGGHHHHHHHHHHIIIIIIIIIIJJJJJJJJJJX",
  "creator_reference": "crt_t1i2t3l4e5l6o7n8",
  "status": "published"
}')
split "$result"
check "4c. Title too long (101 chars) returns 400" 400 "$RESPONSE" "$HTTP_STATUS"

# 4d. Missing creator_reference
result=$(run POST /creator-cards '{
  "title": "No Creator Reference",
  "status": "published"
}')
split "$result"
check "4d. Missing creator_reference returns 400" 400 "$RESPONSE" "$HTTP_STATUS"

# 4e. creator_reference wrong length (19 chars)
result=$(run POST /creator-cards '{
  "title": "Wrong Creator Ref",
  "creator_reference": "crt_tooshort123456",
  "status": "published"
}')
split "$result"
check "4e. creator_reference 19 chars returns 400" 400 "$RESPONSE" "$HTTP_STATUS"

# 4f. creator_reference wrong length (21 chars)
result=$(run POST /creator-cards '{
  "title": "Wrong Creator Ref Long",
  "creator_reference": "crt_toolong1234567890x",
  "status": "published"
}')
split "$result"
check "4f. creator_reference 21 chars returns 400" 400 "$RESPONSE" "$HTTP_STATUS"

# 4g. Missing status
result=$(run POST /creator-cards '{
  "title": "No Status Card",
  "creator_reference": "crt_n1o2s3t4a5t6u7s8"
}')
split "$result"
check "4g. Missing status returns 400" 400 "$RESPONSE" "$HTTP_STATUS"

# 4h. Invalid status enum
result=$(run POST /creator-cards '{
  "title": "Bad Status Card",
  "creator_reference": "crt_q1w2e3r4t5y6u7i8",
  "status": "archived"
}')
split "$result"
check "4h. Invalid status (archived) returns 400" 400 "$RESPONSE" "$HTTP_STATUS"

# 4i. Invalid access_type enum
result=$(run POST /creator-cards '{
  "title": "Bad Access Type",
  "creator_reference": "crt_b1a2d3a4c5t6y7p8",
  "status": "published",
  "access_type": "restricted"
}')
split "$result"
check "4i. Invalid access_type (restricted) returns 400" 400 "$RESPONSE" "$HTTP_STATUS"

# 4j. Description too long (501 chars)
LONG_DESC=$(python3 -c "print('A' * 501)" 2>/dev/null || printf '%0.s A' {1..502} | tr -d ' ' | cut -c1-501)
result=$(run POST /creator-cards "{
  \"title\": \"Long Description Card\",
  \"description\": \"$LONG_DESC\",
  \"creator_reference\": \"crt_d1e2s3c4l5o6n7g8\",
  \"status\": \"published\"
}")
split "$result"
check "4j. Description over 500 chars returns 400" 400 "$RESPONSE" "$HTTP_STATUS"

# =========================================================
echo ""
echo "----- GROUP 5: Create - links validation -----"

# 5a. Link URL without http/https prefix
result=$(run POST /creator-cards '{
  "title": "Bad Link Card",
  "creator_reference": "crt_b1a2d3l4i5n6k7s8",
  "status": "published",
  "links": [{"title": "Bad Link", "url": "ftp://badprotocol.com"}]
}')
split "$result"
check "5a. Link URL with ftp:// prefix returns 400" 400 "$RESPONSE" "$HTTP_STATUS"

# 5b. Link missing url
result=$(run POST /creator-cards '{
  "title": "Missing URL Card",
  "creator_reference": "crt_m1i2s3s4u5r6l7x8",
  "status": "published",
  "links": [{"title": "No URL"}]
}')
split "$result"
check "5b. Link missing url returns 400" 400 "$RESPONSE" "$HTTP_STATUS"

# 5c. Link missing title
result=$(run POST /creator-cards '{
  "title": "Missing Link Title",
  "creator_reference": "crt_m1i2s3s4t5i6t7l8",
  "status": "published",
  "links": [{"url": "https://example.com"}]
}')
split "$result"
check "5c. Link missing title returns 400" 400 "$RESPONSE" "$HTTP_STATUS"

# 5d. Valid http:// link (not just https://)
result=$(run POST /creator-cards '{
  "title": "HTTP Link Card",
  "creator_reference": "crt_h1t2t3p4l5i6n7k8",
  "status": "published",
  "links": [{"title": "HTTP Link", "url": "http://example.com/page"}]
}')
split "$result"
check "5d. Link with http:// prefix is valid" 200 "$RESPONSE" "$HTTP_STATUS"

# =========================================================
echo ""
echo "----- GROUP 6: Create - service_rates validation -----"

# 6a. Invalid currency
result=$(run POST /creator-cards '{
  "title": "Bad Currency Card",
  "creator_reference": "crt_b1a2d3c4u5r6r7e8",
  "status": "published",
  "service_rates": {
    "currency": "EUR",
    "rates": [{"name": "Basic Rate", "amount": 100, "description": "Service"}]
  }
}')
split "$result"
check "6a. Invalid currency (EUR) returns 400" 400 "$RESPONSE" "$HTTP_STATUS"

# 6b. Empty rates array
result=$(run POST /creator-cards '{
  "title": "Empty Rates Card",
  "creator_reference": "crt_e1m2p3t4y5r6a7t8",
  "status": "published",
  "service_rates": {
    "currency": "NGN",
    "rates": []
  }
}')
split "$result"
check "6b. Empty rates array returns 400" 400 "$RESPONSE" "$HTTP_STATUS"

# 6c. Missing currency
result=$(run POST /creator-cards '{
  "title": "No Currency Card",
  "creator_reference": "crt_n1o2c3u4r5r6e7n8",
  "status": "published",
  "service_rates": {
    "rates": [{"name": "Basic Rate", "amount": 100, "description": "Service"}]
  }
}')
split "$result"
check "6c. Missing currency in service_rates returns 400" 400 "$RESPONSE" "$HTTP_STATUS"

# 6d. Amount is zero
result=$(run POST /creator-cards '{
  "title": "Zero Amount Card",
  "creator_reference": "crt_z1e2r3o4a5m6t7x8",
  "status": "published",
  "service_rates": {
    "currency": "NGN",
    "rates": [{"name": "Free Service", "amount": 0, "description": "Zero amount"}]
  }
}')
split "$result"
check "6d. Amount = 0 returns 400" 400 "$RESPONSE" "$HTTP_STATUS"

# 6e. Amount is negative
result=$(run POST /creator-cards '{
  "title": "Negative Amount Card",
  "creator_reference": "crt_n1e2g3a4m5o6u7n8",
  "status": "published",
  "service_rates": {
    "currency": "NGN",
    "rates": [{"name": "Negative", "amount": -100, "description": "Negative amount"}]
  }
}')
split "$result"
check "6e. Negative amount returns 400" 400 "$RESPONSE" "$HTTP_STATUS"

# 6f. Amount is a decimal
result=$(run POST /creator-cards '{
  "title": "Decimal Amount Card",
  "creator_reference": "crt_d1e2c3a4m5o6u7n8",
  "status": "published",
  "service_rates": {
    "currency": "NGN",
    "rates": [{"name": "Decimal", "amount": 100.50, "description": "Decimal amount"}]
  }
}')
split "$result"
check "6f. Decimal amount returns 400" 400 "$RESPONSE" "$HTTP_STATUS"

# 6g. Rate name too short (2 chars)
result=$(run POST /creator-cards '{
  "title": "Short Rate Name",
  "creator_reference": "crt_s1h2o3r4t5r6a7n8",
  "status": "published",
  "service_rates": {
    "currency": "NGN",
    "rates": [{"name": "AB", "amount": 1000, "description": "Short name"}]
  }
}')
split "$result"
check "6g. Rate name too short (2 chars) returns 400" 400 "$RESPONSE" "$HTTP_STATUS"

# 6h. Missing rate name
result=$(run POST /creator-cards '{
  "title": "No Rate Name Card",
  "creator_reference": "crt_n1o2r3a4t5n6a7m8",
  "status": "published",
  "service_rates": {
    "currency": "NGN",
    "rates": [{"amount": 1000, "description": "No name"}]
  }
}')
split "$result"
check "6h. Missing rate name returns 400" 400 "$RESPONSE" "$HTTP_STATUS"

# =========================================================
echo ""
echo "----- GROUP 7: Create - malformed requests -----"

# 7a. Malformed JSON body
result=$(run POST /creator-cards '{invalid json here')
split "$result"
check "7a. Malformed JSON returns 400" 400 "$RESPONSE" "$HTTP_STATUS"

# 7b. Empty body
result=$(run POST /creator-cards '{}')
split "$result"
check "7b. Empty body returns 400" 400 "$RESPONSE" "$HTTP_STATUS"

# 7c. title is a number (wrong type)
result=$(run POST /creator-cards '{
  "title": 12345,
  "creator_reference": "crt_w1r2o3n4g5t6y7p8",
  "status": "published"
}')
split "$result"
check "7c. Title as number returns 400" 400 "$RESPONSE" "$HTTP_STATUS"

# 7d. links is an object not an array
result=$(run POST /creator-cards '{
  "title": "Links Object Card",
  "creator_reference": "crt_l1i2n3k4o5b6j7t8",
  "status": "published",
  "links": {"title": "Not an array", "url": "https://example.com"}
}')
split "$result"
check "7d. links as object (not array) returns 400" 400 "$RESPONSE" "$HTTP_STATUS"

# =========================================================
echo ""
echo "----- GROUP 8: GET - happy paths -----"

# 8a. Get a public published card
result=$(run GET /creator-cards/george-cooks)
split "$result"
check "8a. GET public published card returns 200" 200 "$RESPONSE" "$HTTP_STATUS"
echo "     id present: $(echo "$RESPONSE" | jq '.data | has("id")')"
echo "     _id absent: $(echo "$RESPONSE" | jq '.data | has("_id") | not')"
echo "     access_code absent: $(echo "$RESPONSE" | jq '.data | has("access_code") | not')"

# 8b. Get private card with correct access_code
result=$(run GET "/creator-cards/vip-rate-card?access_code=A1B2C3")
split "$result"
check "8b. GET private card with correct access_code returns 200" 200 "$RESPONSE" "$HTTP_STATUS"
echo "     access_code absent from response: $(echo "$RESPONSE" | jq '.data | has("access_code") | not')"

# =========================================================
echo ""
echo "----- GROUP 9: GET - error cases -----"

# 9a. Non-existent slug
result=$(run GET /creator-cards/does-not-exist-123)
split "$result"
check "9a. GET non-existent slug returns NF01" 404 "$RESPONSE" "$HTTP_STATUS" "NF01"

# 9b. Draft card
result=$(run GET /creator-cards/my-draft-card)
split "$result"
check "9b. GET draft card returns NF02" 404 "$RESPONSE" "$HTTP_STATUS" "NF02"

# 9c. Private card without access_code
result=$(run GET /creator-cards/vip-rate-card)
split "$result"
check "9c. GET private card without code returns AC03" 403 "$RESPONSE" "$HTTP_STATUS" "AC03"

# 9d. Private card with wrong access_code
result=$(run GET "/creator-cards/vip-rate-card?access_code=WRONG1")
split "$result"
check "9d. GET private card with wrong code returns AC04" 403 "$RESPONSE" "$HTTP_STATUS" "AC04"

# 9e. Private card with code that is right length but wrong value
result=$(run GET "/creator-cards/vip-rate-card?access_code=Z9Y8X7")
split "$result"
check "9e. GET private card with valid-format but wrong code returns AC04" 403 "$RESPONSE" "$HTTP_STATUS" "AC04"

# =========================================================
echo ""
echo "----- GROUP 10: DELETE - happy paths -----"

# 10a. Delete an existing card
result=$(run DELETE /creator-cards/ada-designs-things '{
  "creator_reference": "crt_a1b2c3d4e5f6g7h8"
}')
split "$result"
check "10a. DELETE existing card returns 200" 200 "$RESPONSE" "$HTTP_STATUS"
echo "     deleted timestamp: $(echo "$RESPONSE" | jq '.data.deleted')"
echo "     access_code in response: $(echo "$RESPONSE" | jq '.data | has("access_code")')"

# 10b. Get deleted card - should return NF01
result=$(run GET /creator-cards/ada-designs-things)
split "$result"
check "10b. GET deleted card returns NF01" 404 "$RESPONSE" "$HTTP_STATUS" "NF01"

# =========================================================
echo ""
echo "----- GROUP 11: DELETE - error cases -----"

# 11a. Delete non-existent slug
result=$(run DELETE /creator-cards/does-not-exist-123 '{
  "creator_reference": "crt_q1w2e3r4t5y6u7i8"
}')
split "$result"
check "11a. DELETE non-existent slug returns NF01" 404 "$RESPONSE" "$HTTP_STATUS" "NF01"

# 11b. Delete with missing creator_reference
result=$(run DELETE /creator-cards/george-cooks '{}')
split "$result"
check "11b. DELETE without creator_reference returns 400" 400 "$RESPONSE" "$HTTP_STATUS"

# 11c. Delete with creator_reference wrong length
result=$(run DELETE /creator-cards/george-cooks '{
  "creator_reference": "crt_tooshort"
}')
split "$result"
check "11c. DELETE with creator_reference wrong length returns 400" 400 "$RESPONSE" "$HTTP_STATUS"

# 11d. Delete already-deleted card
result=$(run DELETE /creator-cards/ada-designs-things '{
  "creator_reference": "crt_a1b2c3d4e5f6g7h8"
}')
split "$result"
check "11d. DELETE already-deleted card returns NF01" 404 "$RESPONSE" "$HTTP_STATUS" "NF01"

# =========================================================
echo ""
echo "----- GROUP 12: Slug auto-generation edge cases -----"

# 12a. Title that produces a slug shorter than 5 chars after cleanup
result=$(run POST /creator-cards '{
  "title": "Ada",
  "creator_reference": "crt_s1h2o3r4t5t6i7t8",
  "status": "published"
}')
split "$result"
check "12a. Short title gets suffix appended to slug" 200 "$RESPONSE" "$HTTP_STATUS"
SHORT_SLUG=$(echo "$RESPONSE" | jq -r '.data.slug // empty')
echo "     generated slug: $SHORT_SLUG (length ${#SHORT_SLUG})"

# 12b. Auto-generated slug when base is already taken
result=$(run POST /creator-cards '{
  "title": "George Cooks",
  "creator_reference": "crt_d1u2p3s4l5u6g7x8",
  "status": "published"
}')
split "$result"
check "12b. Duplicate base slug gets suffix appended" 200 "$RESPONSE" "$HTTP_STATUS"
DUP_SLUG=$(echo "$RESPONSE" | jq -r '.data.slug // empty')
echo "     generated slug for duplicate base: $DUP_SLUG"

# 12c. Title with special characters (emojis, accents) - stripped from slug
result=$(run POST /creator-cards '{
  "title": "Caf\u00e9 & Resto",
  "creator_reference": "crt_s1p2e3c4c5h6a7r8",
  "status": "published"
}')
split "$result"
check "12c. Title with special chars generates valid slug" 200 "$RESPONSE" "$HTTP_STATUS"
SPECIAL_SLUG=$(echo "$RESPONSE" | jq -r '.data.slug // empty')
echo "     generated slug: $SPECIAL_SLUG"

# =========================================================
echo ""
echo "----- GROUP 13: Response shape verification -----"

# 13a. Verify all expected fields are present in create response
result=$(run POST /creator-cards '{
  "title": "Shape Verify Card",
  "creator_reference": "crt_s1h2a3p4e5v6e7r8",
  "status": "published",
  "slug": "shape-verify-card"
}')
split "$result"
check "13a. Create response shape is correct" 200 "$RESPONSE" "$HTTP_STATUS"
for field in id title description slug creator_reference links service_rates status access_type access_code created updated deleted; do
  present=$(echo "$RESPONSE" | jq ".data | has(\"$field\")")
  echo "     data.$field present: $present"
done

# 13b. Verify GET response omits access_code
result=$(run GET /creator-cards/shape-verify-card)
split "$result"
check "13b. GET response has no access_code field" 200 "$RESPONSE" "$HTTP_STATUS"
echo "     access_code absent: $(echo "$RESPONSE" | jq '.data | has("access_code") | not')"

# =========================================================
echo ""
echo "========================================="
echo " Results: $pass passed, $fail failed"
echo "========================================="
echo ""

# Cleanup test-only cards (best-effort)
for slug in no-access-code-card my-draft-card george-cooks vip-rate-card shape-verify-card http-link-card; do
  curl -s -X DELETE "$BASE/creator-cards/$slug" \
    -H "Content-Type: application/json" \
    -d '{"creator_reference":"crt_8f2k1m9x4p7w3q5z"}' > /dev/null 2>&1
done
