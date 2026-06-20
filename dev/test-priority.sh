#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=dev/lib-test.sh
source "${ROOT_DIR}/dev/lib-test.sh"

require_cluster

test_out_of_order() {
  local newer_sha="$TEST_SHA_STALE_NEWER" older_sha="$TEST_SHA_STALE_OLDER"
  local newer_time="2026-06-03T12:00:00Z" older_time="2026-06-01T12:00:00Z"
  local newer_digest older_digest newer_app_image

  build_test_image "$newer_sha"
  newer_digest="$(cat "${ROOT_DIR}/dev/.last-image-digest")"
  send_ecr_event "$newer_sha" "$newer_digest" "$newer_time"

  newer_app_image="$(wait_for_app_image_match "$newer_sha")"

  build_test_image "$older_sha"
  older_digest="$(cat "${ROOT_DIR}/dev/.last-image-digest")"
  send_ecr_event "$older_sha" "$older_digest" "$older_time"

  wait_for_stable_app_image "$newer_app_image" 25

  local current
  current="$(get_app_kustomize_image)"
  if [[ "$current" == *"$older_sha"* ]]; then
    fail "Application was downgraded to older commit ${older_sha}: ${current}"
  fi
}

test_filter_rejection() {
  local baseline current

  baseline="$(get_app_kustomize_image)"
  if [[ -z "$baseline" ]]; then
    fail "Application has no kustomize image override to compare against"
  fi

  send_ecr_event "$TEST_SHA_FILTER_OK" "sha256:filterwrongrepo" "2026-06-04T12:00:00Z" "other-repo"
  wait_for_stable_app_image "$baseline" 25

  send_ecr_event "prod-bad" "sha256:filterprodbad" "2026-06-04T12:01:00Z"
  wait_for_stable_app_image "$baseline" 25

  current="$(get_app_kustomize_image)"
  if [[ "$current" != "$baseline" ]]; then
    fail "disallowed tag event changed Application: ${current}"
  fi
}

test_repush_same_tag() {
  local sha="$TEST_SHA_REPUSH" first_digest second_digest second_app_image

  build_test_image "$sha" 1
  first_digest="$(cat "${ROOT_DIR}/dev/.last-image-digest")"
  send_ecr_event "$sha" "$first_digest" "2026-06-05T10:00:00Z"

  wait_for_app_image_match "$first_digest" >/dev/null

  build_test_image "$sha" 2
  second_digest="$(cat "${ROOT_DIR}/dev/.last-image-digest")"
  if [[ "$first_digest" == "$second_digest" ]]; then
    fail "Rebuild did not produce a different digest (${first_digest})"
  fi

  send_ecr_event "$sha" "$second_digest" "2026-06-05T11:00:00Z"
  second_app_image="$(wait_for_app_image_match "$second_digest")"

  if [[ "$second_app_image" == *"$first_digest"* ]]; then
    fail "Application still references first digest after re-push"
  fi
  if [[ "$second_app_image" != *"$sha"* ]]; then
    fail "Application lost commit tag ${sha}: ${second_app_image}"
  fi
}

FAILED=0
for name in out-of-order filter-rejection repush-same-tag; do
  fn="test_${name//-/_}"
  echo "==> ${name}"
  if ( "$fn" ); then
    pass "$name"
  else
    FAILED=$((FAILED + 1))
  fi
  echo
done

if [[ "$FAILED" -eq 0 ]]; then
  echo "All priority tests passed."
  exit 0
fi

echo "${FAILED} test(s) failed." >&2
exit 1
