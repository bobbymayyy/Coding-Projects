#!/usr/bin/env bash
set -euo pipefail

SCRIPT_NAME="offline-mirror-manager"
DEFAULT_ROOT="/media/offlinerepo/OFFLINEREPO"   # default mountpoint for removable drive

# ---------------- helpers ----------------
die() { echo "ERROR: $*" >&2; exit 1; }
have_cmd() { command -v "$1" >/dev/null 2>&1; }
need_root() { [[ "${EUID:-$(id -u)}" -eq 0 ]] || die "Run as root (sudo)."; }
mkdirp() { mkdir -p "$1"; }

# ---------------- dialog ----------------
ensure_dialog() {
  have_cmd dialog || die "dialog not found. Install it on the host (apt/dnf install dialog)."
}
dialog_msg() { dialog --clear --title "${1:-Info}" --msgbox "${2:-}" 0 0; }
dialog_input() { dialog --clear --stdout --title "$1" --inputbox "$2" 0 0 "${3:-}"; }
dialog_yesno() { dialog --clear --stdout --title "$1" --yesno "$2" 0 0; }
dialog_menu() { dialog --clear --stdout --title "$1" --menu "$2" 0 0 0 "${@:3}"; }
dialog_checklist() { dialog --clear --stdout --title "$1" --checklist "$2" 0 0 0 "${@:3}"; }

# ---------------- container runtime ----------------
have_podman() { have_cmd podman; }
have_docker() { have_cmd docker; }

container_runtime() {
  if have_podman; then echo podman; return 0; fi
  if have_docker; then echo docker; return 0; fi
  return 1
}

# Default image (change "user" once you publish)
TOOLBOX_IMAGE_DEFAULT="ghcr.io/user/offline-repo-toolbox:latest"

# Will be set after MIRROR_ROOT is known
MIRROR_ROOT=""
CONFIG_PATH=""
UPDATE_INNER=""
CONTAINERFILE=""

run_toolbox() {
  local cmd="$1"
  local rt img
  rt="$(container_runtime)" || die "No container runtime found (podman/docker). Install podman or docker on this host."

  img="$(config_get TOOLBOX_IMAGE || true)"
  img="${img:-$TOOLBOX_IMAGE_DEFAULT}"

  if [[ "$rt" == "podman" ]]; then
    podman run --rm --network=host \
      -v "${MIRROR_ROOT}:/mirror:Z" \
      -e MIRROR_ROOT=/mirror \
      "$img" bash -lc "$cmd"
  else
    docker run --rm --network=host \
      -v "${MIRROR_ROOT}:/mirror" \
      -e MIRROR_ROOT=/mirror \
      "$img" bash -lc "$cmd"
  fi
}

# ---------------- config (drive-contained) ----------------
config_init_paths() {
  MIRROR_ROOT="${MIRROR_ROOT:-$DEFAULT_ROOT}"
  CONFIG_PATH="${MIRROR_ROOT}/config/mirror.conf"
  UPDATE_INNER="${MIRROR_ROOT}/bin/offline-mirror-update-inner"
  CONTAINERFILE="${MIRROR_ROOT}/containers/Containerfile"
}

