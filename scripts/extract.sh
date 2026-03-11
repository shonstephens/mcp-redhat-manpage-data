#!/usr/bin/env bash
# Extract man pages from RHEL UBI containers for each major version.
# Renders groff to plain text and stores under manpages/<version>/.
#
# Usage: bash scripts/extract.sh [8|9|10]
#   No argument = extract all versions.
#
# Requires: podman or docker, network access to registry.access.redhat.com

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
MANPAGES_DIR="$PROJECT_DIR/manpages"

# Detect container runtime
if command -v podman &>/dev/null; then
  CONTAINER_CMD="podman"
elif command -v docker &>/dev/null; then
  CONTAINER_CMD="docker"
else
  echo "ERROR: Neither podman nor docker found. Install one to extract man pages."
  exit 1
fi

echo "Using container runtime: ${CONTAINER_CMD}"

# UBI images per RHEL version
declare -A UBI_IMAGES=(
  [8]="registry.access.redhat.com/ubi8/ubi:latest"
  [9]="registry.access.redhat.com/ubi9/ubi:latest"
  [10]="registry.access.redhat.com/ubi10/ubi:latest"
)

# Packages to install. These are the packages whose man pages we want.
# Extend this list as needed — any RHEL package with useful man pages.
PACKAGES=(
  # SSSD and identity
  sssd-common
  sssd-ad
  sssd-ldap
  sssd-krb5
  sssd-tools
  sssd-client
  # Kerberos
  krb5-workstation
  krb5-libs
  # AD integration
  adcli
  realmd
  # Auth stack
  authselect
  # Crypto
  crypto-policies
  crypto-policies-scripts
  # System services
  chrony
  systemd
  # Network
  NetworkManager
  bind-utils
  # Core
  man-db
  man-pages
  coreutils
  shadow-utils
  # PAM
  pam
)

extract_version() {
  local version="$1"
  local image="${UBI_IMAGES[$version]}"
  local output_dir="$MANPAGES_DIR/rhel${version}"
  local container_name="manpage-extract-rhel${version}"

  echo "=== Extracting man pages for RHEL ${version} ==="
  echo "    Image: ${image}"
  echo "    Output: ${output_dir}"

  mkdir -p "$output_dir"

  # Remove existing container if present
  $CONTAINER_CMD rm -f "$container_name" 2>/dev/null || true

  # Build the package install command — skip unavailable packages gracefully
  local pkg_list="${PACKAGES[*]}"

  # Run container: install packages, then extract all man pages
  # Note: UBI images set tsflags=nodocs by default, which skips man pages.
  # We override this AND reinstall pre-installed packages to get their man pages.
  $CONTAINER_CMD run --name "$container_name" "$image" bash -c "
    set -e

    # Remove nodocs flag so man pages are installed
    sed -i '/^tsflags=nodocs/d' /etc/dnf/dnf.conf 2>/dev/null || true

    # Install man-db first (provides the man command)
    dnf install -y man-db 2>/dev/null || true

    # Reinstall already-installed packages to pick up their man pages
    dnf reinstall -y krb5-libs 2>/dev/null || true

    # Install target packages — skip failures (some may not exist on all versions)
    for pkg in ${pkg_list}; do
      dnf install -y \"\$pkg\" 2>/dev/null || echo \"SKIP: \$pkg not available\"
    done

    # Find all man page files (compressed and uncompressed)
    find /usr/share/man -type f \\( -name '*.gz' -o -name '*.[0-9]' -o -name '*.[0-9]p' \\) 2>/dev/null | sort
  "

  # Copy the man page files out of the container
  local tmpdir
  tmpdir=$(mktemp -d)

  # Get the list of man page files from the container
  local manfiles
  manfiles=$($CONTAINER_CMD start -a "$container_name" 2>/dev/null || true)

  if [ -z "$manfiles" ]; then
    # Re-run to get file list
    manfiles=$($CONTAINER_CMD exec "$container_name" find /usr/share/man -type f \( -name '*.gz' -o -name '*.[0-9]' -o -name '*.[0-9]p' \) 2>/dev/null | sort || true)
  fi

  # Use container cp to extract the entire man directory
  $CONTAINER_CMD cp "$container_name:/usr/share/man" "$tmpdir/man" 2>/dev/null || {
    echo "ERROR: Could not copy man pages from container"
    $CONTAINER_CMD rm -f "$container_name" 2>/dev/null || true
    rm -rf "$tmpdir"
    return 1
  }

  # Render each man page to plain text
  local count=0
  while IFS= read -r -d '' manfile; do
    local basename
    basename=$(basename "$manfile")

    # Strip .gz extension if present
    basename="${basename%.gz}"

    # Extract section number from filename (e.g., sssd.conf.5 -> 5)
    local section="${basename##*.}"
    local pagename="${basename%.*}"

    # Render to text using man or zcat+groff fallback
    local outfile="$output_dir/${pagename}.${section}.txt"

    if command -v man &>/dev/null; then
      # Try rendering with man -l (local file mode)
      if [[ "$manfile" == *.gz ]]; then
        zcat "$manfile" 2>/dev/null | MANWIDTH=120 man -l - 2>/dev/null > "$outfile" || true
      else
        MANWIDTH=120 man -l "$manfile" 2>/dev/null > "$outfile" || true
      fi
    else
      # Fallback: decompress and use col to strip formatting
      if [[ "$manfile" == *.gz ]]; then
        zcat "$manfile" 2>/dev/null | nroff -man 2>/dev/null | col -bx > "$outfile" 2>/dev/null || true
      else
        nroff -man "$manfile" 2>/dev/null | col -bx > "$outfile" 2>/dev/null || true
      fi
    fi

    # Remove empty files
    if [ ! -s "$outfile" ]; then
      rm -f "$outfile"
    else
      count=$((count + 1))
    fi
  done < <(find "$tmpdir/man" -type f \( -name '*.gz' -o -name '*.[0-9]' -o -name '*.[0-9]p' \) -print0 2>/dev/null)

  # Cleanup
  $CONTAINER_CMD rm -f "$container_name" 2>/dev/null || true
  rm -rf "$tmpdir"

  echo "    Extracted ${count} man pages to ${output_dir}"
  echo ""
}

# Main
versions_to_extract=("${@:-8 9 10}")
if [ $# -eq 0 ]; then
  versions_to_extract=(8 9 10)
fi

for v in "${versions_to_extract[@]}"; do
  if [[ -z "${UBI_IMAGES[$v]+x}" ]]; then
    echo "ERROR: Unknown RHEL version: $v (supported: ${!UBI_IMAGES[*]})"
    exit 1
  fi
  extract_version "$v"
done

echo "=== Done ==="
