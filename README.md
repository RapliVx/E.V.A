# E.V.A (Enhanced Visual-render Affinity)

E.V.A is an advanced performance optimizer designed for Android devices, integrating a custom kernel driver with a robust KernelSU module. The primary goal is to provide dynamic, autonomous performance tuning based on process identifiers (PID) and system state, specifically tailored for intensive workloads such as gaming.

## How It Works

E.V.A operates by intercepting the standard Linux Completely Fair Scheduler (CFS) and forcing rendering threads to run on the most capable CPU cores (Big/Prime cores). It works through a continuous cycle:

1. Application Detection: The Rust-based user-space daemon (`evadaemon`) constantly monitors the foreground application state using Android's internal window manager dumps and procfs.
2. PID Injection: When a targeted application (defined in `PackageList.txt`) is brought to the foreground, the daemon extracts its PID and injects it directly into the kernel via a sysctl node (`kernel.sched_eva_pid`).
3. Autonomous Kernel Tracking: Once the kernel scheduler receives the target PID, E.V.A's kernel driver hooks into `trace_sched_process_fork` and `trace_sched_process_exit`. It automatically maps all child threads spawned by the main application.
4. Smart CPU Affinity: A delayed workqueue (Smart Polling) regularly evaluates the utilization of the tracked threads. It forcefully overrides CPU masks and adjusts nice values, guaranteeing that heavy rendering tasks are processed by the fastest available CPU cluster, eliminating micro-stutters.
5. Standby Mode: When the application is closed or moved to the background, the daemon resets the PID. The kernel clears its tracking list and gracefully returns scheduling control to the default CFS behavior to save battery.

## Project Map

The project is structured into two main layers: the Kernel subsystem and the User-Space module.

```text
E.V.A/
|-- kernel/
|   |-- Kconfig             (Kernel configuration flag definition)
|   |-- Makefile            (Kernel build system integration)
|   |-- eva.c               (Core scheduler tracking and affinity logic)
|   |-- eva.h               (Header definitions and global variables)
|   `-- setup.sh            (Automated script to symlink E.V.A into a kernel tree)
|
`-- module/
    |-- evadaemon_src/      (Rust source code for the background daemon)
    |-- webroot/            (HTML/JS/CSS for the KernelSU Web UI Dashboard)
    |-- PackageList.txt     (Target package list for the daemon)
    |-- customize.sh        (KernelSU installation script)
    |-- module.prop         (Module metadata and status indicator)
    `-- service.sh          (Startup script to launch evadaemon and monitor state)
```

## Kernel Implementation

To implement E.V.A in your kernel tree, simply run the automated setup script from the root of your kernel source tree:

```bash
cd /path/to/your/kernel/source
curl -LSs "https://raw.githubusercontent.com/RapliVx/E.V.A/main/kernel/setup.sh" | bash -s main
```

The setup script will automatically:
- Create a symlink of the `kernel/` directory into `kernel/sched/eva/`.
- Patch your `kernel/sched/Makefile` to include the driver.
- Inject the `CONFIG_SCHED_EVA` entry into your Kconfig.

After running the script, ensure that your kernel defconfig includes `CONFIG_SCHED_EVA=y`.

## Compilation

The KernelSU module can be compiled using the provided GitHub Actions workflow.

1. The workflow automatically provisions an Ubuntu runner with the Android NDK and Rust toolchain.
2. It caches dependencies and compiles the Rust daemon (`evadaemon_src`) using `cargo-ndk` for the `aarch64-linux-android` target.
3. The resulting binary is placed into the root of the module directory as `eva_daemon`.
4. The GitHub Actions artifact step directly packages the `module/` directory into a ready-to-flash ZIP file.

## Disclaimer

This project touches critical system components including the CPU scheduler and thermal mitigation systems. Misuse of features like thermal spoofing can cause permanent hardware damage. Use entirely at your own risk.

## License

This project is licensed under the GNU General Public License v2.0 (GPL).<br>
Copyright (c) xMikkkaa (Main Inspiration)<br>
Copyright (c) RapliVx
