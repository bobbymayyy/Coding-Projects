#!/usr/bin/env bash
set -euo pipefail

# offline-mirror-manager.sh
# TUI mirror manager using dialog.
# - Installs tools (host-distro aware)
# - One active config (/etc/offline-mirror/mirror.conf)
# - Mirrors: Debian, Ubuntu, Kali, Proxmox (aptly + Release query), RPM (reposync), Alpine (rsync)
# - Optionally creates cron job

SCRIPT_NAME="offline-mirror-manager"
CONFIG_DIR="/etc/offline-mirror"
CONFIG_PATH="${CONFIG_DIR}/mirror.conf"
UPDATE_SCRIPT="/usr/local/sbin/offline-mirror-update"
CRON_FILE="/etc/cron.d/offline-mirror"
LOG_DIR="/var/log/offline-mirror"

# ---------- helpers ----------
die() { echo "ERROR: $*" >&2; exit 1; }
have_cmd() { command -v "$1" >/dev/null 2>&1; }
need_root() { [[ "${EUID:-$(id -u)}" -eq 0 ]] || die "Run as root (sudo)."; }
mkdirp() { mkdir -p "$1"; }

# ---------- OS detection ----------
OS_ID="unknown"; OS_LIKE=""; OS_PRETTY="Unknown"; PKG_FAMILY="unknown"
os_detect() {
  [[ -r /etc/os-release ]] || die "Cannot read /etc/os-release"
  # shellcheck disable=SC1091
  source /etc/os-release
  OS_ID="${ID:-unknown}"
  OS_LIKE="${ID_LIKE:-}"
  OS_PRETTY="${PRETTY_NAME:-$OS_ID}"

  if [[ "$OS_ID" =~ ^(debian|ubuntu|kali|linuxmint|pop)$ ]] || [[ "$OS_LIKE" == *debian* ]]; then
    PKG_FAMILY="apt"
  elif [[ "$OS_ID" =~ ^(fedora|rocky|rhel|centos|almalinux)$ ]] || [[ "$OS_LIKE" == *rhel* ]] || [[ "$OS_LIKE" == *fedora* ]]; then
    PKG_FAMILY="dnf"
  else
    PKG_FAMILY="unknown"
  fi
}

pkg_install() {
  local pkgs=("$@")
  case "$PKG_FAMILY" in
    apt)
      export DEBIAN_FRONTEND=noninteractive
      apt-get update -y
      apt-get install -y "${pkgs[@]}"
      ;;
    dnf)
      if have_cmd dnf; then
        dnf -y install "${pkgs[@]}"
      elif have_cmd yum; then
        yum -y install "${pkgs[@]}"
      else
        die "Neither dnf nor yum found."
      fi
      ;;
    *)
      die "Unsupported OS family. Install manually: dialog, curl, rsync, gnupg, aptly (on Debian/Ubuntu), dnf-plugins-core, createrepo_c."
      ;;
  esac
}

ensure_dialog() {
  have_cmd dialog || pkg_install dialog
}

# ---------- dialog wrappers ----------
dialog_msg() { dialog --clear --title "${1:-Info}" --msgbox "${2:-}" 12 78; }
dialog_input() { dialog --clear --stdout --title "$1" --inputbox "$2" 10 78 "${3:-}"; }
dialog_yesno() { dialog --clear --stdout --title "$1" --yesno "$2" 10 78; }
dialog_menu() { dialog --clear --stdout --title "$1" --menu "$2" 18 82 12 "${@:3}"; }
dialog_checklist() { dialog --clear --stdout --title "$1" --checklist "$2" 20 82 14 "${@:3}"; }

dialog_any_all_none() {
  dialog --clear --stdout --title "Selection Mode" --menu \
"Choose how to select items:" 12 70 4 \
"ALL"  "Select everything" \
"ANY"  "Pick from a checklist" \
"NONE" "Select nothing"
}

