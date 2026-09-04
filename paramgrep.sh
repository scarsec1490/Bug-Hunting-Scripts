#!/bin/bash
#
# paramgrep.sh - Extract URL parameters and classify them using gf patterns
#
# Usage: ./paramgrep.sh [input_file]
#   input_file defaults to allurls.txt in the current directory
#
# Requirements:
#   - uro   (pip install uro)
#   - gf    (go install github.com/tomnomnom/gf@latest)
#   - gf patterns installed (https://github.com/tomnomnom/gf + Gf-Patterns)
#
set -euo pipefail
# ------------------------------------------------------------------
# Config
# ------------------------------------------------------------------
INPUT_FILE="${1:-allurls.txt}"
OUTPUT_DIR="parameters"
PARAMS_FILE="params.txt"
JS_FILE="jsfiles.txt"
# List of gf patterns to run. Add/remove as your gf-patterns set allows.
GF_PATTERNS=(
    sqli
    xss
    lfi
    ssrf
    rce
    redirect
    idor
    ssti
    debug_logic
    interestingsubs
    interestingparams
    img-traversal
    s3-buckets
)
# ------------------------------------------------------------------
# Colors for output
# ------------------------------------------------------------------
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'
log()  { echo -e "${CYAN}[*]${NC} $1"; }
ok()   { echo -e "${GREEN}[+]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
err()  { echo -e "${RED}[-]${NC} $1"; }
# ------------------------------------------------------------------
# Pre-flight checks
# ------------------------------------------------------------------
if [[ ! -f "$INPUT_FILE" ]]; then
    err "Input file '$INPUT_FILE' not found."
    exit 1
fi
for cmd in uro gf; do
    if ! command -v "$cmd" &>/dev/null; then
        err "Required tool '$cmd' is not installed or not in PATH."
        exit 1
    fi
done
mkdir -p "$OUTPUT_DIR"
# ------------------------------------------------------------------
# Step 1: Extract URLs with parameters, dedupe with uro
# ------------------------------------------------------------------
log "Extracting URLs with parameters from '$INPUT_FILE'..."
cat "$INPUT_FILE" | grep "=" | uro | tee "$PARAMS_FILE" > /dev/null
TOTAL_LINES=$(wc -l < "$PARAMS_FILE" | tr -d ' ')
ok "Extracted $TOTAL_LINES parameterized URLs -> $PARAMS_FILE"
# ------------------------------------------------------------------
# Step 1b: Extract JS file URLs
# ------------------------------------------------------------------
log "Extracting JavaScript file URLs from '$INPUT_FILE'..."
grep -Ei '\.js(\?[^[:space:]]*)?$' "$INPUT_FILE" | sort -u > "$JS_FILE"
JS_COUNT=$(wc -l < "$JS_FILE" | tr -d ' ')
ok "Extracted $JS_COUNT JS file URLs -> $JS_FILE"

if [[ "$TOTAL_LINES" -eq 0 ]]; then
    warn "No parameterized URLs found. Exiting."
    exit 0
fi
# ------------------------------------------------------------------
# Step 2: Run gf patterns and save results into parameters/
# ------------------------------------------------------------------
log "Running gf patterns..."
for pattern in "${GF_PATTERNS[@]}"; do
    out_file="${OUTPUT_DIR}/${pattern}_params.txt"
    if cat "$PARAMS_FILE" | gf "$pattern" > "$out_file" 2>/dev/null; then
        count=$(wc -l < "$out_file" | tr -d ' ')
        if [[ "$count" -gt 0 ]]; then
            ok "$pattern -> $count matches ($out_file)"
        else
            rm -f "$out_file"
            warn "$pattern -> 0 matches (skipped, no file created)"
        fi
    else
        rm -f "$out_file"
        warn "$pattern -> gf pattern not found or failed, skipping"
    fi
done
echo
ok "Done. Results saved in '${OUTPUT_DIR}/' directory."
ls -la "$OUTPUT_DIR"
if [[ -s "$JS_FILE" ]]; then
    ok "JS files saved in '$JS_FILE' ($JS_COUNT entries)."
fi