config_write_defaults() {
  mkdirp "${MIRROR_ROOT}/config" "${MIRROR_ROOT}/bin" "${MIRROR_ROOT}/logs" "${MIRROR_ROOT}/repos" "${MIRROR_ROOT}/aptly" "${MIRROR_ROOT}/repo-defs/rpm"
  cat >"$CONFIG_PATH" <<EOF
# offline mirror config (drive-contained)

MIRROR_ROOT="${MIRROR_ROOT}"

# Container image to use (pull or locally built)
TOOLBOX_IMAGE="${TOOLBOX_IMAGE_DEFAULT}"

# Features
ENABLE_APTLY="yes"
ENABLE_RPM="yes"
ENABLE_ALPINE="yes"

# APTLY
APTLY_ARCHS="amd64"

DEBIAN_ENABLE="yes"
DEBIAN_URL="https://deb.debian.org/debian"
DEBIAN_SUITE="bookworm"
DEBIAN_COMPONENTS="main,contrib,non-free-firmware"
DEBIAN_PREFIX="debian"

UBUNTU_ENABLE="no"
UBUNTU_URL="https://archive.ubuntu.com/ubuntu"
UBUNTU_SUITE="jammy"
UBUNTU_COMPONENTS="main,universe,multiverse,restricted"
UBUNTU_PREFIX="ubuntu"

KALI_ENABLE="no"
KALI_URL="https://http.kali.org/kali"
KALI_SUITE="kali-rolling"
KALI_COMPONENTS="main,contrib,non-free,non-free-firmware"
KALI_PREFIX="kali"

PROXMOX_ENABLE="no"
PROXMOX_URL="http://download.proxmox.com/debian/pve"
PROXMOX_SUITE="bookworm"
PROXMOX_COMPONENTS="pve"
PROXMOX_PREFIX="proxmox"

# RPM reposync sources (multi-line)
# format: name|/mirror/repo-defs/rpm/file.repo|repoid1 repoid2|x86_64 aarch64
RPM_SOURCES=""

# Alpine
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
  local esc
  esc="$(printf '%s' "$val" | sed 's/[\/&]/\\&/g')"
  if grep -qE "^${key}=" "$CONFIG_PATH"; then
    sed -i "s#^${key}=.*#${key}=\"${esc}\"#g" "$CONFIG_PATH"
  else
    printf '\n%s="%s"\n' "$key" "$esc" >>"$CONFIG_PATH"
  fi
}

# ---------------- build/pull image ----------------
tui_container_menu() {
  local choice
  choice="$(dialog_menu "Container Toolbox" "Select:" \
"SETIMG" "Set toolbox image reference (pull)" \
"PULL"   "Pull toolbox image now" \
"BUILD"  "Build toolbox image locally from ${CONTAINERFILE}" \
"BACK"   "Back")" || return 0

  case "$choice" in
    SETIMG)
      local cur new
      cur="$(config_get TOOLBOX_IMAGE || true)"; cur="${cur:-$TOOLBOX_IMAGE_DEFAULT}"
      new="$(dialog_input "Toolbox Image" "Enter image ref (e.g. ghcr.io/user/offline-repo-toolbox:latest):" "$cur")" || return 0
      [[ -n "$new" ]] || return 0
      config_set TOOLBOX_IMAGE "$new"
      dialog_msg "Toolbox" "Set image to:\n$new"
      ;;
    PULL)
      local img rt
      img="$(config_get TOOLBOX_IMAGE || true)"; img="${img:-$TOOLBOX_IMAGE_DEFAULT}"
      rt="$(container_runtime)" || die "No podman/docker"
      if [[ "$rt" == "podman" ]]; then podman pull "$img"; else docker pull "$img"; fi
      dialog_msg "Toolbox" "Pulled:\n$img"
      ;;
    BUILD)
      [[ -r "$CONTAINERFILE" ]] || { dialog_msg "Build" "Missing Containerfile:\n$CONTAINERFILE"; return 0; }
      local img rt
      img="$(config_get TOOLBOX_IMAGE || true)"; img="${img:-offline-repo-toolbox:local}"
      rt="$(container_runtime)" || die "No podman/docker"
      if [[ "$rt" == "podman" ]]; then
        podman build -t "$img" -f "$CONTAINERFILE" "${MIRROR_ROOT}/containers"
      else
        docker build -t "$img" -f "$CONTAINERFILE" "${MIRROR_ROOT}/containers"
      fi
      config_set TOOLBOX_IMAGE "$img"
      dialog_msg "Toolbox" "Built and set image:\n$img"
      ;;
  esac
}

