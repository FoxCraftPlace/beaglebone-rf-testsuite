# beaglebone-rf-testsuite

Hardware-in-the-Loop test automation for a BeagleBone Black, written in Robot Framework and driven from a Raspberry Pi 5.

![Robot Framework](https://img.shields.io/badge/Robot%20Framework-7.4.2-000000?logo=robotframework&logoColor=white)
![Python](https://img.shields.io/badge/Python-3.14-3776AB?logo=python&logoColor=white)
![Platform](https://img.shields.io/badge/platform-ARM64%20%7C%20Raspberry%20Pi%205-A22846?logo=raspberrypi&logoColor=white)
![DUT](https://img.shields.io/badge/DUT-BeagleBone%20Black-00CC66)
![Tests](https://img.shields.io/badge/tests-30%20passing-2ea44f)
![License](https://img.shields.io/badge/license-MIT-yellow)

This is a Robot Framework test suite for a BeagleBone Black, driven from a Raspberry Pi 5 over serial and Ethernet. It watches the board boot over UART, inspects the U-Boot environment mid-boot, brings the board up on the network, and checks its running state over SSH — producing a timestamped HTML report on each run.

Every test runs against physical hardware: a real BeagleBone Black connected to a real Raspberry Pi over UART and a direct Ethernet link. There is no emulation and no mocked transport layer.

|                        |                                                                   |
| ---------------------- | ----------------------------------------------------------------- |
| **Device Under Test**  | BeagleBone Black — TI AM335x, single-core Cortex-A8, 512 MB RAM   |
| **Test Host**          | Raspberry Pi 5 — Ubuntu 26.04 LTS, ARM64, Python 3.14              |
| **Framework**          | Robot Framework 7.4.2, keyword-driven, custom `.resource` libraries |
| **Transports**         | Serial UART (115200 8N1) · direct peer-to-peer Ethernet · SSH      |
| **Boot Image**         | BeagleBoard.org Debian Buster IoT Image 2020-04-06 — U-Boot 2019.04-00002-g31a8ae0206, kernel 4.19.94-ti-r42 |
| **Coverage**           | 30 test cases passing, across 5 suites                             |

---

## Table of Contents

- [Overview](#overview)
- [The Test Bench](#the-test-bench)
- [Why Two Transports](#why-two-transports-serial--ethernet)
- [Repository Structure](#repository-structure)
- [Architecture](#architecture)
- [Test Suite](#test-suite)
- [Engineering War Stories](#engineering-war-stories)
- [Getting Started](#getting-started)
- [Reports](#reports)
- [Testing Philosophy](#testing-philosophy)
- [Limitations](#limitations)
- [Tech Stack](#tech-stack)
- [License](#license)
- [Author](#author)

---

## Overview

This project is a keyword-driven Robot Framework test suite that validates a BeagleBone Black end-to-end: from the moment power is applied, through the U-Boot and Linux boot chain, across the network stack, and into a live SSH session that checks the system's actual health — memory, disk, load, running services, and log output.

A few things about how this suite is built:

- **It's organized by dependency, not by convenience.** Suites are ordered bottom-up: serial boot monitoring first, then U-Boot console inspection, then network, then SSH, then log analysis. Each layer only depends on layers already proven to work, so a failure surfaces at the layer that actually caused it instead of several layers downstream.
- **It's structured to extend.** Adding a new test category follows the same pattern as the existing five: one new `.resource` file, one new `.robot` file, and any new thresholds added to `config/constants.py`.

---

## The Test Bench

```
┌─────────────────────┐                          ┌──────────────────────┐
│   Raspberry Pi 5     │                          │   BeagleBone Black   │
│   Ubuntu 26.04 ARM64 │                          │   Debian Buster      │
│   Python 3.14        │                          │   TI AM335x          │
│                       │                          │                      │
│   10.0.0.1  ──────────── direct P2P Ethernet ────────  10.0.0.2         │
│   /dev/ttyUSB0 ────────── UART, 115200 8N1 ──────────  serial console   │
└─────────────────────┘                          └──────────────────────┘
```

The UART link uses the BBB's J1 debug header at 3.3V TTL logic levels: pin 1 (GND) to the adapter's ground, pin 4 (RXD) to the adapter's TX line, pin 5 (TXD) to the adapter's RX line. Pin 6 (VDD) is left unconnected — the board is powered separately over its own 5V supply, and an adapter running at 5V instead of 3.3V will damage the SoC's UART pins.

The Raspberry Pi is the test runner — it never runs test logic on the DUT itself. Every check is driven from the Pi, over one of the two transports above, and asserts on what comes back.

---

## Why Two Transports (Serial + Ethernet)?

Because they see different, non-overlapping parts of the board's life:

```
SPL → U-Boot → Linux Kernel → Root Filesystem → login: prompt
```

The serial console provides visibility from the SPL stage onward, all the way through to the login prompt. Ethernet and SSH don't exist yet for most of that chain — the network stack only comes up once the kernel has mounted the root filesystem and systemd has started the relevant services. A board that hangs in U-Boot, panics mid-kernel-boot, or fails to mount its root filesystem is invisible to a ping or an SSH test — it just looks like "unreachable," with zero diagnostic value.

That's why serial is treated as the source of truth for boot health, and why the serial-based suites run before the network-based ones — serial can see failures earlier in the chain that a network test would only see as a silent timeout.

---

## Repository Structure

```text
beaglebone-rf-testsuite/
├── config/
│   ├── constants.py               # shared, non-secret thresholds & patterns — committed
│   ├── secrets.example.py         # template with dummy values — committed
│   └── secrets.py                 # SSH credentials — gitignored, never committed
├── resources/
│   ├── serial_keywords.resource   # low-level UART interaction, reboot + boot log capture
│   ├── uboot_keywords.resource    # U-Boot autoboot interrupt + printenv inspection
│   ├── network_keywords.resource  # ping / ARP helper keywords
│   ├── ssh_keywords.resource      # shared SSH session + parsing keywords
│   └── log_keywords.resource      # dmesg / journalctl helper keywords
├── tests/
│   ├── serial/
│   │   └── boot_monitoring_test.robot
│   ├── uboot/
│   │   └── uboot_console_test.robot
│   ├── network/
│   │   └── ping_test.robot
│   ├── ssh/
│   │   └── ssh_test.robot
│   └── logs/
│       └── log_test.robot
├── results/                       # generated log.html / report.html / output.xml — gitignored
├── requirements.txt
├── .gitignore
└── README.md
```

**Why secrets are split from constants:** `config/constants.py` holds everything safe to publish — regex patterns, benign-warning allowlists, timing thresholds, and even the DUT's IP address, serial port, and baud rate, since those are hardware configuration, not credentials. `config/secrets.py` holds the one thing that isn't safe to publish — SSH login credentials — and is excluded via `.gitignore`. Only `config/secrets.example.py`, with placeholder values, is committed.

---

## Architecture

Each `.robot` test file calls keywords defined in one matching `.resource` file — `boot_monitoring_test.robot` uses `serial_keywords.resource`, `ssh_test.robot` uses `ssh_keywords.resource`, and so on. The `.resource` files are the only layer that calls a transport library directly (SerialLibrary, SSHLibrary); test files never invoke SerialLibrary or SSHLibrary keywords themselves. Board-specific values — thresholds, expected banners, IP addresses, the serial port path — live in `config/constants.py` and are imported into the resource files rather than hardcoded into individual keywords. Session state (the open SSH connection, the captured boot log) is set once in Suite Setup as a suite variable and read by every test case in that suite, rather than passed as arguments between tests.

---

## Test Suite

**30 test cases implemented and passing**, across five suites, ordered by dependency.

### Serial / Boot Monitoring — 7 tests
`tests/serial/boot_monitoring_test.robot`

Watches the full boot sequence over UART, from the U-Boot banner to the Linux login prompt, entirely independent of network or SSH — the reboot itself is triggered over serial.

- Boot Log Should Contain Login Prompt
- Boot Log Should Contain No Critical Failures
- Boot Time Should Be Within Threshold (≤ 75s, calibrated with a 25% margin over a 60s measured baseline)
- U-Boot Banner Should Match Expected Version
- Board Should Be Identified As BeagleBone Black
- Network And Storage Drivers Should Initialize
- Root Filesystem Should Be Clean

### U-Boot Console Validation — 7 tests
`tests/uboot/uboot_console_test.robot`

Interrupts autoboot on a live reboot cycle and inspects the actual running U-Boot environment via `printenv`, then resumes normal boot. Entirely read-only — no environment variable is ever written or saved.

- Autoboot Should Be Interruptible And Reach U-Boot Console
- Board Identity Should Match Expected Values
- Ethernet MAC Address Should Be Set And Valid
- Boot Command Should Use Standard Distro Boot Sequence
- Kernel And FDT Load Addresses Should Match Expected Memory Map
- Serial Console Should Be Configured On Expected UART
- DUT Should Resume Normal Boot After Console Inspection

### Network Layer — 3 tests
`tests/network/ping_test.robot`

Validates basic IP connectivity between the Raspberry Pi and the DUT over the direct peer-to-peer Ethernet link.

- Basic connectivity ping (zero packet loss tolerance)
- Sustained load ping (120 packets, ≤ 2% loss tolerance)
- ARP / neighbor table entry validation

### SSH / System Validation — 8 tests
`tests/ssh/ssh_test.robot`

Opens a single shared SSH session in Suite Setup and checks the DUT's live running state. Connection failures are captured rather than raised, so the first test reports the cause clearly and the rest skip cleanly instead of failing on an opaque SSHLibrary error.

- SSH login smoke test
- Uptime sanity check
- Kernel version cross-check against the serial boot log
- Root filesystem usage threshold
- Available memory threshold
- 1-minute load average threshold
- Critical service status (ssh, connman)
- Unexpected reboot detection

### Log Analysis — 5 tests
`tests/logs/log_test.robot`

Reads the kernel ring buffer (`dmesg`) and the systemd journal (`journalctl`) over the same SSH session pattern, catching faults that occur after boot completes and signs of an unclean prior shutdown.

- Dmesg Should Contain No Critical Kernel Failures
- Dmesg Should Not Contain Out Of Memory Killer Events
- Current Boot Journal Should Not Exceed Error Threshold
- Previous Boot Should Have Ended With A Clean Shutdown Sequence
- Journal Disk Usage Should Be Below Threshold

---

## Engineering War Stories

Real bugs hit while building this suite, each with a false start before the actual root cause.

**1. The `PermitRootLogin` default that wasn't disabled**
Root login via SSHLibrary/paramiko kept failing, even though the identical password worked fine in a manual `ssh` session. The commented-out `#PermitRootLogin prohibit-password` line in `sshd_config` looks like a disabled setting — it isn't. `prohibit-password` is OpenSSH's compiled-in default, and the comment merely documents it. Fix: explicitly set `PermitRootLogin yes` and `PasswordAuthentication yes`, then restart `ssh`.

**2. The `tda998x` false positive**
A naive `"error" not in dmesg` check failed on every single boot, including healthy ones. The HDMI driver `tda998x` logs `Error applying setting` simply because no HDMI cape is attached to this headless board — cosmetic noise, not a fault. Fix: an explicit allowlist of known-benign warnings, checked against a short list of genuinely fatal patterns instead of a blanket string search.

**3. The SerialLibrary hexlify trap**
Serial reads were coming back as unreadable hex strings instead of text. `robotframework-seriallibrary` 0.4.3 defaults to hexlify encoding unless told otherwise, and the correct read keyword is `Read All Data`, not the more discoverable `Read Data`. `Read All Data` is also non-blocking, so polling loops need an explicit `Sleep` between reads. Fix: `Library SerialLibrary encoding=ascii`, plus a poll-and-sleep loop.

**4. ConnMan silently reverting the DUT's static IP**
The BeagleBone's IP address would reset after every reboot despite being set via `/etc/network/interfaces`. ConnMan owns network configuration on this image and silently overrides that file on its own schedule. Fix: configure the static IP through `connmanctl config --ipv4 manual` instead.

**5. cloud-init vs. NetworkManager on the Raspberry Pi host**
The Pi's own Ethernet interface would occasionally lose its static IP. Two systems were both trying to manage the same interface: cloud-init's `systemd-networkd` config and NetworkManager. Fix: disable cloud-init's network management via a drop-in `.cfg` file and let NetworkManager own the interface exclusively.

---

## Getting Started

1. **Wire up the bench.** Connect the Raspberry Pi and BeagleBone Black via a direct Ethernet cable and a 3.3V TTL USB-to-serial adapter to the BBB's J1 debug header — see [The Test Bench](#the-test-bench) for pinout and voltage requirements.
2. **Clone and set up the environment.**
   ```bash
   git clone https://github.com/FoxCraftPlace/beaglebone-rf-testsuite.git
   cd beaglebone-rf-testsuite
   python3 -m venv venv
   source venv/bin/activate
   pip install -r requirements.txt
   ```
3. **Configure secrets.**
   ```bash
   cp config/secrets.example.py config/secrets.py
   ```
   Edit `config/secrets.py` with the DUT's real SSH credentials.
4. **Run a suite.**
   ```bash
   robot --outputdir results/ tests/serial/boot_monitoring_test.robot
   ```
   Or run everything:
   ```bash
   robot --outputdir results/ tests/
   ```

---

## Reports

Every run produces a standard Robot Framework `report.html` and `log.html` in `results/`. On this bench, the Raspberry Pi also runs nginx to serve the latest report over the local network, auto-updating as new runs complete — no separate publish step required.

---

## Testing Philosophy

- **Bottom-up dependency ordering** — serial → U-Boot console → network → SSH → log analysis (see [Overview](#overview)).
- **Serial as the source of truth for boot health** (see [Why Two Transports](#why-two-transports-serial--ethernet)).
- **Self-contained reboot triggering** — serial-based suites reboot over UART, not SSH.
- **Single shared session per suite** — one connection opened in Suite Setup, reused by every test.
- **Capture, don't raise, on setup failure** — connection errors are stored as suite variables; later tests skip instead of failing on an opaque error.
- **Known-benign filtering over naive string matching** (see War Story #2).

---

## Limitations

- The suite validates one specific board and image combination — a BeagleBone Black running the BeagleBoard.org Debian Buster IoT Image (2020-04-06), U-Boot 2019.04-00002-g31a8ae0206, kernel 4.19.94-ti-r42. Thresholds, expected banners, and memory-map values in `config/constants.py` are calibrated against this combination.
- Reboots are triggered over the serial console (a warm reset from the running shell or U-Boot's own reset path); there is no relay- or PDU-driven cold power cycle, so failure modes that only surface on a true power-off are not exercised.
- The Ethernet link is a static point-to-point connection (`10.0.0.1` / `10.0.0.2`) configured directly on both hosts; DHCP and other dynamic-addressing paths are not under test.
- Test runs are started manually from the command line; there is no scheduler or CI runner triggering regression runs.
- Keyword logic is exercised through live runs against the physical board rather than isolated unit tests — correctness is validated by hardware asserting on it, not by mocked transport inputs.

---

## Tech Stack

| | |
|---|---|
| **Language**       | Python 3.14 |
| **Test framework** | Robot Framework 7.4.2 |
| **Libraries**       | SSHLibrary, robotframework-seriallibrary 0.4.3, paramiko |
| **Version control** | Git, Conventional Commits |
| **Report serving**  | nginx |

---

## License

Distributed under the MIT License.

---

## Author

Volodymyr Lysenko — linkedin.com/in/volodymyr-lysenk0 —
