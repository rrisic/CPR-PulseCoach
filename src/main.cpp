#include <vector>
#include <Arduino.h>
#include "../include/song_setup.h"
#include <iostream>

using namespace std;

// Constants
const int TARGET_BPM = 103;
const int MIN_BPM = 90;
const int MAX_BPM = 116;
const int SAMPLE_SIZE = 5;
const int COMPRESSION_BUTTON_PIN = 2;
const int MODE_BUTTON_PIN = 4;
const int TEST_DURATION = 30000;  // 2 minutes in milliseconds

// Global variables
bool isTrainingMode = true;  // true = Training, false = Testing
vector<unsigned long> compression_times;
unsigned long last_compression = 0;
unsigned long last_mode_button_press = 0;
unsigned long test_start_time = 0;
const unsigned long MODE_DEBOUNCE = 200;  // Debounce time in ms

void setup() {
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
        isTrainingMode = !isTrainingMode;  // Toggle between modes
        
        // Clear compression history when switching modes
        compression_times.clear();
        
        if (isTrainingMode) {
            Serial.println("Switched to Training Mode");
        } else {
            Serial.println("Switched to Testing Mode");
            test_start_time = millis();  // Start test timer
        }
    }
}

void handleTrainingMode() {
    if (compression_times.size() >= 2) {
        float avg_interval = compression_times[compression_times.size() - 1] - compression_times[0];
        avg_interval /= (compression_times.size() - 1);
        
        int current_bpm = 60000 / avg_interval;
        Serial.print("Current BPM: ");
        Serial.println(current_bpm);

        // LED feedback
        if (current_bpm >= MIN_BPM && current_bpm <= MAX_BPM) {
            digitalWrite(LED_BUILTIN, HIGH);
        } else if (current_bpm > MAX_BPM) {
            digitalWrite(LED_BUILTIN, LOW);
        } else if (current_bpm < MIN_BPM) {
            digitalWrite(LED_BUILTIN, LOW);
        } else {
            Serial.println("Error reading BPM from compression button");
        }
        
        // TODO: Add OLED feedback here
        // Display BPM and "Too Slow/Too Fast/Good Rate" messages
    }
}

void handleTestingMode() {
    unsigned long current_time = millis();
    unsigned long elapsed_time = current_time - test_start_time;
    
    // Check if test duration is complete
    if (elapsed_time >= TEST_DURATION) {
        // Calculate final statistics
        if (compression_times.size() >= 2) {
            float avg_interval = compression_times[compression_times.size() - 1] - compression_times[0];
            avg_interval /= (compression_times.size() - 1);
            int average_bpm = 60000 / avg_interval;
            
            // TODO: Send data to phone app via Bluetooth
            Serial.print("Test Complete. Average BPM: ");
            Serial.println(average_bpm);
            
            // Reset for next test
            compression_times.clear();
            test_start_time = millis();
        }
    } else {
        // Display remaining time on OLED
        int remaining_seconds = (TEST_DURATION - elapsed_time) / 1000;
        Serial.print("Time remaining: ");
        Serial.print(remaining_seconds);
        Serial.println(" seconds");
    }
}

void loop() {
    // Check for mode switch
    checkModeButton();
    
    // Handle compression button press
    if (!digitalRead(COMPRESSION_BUTTON_PIN)) {
        unsigned long current_time = millis();
        while(!digitalRead(COMPRESSION_BUTTON_PIN));
        
        if (compression_times.size() >= SAMPLE_SIZE) {
            compression_times.erase(compression_times.begin());
        }
        compression_times.push_back(current_time);
    }
    
    // Handle current mode
    if (isTrainingMode) {
        handleTrainingMode();
    } else {
        handleTestingMode();
    }
}
