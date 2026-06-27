#!/bin/bash
# tools_enable_coredumps_linux.sh
#
# Version 2.1
# Written by Y.Voinov (C) 2026

set -u

SCRIPT_TAG="tools_enable_coredumps_linux"
MARK_BEGIN="# BEGIN ${SCRIPT_TAG}"
MARK_END="# END ${SCRIPT_TAG}"

STATE_DIR="/var/lib/${SCRIPT_TAG}"
STATE_FILE="${STATE_DIR}/state.conf"

LIMITS_D_FILE="/etc/security/limits.d/99-coredumps.conf"
SYSCTL_D_FILE="/etc/sysctl.d/99-coredumps.conf"
COREDUMP_DROPIN="/etc/systemd/coredump.conf.d/99-coredumps.conf"
SYSTEMD_DROPIN="/etc/systemd/system.conf.d/99-coredumps.conf"

PASS=0
FAIL=0

NONINTERACTIVE=0
LIMIT_CHOICE=""
DELETE_CORE=""

usage_note()
{
  cat <<EOF
Usage: $0 [options]

Options:
  -h, -H, --help               Show this help
  -n, -N                       Non-interactive mode
  -c, -C, --limit-choice N     Coredump config choice (1,2)
  -d, -D, --delete-core Yy|Nn  Delete test coredump

Examples:
  $0
  $0 -n -c 2 -d Y
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    -n|-N)
      NONINTERACTIVE=1
      ;;
    -c|-C|--limit-choice)
      opt="$1"
      shift
      [ $# -gt 0 ] || { echo "Missing argument for $opt"; exit 1; }
      LIMIT_CHOICE="$1"
      ;;
    -d|-D|--delete-core)
      opt="$1"
      shift
      [ $# -gt 0 ] || { echo "Missing argument for $opt"; exit 1; }
      DELETE_CORE="$1"
      ;;
    -h|-H|--help)
      usage_note
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      usage_note
      exit 1
      ;;
  esac
  shift
done

# Check arguments for fast fail in case of incorrect input
if [ "$NONINTERACTIVE" -eq 1 ]; then

  case "${LIMIT_CHOICE:-1}" in
    1|2)
      ;;
    *)
      echo "Invalid limit choice: $LIMIT_CHOICE"
      exit 1
      ;;
  esac

  case "${DELETE_CORE:-N}" in
    Y|y|N|n)
      ;;
    *)
      echo "Invalid delete-core value: $DELETE_CORE"
      exit 1
      ;;
  esac

fi

ok(){ echo "[OK] $*"; PASS=$((PASS+1)); }
nok(){ echo "[NOT OK] $*"; FAIL=$((FAIL+1)); }

check_os()
{
  [ "$(uname)" = "Linux" ] || { echo "Unsupported OS"; exit 1; }
  ok "Running on Linux"
}

check_root()
{
  [ "$(id -u)" -eq 0 ] || { echo "Must run as root"; exit 1; }
  ok "Running as root"
}

save_state_kv()
{
  mkdir -p "$STATE_DIR"
  touch "$STATE_FILE"
  grep -v "^$1=" "$STATE_FILE" > "$STATE_FILE.tmp" 2>/dev/null || true
  echo "$1=$2" >> "$STATE_FILE.tmp"
  mv "$STATE_FILE.tmp" "$STATE_FILE"
}

detect_features()
{
  HAS_SYSTEMD=0
  HAS_COREDUMPCTL=0
  HAS_LIMITS_D=0
  HAS_SYSCTL_D=0

  command -v systemctl >/dev/null 2>&1 && HAS_SYSTEMD=1
  command -v coredumpctl >/dev/null 2>&1 && HAS_COREDUMPCTL=1
  [ -d /etc/security/limits.d ] && HAS_LIMITS_D=1
  [ -d /etc/sysctl.d ] && HAS_SYSCTL_D=1

  save_state_kv HAS_SYSTEMD "$HAS_SYSTEMD"
  save_state_kv HAS_LIMITS_D "$HAS_LIMITS_D"
  save_state_kv HAS_SYSCTL_D "$HAS_SYSCTL_D"

  ok "Feature detection complete"
}

configure_limits()
{
  if [ "$HAS_LIMITS_D" -eq 1 ]; then
    cat > "$LIMITS_D_FILE" <<EOF
* soft core unlimited
* hard core unlimited
root soft core unlimited
root hard core unlimited
EOF
    save_state_kv LIMITS_MODE limitsd
  else
    grep -q "$SCRIPT_TAG" /etc/security/limits.conf 2>/dev/null || cat >> /etc/security/limits.conf <<EOF

$MARK_BEGIN
* soft core unlimited
* hard core unlimited
root soft core unlimited
root hard core unlimited
$MARK_END
EOF
    save_state_kv LIMITS_MODE limitsconf
  fi
  ok "Configured limits"
}

