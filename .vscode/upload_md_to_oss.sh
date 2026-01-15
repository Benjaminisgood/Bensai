#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   # Optional: put envs in .ossenv (KEY=VALUE, one per line)
#   # Optional: export OSS_ENV_FILE=/path/to/.ossenv
#   ./upload_md_to_oss.sh /path/to/note.md blog|note
#
# Required envs (loaded from .ossenv if present):
#   ALIYUN_OSS_ENDPOINT
#   ALIYUN_OSS_ACCESS_KEY_ID
#   ALIYUN_OSS_ACCESS_KEY_SECRET
#   ALIYUN_OSS_BUCKET
#   ALIYUN_OSS_PREFIX
#   ALIYUN_OSS_PUBLIC_BASE_URL
#
# Output:
#   - creates: <original>.oss.md  (references rewritten)
#   - uploads: attachments -> oss://$BUCKET/$PREFIX/<blog|note>/<uuid>.<ext>
#              markdown     -> oss://$BUCKET/$PREFIX/<blog|note>/<original>.md

MD_PATH="${1:-}"
TARGET_SUBDIR="${2:-}"
if [[ -z "${MD_PATH}" || ! -f "${MD_PATH}" || -z "${TARGET_SUBDIR}" ]]; then
  echo "Error: please provide a markdown file path."
  echo "Usage: $0 /path/to/file.md blog|note"
  exit 1
fi
if [[ "${TARGET_SUBDIR}" != "blog" && "${TARGET_SUBDIR}" != "note" ]]; then
  echo "Error: target must be 'blog' or 'note'."
  echo "Usage: $0 /path/to/file.md blog|note"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MD_DIR="$(cd "$(dirname "$MD_PATH")" && pwd)"

# ---- defaults (edit if needed) ----
DEFAULT_ALIYUN_OSS_ENDPOINT="oss-cn-shanghai.aliyuncs.com"
DEFAULT_ALIYUN_OSS_ACCESS_KEY_ID=""
DEFAULT_ALIYUN_OSS_ACCESS_KEY_SECRET=""
DEFAULT_ALIYUN_OSS_BUCKET=""
DEFAULT_ALIYUN_OSS_PREFIX=""
DEFAULT_ALIYUN_OSS_PUBLIC_BASE_URL=""

# ---- auto-load envs ----
ENV_FILES=()
if [[ -n "${OSS_ENV_FILE:-}" ]]; then
  ENV_FILES+=("${OSS_ENV_FILE}")
fi
ENV_FILES+=(
  "${MD_DIR}/.ossenv"
  "${SCRIPT_DIR}/.ossenv"
  "${PWD}/.ossenv"
  "${HOME}/.ossenv"
)

for env_file in "${ENV_FILES[@]}"; do
  if [[ -f "${env_file}" ]]; then
    set -a
    # shellcheck source=/dev/null
    . "${env_file}"
    set +a
    break
  fi
done

ALIYUN_OSS_ENDPOINT="${ALIYUN_OSS_ENDPOINT:-${DEFAULT_ALIYUN_OSS_ENDPOINT}}"
ALIYUN_OSS_ACCESS_KEY_ID="${ALIYUN_OSS_ACCESS_KEY_ID:-${DEFAULT_ALIYUN_OSS_ACCESS_KEY_ID}}"
ALIYUN_OSS_ACCESS_KEY_SECRET="${ALIYUN_OSS_ACCESS_KEY_SECRET:-${DEFAULT_ALIYUN_OSS_ACCESS_KEY_SECRET}}"
ALIYUN_OSS_BUCKET="${ALIYUN_OSS_BUCKET:-${DEFAULT_ALIYUN_OSS_BUCKET}}"
ALIYUN_OSS_PREFIX="${ALIYUN_OSS_PREFIX:-${DEFAULT_ALIYUN_OSS_PREFIX}}"
ALIYUN_OSS_PUBLIC_BASE_URL="${ALIYUN_OSS_PUBLIC_BASE_URL:-${DEFAULT_ALIYUN_OSS_PUBLIC_BASE_URL}}"

