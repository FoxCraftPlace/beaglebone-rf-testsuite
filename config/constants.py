"""
Shared, non-secret test constants for BeagleBone Black validation.
Safe to commit — contains no credentials.
"""

# Serial console prompt that signals boot completion
BOOT_LOGIN_PROMPT = "login:"

# Root shell prompt on this image ends in '#'
SHELL_PROMPT_MARKER = "#"

# U-Boot bootloader banner pattern (major.minor version)
UBOOT_VERSION_PATTERN = r"U-Boot \d{4}\.\d{2}"

EXPECTED_BOARD_NAME = "BeagleBone Black"

# Patterns that indicate a genuinely fatal boot failure
CRITICAL_FAILURE_PATTERNS = [
    "Kernel panic",
    "Oops",
    "Call Trace",
    "Unable to mount root fs",
    "Segmentation fault",
]

# Known, harmless warnings specific to this board revision
# (headless BBB without HDMI cape attached to those pins)
KNOWN_BENIGN_WARNINGS = [
    "tda998x",
    "pinctrl-single",
    "No match for driver 'omap_hsmmc'",
    "Card did not respond to voltage select",
]

# ---------------------------------------------------------------------------
# Category 2: Network Layer
# ---------------------------------------------------------------------------

BBB_IP_ADDRESS = "10.0.0.2"

# Basic connectivity ping: small sample, zero tolerance for loss
PING_BASIC_COUNT = 4
PING_BASIC_TIMEOUT_SEC = 2
PING_BASIC_MAX_LOSS_PERCENT = 0.0

# Sustained/load ping: larger sample, small tolerance for loss
PING_LOAD_COUNT = 120
PING_LOAD_TIMEOUT_SEC = 2
PING_LOAD_MAX_LOSS_PERCENT = 2.0

# Regex for parsing "X% packet loss" out of ping summary output
PING_LOSS_REGEX = r"(\d+(?:\.\d+)?)%\s+packet loss"

# Regex for validating a full standalone MAC address string
MAC_ADDRESS_REGEX = r"^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$"
# Regex for extracting a MAC address out of larger `ip neigh` output
MAC_EXTRACT_REGEX = r"[0-9A-Fa-f]{2}(?::[0-9A-Fa-f]{2}){5}"

# `ip neigh` states that mean the entry is not actually usable
ARP_INVALID_STATES = ["FAILED", "INCOMPLETE"]

# ---------------------------------------------------------------------------
# Category 3: SSH / System Validation
# ---------------------------------------------------------------------------

# Kernel release string reported by U-Boot during boot (see boot_monitoring_test.robot);
# uname -r on a live system should match this exactly.
EXPECTED_KERNEL_RELEASE = "4.19.94-ti-r42"

MAX_ROOT_FS_USAGE_PERCENT = 90
MIN_AVAILABLE_MEMORY_MB = 50
MAX_LOAD_AVERAGE_1MIN = 3.0
MAX_SANE_UPTIME_SEC = 2592000  # 30 days; catches parsing bugs returning garbage

CRITICAL_SERVICES = ["ssh", "connman"]

# ---------------------------------------------------------------------------
# Category 4: Log Analysis
# ---------------------------------------------------------------------------

# Patterns indicating the OOM killer fired -- worth a dedicated check on a
# 512 MiB board that gets rebooted and re-tested repeatedly.
OOM_KILLER_PATTERNS = [
    "Out of memory",
    "oom-killer",
    "Killed process",
]

# Calibrated from a real boot: 9 baseline error-level entries consist of known-benign
# early kernel messages (timer_probe, l4_wkup_cm, omap_voltage_late_init -- all AM335x
# SoC quirks visible in the serial boot log too), the same tda998x/pinctrl-single HDMI
# pin conflict already documented as a war story in Category 1 (headless board, no HDMI
# cape attached), plus two minimal-image userspace warnings (avahi chroot helper
# missing, connman VPN plugin not installed) -- neither used on this test bench.
# 12 = 9 baseline + 25% margin, same approach as COLD_BOOT_TIME_THRESHOLD_SEC.
MAX_ALLOWED_ERROR_JOURNAL_ENTRIES = 12

# Verified against real journal output on this board (journalctl -b -1
# -q --no-pager | tail -30): both markers confirmed present after a
# serial-triggered reboot.
CLEAN_SHUTDOWN_MARKERS = [
    "Reached target Shutdown",
    "Reached target Reboot",
]

MAX_JOURNAL_DISK_USAGE_MB = 50