configure_suid_dumpable()
{
  OLD=$(cat /proc/sys/fs/suid_dumpable 2>/dev/null)
  save_state_kv OLD_SUID_DUMPABLE "$OLD"

  echo 2 > /proc/sys/fs/suid_dumpable

  if [ "$HAS_SYSCTL_D" -eq 1 ]; then
    echo "fs.suid_dumpable=2" > "$SYSCTL_D_FILE"
    save_state_kv SYSCTL_MODE sysctld
  else
    grep -q "$SCRIPT_TAG" /etc/sysctl.conf 2>/dev/null || cat >> /etc/sysctl.conf <<EOF

$MARK_BEGIN
fs.suid_dumpable=2
$MARK_END
EOF
    save_state_kv SYSCTL_MODE sysctlconf
  fi

  ok "Configured fs.suid_dumpable"
}

detect_backend()
{
  CORE_PATTERN=$(cat /proc/sys/kernel/core_pattern)
  BACKEND=file

  case "$CORE_PATTERN" in
    *systemd-coredump*) BACKEND=systemd-coredump ;;
    *abrt*) BACKEND=abrt ;;
    \|*) BACKEND=external-handler ;;
  esac

  save_state_kv COREDUMP_BACKEND "$BACKEND"

  ok "Backend detection: $BACKEND"
}

configure_systemd_limits()
{
  [ "$HAS_SYSTEMD" -eq 1 ] || return 0

  mkdir -p /etc/systemd/system.conf.d

  cat > "$SYSTEMD_DROPIN" <<EOF
[Manager]
DefaultLimitCORE=infinity
EOF

  save_state_kv SYSTEMD_DROPIN_CREATED 1

  systemctl daemon-reexec >/dev/null 2>&1 || true
  ok "Configured DefaultLimitCORE"
}

check_coredump_storage_limits()
{
  [ "$HAS_SYSTEMD" -eq 1 ] || return 0

  echo
  echo "=== Coredump Storage Configuration ==="

  if command -v systemd-analyze >/dev/null 2>&1; then
    systemd-analyze cat-config systemd/coredump.conf 2>/dev/null | \
    grep -E 'Storage=|Compress=|ProcessSizeMax=|ExternalSizeMax=|JournalSizeMax=|MaxUse=|KeepFree=' || true
  fi

  ok "Storage limits checked"
}

configure_coredump_storage()
{
  [ "$HAS_SYSTEMD" -eq 1 ] || return 0

  echo
  echo "1 - Keep current configuration"
  echo "2 - Configure external compressed storage"

  if [ "$NONINTERACTIVE" -eq 1 ]; then
    choice="${LIMIT_CHOICE:-1}"
  else
    printf "Choice [1]: "
    IFS= read -r choice
    [ -z "${choice:-}" ] && choice=1
  fi

  case "$choice" in
    2)
      mkdir -p /etc/systemd/coredump.conf.d

      cat > "$COREDUMP_DROPIN" <<EOF
[Coredump]
Storage=external
Compress=yes
EOF

      save_state_kv COREDUMP_DROPIN_CREATED 1

      systemctl daemon-reload >/dev/null 2>&1 || true

      ok "Configured coredump storage"
      ;;

    *)
      ok "Kept current coredump configuration"
      ;;
  esac
}

wait_for_coredump()
{
  local TIMEOUT=${1:-10}
  local ELAPSED=0

  while [ "$ELAPSED" -lt "$TIMEOUT" ]; do

    if [ "$BACKEND" = "systemd-coredump" ] && [ "$HAS_COREDUMPCTL" -eq 1 ]; then
      coredumpctl --no-pager info "$TEST_PID" >/dev/null 2>&1 && return 0
    fi

    if [ "$BACKEND" = "abrt" ]; then
      for d in /var/spool/abrt/ccpp-*; do
        [ -d "$d" ] || continue

        # ABRT does not reliably persist PID in all builds
        # so we bind by timestamp marker file or directory mtime
        if [ -f "$d/pid" ]; then
          PID_IN_DIR=$(cat "$d/pid" 2>/dev/null || echo "")
          [ "$PID_IN_DIR" = "$TEST_PID" ] && return 0
        fi

        DIR_TS=$(stat -c %Y "$d" 2>/dev/null || echo 0)
        [ "$DIR_TS" -ge "${START_TS:-0}" ] && return 0
      done
    fi

    if [ "$BACKEND" = "file" ]; then
      locate_test_coredump >/dev/null 2>&1
      [ -n "${TEST_FILE:-}" ] && return 0
    fi

    sleep 1
    ELAPSED=$((ELAPSED + 1))
  done

  return 1
}

