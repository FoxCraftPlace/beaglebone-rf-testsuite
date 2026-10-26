"""Robot Framework library: DUT power control through a CH340 USB-serial relay.

Polarity-agnostic: it only knows "energize" and "release" the relay coil.
What that means for the DUT (NC vs NO wiring) is decided one level up, in
resources/power_keywords.resource.
"""
import time

import serial
from robot.api import logger


class RelayPower:
    ROBOT_LIBRARY_SCOPE = "GLOBAL"

    def __init__(
        self,
        port: str,
        baudrate: int = 9600,
        energize_hex: str = "A0 01 01 A2",
        release_hex: str = "A0 01 00 A1",
        settle_s: float = 0.3,
    ):
        self._port = port
        self._baudrate = baudrate
        self._energize = bytes.fromhex(energize_hex)
        self._release = bytes.fromhex(release_hex)
        self._settle_s = settle_s

    def relay_energize(self):
        """Energizes the relay coil (with NC wiring the DUT loses power)."""
        self._send(self._energize, "energize")

    def relay_release(self):
        """Releases the relay coil (with NC wiring the DUT gets power)."""
        self._send(self._release, "release")

    def _send(self, payload: bytes, label: str):
        try:
            with serial.Serial(
                self._port, self._baudrate, timeout=1, write_timeout=2
            ) as ser:
                ser.write(payload)
                ser.flush()
        except serial.SerialException as exc:
            raise RuntimeError(
                f"Relay port {self._port} is not usable: {exc}"
            ) from exc
        logger.info(f"Relay {label}: sent {payload.hex(' ')} to {self._port}")
        time.sleep(self._settle_s)