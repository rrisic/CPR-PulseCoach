#include <vector>
#include <Arduino.h>
#include <ArduinoBLE.h>
#include <Wire.h>
#include "setup.h"
#include "loop.h"

#include "../include/song_setup.h"
#include "../include/bpm_helper.h"

// bluetooth service
BLEService customService("19B10000-E8F2-537E-4F6C-D104768A1214");
BLEByteCharacteristic ledCharacteristic("19B10001-E8F2-537E-4F6C-D104768A1214", BLERead | BLEWrite);
BLEIntCharacteristic numberCharacteristic("19B10002-E8F2-537E-4F6C-D104768A1214", BLERead | BLENotify);

using namespace std;

#define SCREEN_WIDTH 128
#define SCREEN_HEIGHT 64

#define  LC_DATA_PIN   3
#define  LC_CLK_PIN    7
#define  BTN_1_PIN     2

#define OLED_RESET     -1
#define I2C_ADDRESS    0x3C  // Most SSD1306 I2C displays use 0x3C

// Constants
constexpr int COMPRESSION_BUTTON_PIN = 2;
constexpr int MODE_BUTTON_PIN = 4;
constexpr int TEST_DURATION = 30000;

// Global variables
bool isTrainingMode = true;
vector<unsigned long> compression_times;
unsigned long last_compression = 0;
unsigned long last_mode_button_press = 0;
unsigned long test_start_time = 0;
constexpr unsigned long MODE_DEBOUNCE = 200;
int len = 0;
float calibrationFactor;

HX711 loadCell;
Adafruit_SSD1306 display(SCREEN_WIDTH, SCREEN_HEIGHT, &Wire, OLED_RESET);

using namespace std;

void setup() {
    //bluetooth setup
    BLE.begin();
    BLE.setLocalName("Arduino R4 WiFi");
    BLE.setAdvertisedService(customService);
    customService.addCharacteristic(ledCharacteristic);
    customService.addCharacteristic(numberCharacteristic);
    BLE.addService(customService);
    ledCharacteristic.writeValue(0); // Initial value for LED
    numberCharacteristic.writeValue(0); // Initial value for the number

    BLE.advertise();
    Serial.println("BLE Peripheral - Arduino R4 WiFi is now advertising...");

    pinMode(COMPRESSION_BUTTON_PIN, INPUT_PULLUP);
    pinMode(MODE_BUTTON_PIN, INPUT_PULLUP);
    pinMode(LED_BUILTIN, OUTPUT);
    compression_times.reserve(SAMPLE_SIZE);
    Serial.begin(9600);
    while (!Serial);
    Serial.println("Starting program...");
}

void checkModeButton() {
    unsigned long current_time = millis();
    if (!digitalRead(MODE_BUTTON_PIN) && (current_time - last_mode_button_press > MODE_DEBOUNCE)) {
        last_mode_button_press = current_time;
        isTrainingMode = !isTrainingMode;
        compression_times.clear();
        
        if (isTrainingMode) {
            Serial.println("Switched to Training Mode");
        } else {
            Serial.println("Switched to Testing Mode");
            test_start_time = millis();
        }
    }
}

float handleTrainingMode() {
    float avg_bpm = 0;
    if (compression_times.size() >= 2) {
        avg_bpm = calculateWeightedAverageBPM(compression_times);
        float std_dev = calculateBPMStandardDeviation(compression_times);
        bool is_consistent = isConsistentCompression(compression_times);
        
        Serial.print("Current BPM: ");
        Serial.print(avg_bpm);
        Serial.print(" (Std Dev: ");
        Serial.print(std_dev);
        Serial.println(")");

        if (is_consistent && avg_bpm >= MIN_BPM && avg_bpm <= MAX_BPM) {
            digitalWrite(LED_BUILTIN, HIGH);
            Serial.println("Good compression rate and consistency!");
        } else {
            digitalWrite(LED_BUILTIN, LOW);
            if (!is_consistent) {
                Serial.println("Compression rate too inconsistent!");
            }
            if (avg_bpm > MAX_BPM) {
                Serial.println("Too fast!");
            } else if (avg_bpm < MIN_BPM) {
                Serial.println("Too slow!");
            }
        }
    }
    return avg_bpm;
}

float handleTestingMode() {
    unsigned long current_time = millis();
    unsigned long elapsed_time = current_time - test_start_time;
    float avg_bpm = 0;
    if (elapsed_time >= TEST_DURATION) {
        if (compression_times.size() >= 2) {
            avg_bpm = calculateWeightedAverageBPM(compression_times);
            float std_dev = calculateBPMStandardDeviation(compression_times);
            bool is_consistent = isConsistentCompression(compression_times);
            
            Serial.print("Test Complete. Average BPM: ");
            Serial.print(avg_bpm);
            Serial.print(" (Std Dev: ");
            Serial.print(std_dev);
            Serial.print(") - ");
            Serial.println(is_consistent ? "Consistent" : "Inconsistent");
            
            compression_times.clear();
            test_start_time = millis();
        }
    } else {
        int remaining_seconds = (TEST_DURATION - elapsed_time) / 1000;
        Serial.print("Time remaining: ");
        Serial.print(remaining_seconds);
        Serial.println(" seconds");
    }
    return avg_bpm;
}

void loop() {
    checkModeButton();
    char pressed = 0;
    BLEDevice central = BLE.central();
    if (central) {
        Serial.print("Connected to central: ");
        Serial.println(central.address());
    }

    if (!digitalRead(COMPRESSION_BUTTON_PIN)) {
        pressed = 1;
        unsigned long current_time = millis();
        while(!digitalRead(COMPRESSION_BUTTON_PIN));

        // Add new timestamp only if it's a valid press
        if (compression_times.size() >= SAMPLE_SIZE) {
            compression_times.erase(compression_times.begin());
        }
        compression_times.push_back(current_time);
        last_compression = current_time;
    }
    // Time-based decay logic
    const unsigned long DECAY_THRESHOLD = 2000; // 2 seconds without compression
    if (millis() - last_compression > DECAY_THRESHOLD && compression_times.size() > 0) {
        compression_times.erase(compression_times.begin());
    }
    
    float avg_bpm = 0;
    if (isTrainingMode) {
        avg_bpm = handleTrainingMode();
    } else {
        avg_bpm = handleTestingMode();
    }
    if (central.connected() && pressed) {
        numberCharacteristic.writeValue(avg_bpm);
    }
}


