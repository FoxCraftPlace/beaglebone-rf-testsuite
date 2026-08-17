"""
Shared, non-secret test constants for boot log analysis.
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