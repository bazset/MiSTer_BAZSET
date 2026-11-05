#!/bin/sh
# STRIPPER native MiSTer scanner v0.1. Catalog-driven; no RBF modifications.
set -eu

VERSION=0.1
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DATA_DIR=${STRIPPER_DATA_DIR:-"$SCRIPT_DIR/STRIPPER"}
CATALOG="$DATA_DIR/catalog.tsv"
LOCAL="$DATA_DIR/catalog.local.tsv"
FAMILIES="$DATA_DIR/beta_families.txt"
CATALOG_URL=${STRIPPER_CATALOG_URL:-https://raw.githubusercontent.com/bazset/MiSTer_BAZSET/main/STRIPPER/catalog.tsv}
FAMILIES_URL=https://raw.githubusercontent.com/jotego/jtcores/master/.beta.yaml
CORES_DEFAULT=${STRIPPER_CORES_DIR:-/media/fat/_Arcade/cores}

say() { printf '%s\n' "$*"; }
fail() { printf 'STRIPPER ERROR: %s\n' "$*" >&2; exit 1; }
require_data() {
    [ -r "$CATALOG" ] || fail "Missing catalogue: $CATALOG"
    [ -r "$FAMILIES" ] || fail "Missing family list: $FAMILIES"
    [ -r "$LOCAL" ] || fail "Missing local override file: $LOCAL"
}
fetch() {
    case "$1" in https://raw.githubusercontent.com/*) ;; *)
        say "Only raw.githubusercontent.com HTTPS sources are allowed." >&2
        return 1 ;;
    esac
    if command -v curl >/dev/null 2>&1; then
        curl --fail --silent --show-error --location --connect-timeout 10 --max-time 60 --output "$2" "$1"
    elif command -v wget >/dev/null 2>&1; then
        wget -q -O "$2" "$1"
    else
        say "Neither curl nor wget is available." >&2
        return 1
    fi
}
validate_catalog() {
    awk -F '\t' '
      /^#/ || NF==0 {next}
      NF!=4 || length($1)!=64 || $1 ~ /[^0123456789abcdef]/ ||
      $2 !~ /^[a-zA-Z0-9_.-]+[.]rbf$/ ||
      $3!="BETA_FAMILY_LISTED" ||
      $4 !~ /^[a-zA-Z0-9_.-]+$/ {bad=1; next}
      {good++}
      END {if (bad || good<1) exit 1}
    ' "$1"
}
update_catalogue() {
    mkdir -p "$DATA_DIR"
    t1=$(mktemp "$DATA_DIR/.catalog.XXXXXX") || fail "Cannot create temporary file"
    t2=$(mktemp "$DATA_DIR/.upstream.XXXXXX") || fail "Cannot create temporary file"
    t3=$(mktemp "$DATA_DIR/.families.XXXXXX") || fail "Cannot create temporary file"
    trap 'rm -f "$t1" "$t2" "$t3"' 0 1 2 15
    say "Updating exact-hash catalogue from GitHub..."
    fetch "$CATALOG_URL" "$t1" || fail "Catalogue download failed; existing files preserved"
    [ "$(wc -c < "$t1")" -le 524288 ] || fail "Catalogue too large; refusing update"
    validate_catalog "$t1" || fail "Invalid catalogue format; existing files preserved"
    say "Updating beta-family list from Jotego GitHub..."
    fetch "$FAMILIES_URL" "$t2" || fail "Jotego list download failed; existing files preserved"
    [ "$(wc -c < "$t2")" -le 524288 ] || fail "Upstream list too large; refusing update"
    awk '/^[a-z0-9_]+:[[:space:]]*\[/ && /mister/ {split($0,f,":"); print "jt" f[1] ".rbf"}' "$t2" |
        sort -u > "$t3"
    awk '/^jt[a-z0-9_]+[.]rbf$/ {good++; next} {bad=1} END {if(bad || good<1) exit 1}' "$t3" ||
        fail "Unexpected upstream format; existing files preserved"
    mv -f "$t1" "$CATALOG"
    mv -f "$t3" "$FAMILIES"
    say "UPDATE OK: downloaded $(awk -F '\t' '!/^#/ && NF==4 {n++} END{print n+0}' "$CATALOG") exact hashes and $(awk 'NF && !/^#/ {n++} END{print n+0}' "$FAMILIES") upstream beta families."
    say "Your personal catalog.local.tsv is preserved. No RBF was changed."
}
catalogue_name() {
    awk -F '\t' -v n="$1" 'NF==4 && tolower($2)==n {found=1; exit} END{exit !found}' "$CATALOG" "$LOCAL"
}
catalogue_hash() {
    awk -F '\t' -v h="$1" 'NF==4 && $1==h {print $2 "|" $3 "|" $4; exit}' "$CATALOG" "$LOCAL"
}
scan() {
    require_data
    cores="$CORES_DEFAULT"
    [ -d "$cores" ] || cores="$SCRIPT_DIR/../_Arcade/cores"
    full=0
    for arg in "$@"; do
        case "$arg" in --all) full=1 ;; *) cores="$arg" ;; esac
    done
    [ -d "$cores" ] || fail "RBF folder not found: $cores"
    command -v sha256sum >/dev/null 2>&1 || fail "sha256sum not installed"
    say "STRIPPER $VERSION - MiSTer native catalogue scanner"
    say "Scanning: $cores"
    say "Mode: $([ "$full" -eq 1 ] && printf 'all-hashes' || printf 'fast: listed names only')"
    say "-----------------------------------------------"
    total=0; matched=0; candidates=0; skipped=0
    for f in "$cores"/*.rbf "$cores"/*.RBF; do
        [ -f "$f" ] || continue
        total=$((total+1))
        name=${f##*/}
        lower=$(printf '%s' "$name" | tr 'A-Z' 'a-z')
        listed=0
        if grep -Fqx "$lower" "$FAMILIES"; then listed=1; fi
        named=0
        if catalogue_name "$lower"; then named=1; fi
        if [ "$full" -eq 0 ] && [ "$listed" -eq 0 ] && [ "$named" -eq 0 ]; then
            skipped=$((skipped+1))
            continue
        fi
        sum=$(sha256sum "$f" | awk '{print tolower($1)}')
        entry=$(catalogue_hash "$sum")
        if [ -n "$entry" ]; then
            matched=$((matched+1))
            printf 'EXACT HASH: %s [%s]\n' "$name" "$sum"
            if [ "$listed" -eq 0 ]; then
                say "  Note: upstream no longer lists this name (or it was renamed)."
            fi
        elif [ "$listed" -eq 1 ]; then
            candidates=$((candidates+1))
            printf 'BETA FAMILY / UNKNOWN RBF VERSION: %s [%s]\n' "$name" "$sum"
        elif [ "$named" -eq 1 ]; then
            candidates=$((candidates+1))
            printf 'CATALOGUE NAME / UNRECOGNIZED HASH: %s [%s]\n' "$name" "$sum"
        else
            printf 'NOT IN CATALOGUE: %s\n' "$name"
        fi
    done
    say "-----------------------------------------------"
    say "Total RBFs: $total; exact catalogue hashes: $matched; beta-family unknown versions: $candidates; fast-skipped: $skipped"
    say "An entry identifies an RBF version or beta-listed family; it is NOT proof of a key circuit or a working unlock."
    say "No core was decompiled, changed, or replaced."
}
list_catalogue() {
    require_data
    say "STRIPPER $VERSION - known Jotego MiSTer beta core families"
    grep -v '^#' "$FAMILIES"
    say ""
    say "Versioned hash catalogue:"
    awk -F '\t' 'NF==4 && !/^#/ {printf "%s  %s...  %s\n", $2, substr($1,1,12),$3}' "$CATALOG" "$LOCAL"
    say ""
    say "GitHub catalogue: $CATALOG_URL"
}
status() {
    require_data
    say "STRIPPER $VERSION - MiSTer native catalogue mode"
    say "Data location: $DATA_DIR"
    say "Hash entries: $(awk -F '\t' 'NF==4 && !/^#/ {n++} END {print n+0}' "$CATALOG" "$LOCAL")"
    say "Upstream MiSTer beta families: $(awk 'NF && !/^#/ {n++} END {print n+0}' "$FAMILIES")"
    say "Update endpoint: $CATALOG_URL"
    say "Mode: detection/report only. No FPGA patch implemented."
}
menu() {
    while :; do
        say ""
        say "========== STRIPPER $VERSION =========="
        say "1) Scan arcade RBFs (fast)"
        say "2) Update catalogue from GitHub"
        say "3) List known RBFs"
        say "4) Show status"
        say "0) Exit"
        printf "Choose: "
        IFS= read -r choice || return
        case "$choice" in
            1) scan ;; 2) update_catalogue ;; 3) list_catalogue ;;
            4) status ;; 0) return ;; *) say "Choose 0-4." ;;
        esac
    done
}
case "${1:-}" in
    scan) shift; scan "$@" ;;
    update) update_catalogue ;;
    list) list_catalogue ;;
    status) status ;;
    --version) say "STRIPPER $VERSION" ;;
    help|--help|-h) say "Usage: STRIPPER.sh [scan [--all] [RBF_DIRECTORY] | update | list | status]" ;;
    "") if [ -t 0 ]; then menu; else scan; fi ;;
    *) fail "Unknown command. Run --help." ;;
esac
