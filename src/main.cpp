#include <vector>
#include <Arduino.h>
#include "../include/tetris_song.h"
using namespace std;

const int TARGET_BPM = 103;
const int MIN_BPM = 90;
const int MAX_BPM = 116;
const int SAMPLE_SIZE = 5;  // Number of samples to average
const int SPEAKER_PIN = 3;  // Connect speaker to pin 3

vector<unsigned long> compression_times;
unsigned long last_compression = 0;

void setup() {
    //pinMode(2, INPUT_PULLUP);
    //pinMode(LED_BUILTIN, OUTPUT);
    pinMode(SPEAKER_PIN, OUTPUT);
    compression_times.reserve(SAMPLE_SIZE);
}

void loop() {
    // Play tone on button press
    tone(SPEAKER_PIN, 1000, 5000);
    delay(100);
    //tetris();
    /*
    if (!digitalRead(2)) {
        unsigned long current_time = millis();
        
        // Debounce check - ignore presses less than 100ms apart
        if (current_time - last_compression < 100) {
            return;
        }
        
        last_compression = current_time;
        
        // Add new compression time
        if (compression_times.size() >= SAMPLE_SIZE) {
            compression_times.erase(compression_times.begin());
        }
        compression_times.push_back(current_time);
        
        // Calculate BPM if we have enough samples
        if (compression_times.size() >= 2) {
            // Calculate average interval between compressions
            float avg_interval = 0;
            for (size_t i = 1; i < compression_times.size(); i++) {
                avg_interval += compression_times[i] - compression_times[i-1];
            }
            avg_interval /= (compression_times.size() - 1);
            
            // Convert to BPM (60000ms per minute)
            int current_bpm = 60000 / avg_interval;
            
            // Check if BPM is within target range
            if (current_bpm >= MIN_BPM && current_bpm <= MAX_BPM) {
                digitalWrite(LED_BUILTIN, HIGH);
            } else {
                digitalWrite(LED_BUILTIN, LOW);
            }
        }
    
    }
    */
}
