"""
Shared, non-secret test constants for BeagleBone Black validation.
Safe to commit — contains no credentials.
"""

# Calibrated from real measurement: single-run baseline was 60s. 75s gives ~25% margin
# for normal run-to-run jitter (fsck, network negotiation, scheduler variance) while
# still catching genuine regressions. Shared by Category 1 (single reboot) and
# Category 5 (repeated reboot cycles) so both use the exact same calibrated bar.
BOOT_TIME_THRESHOLD_SEC = 75

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
# 12 = 9 baseline + 25% margin, same approach as BOOT_TIME_THRESHOLD_SEC.
MAX_ALLOWED_ERROR_JOURNAL_ENTRIES = 12

# NOTE: exact wording depends on the systemd version and the reboot method;
# not yet verified against this board's actual journal output. Run
# `journalctl -b -1 -q --no-pager | tail -30` once on the DUT and confirm
# these substrings actually appear before trusting this test.
CLEAN_SHUTDOWN_MARKERS = [
    "Reached target Shutdown",
    "Reached target Reboot",
]

MAX_JOURNAL_DISK_USAGE_MB = 50

# ---------------------------------------------------------------------------
# Category 5: Stress / Reboot Cycles
# ---------------------------------------------------------------------------

# Number of consecutive reboot cycles to run in Suite Setup, all over the serial
# console -- the exact same trigger-and-capture mechanism Category 1 uses for its
# single reboot, just repeated. Each cycle costs roughly one full boot, so keep this
# modest -- 5 cycles is already a several-minute Suite Setup.
REBOOT_CYCLE_COUNT = 5

# Absolute ceiling to wait for the login prompt on any one cycle before giving up on
# it entirely. Deliberately looser than BOOT_TIME_THRESHOLD_SEC (the actual pass/fail
# bar, checked separately per cycle) so a slow-but-still-booting cycle gets captured
# and evaluated rather than cut off right at the threshold.
REBOOT_CYCLE_CAPTURE_TIMEOUT_SEC = 150

# Max allowed spread (max - min) in per-cycle boot time across all successful cycles,
# to catch inconsistent/degrading behavior even when every individual cycle is under
# BOOT_TIME_THRESHOLD_SEC. NOTE: not yet calibrated against a real multi-cycle run.
MAX_BOOT_TIME_VARIANCE_SEC = 30

# Stress tests report a statistical pass rate rather than demanding 100%: real hardware
# can have an occasional flaky cycle, and characterizing the failure rate is the point.
MIN_REBOOT_SUCCESS_RATE_PERCENT = 80

# ---------------------------------------------------------------------------
# U-Boot Console Validation (supplemental category -- active CLI inspection)
# ---------------------------------------------------------------------------

# U-Boot's interactive command prompt.
UBOOT_PROMPT_MARKER = "=> "

# NOTE: not yet calibrated against a real timed run -- this is a starting
# estimate covering a normal Linux graceful shutdown plus SPL/U-Boot init,
# with margin. After the first real execution, check how many seconds
# actually elapsed between the reboot command and the '=>' prompt and
# tighten this if there's room, same approach as BOOT_TIME_THRESHOLD_SEC.
UBOOT_INTERRUPT_MAX_WAIT_SEC = 15

# Raw env values as reported by U-Boot itself -- an independent source from
# the friendly "BeagleBone Black" banner string Category 1 checks against.
EXPECTED_BOARD_NAME_ENV = "A335BNLT"
EXPECTED_BOARD_REV_ENV = "00C0"

EXPECTED_BOOTCMD_SUBSTRING = "distro_bootcmd"
EXPECTED_LOADADDR = "0x82000000"
EXPECTED_FDTADDR = "0x88000000"
EXPECTED_CONSOLE_SETTING = "ttyO0,115200n8"