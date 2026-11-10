#!/usr/bin/env bash
# Prints an access token for the local `dev-user` from the throwaway Keycloak
# started by `./gradlew bootTestRun`. Local development only.
#
# Usage: TOKEN=$(backend/scripts/dev-token.sh)
#        curl -H "Authorization: Bearer $TOKEN" localhost:8080/api/v1/...
set -euo pipefail

realm_file="$(cd "$(dirname "$0")/.." && pwd)/src/test/resources/keycloak/orbit-realm.json"
issuer="http://localhost:8180/realms/orbit"

password=$(python3 -I -c 'import json,sys; print(json.load(open(sys.argv[1]))["users"][0]["credentials"][0]["value"])' "$realm_file")

curl -sf -X POST "$issuer/protocol/openid-connect/token" \
  -d grant_type=password \
  -d client_id=orbit-mobile \
  -d username=dev-user \
  --data-urlencode "password=$password" \
  -d scope=openid \
  | python3 -I -c 'import json,sys; print(json.load(sys.stdin)["access_token"])'
