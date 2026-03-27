#!/bin/bash

# Interactive Recon Script with Depth Option + Early Stop on 0 Subdomains
# Usage:
#   ./recon.sh example.com
#   ./recon.sh scope.txt

# Colors
GREEN="\033[0;32m"
RED="\033[0;31m"
YELLOW="\033[1;33m"
NC="\033[0m"

# ----------------- Input Validation -----------------
if [ -z "$1" ]; then
    echo -e "${RED}[-] Usage: $0 <domain | domains.txt>${NC}"
    exit 1
fi

TARGET=$1
BASENAME=$(basename "$TARGET" .txt)
OUTPUT_DIR=$BASENAME
mkdir -p "$OUTPUT_DIR"

# ----------------- Ask for Subdomain Recursion Depth -----------------
while true; do
    read -p "Enter the number of subdomain recursion rounds (1-5): " DEPTH
    if [[ "$DEPTH" =~ ^[1-5]$ ]]; then
        break
    else
        echo -e "${RED}Please enter a valid number between 1 and 5.${NC}"
    fi
done

echo -e "${YELLOW}======================================${NC}"
echo -e "${YELLOW}[+] Target: $TARGET${NC}"
echo -e "${YELLOW}[+] Max Recursion Depth: $DEPTH${NC}"
echo -e "${YELLOW}[+] Output directory: $OUTPUT_DIR/${NC}"
echo -e "${YELLOW}======================================${NC}"

# ----------------- Helper -----------------
check_and_count() {
    local file="$1"
    if [[ -f "$file" && -s "$file" ]]; then
        echo "$(wc -l < "$file")"
    else
        echo "0"
    fi
}

# ----------------- Subdomain Expansion -----------------
PREV_FILE=""
for ((i=1;i<=DEPTH;i++)); do
    CURRENT_FILE="$OUTPUT_DIR/subs_${i}.txt"
    echo -e "${GREEN}[+] Running subfinder for round $i -> $CURRENT_FILE${NC}"

    if [[ $i -eq 1 ]]; then
        if [[ -f "$TARGET" ]]; then
            subfinder -dL "$TARGET" -all -recursive -o "$CURRENT_FILE"
        else
            subfinder -d "$TARGET" -all -recursive -o "$CURRENT_FILE"
        fi
    else
        if [[ -s "$PREV_FILE" ]]; then
            subfinder -dL "$PREV_FILE" -all -recursive -o "$CURRENT_FILE"
        else
            touch "$CURRENT_FILE"
        fi
    fi

    if [[ -f "$CURRENT_FILE" ]]; then
        sort -u "$CURRENT_FILE" -o "$CURRENT_FILE"
    fi

    NEW_SUBS=$(check_and_count "$CURRENT_FILE")
    echo -e "${YELLOW}[+] Round $i subdomains: $NEW_SUBS${NC}"

    if [[ $NEW_SUBS -eq 0 ]]; then
        echo -e "${YELLOW}[!] No subdomains found in round $i. Stopping early.${NC}"
        rm -f "$CURRENT_FILE"
        break
    fi

    PREV_FILE="$CURRENT_FILE"
done

# ----------------- Merge all rounds + Add original targets -----------------
echo -e "${GREEN}[+] Merging all rounds + original targets -> allsubs.txt${NC}"
cat "$OUTPUT_DIR"/subs_*.txt 2>/dev/null | sort -u > "$OUTPUT_DIR/allsubs.txt"

# Add original target(s) to allsubs.txt
if [[ -f "$TARGET" ]]; then
    echo -e "${GREEN}[+] Adding all domains from $TARGET to allsubs.txt${NC}"
    cat "$TARGET" >> "$OUTPUT_DIR/allsubs.txt"
else
    echo -e "${GREEN}[+] Adding $TARGET to allsubs.txt${NC}"
    echo "$TARGET" >> "$OUTPUT_DIR/allsubs.txt"
fi

# Final dedup
sort -u "$OUTPUT_DIR/allsubs.txt" -o "$OUTPUT_DIR/allsubs.txt"
echo -e "${YELLOW}[+] Total unique subdomains: $(check_and_count "$OUTPUT_DIR/allsubs.txt")${NC}"

if [[ ! -s "$OUTPUT_DIR/allsubs.txt" ]]; then
    echo -e "${RED}[-] No subdomains found. Exiting.${NC}"
    exit 1
fi

# ----------------- Live Subdomain Check -----------------
echo -e "${GREEN}[+] Running httpx to filter live subdomains...${NC}"
httpx -l "$OUTPUT_DIR/allsubs.txt" -silent -o "$OUTPUT_DIR/live_subs.txt"
echo -e "${YELLOW}[+] Live subdomains: $(check_and_count "$OUTPUT_DIR/live_subs.txt")${NC}"

# ----------------- Crawling -----------------
echo -e "${GREEN}[+] Running katana, gau, and waybackurls...${NC}"

if [[ -s "$OUTPUT_DIR/live_subs.txt" ]]; then
    katana -list "$OUTPUT_DIR/live_subs.txt" -d 5 -o "$OUTPUT_DIR/katana_urls.txt"
    echo -e "${YELLOW}[+] Katana URLs: $(check_and_count "$OUTPUT_DIR/katana_urls.txt")${NC}"
else
    touch "$OUTPUT_DIR/katana_urls.txt"
    echo -e "${YELLOW}[!] No live hosts to scan with katana.${NC}"
fi

if [[ -s "$OUTPUT_DIR/allsubs.txt" ]]; then
    cat "$OUTPUT_DIR/allsubs.txt" | gau > "$OUTPUT_DIR/gau_urls.txt" 2>/dev/null &
    gau_pid=$!
    cat "$OUTPUT_DIR/allsubs.txt" | waybackurls > "$OUTPUT_DIR/wayback_urls.txt" 2>/dev/null &
    wayback_pid=$!
    wait $gau_pid
    wait $wayback_pid
    echo -e "${YELLOW}[+] GAU URLs: $(check_and_count "$OUTPUT_DIR/gau_urls.txt")${NC}"
    echo -e "${YELLOW}[+] Wayback URLs: $(check_and_count "$OUTPUT_DIR/wayback_urls.txt")${NC}"
else
    touch "$OUTPUT_DIR/gau_urls.txt" "$OUTPUT_DIR/wayback_urls.txt"
fi

cat "$OUTPUT_DIR"/katana_urls.txt "$OUTPUT_DIR"/gau_urls.txt "$OUTPUT_DIR"/wayback_urls.txt 2>/dev/null | sort -u > "$OUTPUT_DIR/allurls.txt"
echo -e "${YELLOW}[+] Total unique URLs: $(check_and_count "$OUTPUT_DIR/allurls.txt")${NC}"

# ----------------- Summary -----------------
echo -e "${YELLOW}======================================${NC}"
echo -e "${GREEN}[+] Recon completed. Files generated in $OUTPUT_DIR/:${NC}"
for f in subs_*.txt allsubs.txt live_subs.txt katana_urls.txt gau_urls.txt wayback_urls.txt allurls.txt; do
    [[ -f "$OUTPUT_DIR/$f" ]] && echo "  - $f"
done
echo -e "${YELLOW}======================================${NC}"
