# memory-tools
[![License](https://img.shields.io/badge/License-BSD%203--Clause-blue.svg)](https://github.com/yvoinov/memory-tools/blob/master/LICENSE)

## Memory-related and performance tools

These tools are designed to perform prerequisites and performance improvements for custom allocators.

Although they were originally developed for LMA, it is not difficult to adapt them to any custom allocator since the requirements are approximately the same.

All utilities are run as root (since sudo may not necessarily be installed). Read them carefully before run to understand what you are doing exactly.

`disable_thp.sh` is intended to create a service that disables THP globally, since THP leads to increased memory fragmentation and, as a result, to excessive swapping (Linux).

`ld_prereq.sh` fulfills the prerequisites required for ld.so when using a custom allocator (Linux/Solaris/FreeBSD).

`disable_overcommit.sh` creates a system configuration that minimizes swapping, disables overcommit and OOM killer; remember that for this configuration to work effectively, a swap partition of at least one amount of RAM is required, no matter how much this RAM is (Linux).

`check_all_prereq.sh` allows you to check all the prerequisites required to use a custom allocator. Platform specific script.

`mem_frag.sh` is determine memory fragmentation (Linux/Solaris).

`disable_pymalloc.sh` sets PYTHONMALLOC to use libC (Linux).

`disable_pymalloc_for_service_linux.sh` sets PYTHONMALLOC to use libC for python-based systemd service (Linux).

`enable_preload_per_service_linux.sh` enables non-system allocator preload per specified systemd service (Linux).

`disable_preload_for_service_linux.sh` allows you to selectively disable global preload of any non-system allocator for a given systemd service or remove per-service allocator preload (-d option) (Linux).

`enable_global_preload_linux.sh` enables non-system allocator global preload (Linux).

`disable_global_preload_linux.sh` disables non-system allocator global preload (Linux).

`enable_preload_per_service_solaris.sh` enables non-system allocator preload per specified systemd service (Solaris).

`disable_preload_for_service_solaris.sh` allows you to selectively disable global preload of any non-system allocator for a given systemd service or remove per-service allocator preload (-d option) (Solaris).

`enable_global_preload_solaris.sh` enables non-system allocator global preload (Solaris/OpenIndiana/OmniOS).

`disable_global_preload_solaris.sh` disables non-system allocator global preload (Solaris/OpenIndiana/OmniOS).

`enable_global_preload_aix.sh` enables non-system allocator global preload (AIX).

`disable_global_preload_aix.sh` disables non-system allocator global preload (AIX).

`enable_global_extra_env_linux.sh` enables extra env drop-ins for all running systemd services due to lack systemd global environment functionality (Linux).

`disable_global_extra_env_linux.sh` disables extra env drop-ins for all running systemd services due to lack systemd global environment functionality (Linux).

`enable_extra_env_per_service_linux.sh` enables extra env per specified systemd service.

`disable_extra_env_per_service_linux.sh` disables extra env for specified systemd service.

**Note**: The "Support" directory contains auxiliary tools for debugging and support.

<ins>Support</ins>

`tools_enable_coredumps_linux.sh` enables coredumps (Linux)
```
Usage: tools_enable_coredumps_linux.sh [options]

Options:
  -h, -H, --help               Show this help
  -n, -N                       Non-interactive mode
  -c, -C, --limit-choice N     Coredump config choice (1,2)
  -d, -D, --delete-core Yy|Nn  Delete test coredump

Examples:
  tools_enable_coredumps_linux.sh
  tools_enable_coredumps_linux.sh -n -c 2 -d Y
```
`tools_enable_coredumps_solaris.sh` enables coredumps (Solaris)

`tools_enable_coredumps_freebsd.sh` enables coredumps (FreeBSD)

`tools_enable_coredumps_aix.sh` enables coredumps (AIX)

`tools_disable_coredumps_linux.sh` disables coredumps (Linux)

`tools_disable_coredumps_solaris.sh` disables coredumps (Solaris)

`tools_disable_coredumps_freebsd.sh` disables coredumps (FreeBSD)

`tools_disable_coredumps_aix.sh` disables coredumps (AIX)

`tools_analyze_core_linux.sh` extracts a stacktrace from the coredump (Linux)
```
Usage: tools_analyze_core_linux.sh CORE [options]

Options:
  -e, -E FILE      Specify executable image
  -h, -H, --help   Show this help

Examples:
    tools_analyze_core_linux.sh core.12345 -e ./my_program
```
`tools_analyze_core_solaris.sh` extracts a stacktrace from the coredump (Solaris)
```
Usage: tools_analyze_core_solaris.sh CORE [options]

Options:
  -e, -E FILE      Specify executable image
  -h, -H, --help   Show this help

Examples:
    tools_analyze_core_solaris.sh core.12345 -e ./my_program
```
`tools_analyze_core_freebsd.sh`  extracts a stacktrace from the coredump (FreeBSD)
```
Usage: tools_analyze_core_freebsd.sh CORE [options]

Options:
  -e, -E FILE      Specify executable image
  -h, -H, --help   Show this help

Examples:
    tools_analyze_core_freebsd.sh core.12345 -e ./my_program
```