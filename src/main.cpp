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
BLEIntCharacteristic testCharacteristic("19B10001-E8F2-537E-4F6C-D104768A1214", BLERead | BLENotify);
BLEIntCharacteristic numberCharacteristic("19B10002-E8F2-537E-4F6C-D104768A1214", BLERead | BLENotify);
BLEIntCharacteristic resultCharacteristic("19B10003-E8F2-537E-4F6C-D104768A1214", BLERead | BLENotify);

using namespace std;

#define SCREEN_WIDTH 128
#define SCREEN_HEIGHT 64

#define  LC_DATA_PIN   4
#define  LC_CLK_PIN    3
#define  BTN_1_PIN     2

#define OLED_RESET     -1
#define I2C_ADDRESS    0x3C  // Most SSD1306 I2C displays use 0x3C

// Constants
constexpr int COMPRESSION_BUTTON_PIN = 2;
constexpr int MODE_BUTTON_PIN = 4;
constexpr int TEST_DURATION = 30000;
constexpr float CALIB_FACTOR = 117.58f;
// Global variables
bool isTrainingMode = true;
vector<unsigned long> compression_times;
unsigned long last_compression = 0;
unsigned long last_mode_button_press = 0;
unsigned long test_start_time = 0;
unsigned long test_button_presses = 0;
constexpr unsigned long MODE_DEBOUNCE = 200;
int len = 0;
float calibrationFactor;

HX711 loadCell;
Adafruit_SSD1306 display(SCREEN_WIDTH, SCREEN_HEIGHT, &Wire, OLED_RESET);

using namespace std;

void setup() {
    //OLED setup
    oledSetup(display, SSD1306_SWITCHCAPVCC, I2C_ADDRESS);

    //bluetooth setup
    BLE.begin();
    BLE.setLocalName("Arduino R4 WiFi");
    BLE.setAdvertisedService(customService);
    customService.addCharacteristic(testCharacteristic);
    customService.addCharacteristic(numberCharacteristic);
    customService.addCharacteristic(resultCharacteristic);
    BLE.addService(customService);
    testCharacteristic.writeValue(0); // Initial value for testing
    numberCharacteristic.writeValue(0); // Initial value for the number
    resultCharacteristic.writeValue(0); // Initial Result

    BLE.advertise();
    Serial.println("BLE Peripheral - Arduino R4 WiFi is now advertising...");
  
    pinMode(COMPRESSION_BUTTON_PIN, INPUT_PULLUP);
    pinMode(MODE_BUTTON_PIN, INPUT_PULLUP);
    pinMode(LED_BUILTIN, OUTPUT);
    compression_times.reserve(SAMPLE_SIZE);
    Serial.begin(9600);
    while (!Serial);
    Serial.println("Starting program...");

    /* TEST hx711 
    loadCell.begin(LC_DATA_PIN, LC_CLK_PIN);
    while (!loadCell.is_ready()) {Serial.println("Load Cell NOT DETECTED!");}
    Serial.println("TARING!");
    delay(3000);
    loadCell.tare();
    delay(500);

    loadCell.set_scale(CALIB_FACTOR);
    // END TEST HX711

    // OLED DISPLAY
    clearOled(display);
    delay(50);
    setText(display, "Hello World!");
    display.display();
    delay(100);
    // END OLED DISPLAY
    */
}

void checkModeButton() {
    unsigned long current_time = millis();
    if (!digitalRead(MODE_BUTTON_PIN) && (current_time - last_mode_button_press > MODE_DEBOUNCE)) {
        last_mode_button_press = current_time;
        isTrainingMode = !isTrainingMode;
        
        compression_times.clear();  // Clear history on mode switch

        if (isTrainingMode) {
            Serial.println("Switched to Training Mode");
        } else {
            Serial.println("Switched to Testing Mode");
            test_start_time = millis() + 3000;
            test_button_presses = 0;
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
                Serial.println("Too Fast!");
                clearOled(display);
                delay(50);
                setText(display, "Too Fast!");
                delay(50);
                display.display();
            } else if (avg_bpm < MIN_BPM) {
                Serial.println("Too Slow!");
                clearOled(display);
                delay(50);
                setText(display, "Too Slow!");
                delay(50);
                display.display();
            }
        }
    }
    return avg_bpm;
}

