#include <vector>
#include <Arduino.h>
#include "../include/tetris_song.h"
#include <iostream>
using namespace std;

const int TARGET_BPM = 103;
const int MIN_BPM = 90;
const int MAX_BPM = 116;
const int SAMPLE_SIZE = 5;  // Number of samples to average
const int SPEAKER_PIN = 3;  // Connect speaker to pin 3

vector<unsigned long> compression_times;
unsigned long last_compression = 0;

void setup() {
    pinMode(2, INPUT_PULLUP);
    pinMode(LED_BUILTIN, OUTPUT);
    //pinMode(SPEAKER_PIN, OUTPUT);
    compression_times.reserve(SAMPLE_SIZE);
    Serial.begin(9600);  // Start serial at 9600 baud
    // Wait for Serial to connect (optional, helpful for boards like Leonardo or R4 WiFi)
    while (!Serial);

    Serial.println("Starting program...");
}

void loop() {
    // Play tone on button press
    //tone(SPEAKER_PIN, 1000, 5000);
    //delay(100);
    //tetris(SPEAKER_PIN, TARGET_BPM);
    
    // Calculate BPM if we have enough samples
    if (compression_times.size() >= 2) {
        // Calculate average interval between compressions
        float avg_interval = compression_times[compression_times.size() - 1] - compression_times[0];
        avg_interval /= (compression_times.size() - 1);
        
        // Convert to BPM (60000ms per minute)
        int current_bpm = 60000 / avg_interval;
        //while (digitalRead(2)) {delay(50);}
        Serial.print(current_bpm);
        Serial.println();

        // Check if BPM is within target range
        if (current_bpm >= MIN_BPM && current_bpm <= MAX_BPM) {
            digitalWrite(LED_BUILTIN, HIGH);
        } else {
            digitalWrite(LED_BUILTIN, LOW);
        }
    }
    if (!digitalRead(2)) {
        unsigned long current_time = millis();
        while(!digitalRead(2));

        last_compression = current_time;
        
        // Add new compression time
        if (compression_times.size() >= SAMPLE_SIZE) {
            compression_times.erase(compression_times.begin());
        }
        compression_times.push_back(current_time);
        delay(50);
    }
    
    
}
