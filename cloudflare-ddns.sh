#!/usr/bin/env bash
set -euo pipefail

# CF_DDNS_RECORDS env var: comma-separated "zone:name" pairs
# e.g. CF_DDNS_RECORDS="example.com:home.example.com,example.com:www.example.com"
if [[ -z "${CF_DDNS_RECORDS:-}" ]]; then
  echo "$(date): ERROR - CF_DDNS_RECORDS not set" >&2
  exit 1
fi
IFS=',' read -ra RECORDS <<< "$CF_DDNS_RECORDS"

DRY_RUN=false
if [[ "${1:-}" == "--dry-run" || "${1:-}" == "-n" ]]; then
  DRY_RUN=true
fi

IP_CACHE="/tmp/cloudflare-ddns-last-ip"

# Get current public IP
current_ip=$(curl -s -f https://ifconfig.net || curl -s -f https://ifconfig.me/ip)
current_ip=$(echo "$current_ip" | tr -d '[:space:]')

if [[ -z "$current_ip" ]]; then
  echo "$(date): ERROR - Could not determine public IP" >&2
  exit 1
fi

# Check if IP changed
if [[ -f "$IP_CACHE" ]] && [[ "$(cat "$IP_CACHE")" == "$current_ip" ]]; then
  $DRY_RUN && echo "IP unchanged ($current_ip), nothing to do"
  exit 0
fi

echo "$(date): IP changed to $current_ip"

failed=0
for record in "${RECORDS[@]}"; do
  zone="${record%%:*}"
  name="${record##*:}"

  # Look up existing record to get ID, IP, and proxy status
  existing=$(flarectl --json dns list --zone "$zone" --name "$name" --type A 2>/dev/null) || true
  record_id=$(echo "$existing" | jq -r '.[0].ID // empty')
  old_ip=$(echo "$existing" | jq -r '.[0].Content // empty')
  proxied=$(echo "$existing" | jq -r '.[0].Proxied // "false"')

  proxy_flag=""
  if [[ "$proxied" == "true" ]]; then
    proxy_flag="--proxy"
  fi

  if [[ -z "$record_id" ]]; then
    echo "  WARNING: No existing A record found for $name, skipping" >&2
    failed=1
    continue
  fi

  if [[ "$old_ip" == "$current_ip" ]]; then
    continue
  fi

  if $DRY_RUN; then
    echo "  [dry-run] Would update $name: $old_ip -> $current_ip (proxy: $proxied)"
    continue
  fi

  if flarectl dns update --zone "$zone" --id "$record_id" --name "$name" --type A --content "$current_ip" --ttl 1 $proxy_flag; then
    echo "  Updated $name: $old_ip -> $current_ip (proxy: $proxied)"
  else
    echo "  ERROR updating $name" >&2
    failed=1
  fi
done

if [[ "$failed" -eq 0 ]] && ! $DRY_RUN; then
  echo "$current_ip" > "$IP_CACHE"
fi