float handleTestingMode(bool& shouldSwitchToTraining, float& accuracy, float& consistency) {
    unsigned long current_time = millis();
    unsigned long elapsed_time = current_time - test_start_time;

    if (elapsed_time >= TEST_DURATION) {
        float avg_bpm = 0;

        if (compression_times.size() >= 2) {
            avg_bpm = calculateWeightedAverageBPM(compression_times, compression_times.size());  // Use full history
            float std_dev = calculateBPMStandardDeviation(compression_times, compression_times.size());

            // Accuracy = closeness to target
            accuracy = max(0.0f, 1.0f - fabs(avg_bpm - TARGET_BPM) / TARGET_BPM);  // 0–1 score

            // Consistency = inverse of std dev
            consistency = max(0.0f, 1.0f - std_dev / MAX_STD_DEV);  // 0–1 score

            Serial.print("Test Complete. Avg BPM: ");
            Serial.print(avg_bpm);
            Serial.print(" | Accuracy: ");
            Serial.print(accuracy);
            Serial.print(" | Consistency: ");
            Serial.println(consistency);
        }

        compression_times.clear();  // Reset for next session
        shouldSwitchToTraining = true;
        return avg_bpm;
    } else {
        int remaining_seconds = (TEST_DURATION - elapsed_time) / 1000;
        Serial.print("Time remaining: ");
        Serial.print(remaining_seconds);
        Serial.println(" seconds");
        return 0;
    }
    
}


void loop() {

    /* 
    //testing hx711 (delete later on)
    float load = measureLoadCell(loadCell, LC_DATA_PIN, LC_CLK_PIN);
    Serial.print("Load: ");
    Serial.println(load);
    delay(1000);
   // END OF TESTING HX711 
   */
  
    bool oldTraining = isTrainingMode;
    checkModeButton();
    if (oldTraining != isTrainingMode){
      testCharacteristic.writeValue(1); // start test
      for (int i = 0; i < 5; i++) {
              numberCharacteristic.writeValue(0);
              delay(600);
          }
    }
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
    // Time-based decay logic — reset BPM and clear history if idle too long
    const unsigned long DECAY_THRESHOLD = 3000; // 3 seconds
    if (millis() - last_compression > DECAY_THRESHOLD && !compression_times.empty()) {
        Serial.println("No compressions detected for 3 seconds. Resetting...");
        compression_times.clear();  // Clear for new set
        last_compression = millis(); // Avoid repeated clearing
        if (central && central.connected()) {
            numberCharacteristic.writeValue(0); // Send BPM = 0 over BLE
        }
    }
    
    if (isTrainingMode) {
        float avg_bpm = handleTrainingMode();
        if (central.connected() && pressed) {
            numberCharacteristic.writeValue(avg_bpm);
        }
    } else {
        static bool waitingToSwitch = false;
        static unsigned long testEndTime = 0;
        bool switchToTraining = false;
        float accuracy = 0.0, consistency = 0.0;
        float test_avg_bpm = handleTestingMode(switchToTraining, accuracy, consistency);

        if (switchToTraining && !waitingToSwitch) {
            // Send results once
            if (central && central.connected()) {
                delay(2000);
                resultCharacteristic.writeValue(test_avg_bpm); // You can add new BLECharacteristics for accuracy & consistency if needed
                Serial.println("Sent test results to Flutter app.");
            }

            waitingToSwitch = true;
            testEndTime = millis();
        }

        if (waitingToSwitch && millis() - testEndTime > 2000) {  // 2 second pause
            isTrainingMode = true;
            waitingToSwitch = false;
            Serial.println("Auto-switched back to Training Mode.");
        }

      }
}


