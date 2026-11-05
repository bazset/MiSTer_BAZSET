#!/bin/sh
# Future opt-in GitHub metadata channels. Both are OFF by default.
# Downloaded files are untrusted DATA; never source or execute them.
HOOKS_CONF="$DATA_DIR/update_hooks.conf"
VERSION_FEED_URL="https://raw.githubusercontent.com/bazset/MiSTer_BAZSET/main/STRIPPER/script_version.txt"
UNLOCKABLE_FEED_URL="https://raw.githubusercontent.com/bazset/MiSTer_BAZSET/main/STRIPPER/unlockable.tsv"
hook_enabled() {
    [ -r "$HOOKS_CONF" ] || return 1
    awk -F= -v flag="$1" '$1==flag && $2=="1" {yes=1} END {exit !yes}' "$HOOKS_CONF"
}
future_hooks_status() {
    if hook_enabled SCRIPT_VERSION_CHECK_ENABLED; then
        say "  Script version-check hook: enabled (check only, no self-install)"
    else
        say "  Script version-check hook: DISABLED"
    fi
    if hook_enabled UNLOCKABLE_FEED_ENABLED; then
        say "  Verified-unlockable metadata feed: enabled"
    else
        say "  Verified-unlockable metadata feed: DISABLED"
    fi
}
check_script_version() {
    if ! hook_enabled SCRIPT_VERSION_CHECK_ENABLED; then
        say "Script version checking is currently disabled pending feed validation."
        return 0
    fi
    temp=$(mktemp "$DATA_DIR/.version.XXXXXX") || return 1
    if ! fetch_with_feedback "STRIPPER version metadata" "$VERSION_FEED_URL" "$temp"; then
        rm -f "$temp"; return 1
    fi
    value=$(sed -n 's/^STRIPPER_VERSION=//p' "$temp")
    rm -f "$temp"
    case "$value" in
        *[!0-9.]*|""|.*|*.) say "Invalid version metadata received" >&2; return 1 ;;
    esac
    if [ "$value" = "$VERSION" ]; then
        say "STRIPPER $VERSION: current version according to GitHub metadata"
    else
        say "Installed version: $VERSION; GitHub version: $value"
        say "Automatic script replacement is deliberately disabled."
    fi
}
check_unlockable_feed() {
    if ! hook_enabled UNLOCKABLE_FEED_ENABLED; then
        say "Verified-unlockable RBF feed is currently disabled; no recipe claims are made."
        return 0
    fi
    temp=$(mktemp "$DATA_DIR/.unlockable.XXXXXX") || return 1
    if ! fetch_with_feedback "verified-unlockable catalogue" "$UNLOCKABLE_FEED_URL" "$temp"; then
        rm -f "$temp"; return 1
    fi
    [ "$(wc -c < "$temp")" -le 524288 ] || { rm -f "$temp"; say "Feed too large" >&2; return 1; }
    awk -F '\t' '
      /^#/ || NF==0 {next}
      NF!=4 || length($1)!=64 || $1 ~ /[^0123456789abcdef]/ ||
      $2 !~ /^[a-zA-Z0-9_.-]+[.]rbf$/ || $3!="VERIFIED" ||
      $4 !~ /^[a-zA-Z0-9_.-]+$/ {bad=1; next}
      {found++}
      END {if(bad) exit 1}
    ' "$temp" || { rm -f "$temp"; say "Invalid unlockable metadata" >&2; return 1; }
    mv -f "$temp" "$DATA_DIR/unlockable.tsv"
    say "Verified-unlockable metadata downloaded. This is informational; it does not install a patch."
}
