# cloudflare-ddns

Simple dynamic DNS updater for Cloudflare using [flarectl](https://github.com/cloudflare/cloudflare-go/tree/master/cmd/flarectl).

Updates existing A records when your public IP changes. Preserves proxy (orange cloud) settings.

## Requirements

- `flarectl`
- `jq`
- `curl`

## Environment variables

| Variable | Description |
|---|---|
| `CF_API_TOKEN` | Cloudflare API token (used by flarectl) |
| `CF_DDNS_RECORDS` | Comma-separated `zone:name` pairs, e.g. `example.com:home.example.com,example.com:vpn.example.com` |

## Usage

```bash
# Dry run
./cloudflare-ddns.sh --dry-run

# Run
./cloudflare-ddns.sh
```

## Cron

```cron
PATH=/opt/homebrew/bin:/usr/bin:/bin
*/5 * * * * . ~/.envrc && /path/to/cloudflare-ddns.sh >> /tmp/cloudflare-ddns.log 2>&1
```
