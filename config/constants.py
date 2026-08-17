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