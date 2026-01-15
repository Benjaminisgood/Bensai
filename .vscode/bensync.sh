#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
ENV_FILE="${ROOT_DIR}/.env"

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "未找到 ${ENV_FILE}，请先在根目录创建 .env 配置" >&2
  exit 1
fi

set -a
# shellcheck disable=SC1090
. "${ENV_FILE}"
set +a

required_vars=(
  ALIYUN_OSS_ENDPOINT
  ALIYUN_OSS_ACCESS_KEY_ID
  ALIYUN_OSS_ACCESS_KEY_SECRET
  ALIYUN_OSS_BUCKET
)

for var in "${required_vars[@]}"; do
  if [[ -z "${!var:-}" ]]; then
    echo "缺少环境变量: ${var}" >&2
    exit 1
  fi
done

OSSUTIL_BIN="${OSSUTIL_BIN:-}"
if [[ -z "${OSSUTIL_BIN}" ]]; then
  if command -v ossutil >/dev/null 2>&1; then
    OSSUTIL_BIN="ossutil"
  elif command -v ossutil64 >/dev/null 2>&1; then
    OSSUTIL_BIN="ossutil64"
  else
    echo "未找到 ossutil/ossutil64，请先安装阿里云 ossutil" >&2
    exit 1
  fi
fi

trim_space() {
  local s="$1"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  printf '%s' "${s}"
}

is_excluded() {
  local rel="$1"
  local pat
  for pat in "${exclude_patterns[@]}"; do
    if [[ "${rel}" == ${pat} || "${rel}" == ${pat}/* || "${rel}" == */${pat} || "${rel}" == */${pat}/* ]]; then
      return 0
    fi
  done
  return 1
}

local_crc64() {
  local file="$1"
  local out crc64
  if ! out="$("${OSSUTIL_BIN}" hash "${file}" --type=crc64 2>&1)"; then
    echo "计算 CRC64 失败: ${file}" >&2
    echo "${out}" >&2
    return 2
  fi
  crc64="$(echo "${out}" | awk -F: '/CRC64-ECMA/ {gsub(/[[:space:]]/,"",$2); print $2}')"
  if [[ -z "${crc64}" ]]; then
    echo "未解析到 CRC64: ${file}" >&2
    return 2
  fi
  printf '%s' "${crc64}"
}

remote_crc64() {
  local url="$1"
  local out crc64
  if ! out="$("${OSSUTIL_BIN}" stat "${url}" -e "${ALIYUN_OSS_ENDPOINT}" -i "${ALIYUN_OSS_ACCESS_KEY_ID}" -k "${ALIYUN_OSS_ACCESS_KEY_SECRET}" 2>&1)"; then
    if echo "${out}" | grep -Eqi 'NoSuchKey|NoSuchObject|NotFound|404'; then
      return 1
    fi
    echo "读取远端对象失败: ${url}" >&2
    echo "${out}" >&2
    return 2
  fi
  crc64="$(echo "${out}" | awk -F: '/X-Oss-Hash-Crc64ecma/ {gsub(/[[:space:]]/,"",$2); print $2}')"
  printf '%s' "${crc64}"
}

upload_file() {
  local file="$1"
  local url="$2"
  local out
  if ! out="$("${OSSUTIL_BIN}" cp "${file}" "${url}" -f -e "${ALIYUN_OSS_ENDPOINT}" -i "${ALIYUN_OSS_ACCESS_KEY_ID}" -k "${ALIYUN_OSS_ACCESS_KEY_SECRET}" 2>&1)"; then
    echo "上传失败: ${file}" >&2
    echo "${out}" >&2
    return 1
  fi
}

prefix="${ALIYUN_OSS_PREFIX:-}"
prefix="${prefix#/}"
prefix="${prefix%/}"

root_name="$(basename "${ROOT_DIR}")"
dest_prefix="${root_name}"
if [[ -n "${prefix}" ]]; then
  dest_prefix="${prefix}/${root_name}"
fi
dest_base="oss://${ALIYUN_OSS_BUCKET}/${dest_prefix}"

declare -a exclude_patterns=()
if [[ -n "${OSS_SYNC_EXCLUDES:-}" ]]; then
  IFS=',' read -r -a raw_excludes <<< "${OSS_SYNC_EXCLUDES}"
  for pattern in "${raw_excludes[@]}"; do
    pattern="$(trim_space "${pattern}")"
    pattern="${pattern#/}"
    pattern="${pattern#./}"
    if [[ -n "${pattern}" ]]; then
      exclude_patterns+=("${pattern}")
    fi
  done
fi

if [[ -f "${ENV_FILE}" ]] && [[ -z "${OSS_SYNC_EXCLUDES:-}" ]]; then
  echo "提示: 未设置 OSS_SYNC_EXCLUDES，.env 将被同步。" >&2
fi

if ! "${OSSUTIL_BIN}" stat "oss://${ALIYUN_OSS_BUCKET}" -e "${ALIYUN_OSS_ENDPOINT}" -i "${ALIYUN_OSS_ACCESS_KEY_ID}" -k "${ALIYUN_OSS_ACCESS_KEY_SECRET}" >/dev/null 2>&1; then
  echo "无法访问 bucket: oss://${ALIYUN_OSS_BUCKET}" >&2
  exit 1
fi

echo "同步源: ${ROOT_DIR}"
echo "同步目标: ${dest_base}/"
if [[ ${#exclude_patterns[@]} -gt 0 ]]; then
  echo "排除规则: ${OSS_SYNC_EXCLUDES}"
fi

total=0
excluded=0
skipped=0
uploaded=0
verified=0

while IFS= read -r -d '' file; do
  rel="${file#${ROOT_DIR}/}"
  total=$((total + 1))

  if [[ ${#exclude_patterns[@]} -gt 0 ]] && is_excluded "${rel}"; then
    excluded=$((excluded + 1))
    continue
  fi

  local_crc="$(local_crc64 "${file}")"
  object_url="${dest_base}/${rel}"

  remote_crc=""
  if remote_crc="$(remote_crc64 "${object_url}")"; then
    if [[ -n "${remote_crc}" && "${remote_crc}" == "${local_crc}" ]]; then
      skipped=$((skipped + 1))
      continue
    fi
  else
    rc=$?
    if [[ ${rc} -eq 2 ]]; then
      exit 1
    fi
  fi

  upload_file "${file}" "${object_url}"
  uploaded=$((uploaded + 1))

  remote_crc_after="$(remote_crc64 "${object_url}")"
  if [[ -z "${remote_crc_after}" || "${remote_crc_after}" != "${local_crc}" ]]; then
    echo "完整性校验失败: ${rel}" >&2
    echo "本地 CRC64: ${local_crc}" >&2
    echo "远端 CRC64: ${remote_crc_after:-<empty>}" >&2
    exit 1
  fi
  verified=$((verified + 1))
done < <(find "${ROOT_DIR}" -type f -print0)

echo "扫描文件数: ${total}"
echo "排除文件数: ${excluded}"
echo "跳过文件数: ${skipped}"
echo "上传文件数: ${uploaded}"
echo "校验通过数: ${verified}"
