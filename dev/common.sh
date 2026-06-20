# Shared LocalStack / fake ECR settings for dev scripts.
ECR_ACCOUNT_ID="${ECR_ACCOUNT_ID:-000000000000}"
ECR_REGION="${ECR_REGION:-us-east-1}"
ECR_REPO="${ECR_REPO:-demo-app}"
ECR_REGISTRY="${ECR_REGISTRY:-${ECR_ACCOUNT_ID}.dkr.ecr.${ECR_REGION}.amazonaws.com}"
ECR_IMAGE="${ECR_REGISTRY}/${ECR_REPO}"

# Fixed 40-char commit SHAs used by dev integration tests.
TEST_SHA_INITIAL="0000000000000000000000000000000000000001"
TEST_SHA_STALE_NEWER="cafed00dcafe0000000000000000000000000001"
TEST_SHA_STALE_OLDER="deadbeefdeadbeefdeadbeefdeadbeefdeadbeef"
TEST_SHA_REPUSH="bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
TEST_SHA_FILTER_OK="aabbccddeeff0011223344556677889900aabbcc"

ecr_image_ref() {
  local tag="$1"
  echo "${ECR_IMAGE}:${tag}"
}

is_git_sha_tag() {
  local tag="$1"
  [[ "$tag" =~ ^[0-9a-f]{40}$ ]]
}

normalize_git_sha_tag() {
  local tag="$1"
  tag="$(printf '%s' "$tag" | tr '[:upper:]' '[:lower:]')"
  if ! is_git_sha_tag "$tag"; then
    echo "expected a 40-character lowercase git commit SHA, got: ${tag}" >&2
    return 1
  fi
  echo "$tag"
}

demo_git_sha() {
  local root="${1:-.}"
  local sha=""
  if sha="$(git -C "$root" rev-parse HEAD 2>/dev/null)"; then
    normalize_git_sha_tag "$sha"
    return 0
  fi
  normalize_git_sha_tag "$(printf '%040x' "$(date +%s)")"
}