# ---------------- configure mirror root ----------------
tui_set_root() {
  local cur new
  cur="${MIRROR_ROOT:-$DEFAULT_ROOT}"
  new="$(dialog_input "Mirror Root" "Enter removable drive mount path:" "$cur")" || return 1
  [[ -n "$new" ]] || return 1
  MIRROR_ROOT="$new"
  config_init_paths
  mkdirp "$MIRROR_ROOT"
  [[ -r "$CONFIG_PATH" ]] || config_write_defaults
  dialog_msg "Mirror Root" "Using:\n$MIRROR_ROOT"
}

# ---------------- configure APT distro (simple) ----------------
tui_cfg_apt_one() {
  local id="$1" pretty="$2" def_url="$3" def_suite="$4" def_comps="$5" def_prefix="$6"

  local en_key="${id}_ENABLE"
  local url_key="${id}_URL"
  local suite_key="${id}_SUITE"
  local comps_key="${id}_COMPONENTS"
  local prefix_key="${id}_PREFIX"

  local cur_en cur_url cur_suite cur_comps cur_prefix
  cur_en="$(config_get "$en_key" || true)"; cur_en="${cur_en:-no}"
  cur_url="$(config_get "$url_key" || true)"; cur_url="${cur_url:-$def_url}"
  cur_suite="$(config_get "$suite_key" || true)"; cur_suite="${cur_suite:-$def_suite}"
  cur_comps="$(config_get "$comps_key" || true)"; cur_comps="${cur_comps:-$def_comps}"
  cur_prefix="$(config_get "$prefix_key" || true)"; cur_prefix="${cur_prefix:-$def_prefix}"

  if dialog_yesno "$pretty" "Enable mirroring for $pretty?" ; then
    config_set "$en_key" "yes"
  else
    config_set "$en_key" "no"
    dialog_msg "$pretty" "$pretty disabled."
    return 0
  fi

  local u s c p
  u="$(dialog_input "$pretty URL" "Base URL:" "$cur_url")" || return 0
  s="$(dialog_input "$pretty Suite" "Suite (distribution/codename):" "$cur_suite")" || return 0
  c="$(dialog_input "$pretty Components" "CSV components (e.g. main,universe):" "$cur_comps")" || return 0
  p="$(dialog_input "$pretty Prefix" "Publish prefix folder name:" "$cur_prefix")" || return 0

  [[ -n "$u" && -n "$s" && -n "$c" && -n "$p" ]] || return 0

  config_set "$url_key" "$u"
  config_set "$suite_key" "$s"
  config_set "$comps_key" "$c"
  config_set "$prefix_key" "$p"
  dialog_msg "$pretty" "Saved:\nURL=$u\nSUITE=$s\nCOMPS=$c\nPREFIX=$p"
}

tui_cfg_archs() {
  local cur new
  cur="$(config_get APTLY_ARCHS || true)"; cur="${cur:-amd64}"
  new="$(dialog_input "APT Architectures" "CSV architectures (e.g. amd64,arm64):" "$cur")" || return 0
  [[ -n "$new" ]] || return 0
  config_set APTLY_ARCHS "$new"
  dialog_msg "APT" "APTLY_ARCHS=$new"
}