missing=0
for var in \
  ALIYUN_OSS_ENDPOINT \
  ALIYUN_OSS_ACCESS_KEY_ID \
  ALIYUN_OSS_ACCESS_KEY_SECRET \
  ALIYUN_OSS_BUCKET \
  ALIYUN_OSS_PREFIX \
  ALIYUN_OSS_PUBLIC_BASE_URL
do
  if [[ -z "${!var:-}" ]]; then
    echo "Missing env: ${var}"
    missing=1
  fi
done
if [[ "${missing}" -ne 0 ]]; then
  exit 1
fi

# ---- settings ----
OSSUTIL_BIN="${OSSUTIL_BIN:-ossutil}"

# Normalize prefix: no leading/trailing slash
ALIYUN_OSS_PREFIX="${ALIYUN_OSS_PREFIX#/}"
ALIYUN_OSS_PREFIX="${ALIYUN_OSS_PREFIX%/}"

MD_BASENAME="$(basename "$MD_PATH")"
OUT_MD="${MD_PATH}.oss.md"

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

# ---- prepare ossutil config (local temp config file) ----
OSSUTIL_CONFIG="${TMPDIR}/ossutilconfig"
cat > "${OSSUTIL_CONFIG}" <<EOF
[Credentials]
language=EN
endpoint=${ALIYUN_OSS_ENDPOINT}
accessKeyID=${ALIYUN_OSS_ACCESS_KEY_ID}
accessKeySecret=${ALIYUN_OSS_ACCESS_KEY_SECRET}
EOF

OSS_CP() {
  # usage: OSS_CP <local_path> <oss://bucket/prefix/key>
  "${OSSUTIL_BIN}" -c "${OSSUTIL_CONFIG}" cp -f "$1" "$2" >/dev/null
}

# ---- python: parse markdown, collect local referenced files, rewrite links ----
# Handles:
#   - Markdown links/images: [](...) and ![](...)
#   - Obsidian wikilinks/embeds: [[...]] and ![[...]]
#   - Distinguish .md notes vs attachments
# Skips:
#   - http(s)://, data:, mailto:, obsidian://, #anchor
#   - code fences
PY_SCRIPT="${TMPDIR}/rewrite_md.py"
cat > "${PY_SCRIPT}" <<'PY'
import json
import os
import re
import sys
import uuid
from pathlib import Path
from urllib.parse import quote, unquote

md_path = Path(sys.argv[1]).resolve()
md_dir = md_path.parent

MD_EXTS = {".md", ".markdown", ".mdown", ".mkd"}
IMAGE_EXTS = {".png", ".jpg", ".jpeg", ".gif", ".bmp", ".webp", ".svg"}

text = md_path.read_text(encoding="utf-8")

def find_vault_root(start: Path):
    cur = start
    while True:
        if (cur / ".obsidian").is_dir():
            return cur
        if cur.parent == cur:
            break
        cur = cur.parent
    return None

vault_root_env = os.environ.get("OBSIDIAN_VAULT_ROOT") or os.environ.get("VAULT_ROOT")
if vault_root_env:
    vault_root = Path(vault_root_env).expanduser().resolve()
else:
    vault_root = find_vault_root(md_dir) or md_dir

def build_index(root: Path):
    name_index = {}
    stem_index = {}
    skip_dirs = {".git", ".obsidian", ".trash"}
    for base, dirs, files in os.walk(root):
        dirs[:] = [d for d in dirs if d not in skip_dirs]
        for fn in files:
            p = Path(base) / fn
            name_index.setdefault(fn.lower(), []).append(p)
            stem_index.setdefault(p.stem.lower(), []).append(p)
    return name_index, stem_index

name_index = {}
stem_index = {}
if "[[" in text:
    name_index, stem_index = build_index(vault_root)

