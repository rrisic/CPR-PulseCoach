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
const float MIN_CONSISTENCY = 0.8;

// Helper function to calculate standard deviation of BPMs
float calculateBPMStandardDeviation(const std::vector<unsigned long>& times) {
    if (times.size() < 2) return 0.0;
    
    std::vector<float> bpms;
    for (size_t i = 1; i < times.size(); i++) {
        float interval = times[i] - times[i-1];
        bpms.push_back(60000.0 / interval);
    }
    
    float sum = 0.0;
    for (float bpm : bpms) {
        sum += bpm;
    }
    float mean = sum / bpms.size();
    
    float sum_squared_diff = 0.0;
    for (float bpm : bpms) {
        sum_squared_diff += (bpm - mean) * (bpm - mean);
    }
    
    return sqrt(sum_squared_diff / bpms.size());
}

// Helper function to calculate weighted average BPM
float calculateWeightedAverageBPM(const std::vector<unsigned long>& times) {
    if (times.size() < 2) return 0.0;
    
    float total_weight = 0.0;
    float weighted_sum = 0.0;
    
    // Give more weight to recent compressions
    for (size_t i = 1; i < times.size(); i++) {
        float weight = static_cast<float>(i) / times.size();  // Linear weighting
        float interval = times[i] - times[i-1];
        float bpm = 60000.0 / interval;
        
        weighted_sum += bpm * weight;
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
    
    // Check if both the average and consistency are within acceptable ranges
    return (consistency >= MIN_CONSISTENCY) && 
           (avg_bpm >= MIN_BPM) && 
           (avg_bpm <= MAX_BPM);
}

#endif // BPM_HELPER_H 