# ---------------- configure RPM sources ----------------
tui_cfg_rpm_sources() {
  local defs_dir="${MIRROR_ROOT}/repo-defs/rpm"
  mkdirp "$defs_dir"

  dialog_msg "RPM" "Put curated .repo files here:\n$defs_dir\n\nThen you’ll select them next."

  local files=()
  shopt -s nullglob
  files=("$defs_dir"/*.repo)
  shopt -u nullglob

  if (( ${#files[@]} == 0 )); then
    dialog_msg "RPM" "No .repo files found in:\n$defs_dir"
    return 0
  fi

  local args=()
  local i=0
  for f in "${files[@]}"; do
    args+=("$i" "$(basename "$f")" "off")
    ((i++))
  done

  local sel
  sel="$(dialog_checklist "RPM Repo Files" "Select one or more .repo files:" "${args[@]}")" || return 0
  sel="$(echo "$sel" | tr -d '"')"
  [[ -n "${sel// }" ]] || return 0

  local sources=""
  local idx
  for idx in $sel; do
    local repo_file="${files[$idx]}"
    local name
    name="$(dialog_input "RPM Source Name" "Namespace name (no spaces):" "$(basename "$repo_file" .repo)")" || continue
    name="$(echo "$name" | xargs)"
    [[ -n "$name" ]] || continue

    local repo_ids
    repo_ids="$(awk -F'[][]' '/^\[.*\]/{print $2}' "$repo_file")"
    [[ -n "$repo_ids" ]] || continue

    local args2=()
    local id
    for id in $repo_ids; do args2+=("$id" "" "off"); done

    local chosen
    chosen="$(dialog_checklist "Repo IDs" "Select repo IDs from $(basename "$repo_file"):" "${args2[@]}")" || continue
    chosen="$(echo "$chosen" | tr -d '"' | xargs)"
    [[ -n "$chosen" ]] || continue

    local arch
    arch="$(dialog_input "RPM Architectures" "Space-separated arch (e.g. x86_64 aarch64):" "x86_64")" || continue
    arch="$(echo "$arch" | xargs)"
    [[ -n "$arch" ]] || arch="x86_64"

    # IMPORTANT: inside container, drive is mounted at /mirror
    local repo_file_in_container="/mirror/repo-defs/rpm/$(basename "$repo_file")"
    sources+="${name}|${repo_file_in_container}|${chosen}|${arch}"$'\n'
  done

  config_set RPM_SOURCES "$sources"
  dialog_msg "RPM" "Saved RPM_SOURCES.\nMirrors will go to:\n${MIRROR_ROOT}/repos/rpm/<name>/<repoid>/"
}

# ---------------- configure Alpine ----------------
tui_cfg_alpine() {
  local cur_url cur_br url br
  cur_url="$(config_get ALPINE_RSYNC_URL || true)"; cur_url="${cur_url:-rsync://rsync.alpinelinux.org/alpine}"
  cur_br="$(config_get ALPINE_BRANCHES || true)"; cur_br="${cur_br:-v3.19}"
  url="$(dialog_input "Alpine rsync URL" "rsync base:" "$cur_url")" || return 0
  br="$(dialog_input "Alpine branches" "Space-separated (e.g. v3.19 edge):" "$cur_br")" || return 0
  config_set ALPINE_RSYNC_URL "$url"
  config_set ALPINE_BRANCHES "$br"
  dialog_msg "Alpine" "Saved."
}

# ---------------- write inner update script (runs inside container) ----------------
write_update_inner() {
  mkdirp "$(dirname "$UPDATE_INNER")"
  cat >"$UPDATE_INNER" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

CONFIG="${1:-/mirror/config/mirror.conf}"
[[ -r "$CONFIG" ]] || { echo "Missing config: $CONFIG" >&2; exit 1; }
# shellcheck disable=SC1090
source "$CONFIG"
CONFIG_MIRROR_ROOT="${MIRROR_ROOT:-}"
MIRROR_ROOT="/mirror"

timestamp() { date +"%Y-%m-%d %H:%M:%S"; }
log() { echo "[$(timestamp)] $*"; }

mkdir -p "$MIRROR_ROOT" "$MIRROR_ROOT/repos" "$MIRROR_ROOT/logs" "$MIRROR_ROOT/aptly"
LOG_FILE="${MIRROR_ROOT}/logs/mirror-update.log"
exec >>"$LOG_FILE" 2>&1

log "Starting mirror update (container)"

# ----- APTLY -----
if [[ "${ENABLE_APTLY:-no}" == "yes" ]]; then
  export APTLY_HOME="${MIRROR_ROOT}/aptly"
  mkdir -p "$APTLY_HOME"
  PUBLISH_ROOT="${MIRROR_ROOT}/repos"

  import_archive_keys() {
    local tk="$APTLY_HOME/trustedkeys.gpg"
    mkdir -p "$APTLY_HOME"

    # Debian + Ubuntu keyrings from the container packages
    for f in /usr/share/keyrings/debian-archive-keyring.gpg \
             /usr/share/keyrings/ubuntu-archive-keyring.gpg; do
      [[ -r "$f" ]] || continue
      gpg --no-default-keyring --keyring "$tk" --import "$f" >/dev/null 2>&1 || true
    done

    # Optional: keep your own cached keys too
    if compgen -G "${MIRROR_ROOT}/keys/*.asc" >/dev/null; then
      for f in "${MIRROR_ROOT}"/keys/*.asc; do
        gpg --no-default-keyring --keyring "$tk" --import "$f" >/dev/null 2>&1 || true
      done
    fi
  }


  ensure_mirror() {
    local name="$1" archs_csv="$2" comps_csv="$3" url="$4" suite="$5"
    local archs comps
    archs="$(echo "${archs_csv:-amd64}" | tr ',' ' ' | xargs)"
    comps="$(echo "${comps_csv:-main}" | tr ',' ' ' | xargs)"

    if ! aptly mirror show "$name" >/dev/null 2>&1; then
      # shellcheck disable=SC2086
      aptly mirror create \
        -keyring="$APTLY_HOME/trustedkeys.gpg" \
        -architectures="$archs" \
        "$name" "$url" "$suite" $comps
    fi
    aptly mirror update "$name"
  }

  ensure_publish() {
    local prefix="$1" suite="$2" mirror_name="$3"
    if ! aptly publish show "filesystem:${PUBLISH_ROOT}:${prefix}" >/dev/null 2>&1; then
      log "APTLY: initial publish prefix=$prefix"
      aptly publish mirror "$mirror_name" filesystem:"${PUBLISH_ROOT}":"${prefix}"
    else
      log "APTLY: update publish prefix=$prefix"
      aptly publish update "$suite" filesystem:"${PUBLISH_ROOT}":"${prefix}" || \
      aptly publish switch "$suite" filesystem:"${PUBLISH_ROOT}":"${prefix}" "$mirror_name" || true
    fi
  }

  ARCHS="${APTLY_ARCHS:-amd64}"

  if [[ "${DEBIAN_ENABLE:-no}" == "yes" ]]; then
    log "APTLY: Debian ${DEBIAN_SUITE:-} arch=${ARCHS}"
    ensure_mirror "debian-${DEBIAN_SUITE}" "$ARCHS" "${DEBIAN_COMPONENTS}" "${DEBIAN_URL}" "${DEBIAN_SUITE}"
    ensure_publish "${DEBIAN_PREFIX:-debian}" "${DEBIAN_SUITE}" "debian-${DEBIAN_SUITE}"
  fi

  if [[ "${UBUNTU_ENABLE:-no}" == "yes" ]]; then
    log "APTLY: Ubuntu ${UBUNTU_SUITE:-} arch=${ARCHS}"
    ensure_mirror "ubuntu-${UBUNTU_SUITE}" "$ARCHS" "${UBUNTU_COMPONENTS}" "${UBUNTU_URL}" "${UBUNTU_SUITE}"
    ensure_publish "${UBUNTU_PREFIX:-ubuntu}" "${UBUNTU_SUITE}" "ubuntu-${UBUNTU_SUITE}"
  fi

  if [[ "${KALI_ENABLE:-no}" == "yes" ]]; then
    log "APTLY: Kali ${KALI_SUITE:-} arch=${ARCHS}"
    ensure_mirror "kali-${KALI_SUITE}" "$ARCHS" "${KALI_COMPONENTS}" "${KALI_URL}" "${KALI_SUITE}"
    ensure_publish "${KALI_PREFIX:-kali}" "${KALI_SUITE}" "kali-${KALI_SUITE}"
  fi

  if [[ "${PROXMOX_ENABLE:-no}" == "yes" ]]; then
    log "APTLY: Proxmox ${PROXMOX_SUITE:-} arch=${ARCHS}"
    ensure_mirror "proxmox-${PROXMOX_SUITE}" "$ARCHS" "${PROXMOX_COMPONENTS}" "${PROXMOX_URL}" "${PROXMOX_SUITE}"
    ensure_publish "${PROXMOX_PREFIX:-proxmox}" "${PROXMOX_SUITE}" "proxmox-${PROXMOX_SUITE}"
  fi
fi

# ----- RPM (reposync) -----
if [[ "${ENABLE_RPM:-no}" == "yes" ]]; then
  if [[ -n "${RPM_SOURCES:-}" ]]; then
    while IFS='|' read -r name repo_file repoids archs; do
      [[ -z "${name// }" ]] && continue
      [[ "$name" =~ ^[[:space:]]*# ]] && continue

      if [[ ! -r "$repo_file" ]]; then
        log "RPM: repo file not readable in container: $repo_file (did you store it under /mirror/repo-defs/rpm/?)"
        continue
      fi

      local_out="${MIRROR_ROOT}/repos/rpm/${name}"
      mkdir -p "$local_out"
      archs="${archs:-x86_64}"

      for id in $repoids; do
        for a in $archs; do
          log "RPM: source=$name repoid=$id arch=$a"
          reposync --config="$repo_file" --repoid="$id" --download-path="$local_out" --arch="$a" --download-metadata --newest-only || true
        done
        if [[ -d "${local_out}/${id}" ]]; then
          createrepo_c "${local_out}/${id}"
        fi
      done
    done <<< "${RPM_SOURCES}"
  else
    log "RPM: RPM_SOURCES empty; skipping."
  fi
fi

# ----- Alpine (rsync) -----
if [[ "${ENABLE_ALPINE:-no}" == "yes" ]]; then
  out="${MIRROR_ROOT}/repos/alpine"
  mkdir -p "$out"
  for b in ${ALPINE_BRANCHES:-}; do
    log "ALPINE: branch=$b"
    rsync -av --delete "${ALPINE_RSYNC_URL}/${b}/" "${out}/${b}/"
  done
fi

log "Mirror update complete"
echo "OK"
EOF
  chmod +x "$UPDATE_INNER"
}

# ---------------- update now ----------------
run_update_now() {
  [[ -r "$CONFIG_PATH" ]] || config_write_defaults
  [[ -x "$UPDATE_INNER" ]] || write_update_inner

  # Ensure logs dir exists on drive
  mkdirp "${MIRROR_ROOT}/logs"
  local log_file="${MIRROR_ROOT}/logs/mirror-update.log"
  echo "----- $(date) -----" >>"$log_file"

  clear
  echo "Running update inside container..."
  echo "Log: $log_file"
  echo

  run_toolbox "/mirror/bin/offline-mirror-update-inner /mirror/config/mirror.conf" || true

  echo
  read -r -p "Press Enter to return to TUI..." _
}

# ---------------- show config ----------------
show_cfg() {
  [[ -r "$CONFIG_PATH" ]] || config_write_defaults
  # shellcheck disable=SC1090
  source "$CONFIG_PATH"
  local tmp
  tmp="$(mktemp)"
  cat >"$tmp" <<EOF
MIRROR_ROOT: ${MIRROR_ROOT}

TOOLBOX_IMAGE: ${TOOLBOX_IMAGE:-<unset>}
ENABLE_APTLY: ${ENABLE_APTLY:-<unset>}
APTLY_ARCHS: ${APTLY_ARCHS:-<unset>}

DEBIAN: ${DEBIAN_ENABLE:-no} ${DEBIAN_URL:-} ${DEBIAN_SUITE:-} ${DEBIAN_COMPONENTS:-} prefix=${DEBIAN_PREFIX:-}
UBUNTU: ${UBUNTU_ENABLE:-no} ${UBUNTU_URL:-} ${UBUNTU_SUITE:-} ${UBUNTU_COMPONENTS:-} prefix=${UBUNTU_PREFIX:-}
KALI: ${KALI_ENABLE:-no} ${KALI_URL:-} ${KALI_SUITE:-} ${KALI_COMPONENTS:-} prefix=${KALI_PREFIX:-}
PROXMOX: ${PROXMOX_ENABLE:-no} ${PROXMOX_URL:-} ${PROXMOX_SUITE:-} ${PROXMOX_COMPONENTS:-} prefix=${PROXMOX_PREFIX:-}

RPM_SOURCES:
$(printf '%s\n' "${RPM_SOURCES:-<none>}" | sed 's/^/  /')

ALPINE: ${ENABLE_ALPINE:-<unset>} ${ALPINE_RSYNC_URL:-} branches=${ALPINE_BRANCHES:-}

Inner updater: ${UPDATE_INNER}
EOF
  dialog --title "Current Config" --textbox "$tmp" 0 0
  rm -f "$tmp"
}

# ---------------- configure menu ----------------
tui_config_menu() {
  while true; do
    local c
    c="$(dialog_menu "Configure" "Select:" \
"ROOT"    "Set mirror root (drive mount)" \
"IMG"     "Container toolbox (set/pull/build)" \
"ARCHS"   "Set APT architectures (CSV)" \
"DEBIAN"  "Configure Debian (APT)" \
"UBUNTU"  "Configure Ubuntu (APT)" \
"KALI"    "Configure Kali (APT)" \
"PROXMOX" "Configure Proxmox (APT)" \
"RPM"     "Configure RPM sources (.repo + repoids)" \
"ALPINE"  "Configure Alpine (rsync)" \
"BACK"    "Back")" || return 0

    case "$c" in
      ROOT) tui_set_root ;;
      IMG)  tui_container_menu ;;
      ARCHS) tui_cfg_archs ;;
      DEBIAN) tui_cfg_apt_one DEBIAN Debian "https://deb.debian.org/debian" "bookworm" "main,contrib,non-free-firmware" "debian" ;;
      UBUNTU) tui_cfg_apt_one UBUNTU Ubuntu "https://archive.ubuntu.com/ubuntu" "jammy" "main,universe,multiverse,restricted" "ubuntu" ;;
      KALI) tui_cfg_apt_one KALI Kali "https://http.kali.org/kali" "kali-rolling" "main,contrib,non-free,non-free-firmware" "kali" ;;
      PROXMOX) tui_cfg_apt_one PROXMOX Proxmox "http://download.proxmox.com/debian/pve" "bookworm" "pve" "proxmox" ;;
      RPM) tui_cfg_rpm_sources ;;
      ALPINE) tui_cfg_alpine ;;
      BACK) return 0 ;;
    esac
  done
}

# ---------------- init + main menu ----------------
init() {
  ensure_dialog
  config_init_paths

  # Ask/set root early if it doesn't exist
  if [[ -z "${MIRROR_ROOT:-}" || "${MIRROR_ROOT}" == "$DEFAULT_ROOT" ]]; then
    # Attempt to reuse existing drive config if present at default root
    if [[ -r "${DEFAULT_ROOT}/config/mirror.conf" ]]; then
      MIRROR_ROOT="$DEFAULT_ROOT"
      config_init_paths
    fi
  fi

  mkdirp "$MIRROR_ROOT"
  [[ -r "$CONFIG_PATH" ]] || config_write_defaults
  [[ -x "$UPDATE_INNER" ]] || write_update_inner
}

main_menu() {
  init
  while true; do
    local rt
    rt="$(container_runtime 2>/dev/null || true)"
    local c
    c="$(dialog_menu "Offline Repo Mirror (Containerized)" \
"Mirror root: ${MIRROR_ROOT}\nConfig: ${CONFIG_PATH}\nRuntime: ${rt:-<none>} (podman preferred)\n\nTip: Configure image under Configure → Container toolbox" \
"CONFIG" "Configure repos + image" \
"UPDATE" "Update/sync now (inside container)" \
"SHOW"   "Show current config" \
"EXIT"   "Exit")" || exit 0

    case "$c" in
      CONFIG) tui_config_menu ;;
      UPDATE) run_update_now ;;
      SHOW) show_cfg ;;
      EXIT) clear; exit 0 ;;
    esac
  done
}

need_root
main_menu
