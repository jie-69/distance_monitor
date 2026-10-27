#include <WiFi.h>
#include <WebServer.h>
#include <ESPmDNS.h>
#include <Wire.h>
#include <LiquidCrystal_I2C.h>

// Assumed wiring for a classic ESP32 DevKit. Adapt for your board.
constexpr int TRIG_PIN = 23, ECHO_PIN = 19;
constexpr int GREEN_PIN = 25, YELLOW_PIN = 26, RED_PIN = 27;
constexpr int SDA_PIN = 21, SCL_PIN = 22;
const char* WIFI_SSID = "YOUR_WIFI_SSID";
const char* WIFI_PASSWORD = "YOUR_WIFI_PASSWORD";
WebServer server(80);
LiquidCrystal_I2C lcd(0x27, 16, 2);
volatile uint32_t echoStart = 0, echoWidth = 0;
volatile bool echoReady = false, waitingEcho = false;
portMUX_TYPE echoMux = portMUX_INITIALIZER_UNLOCKED;
uint32_t lastTrigger = 0, triggerMicros = 0, lastValid = 0, lastReconnect = 0;
bool sensorOk = false, mdnsStarted = false;
float distanceCm = 0;

void IRAM_ATTR echoChanged() {
  portENTER_CRITICAL_ISR(&echoMux);
  if (waitingEcho) {
    if (digitalRead(ECHO_PIN)) echoStart = micros();
    else { echoWidth = micros() - echoStart; echoReady = true; waitingEcho = false; }
  }
  portEXIT_CRITICAL_ISR(&echoMux);
}

void showReading() {
  const bool safe = sensorOk && distanceCm > 30;
  const bool caution = sensorOk && distanceCm >= 15 && distanceCm <= 30;
  const bool danger = sensorOk && distanceCm < 15;
  digitalWrite(GREEN_PIN, safe); digitalWrite(YELLOW_PIN, caution); digitalWrite(RED_PIN, danger);
  char line[17];
  lcd.setCursor(0, 0);
  if (sensorOk) { snprintf(line, sizeof(line), "%6.1f cm       ", distanceCm); lcd.print(line); }
  else lcd.print("No sensor data  ");
  lcd.setCursor(0, 1);
  lcd.print(!sensorOk ? "SENSOR ERROR    " : safe ? "SAFE            " : caution ? "CAUTION         " : "DANGER          ");
}

void setup() {
  Serial.begin(115200);
  pinMode(TRIG_PIN, OUTPUT); digitalWrite(TRIG_PIN, LOW);
  pinMode(ECHO_PIN, INPUT);
  pinMode(GREEN_PIN, OUTPUT); pinMode(YELLOW_PIN, OUTPUT); pinMode(RED_PIN, OUTPUT);
  attachInterrupt(digitalPinToInterrupt(ECHO_PIN), echoChanged, CHANGE);
  Wire.begin(SDA_PIN, SCL_PIN); lcd.init(); lcd.backlight(); showReading();
  WiFi.mode(WIFI_STA); WiFi.setAutoReconnect(true); WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  server.on("/distance", HTTP_GET, []() {
    const bool fresh = sensorOk && millis() - lastValid <= 1000;
    server.sendHeader("Cache-Control", "no-store");
    server.send(200, "application/json", fresh ? String("{\"distance_cm\":") + String(distanceCm, 1) + ",\"sensor_ok\":true}" : "{\"distance_cm\":null,\"sensor_ok\":false}");
  });
  server.begin();
}

void loop() {
  server.handleClient();
  const uint32_t now = millis();
  if (WiFi.status() == WL_CONNECTED && !mdnsStarted) {
    mdnsStarted = MDNS.begin("esp32");
    Serial.print("ESP32 address: "); Serial.println(WiFi.localIP());
  }
  if (WiFi.status() != WL_CONNECTED) {
    if (mdnsStarted) { MDNS.end(); mdnsStarted = false; }
    if (now - lastReconnect >= 10000) { lastReconnect = now; WiFi.reconnect(); }
  }
  bool ready, waiting;
  uint32_t width;
  portENTER_CRITICAL(&echoMux);
  ready = echoReady; width = echoWidth; waiting = waitingEcho;
  if (ready) echoReady = false;
  portEXIT_CRITICAL(&echoMux);
  if (ready) {
    distanceCm = roundf((width * 0.0343f / 2.0f) * 10.0f) / 10.0f;
    sensorOk = width > 0 && distanceCm >= 2 && distanceCm <= 400;
    if (sensorOk) lastValid = now;
    showReading();
  } else if (waiting && micros() - triggerMicros > 30000) {
    portENTER_CRITICAL(&echoMux); waitingEcho = false; portEXIT_CRITICAL(&echoMux);
    sensorOk = false; showReading();
  }
  if (now - lastTrigger >= 100) {
    lastTrigger = now;
    portENTER_CRITICAL(&echoMux); echoReady = false; waitingEcho = true; echoStart = micros(); portEXIT_CRITICAL(&echoMux);
    triggerMicros = micros();
    digitalWrite(TRIG_PIN, HIGH); delayMicroseconds(10); digitalWrite(TRIG_PIN, LOW);
  }
}