def choose_best(paths, prefer_exts=None):
    uniq = []
    seen = set()
    for p in paths:
        rp = str(p.resolve())
        if rp not in seen:
            seen.add(rp)
            uniq.append(p)
    paths = uniq
    if prefer_exts:
        pref = [p for p in paths if p.suffix.lower() in prefer_exts]
        if pref:
            paths = pref
    same_dir = [p for p in paths if p.parent == md_dir]
    if same_dir:
        return same_dir[0]
    paths_sorted = sorted(paths, key=lambda p: len(os.path.relpath(p, md_dir)))
    return paths_sorted[0]

def resolve_wiki_target(file_part: str, prefer_exts=None):
    if not file_part:
        return None
    target = file_part.strip()
    if not target:
        return None

    candidates = []
    if target.startswith("/"):
        candidates.append(vault_root / target.lstrip("/"))
    elif target.startswith("./") or target.startswith("../") or "/" in target or "\\" in target:
        candidates.append(md_dir / target)
        candidates.append(vault_root / target)
    else:
        ext = Path(target).suffix.lower()
        if ext:
            candidates.extend(name_index.get(target.lower(), []))
            candidates.append(md_dir / target)
        else:
            candidates.extend(stem_index.get(target.lower(), []))
            candidates.append(md_dir / f"{target}.md")

    files = [p for p in candidates if p.exists() and p.is_file()]
    if not files:
        return None
    return choose_best(files, prefer_exts=prefer_exts)

def split_fenced_blocks(text: str):
    lines = text.splitlines(keepends=True)
    blocks = []
    cur = []
    in_fence = False
    fence_char = ""
    fence_len = 0
    fence_re = re.compile(r"^(\s*)(```+|~~~+)")
    for line in lines:
        m = fence_re.match(line)
        if m:
            fence = m.group(2)
            if not in_fence:
                if cur:
                    blocks.append((False, "".join(cur)))
                    cur = []
                in_fence = True
                fence_char = fence[0]
                fence_len = len(fence)
                cur.append(line)
                continue
            if fence[0] == fence_char and len(fence) >= fence_len:
                cur.append(line)
                blocks.append((True, "".join(cur)))
                cur = []
                in_fence = False
                fence_char = ""
                fence_len = 0
                continue
        cur.append(line)
    if cur:
        blocks.append((in_fence, "".join(cur)))
    return blocks

def split_url_title(raw: str):
    raw = raw.strip()
    if raw.startswith("<") and raw.endswith(">"):
        raw = raw[1:-1].strip()
    m = re.match(r"^(\S+)(\s+.+)?$", raw)
    if not m:
        return raw, ""
    url = m.group(1)
    title = m.group(2) or ""
    return url, title

def split_path_tail(url: str):
    q = url.find("?")
    h = url.find("#")
    idx = None
    if q != -1 and h != -1:
        idx = min(q, h)
    elif q != -1:
        idx = q
    elif h != -1:
        idx = h
    else:
        return url, ""
    return url[:idx], url[idx:]

def is_remote(url: str):
    u = url.lower()
    return (
        u.startswith(("http://", "https://", "data:", "mailto:", "obsidian://", "file://", "ftp://"))
        or u.startswith("//")
        or u.startswith("#")
    )

def resolve_md_url(url: str):
    path_raw, tail = split_path_tail(url)
    if not path_raw:
        return None, tail
    path_decoded = unquote(path_raw)
    local = Path(path_decoded)
    if not local.is_absolute():
        local = (md_dir / path_decoded).resolve()
    if local.exists() and local.is_file():
        return local, tail
    return None, tail

