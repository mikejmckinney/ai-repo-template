# bot-allowlist-normalize.jq — normalize the canonical bot allow-list.
#
# Input: raw lines from scripts/lib/bot-allowlist.txt
# Output: JSON array of normalized allow-listed logins.
#
# Replaces the inline jq program in scripts/pr-resolve-all-poll.sh.

[inputs
 | sub("#.*$"; "")
 | sub("^[[:space:]]+"; "")
 | sub("[[:space:]]+$"; "")
 | select(length > 0)
 | ascii_downcase
 | sub("\\[bot\\]$"; "")]