test_coredump()
{
  local START_TS
  START_TS=$(date +%s)

  rm -f /tmp/coredump_test.pid

  (
    /bin/bash -c '
      echo $$ >/tmp/coredump_test.pid
      sleep 0.2
      kill -SEGV $$
    ' >/dev/null 2>&1
  ) >/dev/null 2>&1

  TEST_PID=$(cat /tmp/coredump_test.pid 2>/dev/null || true)

  wait_for_coredump "$START_TS" 10 || true

  if [ "$BACKEND" = "systemd-coredump" ] && [ "$HAS_COREDUMPCTL" -eq 1 ]; then
    coredumpctl --no-pager info "$TEST_PID" >/dev/null 2>&1 && ok "Coredump detected" || nok "Coredump not detected"
    return
  fi

  if [ "$BACKEND" = "abrt" ]; then
    ABRT_FOUND=$(ls -1td /var/spool/abrt/ccpp-* 2>/dev/null | head -n 1)

    if [ -n "$ABRT_FOUND" ]; then
      ABRT_TIME=$(stat -c %Y "$ABRT_FOUND" 2>/dev/null || echo 0)

      if [ "$ABRT_TIME" -ge "$START_TS" ]; then
        TEST_FILE="$ABRT_FOUND"
        ok "Coredump detected (ABRT)"
      else
        nok "Coredump not detected (ABRT)"
      fi
    else
      nok "Coredump not detected (ABRT)"
    fi

    return
  fi

  FILE=$(ls -1 /var/lib/coredumps/core-* 2>/dev/null | grep "$TEST_PID" || true)
  [ -n "$FILE" ] && ok "Coredump detected (file backend)" || nok "Coredump not detected (file backend)"
}

locate_test_coredump()
{
  local FOUND=""

  if [ "$BACKEND" = "systemd-coredump" ] && [ "$HAS_COREDUMPCTL" -eq 1 ]; then

    FOUND=$(coredumpctl --no-pager info "$TEST_PID" 2>/dev/null | \
      awk '/Storage:/ {print $2}' | tail -n 1)

  elif [ "$BACKEND" = "abrt" ]; then

    FOUND=$(find /var/spool/abrt \
      -maxdepth 1 \
      -type d \
      -name "ccpp-*-${TEST_PID}" \
      2>/dev/null | head -n 1)

  else

    FOUND=$(find /var/crash /var/lib/coredumps \
      -maxdepth 1 \
      -type f \
      2>/dev/null | grep "$TEST_PID" | head -n 1 || true)

  fi

  if [ -n "$FOUND" ]; then
    TEST_FILE="$FOUND"
    echo "Detected coredump file: $TEST_FILE"
  fi
}

ask_yn()
{
  local prompt="$1"
  local default="${2:-N}"
  local ans=""

  if [ "$NONINTERACTIVE" -eq 1 ]; then
    ans="${DELETE_CORE:-$default}"
  else
    if [ -t 0 ]; then
      printf "%s (Y/N): " "$prompt"
      IFS= read -r ans </dev/tty || ans=""
    else
      ans="$default"
    fi
  fi

  case "$ans" in
    Y|y) return 0 ;;
    *) return 1 ;;
  esac
}

delete_test_coredump()
{
  [ -n "${TEST_FILE:-}" ] || return

  sleep 1

  if ask_yn "Delete test coredump" "N"; then
    if [ "$BACKEND" = "abrt" ] && command -v abrt-cli >/dev/null 2>&1; then
      abrt-cli remove "$TEST_FILE" >/dev/null 2>&1 || rm -rf "$TEST_FILE"
      ok "Deleted test coredump"
    else
      rm -rf "$TEST_FILE" >/dev/null 2>&1
      ok "Deleted test coredump"
    fi
  else
    ok "Test coredump left in place"
  fi
}

show_effective_configuration()
{
  echo
  echo "=== Effective Coredump Configuration ==="
  echo "Backend            : $BACKEND"
  echo "fs.suid_dumpable   : $(cat /proc/sys/fs/suid_dumpable 2>/dev/null)"
  echo "kernel.core_pattern: $(cat /proc/sys/kernel/core_pattern)"
  [ -f "$SYSTEMD_DROPIN" ] && cat "$SYSTEMD_DROPIN"
  [ -f "$COREDUMP_DROPIN" ] && cat "$COREDUMP_DROPIN"
}

summary()
{
  echo
  echo "Passed : $PASS"
  echo "Failed : $FAIL"
}

check_os
check_root
detect_features
configure_limits
configure_suid_dumpable
detect_backend
configure_systemd_limits
check_coredump_storage_limits
configure_coredump_storage
test_coredump
locate_test_coredump
delete_test_coredump
show_effective_configuration
summary
exit 0