# ---------------------------------------------------------------------------
# Category 5: Stress / Reboot Cycles
# ---------------------------------------------------------------------------

# Number of consecutive power cycles to run in Suite Setup. Each one is a graceful
# shutdown over serial, a relay power cut and a cold boot captured from the first byte
# (Cold Boot DUT) -- the same sequence Category 1 uses for its single cold boot, just
# repeated. A cycle took ~73s on this bench, so 5 cycles is a ~6 minute Suite Setup.
REBOOT_CYCLE_COUNT = 5

# Max allowed spread (max - min) in per-cycle cold-boot time across all successful
# cycles, to catch inconsistent/degrading behavior even when every individual cycle is
# under COLD_BOOT_TIME_THRESHOLD_SEC. Calibrated from a real 5-cycle run: 57s on every
# cycle, spread 0s (times are whole seconds). With ~57s boots, 10s trips at 68s -- ahead
# of the 72s absolute limit -- while the previous 30s could only trip above it.
MAX_BOOT_TIME_VARIANCE_SEC = 10

# Stress tests report a statistical pass rate rather than demanding 100%: real hardware
# can have an occasional flaky cycle, and characterizing the failure rate is the point.
MIN_REBOOT_SUCCESS_RATE_PERCENT = 80

# ---------------------------------------------------------------------------
# U-Boot Console Validation (supplemental category -- active CLI inspection)
# ---------------------------------------------------------------------------

# U-Boot's interactive command prompt.
UBOOT_PROMPT_MARKER = "=> "

# NOTE: not yet calibrated against enough timed runs -- 15s is a starting estimate for
# SPL/U-Boot init after a relay power-on, with generous margin. The seconds until the
# '=>' prompt are logged on every run ("U-Boot console reached=... after power-on"); the
# first real run reached it after 1s. Tighten this once more runs are logged, same
# approach as COLD_BOOT_TIME_THRESHOLD_SEC.
UBOOT_INTERRUPT_MAX_WAIT_SEC = 15

# Raw env values as reported by U-Boot itself -- an independent source from
# the friendly "BeagleBone Black" banner string Category 1 checks against.
EXPECTED_BOARD_NAME_ENV = "A335BNLT"
EXPECTED_BOARD_REV_ENV = "00C0"

EXPECTED_BOOTCMD_SUBSTRING = "distro_bootcmd"
EXPECTED_LOADADDR = "0x82000000"
EXPECTED_FDTADDR = "0x88000000"
EXPECTED_CONSOLE_SETTING = "ttyO0,115200n8"

# ---------------------------------------------------------------------------
# Power control (USB-serial relay, NC wiring)
# ---------------------------------------------------------------------------

# CH340 relay module behind a stable udev symlink (/etc/udev/rules.d/99-bench.rules).
RELAY_PORT = "/dev/relay0"
RELAY_BAUDRATE = 9600

# NC wiring: energizing the coil OPENS the contact -> DUT loses power.
# Byte sequences verified on the real module (relay clicks on each command).
RELAY_CMD_ENERGIZE_HEX = "A0 01 01 A2"
RELAY_CMD_RELEASE_HEX = "A0 01 00 A1"

# How long power stays off so the board fully de-energizes (caps, UART back-feed).
POWER_OFF_HOLD_SEC = 5

# Graceful shutdown over serial before the relay cuts power.
# Marker verified on a real run: seen on the console after poweroff.
POWEROFF_MARKER = "Power down"
POWEROFF_WAIT_SEC = 60

# Cold boot = relay power-on to login prompt (no shutdown time included). Calibrated
# from a real run: 57.4s measured, 72s gives ~25% margin for normal run-to-run jitter
# while still catching genuine regressions. A later 5-cycle stress run measured 57s on
# every cycle.
COLD_BOOT_TIME_THRESHOLD_SEC = 72

# Absolute ceiling to wait for the login prompt after power-on before giving up on the
# boot. Deliberately looser than COLD_BOOT_TIME_THRESHOLD_SEC (the actual pass/fail
# bar, checked separately) so a slow-but-still-booting board is captured and evaluated
# rather than cut off right at the threshold.
COLD_BOOT_CAPTURE_TIMEOUT_SEC = 150

# Don't nudge the console with Enter before this many seconds after power-on:
# U-Boot has autoboot delay 0, and a stray keypress at the wrong moment drops the
# board into the U-Boot prompt instead of booting.
COLD_BOOT_NUDGE_AFTER_SEC = 30