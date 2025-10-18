#!/bin/bash

# ==============================
# Param Extractor Script
# ==============================
# Usage: ./paramgrep.sh allurls.txt
# Output: Results saved in ./params_output/
# ==============================

# Check if input file provided
if [ $# -eq 0 ]; then
    echo "Usage: $0 <urls_file>"
    exit 1
fi

INPUT=$1

# Check if file exists
if [ ! -f "$INPUT" ]; then
    echo "Error: File '$INPUT' not found!"
    exit 1
fi

# Create output directory
OUTDIR="params_output"
mkdir -p "$OUTDIR"

echo "[*] Extracting parameters and JS files from $INPUT ..."
echo "[*] Results will be saved in $OUTDIR/"

# XSS (full URLs)
grep -Ei "(\?|&)(q|s|search|id|page|lang|query|keyword)=" "$INPUT" | sort -u > "$OUTDIR/xss_params.txt"
echo "[+] XSS parameterized URLs saved to $OUTDIR/xss_params.txt"

# SQLi (full URLs)
grep -Ei "(\?|&)(id|uid|pid|product|cat|category|item|shop|user|number|order)=" "$INPUT" | sort -u > "$OUTDIR/sqli_params.txt"
echo "[+] SQLi parameterized URLs saved to $OUTDIR/sqli_params.txt"

# LFI (full URLs)
grep -Ei "(\?|&)(file|path|dir|page|template|inc|include|doc|document)=" "$INPUT" | sort -u > "$OUTDIR/lfi_params.txt"
echo "[+] LFI parameterized URLs saved to $OUTDIR/lfi_params.txt"

# Open Redirect (full URLs)
grep -Ei "(\?|&)(url|redirect|next|dest|destination|return|go|r|link)=" "$INPUT" | sort -u > "$OUTDIR/openredirect_params.txt"
echo "[+] Open Redirect parameterized URLs saved to $OUTDIR/openredirect_params.txt"

# SSRF (full URLs)
grep -Ei "(\?|&)(dest|redirect|uri|path|continue|url|window|next)=" "$INPUT" | sort -u > "$OUTDIR/ssrf_params.txt"
echo "[+] SSRF parameterized URLs saved to $OUTDIR/ssrf_params.txt"

# General extractor: all URLs with parameters
grep -E "\?.*=" "$INPUT" | sort -u > "$OUTDIR/all_param_urls.txt"
echo "[+] All parameterized URLs saved to $OUTDIR/all_param_urls.txt"

# Parameter names only
grep -oP "(?<=\?|&)[^=]+(?==)" "$INPUT" | sort -u > "$OUTDIR/all_params.txt"
echo "[+] All unique parameter names saved to $OUTDIR/all_params.txt"

# JavaScript files
grep -E "\.js(\?|$)" "$INPUT" | sort -u > "$OUTDIR/jsfiles.txt"
echo "[+] JavaScript files saved to $OUTDIR/jsfiles.txt"

echo "[*] Done! Extracted parameters and JS files are in $OUTDIR/"