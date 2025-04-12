#include <vector>
#include <Arduino.h>
#include "../include/song_setup.h"
#include "../include/bpm_helper.h"

using namespace std;

// Constants
const int COMPRESSION_BUTTON_PIN = 2;
const int MODE_BUTTON_PIN = 4;
const int TEST_DURATION = 30000;

// Global variables
bool isTrainingMode = true;
vector<unsigned long> compression_times;
unsigned long last_compression = 0;
unsigned long last_mode_button_press = 0;
unsigned long test_start_time = 0;
const unsigned long MODE_DEBOUNCE = 200;

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

void handleTrainingMode() {
    if (compression_times.size() >= 2) {
        float avg_bpm = calculateWeightedAverageBPM(compression_times);
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
            } else if (avg_bpm > MAX_BPM) {
                Serial.println("Too fast!");
            } else if (avg_bpm < MIN_BPM) {
                Serial.println("Too slow!");
            }
        }
    }
}

void handleTestingMode() {
    unsigned long current_time = millis();
    unsigned long elapsed_time = current_time - test_start_time;
    
    if (elapsed_time >= TEST_DURATION) {
        if (compression_times.size() >= 2) {
            float avg_bpm = calculateWeightedAverageBPM(compression_times);
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
}

void loop() {
    checkModeButton();
    
    if (!digitalRead(COMPRESSION_BUTTON_PIN)) {
        unsigned long current_time = millis();
        while(!digitalRead(COMPRESSION_BUTTON_PIN));
        
        if (compression_times.size() >= SAMPLE_SIZE) {
            compression_times.erase(compression_times.begin());
        }
        compression_times.push_back(current_time);
    }
    
    if (isTrainingMode) {
        handleTrainingMode();
    } else {
        handleTestingMode();
    }
}
