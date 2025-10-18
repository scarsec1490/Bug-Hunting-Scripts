#!/bin/bash

# Usage: ./scanner.sh ips.txt

INPUT_FILE="$1"

if [[ -z "$INPUT_FILE" || ! -f "$INPUT_FILE" ]]; then
    echo "Usage: $0 <ips_file>"
    exit 1
fi

echo "[*] Running rustscan on $INPUT_FILE..."
rustscan -a "$INPUT_FILE" -r 1-65535 -- --no-nmap | tee rustresult.txt

echo "[*] Extracting IP:PORT pairs..."
grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}:[0-9]+' rustresult.txt | sort -u > ips_with_ports.txt

echo "[*] Done. Results saved in:"
echo "   - rustresult.txt (raw scan)"
echo "   - ips_with_ports.txt (clean IP:PORT list)"
