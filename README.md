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

`enable_preload_per_service.sh` enables custom allocator preload per specified systemd service.

`disable_preload_for_service.sh` allows you to selectively disable global preloading of any custom allocator for a given systemd service.
