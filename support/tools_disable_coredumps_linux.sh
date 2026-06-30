#!/bin/bash
# tools_disable_coredumps_linux.sh
#
# Version 2.2
# Written by Y.Voinov (C) 2026

set -u

STATE_FILE="/var/lib/tools_enable_coredumps_linux/state.conf"
LIMITS_D_FILE="/etc/security/limits.d/99-coredumps.conf"
SYSCTL_D_FILE="/etc/sysctl.d/99-coredumps.conf"
COREDUMP_DROPIN="/etc/systemd/coredump.conf.d/99-coredumps.conf"
SYSTEMD_DROPIN="/etc/systemd/system.conf.d/99-coredumps.conf"

check_os()
{
  [ "`uname`" == "Linux" ] || { echo "Unsupported OS"; exit 1; }
}

check_root()
{
  [ "$(id -u)" -eq 0 ] || { echo "Must run as root"; exit 1; }
}

load_state()
{
  [ -f "$STATE_FILE" ] && . "$STATE_FILE"
}

restore_limits()
{
  case "${LIMITS_MODE:-}" in
    limitsd) rm -f "$LIMITS_D_FILE" ;;
    limitsconf)
             sed -i '/tools_enable_coredumps_linux/,/# END tools_enable_coredumps_linux/d' /etc/security/limits.conf
            ;;
  esac
}

restore_suid_dumpable()
{
  echo "${OLD_SUID_DUMPABLE:-0}" > /proc/sys/fs/suid_dumpable 2>/dev/null || true

  case "${SYSCTL_MODE:-}" in
    sysctld) rm -f "$SYSCTL_D_FILE" ;;
    sysctlconf)
             sed -i '/tools_enable_coredumps_linux/,/# END tools_enable_coredumps_linux/d' /etc/sysctl.conf
             ;;
  esac
}

restore_systemd()
{
  [ -f "$SYSTEMD_DROPIN" ] && rm -f "$SYSTEMD_DROPIN"

  if [ "${COREDUMP_DROPIN_CREATED:-0}" = "1" ]; then
    rm -f "$COREDUMP_DROPIN"
  fi

  command -v systemctl >/dev/null 2>&1 && {
    systemctl daemon-reload >/dev/null 2>&1 || true
    systemctl daemon-reexec >/dev/null 2>&1 || true
  }
}

restore_core_pattern()
{
  if [ -n "${ORIGINAL_CORE_PATTERN:-}" ]; then
    printf '%s\n' "$ORIGINAL_CORE_PATTERN" > /proc/sys/kernel/core_pattern \
      2>/dev/null || true
  fi
}

cleanup()
{
  rm -f "$STATE_FILE"
}

check_os
check_root
load_state
restore_limits
restore_suid_dumpable
restore_systemd
restore_core_pattern
cleanup

echo "Original coredump configuration restored"
echo "Done"
exit 0