def build_note_url(file_part: str, local_path: Path, subpath: str):
    if file_part:
        if local_path:
            rel = os.path.relpath(local_path, md_dir)
        else:
            rel = file_part
            if Path(rel).suffix == "":
                rel = rel + ".md"
        rel = rel.replace(os.sep, "/")
        rel_enc = quote(rel, safe="/")
        if subpath:
            frag = quote(subpath[1:], safe="^")
            return rel_enc + "#" + frag
        return rel_enc
    if subpath:
        frag = quote(subpath[1:], safe="^")
        return "#" + frag
    return ""

def is_md_file(path: Path):
    return path.suffix.lower() in MD_EXTS

assets = {}

def alloc_asset(local_path: Path):
    key = str(local_path.resolve())
    if key in assets:
        return assets[key]
    ext = local_path.suffix
    new_name = f"{uuid.uuid4()}{ext}"
    assets[key] = new_name
    return new_name

TOKEN_RE = re.compile(r"(!?\[\[[^\]]+\]\])|(!?\[[^\]]*\]\([^)]+\))")
MD_LINK_RE = re.compile(r"^(!?)\[([^\]]*)\]\(([^)]*)\)$")
SIZE_RE = re.compile(r"^\d+(x\d+)?$")

def rewrite_md_token(token: str):
    m = MD_LINK_RE.match(token)
    if not m:
        return token
    is_image = bool(m.group(1))
    label = m.group(2)
    inner = m.group(3)
    url, title = split_url_title(inner)
    if is_remote(url):
        return token
    local_path, tail = resolve_md_url(url)
    if not local_path:
        return token
    if is_md_file(local_path):
        return token
    new_name = alloc_asset(local_path)
    new_url = "__OSS_ASSET__/" + new_name + tail
    inside = new_url + (title or "")
    return f"{'!' if is_image else ''}[{label}]({inside})"

def rewrite_wiki_token(token: str):
    is_embed = token.startswith("![[")
    inner = token[3:-2] if is_embed else token[2:-2]
    if inner.startswith(("##", "^^")):
        return token

    if "|" in inner:
        target_part, alias = inner.split("|", 1)
        alias = alias.strip()
    else:
        target_part, alias = inner, ""

    target_part = target_part.strip()
    if target_part.startswith(("##", "^^")):
        return token

    if target_part.startswith("#"):
        file_part = ""
        subpath = target_part
    else:
        if "#" in target_part:
            file_part, sub = target_part.split("#", 1)
            subpath = "#" + sub
        else:
            file_part = target_part
            subpath = ""

    file_part = file_part.strip()
    subpath = subpath.strip()

    size = ""
    display = alias
    if is_embed and display and SIZE_RE.match(display):
        size = display
        display = ""

    ext = Path(file_part).suffix.lower() if file_part else ""
    prefer_exts = MD_EXTS if (not ext or ext in MD_EXTS) else None
    local_path = resolve_wiki_target(file_part, prefer_exts=prefer_exts) if file_part else None

    ext_local = local_path.suffix.lower() if local_path else ext
    if ext:
        is_note = ext in MD_EXTS
    elif local_path and is_md_file(local_path):
        is_note = True
    else:
        is_note = True

    if is_note:
        url = build_note_url(file_part, local_path, subpath)
        if not url:
            return token
        text = display or (file_part if file_part else subpath.lstrip("#"))
        return f"[{text}]({url})"

    if not local_path:
        return token

    new_name = alloc_asset(local_path)
    new_url = "__OSS_ASSET__/" + new_name + (subpath or "")
    if is_embed and ext_local in IMAGE_EXTS:
        alt = display or (Path(file_part).name if file_part else local_path.name)
        if size:
            alt = f"{alt}|{size}" if alt else f"|{size}"
        return f"![{alt}]({new_url})"
    text = display or (Path(file_part).name if file_part else local_path.name)
    return f"[{text}]({new_url})"

def rewrite_segment(seg: str):
    out = []
    last = 0
    for m in TOKEN_RE.finditer(seg):
        out.append(seg[last:m.start()])
        token = m.group(0)
        if token.startswith("[[") or token.startswith("![["):
            out.append(rewrite_wiki_token(token))
        else:
            out.append(rewrite_md_token(token))
        last = m.end()
    out.append(seg[last:])
    return "".join(out)

