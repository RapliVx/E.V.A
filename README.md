# Project E.V.A

Project E.V.A is an advanced performance optimizer designed for Android devices, integrating a custom kernel driver with a robust KernelSU module. The primary goal is to provide dynamic, autonomous performance tuning based on process identifiers (PID) and system state, specifically tailored for intensive workloads such as gaming.

## Architecture

Project E.V.A consists of three primary components:

1.  **Kernel Modifications (C)**:
    Located in the `kernel/` directory. This includes modifications to the CPU scheduler (`eva.c`) to provide aggressive performance scaling based on the targeted PID.
2.  **User-Space Daemon (Rust)**:
    A lightweight, memory-safe, and highly efficient background service written in Rust. It utilizes Android's `dumpsys window` command and `procfs` to actively monitor the foreground application. If the active application matches the user-defined `PackageList.txt`, the daemon injects its PID into the E.V.A kernel node (`kernel.sched_eva_pid`).
3.  **KernelSU Module & WebUI (JavaScript/HTML)**:
    A fully integrated root module and an elegant Web UI dashboard designed with Material 3. The interface allows users to manage their target applications, toggle performance modes, apply network optimizations, and spoof battery thermal readings.

## Kernel Implementation

To implement Project E.V.A in your kernel tree, simply run the automated setup script from the root of your kernel source tree:

```bash
bash <(curl -sL https://raw.githubusercontent.com/RapliVx/E.V.A/main/setup.sh)
```

The setup script will automatically:
- Download the required `eva.c` and `eva.h` files.
- Patch your `kernel/sched/Makefile` to include the driver.
- Inject the `CONFIG_SCHED_EVA` entry into your `init/Kconfig` or `kernel/Kconfig.preempt`.

After running the script, ensure that your kernel defconfig includes `CONFIG_SCHED_EVA=y`.

## Module Structure

The KSU module is located in the `module/` directory.
-   `evadaemon_src/`: The Rust source code for the background service.
-   `webroot/`: The front-end files for the KernelSU WebUI.
-   `PackageList.txt`: A plain-text list of application package names targeted for auto-boosting.
-   `customize.sh`: The installation script handling the initial synchronization of installed packages against the target list.

## Compilation

The KernelSU module can be compiled using the provided GitHub Actions workflow.

1.  The workflow automatically provisions an Ubuntu runner with the Android NDK and Rust toolchain.
2.  It compiles the Rust daemon (`evadaemon_src`) using `cargo-ndk` for the `aarch64-linux-android` target.
3.  The resulting binary is placed into the root of the module directory as `eva_daemon`.
4.  The entire `module/` directory (excluding source code files) is packaged into a flashable ZIP file.

You can download the compiled ZIP file from the Artifacts section of the GitHub Actions run.

## Disclaimer

This project touches critical system components including the CPU scheduler and thermal mitigation systems. Misuse of features like thermal spoofing can cause permanent hardware damage. Use entirely at your own risk.
