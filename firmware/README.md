# ESP32 firmware and wiring

These pin assignments are **assumptions for a classic ESP32 DevKit**, not confirmed wiring for your hardware. Check your board pinout before connecting power. The sketch uses the ESP32 Arduino core, built-in WiFi/WebServer/ESPmDNS/Wire libraries, and the LiquidCrystal_I2C library exposing `init()` / `backlight()` (for example Frank de Brabander's library). LCD backpacks commonly use address 0x27 or 0x3F; run an I2C scan and edit the constructor if needed.

| ESP32 GPIO / rail | Component | Component pin | Power / connection |
|---|---|---|---|
| GPIO23 | HC-SR04 | Trig | 3.3 V logic output; verify module accepts it |
| GPIO19 | HC-SR04 | Echo via divider | Never connect 5 V Echo directly |
| Regulated 5 V | HC-SR04 | VCC | Standard module needs 5 V |
| GND | HC-SR04 | GND | Common ground |
| GPIO25 | Green LED | Anode via 330 ohm resistor | Cathode to GND |
| GPIO26 | Yellow LED | Anode via 330 ohm resistor | Cathode to GND |
| GPIO27 | Red LED | Anode via 330 ohm resistor | Cathode to GND |
| GPIO21 | I2C level shifter LV1 | SDA path to LCD SDA | LV supply 3.3 V; HV supply 5 V |
| GPIO22 | I2C level shifter LV2 | SCL path to LCD SCL | Bidirectional I2C-compatible shifter |
| Regulated 5 V | LCD backpack | VCC | Check backpack specification |
| GND | LCD and level shifter | GND | Common ground with ESP32 |

## Voltage protection

Echo divider: HC-SR04 Echo → **2.2 kohm** → junction → GPIO19; junction → **3.3 kohm** → GND. This yields approximately 3.0 V from a 5 V Echo. Use suitable resistor tolerances or a rated logic level shifter. These two resistors are in addition to the three LED resistors.

Many 5 V LCD I2C backpacks pull SDA/SCL up to 5 V. Do not connect those lines directly to ESP32 GPIO. Use a bidirectional I2C level shifter with 3.3 V on its ESP32 side and 5 V on its LCD side, with suitable pull-ups. A verified 3.3 V-compatible LCD/backpack is an alternative; do not assume every backpack is compatible.

Power the ESP32 according to its board's USB/VIN requirements. Never feed 5 V into its 3V3 pin. Use a stable supply for the sensor and LCD, share ground, and avoid back-feeding competing USB/external supplies. Disconnect power while rewiring.

## Flash and check

1. Install the ESP32 board package and the LCD library in Arduino IDE.
2. Open [distance_monitor.ino](distance_monitor/distance_monitor.ino).
3. Set WIFI_SSID/WIFI_PASSWORD locally (do not publish credentials), verify pins/LCD address, select your board and serial port, and upload.
4. Open Serial Monitor at 115200 baud. Use the printed DHCP IP in Flutter Settings, or try `esp32.local`.
5. On the same WiFi, request `http://<IP>/distance` and verify valid JSON.
6. Move a flat object through >30 cm, 15–30 cm, and <15 cm ranges. Confirm LCD and exactly one corresponding LED. Test at 14.9 / 15.0 / 30.0 / 30.1 cm when possible, recognizing sensor accuracy limits.
7. Disconnect the sensor and verify `sensor_ok:false`, all LEDs off, LCD SENSOR ERROR, and app NO DATA. Power off ESP32 and verify app reconnect behavior.

The echo pulse is captured by an interrupt with a 30 ms timeout, rather than a long blocking pulseIn call. Sampling is every 100 ms. Only the 10 microsecond trigger pulse blocks intentionally; LCD and HTTP library calls are short synchronous operations. The firmware rounds to 0.1 cm before classification so its LED decisions agree with JSON values and Flutter's classifier. Firmware freshness is limited to one second. WiFi reconnect attempts are spaced by ten seconds.

This sketch has not been verified on physical hardware. A compile/upload check with your exact ESP32 core, board, LCD library, and wiring is required.