# ---------- config IO ----------
config_write_defaults() {
  mkdirp "$CONFIG_DIR"
  mkdirp "$LOG_DIR"
  cat >"$CONFIG_PATH" <<'EOF'
# offline mirror config (single active)
MIRROR_ROOT="/mnt/repo"

ENABLE_APTLY="yes"
ENABLE_RPM="yes"
ENABLE_ALPINE="yes"

# ---------- APT (aptly) ----------
# APTLY_HOME stored under MIRROR_ROOT for portability
APTLY_ARCHS="amd64"

# Debian
DEBIAN_ENABLE="yes"
DEBIAN_MIRROR_URL="https://deb.debian.org/debian"
DEBIAN_SUITE="bookworm"
DEBIAN_COMPONENTS="main,contrib,non-free-firmware"
DEBIAN_PUBLISH_PREFIX="debian"

# Debian Security (optional)
DEBIAN_SECURITY_ENABLE="yes"
DEBIAN_SECURITY_URL="https://security.debian.org/debian-security"
DEBIAN_SECURITY_SUITE="bookworm-security"
DEBIAN_SECURITY_COMPONENTS="main,contrib,non-free-firmware"
# Typically not separately published at first; can be snapshot-combined later.

# Ubuntu
UBUNTU_ENABLE="no"
UBUNTU_MIRROR_URL="http://archive.ubuntu.com/ubuntu"
UBUNTU_SUITE="jammy"
UBUNTU_COMPONENTS="main,universe,multiverse,restricted"
UBUNTU_PUBLISH_PREFIX="ubuntu"

# Kali
KALI_ENABLE="no"
KALI_MIRROR_URL="https://http.kali.org/kali"
KALI_SUITE="kali-rolling"
KALI_COMPONENTS="main,contrib,non-free,non-free-firmware"
KALI_PUBLISH_PREFIX="kali"

# Proxmox (VE)
# Proxmox provides both "pve" and "ceph" repos; start with pve.
PROXMOX_ENABLE="no"
PROXMOX_MIRROR_URL="http://download.proxmox.com/debian/pve"
PROXMOX_SUITE="bookworm"
PROXMOX_COMPONENTS="pve"
PROXMOX_PUBLISH_PREFIX="proxmox"

# ---------- RPM (reposync) ----------
RPM_REPO_DIR=""
RPM_REPO_FILE=""
RPM_ARCHS="x86_64"
RPM_SELECTED_REPOIDS=""

# ---------- Alpine (rsync) ----------
ALPINE_RSYNC_URL="rsync://rsync.alpinelinux.org/alpine"
ALPINE_BRANCHES="v3.19"
EOF
}

config_get() {
  local key="$1"
  [[ -r "$CONFIG_PATH" ]] || return 1
  # shellcheck disable=SC1090
  source "$CONFIG_PATH"
  eval "printf '%s' \"\${$key:-}\""
}

config_set() {
  local key="$1" val="$2"
  [[ -r "$CONFIG_PATH" ]] || config_write_defaults
  if grep -qE "^${key}=" "$CONFIG_PATH"; then
    local esc
    esc="$(printf '%s' "$val" | sed 's/[\/&]/\\&/g')"
    sed -i "s#^${key}=.*#${key}=\"${esc}\"#g" "$CONFIG_PATH"
  else
    printf '\n%s="%s"\n' "$key" "$val" >>"$CONFIG_PATH"
  fi
}

tui_rpm_probe_helper() {
  dialog --clear --title "RPM Probe Helper (.repo harvesting)" --msgbox \
"Goal:
  Generate/collect authoritative .repo files from an RPM-family 'probe' VM
  and copy them into:
    <MIRROR_ROOT>/repo-defs/rpm/

Why:
  Those .repo files contain metalink=/mirrorlist= redirectors + GPG keys,
  so your mirror host follows upstream changes automatically.

--- Fedora probe (Fedora 39/40/etc) ---
1) Ensure repos exist:
  sudo dnf -y install fedora-repos

2) (Optional) enable extras you want:
  sudo dnf config-manager --set-enabled updates updates-testing