new_chunks = []
for is_code, block in split_fenced_blocks(text):
    if is_code:
        new_chunks.append(block)
    else:
        new_chunks.append(rewrite_segment(block))

new_text = "".join(new_chunks)
md_object_name = md_path.name

print(json.dumps(
    {
        "md_path": str(md_path),
        "md_object_name": md_object_name,
        "assets": [(k, v) for k, v in assets.items()],
        "rewritten_md": new_text,
    },
    ensure_ascii=False,
))
PY

JSON_OUT="$(python3 "${PY_SCRIPT}" "${MD_PATH}")"

# Extract fields with python (avoid jq dependency)
MD_OBJECT_NAME="$(python3 - "${JSON_OUT}" <<'PY'
import json,sys
o=json.loads(sys.argv[1])
print(o["md_object_name"])
PY
)"
MD_OBJECT_URL_NAME="$(python3 - "${MD_OBJECT_NAME}" <<'PY'
import sys
from urllib.parse import quote
print(quote(sys.argv[1], safe=""))
PY
)"

# Write rewritten md (replace placeholder with real base url)
ASSET_BASE_URL="${ALIYUN_OSS_PUBLIC_BASE_URL%/}/${ALIYUN_OSS_PREFIX}/${TARGET_SUBDIR}"
python3 - "${JSON_OUT}" <<PY
import json,sys
o=json.loads(sys.argv[1])
txt=o["rewritten_md"].replace("__OSS_ASSET__", "${ASSET_BASE_URL}")
open("${OUT_MD}", "w", encoding="utf-8").write(txt)
print("${OUT_MD}")
PY
>/dev/null

echo "Rewritten markdown: ${OUT_MD}"

# Upload assets
python3 - "${JSON_OUT}" "${TMPDIR}/assets.list" <<'PY'
import json,sys
o=json.loads(sys.argv[1])
out_path=sys.argv[2]
with open(out_path,"w",encoding="utf-8") as f:
    for local_abs, new_name in o["assets"]:
        f.write(local_abs+"\t"+new_name+"\n")
PY

ASSET_COUNT="$(wc -l < "${TMPDIR}/assets.list" | tr -d ' ')"
echo "Found ${ASSET_COUNT} local asset(s) to upload."

while IFS=$'\t' read -r LOCAL_ABS NEW_NAME; do
  [[ -z "${LOCAL_ABS}" ]] && continue
  OSS_KEY="oss://${ALIYUN_OSS_BUCKET}/${ALIYUN_OSS_PREFIX}/${TARGET_SUBDIR}/${NEW_NAME}"
  echo "Uploading asset: ${LOCAL_ABS} -> ${OSS_KEY}"
  OSS_CP "${LOCAL_ABS}" "${OSS_KEY}"
done < "${TMPDIR}/assets.list"

# Upload rewritten markdown with original filename
OSS_MD_KEY="oss://${ALIYUN_OSS_BUCKET}/${ALIYUN_OSS_PREFIX}/${TARGET_SUBDIR}/${MD_OBJECT_NAME}"
echo "Uploading markdown: ${OUT_MD} -> ${OSS_MD_KEY}"
OSS_CP "${OUT_MD}" "${OSS_MD_KEY}"

MD_PUBLIC_URL="${ALIYUN_OSS_PUBLIC_BASE_URL%/}/${ALIYUN_OSS_PREFIX}/${TARGET_SUBDIR}/${MD_OBJECT_URL_NAME}"

if [[ -f "${OUT_MD}" ]]; then
  rm -f "${OUT_MD}"
  echo "Cleaned local rewritten markdown: ${OUT_MD}"
fi

echo
echo "Done."
echo "Public markdown URL:"
echo "${MD_PUBLIC_URL}"
