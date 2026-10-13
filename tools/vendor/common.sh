# Shared helpers for the vendoring scripts. Sourced, not executed.

# sha256 of a file, bare hex, on macOS and Linux alike.
sha256_of() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$1" | cut -d' ' -f1
    elif command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$1" | cut -d' ' -f1
    else
        echo "no sha256sum or shasum available" >&2
        exit 1
    fi
}

# Field $2 of the manifest row for source $1.
manifest_field() {
    awk -v want="$1" -v col="$2" '
        NR == 1 { for (i = 1; i <= NF; i++) if ($i == col) c = i; next }
        $1 == want { print $c; found = 1; exit }
        END { if (!found) exit 1 }
    ' FS='\t' "$MANIFEST"
}

# Every source named in the manifest.
manifest_sources() {
    awk 'NR > 1 { print $1 }' FS='\t' "$MANIFEST"
}

# Every vendored file for source $1, sorted, repo-relative.
vendored_files() {
    find "src/vendor/$1" -type f ! -name '*.o' ! -name '*.so' ! -name '*.dll' \
        | LC_ALL=C sort
}

# The files kept from each source: the archive members, then the licence
# taken from the tagged commit, since the release artefact carries none.
archive_members() {
    case "$1" in
        simdutf) echo "simdutf.h simdutf.cpp simdutf_c.h" ;;
        *) echo "no keep list for source: $1" >&2; exit 1 ;;
    esac
}
licence_files() {
    case "$1" in
        simdutf) echo "LICENSE-MIT" ;;
        *) echo "no licence list for source: $1" >&2; exit 1 ;;
    esac
}