3) Copy repo definitions to your removable drive (example path):
  sudo cp -v /etc/yum.repos.d/*.repo /mnt/repo/repo-defs/rpm/

--- Rocky / Alma / RHEL-like probe ---
1) Repo files are typically already present:
  ls -l /etc/yum.repos.d/

2) Copy them:
  sudo cp -v /etc/yum.repos.d/*.repo /mnt/repo/repo-defs/rpm/

--- EPEL (common on Rocky/RHEL-like) ---
1) Install EPEL release package:
  sudo dnf -y install epel-release

2) Copy EPEL repo file(s):
  sudo cp -v /etc/yum.repos.d/epel*.repo /mnt/repo/repo-defs/rpm/

--- RPM Fusion (Fedora) ---
RPM Fusion provides its own release RPMs that drop .repo files.
Follow RPM Fusion's official instructions on the Fedora probe VM, then:
  sudo cp -v /etc/yum.repos.d/rpmfusion*.repo /mnt/repo/repo-defs/rpm/

--- NVIDIA / CUDA repos (RPM) ---
Install NVIDIA/CUDA repo package on the probe VM (per NVIDIA docs),
then copy the created .repo (often named cuda*.repo or nvidia*.repo):
  sudo cp -v /etc/yum.repos.d/cuda*.repo /mnt/repo/repo-defs/rpm/
  sudo cp -v /etc/yum.repos.d/nvidia*.repo /mnt/repo/repo-defs/rpm/

--- Verify what you harvested ---
  grep -R \"^\\[\" -n /mnt/repo/repo-defs/rpm/*.repo
  grep -R \"metalink=\\|mirrorlist=\\|baseurl=\" -n /mnt/repo/repo-defs/rpm/*.repo

Tip:
  If you want separation, rename files after copying:
    fedora.repo, rocky.repo, epel.repo, cuda.repo
  Your mirror tool will namespace output by source name anyway." \
  28 86
}


# ---------- APT Release querying ----------
fetch_apt_release() {
  local base_url="$1" suite="$2" out="$3"
  curl -fsSL "${base_url}/dists/${suite}/Release" -o "$out"
}

parse_release_field() {
  local file="$1" field="$2"
  awk -v f="${field}:" '
    $1==f {
      $1=""; sub(/^ /,"");
      print; exit
    }' "$file"
}

dialog_checklist_from_words() {
  local title="$1" prompt="$2" words="$3" default_on_word="${4:-}"
  local args=()
  local w
  for w in $words; do
    local state="off"
    [[ -n "$default_on_word" && "$w" == "$default_on_word" ]] && state="on"
    args+=("$w" "" "$state")
  done
  dialog_checklist "$title" "$prompt" "${args[@]}"
}

words_to_csv() { echo "$1" | xargs | tr ' ' ','; }
csv_to_words() { echo "$1" | tr ',' ' '; }

# ---------- Generic APT TUI (Debian/Ubuntu/Kali/Proxmox) ----------
tui_configure_apt_distro() {
  local distro="$1"  # e.g. DEBIAN, UBUNTU, KALI, PROXMOX
  local pretty="$2"  # display name
  local default_url="$3"
  local default_suite="$4"
  local default_components="$5"
  local enforce_main="$6"  # "yes" or "no"
  local suite_mode="$7"    # "debianlike" "ubuntu" "kali" "proxmox" (curated lists)

  local enable_key="${distro}_ENABLE"
  local url_key="${distro}_MIRROR_URL"
  local suite_key="${distro}_SUITE"
  local comp_key="${distro}_COMPONENTS"
  local pub_key="${distro}_PUBLISH_PREFIX"

  local cur_enable cur_url cur_suite cur_comps
  cur_enable="$(config_get "$enable_key" | sed 's/^$/no/')"
  cur_url="$(config_get "$url_key" | sed "s#^$#${default_url}#")"
  cur_suite="$(config_get "$suite_key" | sed "s#^$#${default_suite}#")"
  cur_comps="$(config_get "$comp_key" | sed "s#^$#${default_components}#")"

  if dialog_yesno "$pretty" "Enable mirroring for $pretty?" ; then
    config_set "$enable_key" "yes"
  else
    config_set "$enable_key" "no"
    dialog_msg "$pretty" "$pretty mirroring disabled."
    return 0
  fi

  local base_url suite tmp_release comps archs
  base_url="$(dialog_input "$pretty Mirror URL" "Enter base URL:" "$cur_url")" || return 1
  [[ -n "$base_url" ]] || return 1

  # Suites: curated + custom (directory listing is often disabled)
  local suite_choice
  case "$suite_mode" in
    debianlike)
      suite_choice="$(dialog_menu "$pretty Suite" "Pick suite (or Custom):" \
"stable" "Tracks stable" \
"testing" "Tracks testing" \
"oldstable" "Tracks oldstable" \
"bookworm" "Debian 12" \
"bullseye" "Debian 11" \
"trixie" "Debian 13" \
"sid" "Unstable" \
"custom" "Enter manually")" || return 1
      ;;
    ubuntu)
      suite_choice="$(dialog_menu "$pretty Suite" "Pick suite (or Custom):" \
"noble" "24.04 LTS" \
"jammy" "22.04 LTS" \
"focal" "20.04 LTS" \
"oracular" "newer (if used)" \
"custom" "Enter manually")" || return 1
      ;;
    kali)
      suite_choice="$(dialog_menu "$pretty Suite" "Pick suite (or Custom):" \
"kali-rolling" "Rolling" \
"custom" "Enter manually")" || return 1
      ;;
    proxmox)
      suite_choice="$(dialog_menu "$pretty Suite" "Pick suite (or Custom):" \
"bookworm" "Debian 12 base" \
"bullseye" "Debian 11 base" \
"custom" "Enter manually")" || return 1
      ;;
    *)
      suite_choice="custom"
      ;;
  esac

  if [[ "$suite_choice" == "custom" ]]; then
    suite="$(dialog_input "$pretty Suite" "Enter suite:" "$cur_suite")" || return 1
  else
    suite="$suite_choice"
  fi
  [[ -n "$suite" ]] || return 1

  tmp_release="$(mktemp)"
  if ! fetch_apt_release "$base_url" "$suite" "$tmp_release"; then
    rm -f "$tmp_release"
    dialog_msg "$pretty Query Failed" "Could not fetch:\n${base_url}/dists/${suite}/Release\n\nCheck suite or URL."
    return 1
  fi

  comps="$(parse_release_field "$tmp_release" "Components")"
  archs="$(parse_release_field "$tmp_release" "Architectures")"
  rm -f "$tmp_release"

  [[ -n "$comps" ]] || comps="$(csv_to_words "$cur_comps")"
  [[ -n "$archs" ]] || archs="$(csv_to_words "$(config_get APTLY_ARCHS | sed 's/^$/amd64/')")"

  # Components
  local comp_mode comp_sel
  comp_mode="$(dialog_any_all_none)" || return 1
  case "$comp_mode" in
    ALL)  comp_sel="$comps" ;;
    NONE)
      if [[ "$enforce_main" == "yes" ]]; then
        comp_sel="main"
      else
        comp_sel=""
      fi
      ;;
    ANY)
      comp_sel="$(dialog_checklist_from_words "$pretty Components" \
"Select components$( [[ "$enforce_main" == "yes" ]] && echo " (main is always included)" ):" \
"$comps" "$( [[ "$enforce_main" == "yes" ]] && echo "main" )")" || return 1
      comp_sel="$(echo "$comp_sel" | tr -d '"')"
      ;;
  esac

  if [[ "$enforce_main" == "yes" ]]; then
    if ! grep -qw "main" <<<"$comp_sel"; then
      comp_sel="main $comp_sel"
    fi
  fi

  # Architectures
  local arch_mode arch_sel
  arch_mode="$(dialog_any_all_none)" || return 1
  case "$arch_mode" in
    ALL)  arch_sel="$archs" ;;
    NONE) arch_sel="amd64" ;;
    ANY)
      arch_sel="$(dialog_checklist_from_words "$pretty Architectures" \
"Select architectures:" "$archs" "amd64")" || return 1
      arch_sel="$(echo "$arch_sel" | tr -d '"')"
      ;;
  esac

  # Save
  config_set "$url_key" "$base_url"
  config_set "$suite_key" "$suite"
  config_set "$comp_key" "$(words_to_csv "$comp_sel")"
  config_set "APTLY_ARCHS" "$(words_to_csv "$arch_sel")"

  dialog_msg "$pretty Configured" \
"$pretty configured:\n\nURL: $base_url\nSuite: $suite\nComponents: $(config_get "$comp_key")\nArchitectures: $(config_get APTLY_ARCHS)"
}

# ---------- RPM: choose .repo file + repoid selection + arch selection ----------
rpm_list_repo_files() {
  local dir="$1"
  shopt -s nullglob
  local files=("$dir"/*.repo)
  shopt -u nullglob
  if (( ${#files[@]} == 0 )); then
    echo ""
    return 0
  fi
  printf '%s\n' "${files[@]}"
}

tui_configure_rpm() {
  local mirror_root repo_dir repo_file

  mirror_root="$(config_get MIRROR_ROOT | sed 's/^$/\/mnt\/repo/')"
  repo_dir="$(config_get RPM_REPO_DIR)"
  [[ -n "$repo_dir" ]] || repo_dir="${mirror_root}/repo-defs/rpm"

  repo_dir="$(dialog_input "RPM Repo Definitions" \
"Folder containing curated .repo files (from probe VMs):" "$repo_dir")" || return 1
  [[ -n "$repo_dir" ]] || return 1
  mkdirp "$repo_dir"

  local files args=()
  mapfile -t files < <(rpm_list_repo_files "$repo_dir")
  if (( ${#files[@]} == 0 )); then
    dialog_msg "No .repo files" \
"No .repo files found in:\n${repo_dir}\n\nHow to get them:\n- On Fedora/Rocky/RHEL probe VM, copy /etc/yum.repos.d/*.repo\n- Also install epel-release/rpmfusion-release/cuda repo pkg as needed\n\nThen copy the .repo files into this folder."
    return 1
  fi

  local i=1
  for f in "${files[@]}"; do
    args+=("$i" "$(basename "$f")")
    ((i++))
  done

  local choice
  choice="$(dialog_menu "RPM Repo File" "Select a .repo file to drive reposync:" "${args[@]}")" || return 1
  repo_file="${files[$((choice-1))]}"

  local repo_ids args2=()
  repo_ids="$(awk -F'[][]' '/^\[.*\]/{print $2}' "$repo_file")"
  [[ -n "$repo_ids" ]] || { dialog_msg "RPM Config" "No repo IDs found in:\n$repo_file"; return 1; }

  for id in $repo_ids; do
    args2+=("$id" "" "off")
  done

  local selected
  selected="$(dialog_checklist "RPM Repo IDs" \
"Select repo IDs to mirror (metalink/mirrorlist preserved):\n$(basename "$repo_file")" \
"${args2[@]}")" || return 1
  selected="$(echo "$selected" | tr -d '"')"

  local arch_sel
  arch_sel="$(dialog_checklist "RPM Architectures" "Select architectures:" \
"x86_64"  "" "on" \
"aarch64" "" "off" \
"ppc64le" "" "off" \
"s390x"   "" "off")" || return 1
  arch_sel="$(echo "$arch_sel" | tr -d '"' | xargs)"

  config_set "RPM_REPO_DIR" "$repo_dir"
  config_set "RPM_REPO_FILE" "$repo_file"
  config_set "RPM_SELECTED_REPOIDS" "$selected"
  config_set "RPM_ARCHS" "$arch_sel"

  dialog_msg "RPM Configured" \
"Repo dir: $repo_dir\nRepo file: $(basename "$repo_file")\nRepo IDs: ${selected:-<none>}\nArch: $arch_sel"
}

# ---------- Alpine ----------
tui_configure_alpine() {
  local url current mode branches
  url="$(dialog_input "Alpine rsync URL" \
"Enter Alpine rsync base:" \
"$(config_get ALPINE_RSYNC_URL | sed 's#^$#rsync://rsync.alpinelinux.org/alpine#')" )" || return 1

  current="$(config_get ALPINE_BRANCHES | sed 's/^$/v3.19/')"

  mode="$(dialog_any_all_none)" || return 1
  case "$mode" in
    ALL)  branches="v3.17 v3.18 v3.19 v3.20 edge" ;;
    NONE) branches="" ;;
    ANY)
      local sel
      sel="$(dialog_checklist "Alpine Branches" "Select branches to mirror:" \
"v3.17" "" "off" \
"v3.18" "" "off" \
"v3.19" "" "on"  \
"v3.20" "" "off" \
"edge"  "" "off")" || return 1
      branches="$(echo "$sel" | tr -d '"' | xargs)"
      ;;
  esac

  config_set "ALPINE_RSYNC_URL" "$url"
  config_set "ALPINE_BRANCHES" "$branches"
  dialog_msg "Alpine Configured" "rsync: $url\nbranches: ${branches:-<none>}"
}

# ---------- install tools ----------
install_tools_wizard() {
  os_detect
  ensure_dialog

  dialog_msg "Installer" \
"Host OS detected:\n${OS_PRETTY}\n\nWill install:\n- dialog, curl, rsync, gnupg\n- aptly (best on Debian/Ubuntu)\n- reposync + createrepo_c"

  pkg_install ca-certificates curl rsync gnupg2

  if [[ "$PKG_FAMILY" == "apt" ]]; then
    pkg_install aptly
  fi

  if [[ "$PKG_FAMILY" == "dnf" ]]; then
    pkg_install dnf-plugins-core createrepo_c
  elif [[ "$PKG_FAMILY" == "apt" ]]; then
    pkg_install dnf dnf-plugins-core createrepo-c
  fi

  if dialog_yesno "Optional" "Install nginx for testing serving repos from this host (optional)?" ; then
    pkg_install nginx
    systemctl enable --now nginx >/dev/null 2>&1 || true
  fi

  dialog_msg "Installer" "Done installing tools."
}

# ---------- update script writer ----------
write_update_script() {
  mkdirp "$(dirname "$UPDATE_SCRIPT")"
  cat >"$UPDATE_SCRIPT" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

CONFIG="${1:-/etc/offline-mirror/mirror.conf}"
[[ -r "$CONFIG" ]] || { echo "Missing config: $CONFIG" >&2; exit 1; }
# shellcheck disable=SC1090
source "$CONFIG"

timestamp() { date +"%Y-%m-%d %H:%M:%S"; }
log() { echo "[$(timestamp)] $*"; }
need_cmd() { command -v "$1" >/dev/null 2>&1 || { echo "Missing command: $1" >&2; exit 1; }; }

mkdir -p "$MIRROR_ROOT" "$MIRROR_ROOT/repos" "$MIRROR_ROOT/logs"
LOG_FILE="${MIRROR_ROOT}/logs/mirror-update.log"
exec >>"$LOG_FILE" 2>&1

log "Starting mirror update"

# ---- APTLY ----
if [[ "${ENABLE_APTLY:-no}" == "yes" ]]; then
  need_cmd aptly
  need_cmd gpg

  export APTLY_HOME="${MIRROR_ROOT}/aptly"
  mkdir -p "$APTLY_HOME"

  PUBLISH_ROOT="${MIRROR_ROOT}/repos"

  ensure_mirror() {
    local name="$1" archs="$2" comps="$3" url="$4" suite="$5"
    if ! aptly mirror show "$name" >/dev/null 2>&1; then
      aptly mirror create -architectures="$archs" -components="$comps" "$name" "$url" "$suite"
    fi
    aptly mirror update "$name"
  }

  ensure_publish() {
    local prefix="$1" suite="$2" mirror_name="$3"
    # Publish to filesystem:<PUBLISH_ROOT>:<prefix>
    if ! aptly publish show "filesystem:${PUBLISH_ROOT}:${prefix}" >/dev/null 2>&1; then
      log "APTLY: Initial publish ${prefix}"
      aptly publish mirror "$mirror_name" filesystem:"${PUBLISH_ROOT}":"${prefix}"
    else
      log "APTLY: Updating publish ${prefix}"
      # Try update, fallback to switch
      aptly publish update "$suite" filesystem:"${PUBLISH_ROOT}":"${prefix}" || \
      aptly publish switch "$suite" filesystem:"${PUBLISH_ROOT}":"${prefix}" "$mirror_name" || true
    fi
  }

  ARCHS="${APTLY_ARCHS:-amd64}"

  # Debian
  if [[ "${DEBIAN_ENABLE:-no}" == "yes" ]]; then
    log "APTLY: Debian ${DEBIAN_SUITE} comps=${DEBIAN_COMPONENTS} arch=${ARCHS}"
    ensure_mirror "debian-${DEBIAN_SUITE}" "$ARCHS" "${DEBIAN_COMPONENTS:-main}" "${DEBIAN_MIRROR_URL}" "${DEBIAN_SUITE}"
    ensure_publish "${DEBIAN_PUBLISH_PREFIX:-debian}" "${DEBIAN_SUITE}" "debian-${DEBIAN_SUITE}"

    if [[ "${DEBIAN_SECURITY_ENABLE:-no}" == "yes" && -n "${DEBIAN_SECURITY_SUITE:-}" ]]; then
      log "APTLY: Debian security ${DEBIAN_SECURITY_SUITE}"
      ensure_mirror "debian-${DEBIAN_SECURITY_SUITE}" "$ARCHS" "${DEBIAN_SECURITY_COMPONENTS:-main}" "${DEBIAN_SECURITY_URL}" "${DEBIAN_SECURITY_SUITE}"
      # Not separately published by default (keeps things simpler).
    fi
  fi

  # Ubuntu
  if [[ "${UBUNTU_ENABLE:-no}" == "yes" ]]; then
    log "APTLY: Ubuntu ${UBUNTU_SUITE} comps=${UBUNTU_COMPONENTS} arch=${ARCHS}"
    ensure_mirror "ubuntu-${UBUNTU_SUITE}" "$ARCHS" "${UBUNTU_COMPONENTS:-main}" "${UBUNTU_MIRROR_URL}" "${UBUNTU_SUITE}"
    ensure_publish "${UBUNTU_PUBLISH_PREFIX:-ubuntu}" "${UBUNTU_SUITE}" "ubuntu-${UBUNTU_SUITE}"
  fi

  # Kali
  if [[ "${KALI_ENABLE:-no}" == "yes" ]]; then
    log "APTLY: Kali ${KALI_SUITE} comps=${KALI_COMPONENTS} arch=${ARCHS}"
    ensure_mirror "kali-${KALI_SUITE}" "$ARCHS" "${KALI_COMPONENTS:-main}" "${KALI_MIRROR_URL}" "${KALI_SUITE}"
    ensure_publish "${KALI_PUBLISH_PREFIX:-kali}" "${KALI_SUITE}" "kali-${KALI_SUITE}"
  fi

  # Proxmox
  if [[ "${PROXMOX_ENABLE:-no}" == "yes" ]]; then
    log "APTLY: Proxmox ${PROXMOX_SUITE} comps=${PROXMOX_COMPONENTS} arch=${ARCHS}"
    ensure_mirror "proxmox-${PROXMOX_SUITE}" "$ARCHS" "${PROXMOX_COMPONENTS:-pve}" "${PROXMOX_MIRROR_URL}" "${PROXMOX_SUITE}"
    ensure_publish "${PROXMOX_PUBLISH_PREFIX:-proxmox}" "${PROXMOX_SUITE}" "proxmox-${PROXMOX_SUITE}"
  fi
fi

# ---- RPM (reposync) ----
if [[ "${ENABLE_RPM:-no}" == "yes" ]]; then
  need_cmd reposync
  need_cmd createrepo_c

  RPM_OUT="${MIRROR_ROOT}/repos/rpm"
  mkdir -p "$RPM_OUT"

  repo_file="${RPM_REPO_FILE:-}"
  if [[ -z "$repo_file" || ! -r "$repo_file" ]]; then
    log "RPM: RPM_REPO_FILE not set or not readable, skipping."
  else
    repoids="${RPM_SELECTED_REPOIDS:-}"
    if [[ -z "$repoids" ]]; then
      log "RPM: No RPM_SELECTED_REPOIDS selected, skipping."
    else
      for id in $repoids; do
        for arch in ${RPM_ARCHS:-x86_64}; do
          log "RPM: reposync repoid=$id arch=$arch"
          reposync \
            --config="$repo_file" \
            --repoid="$id" \
            --download-path="$RPM_OUT" \
            --arch="$arch" \
            --download-metadata \
            --newest-only || true
        done

        if [[ -d "${RPM_OUT}/${id}" ]]; then
          log "RPM: createrepo_c ${RPM_OUT}/${id}"
          createrepo_c "${RPM_OUT}/${id}"
        fi
      done
    fi
  fi
fi

# ---- Alpine (rsync) ----
if [[ "${ENABLE_ALPINE:-no}" == "yes" ]]; then
  need_cmd rsync
  ALP_OUT="${MIRROR_ROOT}/repos/alpine"
  mkdir -p "$ALP_OUT"

  for b in ${ALPINE_BRANCHES:-}; do
    log "ALPINE: rsync branch=$b"
    rsync -av --delete "${ALPINE_RSYNC_URL}/${b}/" "${ALP_OUT}/${b}/"
  done
fi

log "Mirror update complete"
echo "OK"
EOF
  chmod +x "$UPDATE_SCRIPT"
}

# ---------- cron ----------
install_cron_job() {
  local schedule
  schedule="$(dialog_input "Cron Schedule" \
"Enter cron schedule (min hour dom mon dow):" "17 2 * * *")" || return 1

  mkdirp "$LOG_DIR"
  cat >"$CRON_FILE" <<EOF
# Managed by ${SCRIPT_NAME}
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
${schedule} root ${UPDATE_SCRIPT} ${CONFIG_PATH} >> ${LOG_DIR}/cron.log 2>&1
EOF
  chmod 0644 "$CRON_FILE"
  dialog_msg "Cron" "Cron installed:\n${CRON_FILE}\n\nSchedule:\n${schedule}"
}

remove_cron_job() {
  if [[ -f "$CRON_FILE" ]]; then
    rm -f "$CRON_FILE"
    dialog_msg "Cron" "Removed:\n${CRON_FILE}"
  else
    dialog_msg "Cron" "No cron job found at:\n${CRON_FILE}"
  fi
}

# ---------- configure mirror root ----------
tui_set_mirror_root() {
  local current newroot
  current="$(config_get MIRROR_ROOT | sed 's/^$/\/mnt\/repo/')"
  newroot="$(dialog_input "Mirror Root" \
"Enter target folder (removable drive mount or permanent path):" "$current")" || return 1
  [[ -n "$newroot" ]] || return 1
  mkdirp "$newroot"
  config_set "MIRROR_ROOT" "$newroot"
  dialog_msg "Mirror Root" "Set MIRROR_ROOT to:\n$newroot"
}

# ---------- configure menu ----------
tui_configure_menu() {
  while true; do
    local choice
    choice="$(dialog_menu "Configure" "Select what to configure:" \
"ROOT"    "Set mirror root folder" \
"DEBIAN"  "Configure Debian (Release query)" \
"UBUNTU"  "Configure Ubuntu (Release query)" \
"KALI"    "Configure Kali (Release query)" \
"PROXMOX" "Configure Proxmox (Release query)" \
"RPM"     "Configure RPM mirroring (.repo + repo IDs + arch)" \
"RPMHELP" "RPM probe helper (how to harvest .repo files)" \
"ALPINE"  "Configure Alpine branches" \
"BACK"    "Back to main menu")" || return 0

    case "$choice" in
      ROOT) tui_set_mirror_root ;;
      DEBIAN)  tui_configure_apt_distro "DEBIAN" "Debian" \
        "https://deb.debian.org/debian" "bookworm" "main,contrib,non-free-firmware" "yes" "debianlike" ;;
      UBUNTU)  tui_configure_apt_distro "UBUNTU" "Ubuntu" \
        "http://archive.ubuntu.com/ubuntu" "jammy" "main,universe,multiverse,restricted" "yes" "ubuntu" ;;
      KALI)    tui_configure_apt_distro "KALI" "Kali" \
        "https://http.kali.org/kali" "kali-rolling" "main,contrib,non-free,non-free-firmware" "yes" "kali" ;;
      PROXMOX) tui_configure_apt_distro "PROXMOX" "Proxmox" \
        "http://download.proxmox.com/debian/pve" "bookworm" "pve" "no" "proxmox" ;;
      RPM) tui_configure_rpm ;;
      RPMHELP) tui_rpm_probe_helper ;;
      ALPINE) tui_configure_alpine ;;
      BACK) return 0 ;;
    esac
  done
}

# ---------- run update ----------
run_update_now() {
  [[ -x "$UPDATE_SCRIPT" ]] || write_update_script
  clear
  echo "Running update: ${UPDATE_SCRIPT} ${CONFIG_PATH}"
  echo "Log: \$(MIRROR_ROOT)/logs/mirror-update.log"
  echo
  "$UPDATE_SCRIPT" "$CONFIG_PATH" || true
  echo
  read -r -p "Press Enter to return to TUI..." _
}

# ---------- initialize ----------
init_if_needed() {
  os_detect
  ensure_dialog
  [[ -r "$CONFIG_PATH" ]] || config_write_defaults
  [[ -x "$UPDATE_SCRIPT" ]] || write_update_script
}

# ---------- main menu ----------
main_menu() {
  init_if_needed

  while true; do
    local root
    root="$(config_get MIRROR_ROOT | sed 's/^$/\/mnt\/repo/')"
    local choice
    choice="$(dialog_menu "Offline Repo Mirror" \
"Host: ${OS_PRETTY}\nConfig: ${CONFIG_PATH}\nMirror root: ${root}" \
"INSTALL"  "Install required tools on this host" \
"CONFIG"   "Configure what to mirror (interactive queries)" \
"UPDATE"   "Update/sync now" \
"CRONADD"  "Create cron job (auto updates)" \
"CRONDEL"  "Remove cron job" \
"SHOWCFG"  "Show current config summary" \
"EXIT"     "Exit")" || exit 0

    case "$choice" in
      INSTALL) install_tools_wizard ;;
      CONFIG)  tui_configure_menu ;;
      UPDATE)  run_update_now ;;
      CRONADD) install_cron_job ;;
      CRONDEL) remove_cron_job ;;
      SHOWCFG)
        # shellcheck disable=SC1090
        source "$CONFIG_PATH"
        dialog_msg "Current Config" \
"MIRROR_ROOT: ${MIRROR_ROOT}\n\nAPTLY:\n  ENABLE_APTLY=${ENABLE_APTLY}\n  APTLY_ARCHS=${APTLY_ARCHS}\n\nDEBIAN:\n  ENABLE=${DEBIAN_ENABLE}\n  URL=${DEBIAN_MIRROR_URL}\n  SUITE=${DEBIAN_SUITE}\n  COMPONENTS=${DEBIAN_COMPONENTS}\n  PREFIX=${DEBIAN_PUBLISH_PREFIX}\n\nUBUNTU:\n  ENABLE=${UBUNTU_ENABLE}\n  URL=${UBUNTU_MIRROR_URL}\n  SUITE=${UBUNTU_SUITE}\n  COMPONENTS=${UBUNTU_COMPONENTS}\n  PREFIX=${UBUNTU_PUBLISH_PREFIX}\n\nKALI:\n  ENABLE=${KALI_ENABLE}\n  URL=${KALI_MIRROR_URL}\n  SUITE=${KALI_SUITE}\n  COMPONENTS=${KALI_COMPONENTS}\n  PREFIX=${KALI_PUBLISH_PREFIX}\n\nPROXMOX:\n  ENABLE=${PROXMOX_ENABLE}\n  URL=${PROXMOX_MIRROR_URL}\n  SUITE=${PROXMOX_SUITE}\n  COMPONENTS=${PROXMOX_COMPONENTS}\n  PREFIX=${PROXMOX_PUBLISH_PREFIX}\n\nRPM:\n  ENABLE_RPM=${ENABLE_RPM}\n  RPM_REPO_DIR=${RPM_REPO_DIR}\n  RPM_REPO_FILE=${RPM_REPO_FILE}\n  RPM_SELECTED_REPOIDS=${RPM_SELECTED_REPOIDS}\n  RPM_ARCHS=${RPM_ARCHS}\n\nALPINE:\n  ENABLE_ALPINE=${ENABLE_ALPINE}\n  ALPINE_RSYNC_URL=${ALPINE_RSYNC_URL}\n  ALPINE_BRANCHES=${ALPINE_BRANCHES}\n\nUpdate script:\n  ${UPDATE_SCRIPT}"
        ;;
      EXIT) clear; exit 0 ;;
    esac
  done
}

need_root
main_menu
