#!/usr/bin/env bash
# domain_to_ip.sh
# Usage: ./domain_to_ip.sh urls.txt
# Output: domain_ips.txt (only IPv4)

set -euo pipefail
[ $# -ne 1 ] && { echo "Usage: $0 urls.txt"; exit 1; }

input="$1"
output="domain_ips.txt"
> "$output"

extract_host() {
  local url="$1"
  url="${url#*://}"      # remove scheme (http://, https://)
  url="${url##*@}"       # remove credentials
  url="${url%%/*}"       # remove path
  url="${url%%:*}"       # remove port
  [ -n "$url" ] && echo "$url"
}

while IFS= read -r line || [ -n "$line" ]; do
  [[ -z "$line" || "$line" =~ ^# ]] && continue

  host=$(extract_host "$line")
  [ -z "$host" ] && continue

  # Resolve only IPv4 (A records)
  ip=$(dig +short A "$host" 2>/dev/null | grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -n1)

  # If dig fails, try getent
  if [ -z "$ip" ]; then
    ip=$(getent ahostsv4 "$host" 2>/dev/null | awk '{print $1; exit}')
  fi

  # If still empty, try ping (IPv4 only)
  if [ -z "$ip" ]; then
    ip=$(ping -4 -c1 -W1 "$host" 2>/dev/null | grep -oP '(?<=\().+?(?=\))' | head -n1)
  fi

  # Save IP if found
  [ -n "$ip" ] && echo "$ip"
done < "$input" | sort -u > "$output"

echo "✅ IPv4 addresses saved to: $output"
