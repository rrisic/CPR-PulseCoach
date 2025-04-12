#ifndef BPM_HELPER_H
#define BPM_HELPER_H

#include <vector>
#include <cmath>
#include <Arduino.h>

// Constants
const int TARGET_BPM = 103;
const int MIN_BPM = 90;
const int MAX_BPM = 116;
const int SAMPLE_SIZE = 10;
const float MAX_STD_DEV = 15.0;
const float MIN_CONSISTENCY = 0.5;

// Helper function to calculate standard deviation of BPMs
float calculateBPMStandardDeviation(const std::vector<unsigned long>& times, int last_n = 5) {
    int size = times.size();
    if (size < 2) return 0.0;

    std::vector<float> bpms;
    for (int i = std::max(1, size - last_n); i < size; i++) {
        float interval = times[i] - times[i - 1];
        if (interval > 0) {
            bpms.push_back(60000.0 / interval);
        }
    }

    float mean = 0.0;
    for (float bpm : bpms) mean += bpm;
    mean /= bpms.size();

    float variance = 0.0;
    for (float bpm : bpms) variance += (bpm - mean) * (bpm - mean);
    variance /= bpms.size();

    return sqrt(variance);
}

// Helper function to calculate weighted average BPM
float calculateWeightedAverageBPM(const std::vector<unsigned long>& times, int last_n = 5) {
    int size = times.size();
    if (size < 2) return 0.0;

    std::vector<float> bpms;
    for (int i = std::max(1, size - last_n); i < size; i++) {
        float interval = times[i] - times[i - 1];
        if (interval > 0) {
            bpms.push_back(60000.0 / interval);
        }
    }

    float total_weight = 0.0;
    float weighted_sum = 0.0;
    for (size_t i = 0; i < bpms.size(); i++) {
        float weight = static_cast<float>(i + 1) / bpms.size();
        weighted_sum += bpms[i] * weight;
        total_weight += weight;
    }

    return weighted_sum / total_weight;
}

// Helper function to check compression consistency
bool isConsistentCompression(const std::vector<unsigned long>& times) {
    if (times.size() < 2) return false;
    
    float std_dev = calculateBPMStandardDeviation(times);
    float avg_bpm = calculateWeightedAverageBPM(times);
    
    // Calculate consistency ratio (1.0 = perfect consistency)
    float consistency = 1.0 - (std_dev / MAX_STD_DEV);
    Serial.print("Consistency: ");
    Serial.println(consistency);
    
    // Check if both the average and consistency are within acceptable ranges
    return (consistency >= MIN_CONSISTENCY);
}

#endif // BPM_HELPER_H 