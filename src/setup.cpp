#include "setup.h"
#include <Arduino.h>
#include <HX711.h>

void buttonSetup(const int pinNum)
{
    if (Serial)
        Serial.println("Settting up button");

    pinMode(pinNum, INPUT_PULLUP);
}

/* UNUSED FUNCTION. DO NOT USE. CALIBRATION HAS BEEN RUN PRIOR TO CODING THIS */
float loadCellCalibrate(HX711 &loadCell, const int dataPin, const int clkPin, const int btnPin, const float knownWeight)
{
    // Number of weight samples averaged per reading
    constexpr int NUM_SAMPLES = 10;
    // Weight precision (round to n decimal places)
    constexpr int G_PER_KG    = 1000;

    if (Serial) Serial.println("Calibrating Load Cell Sensor");

    loadCell.begin(dataPin, clkPin);
    loadCell.set_scale();
    loadCell.tare();

    delay(100);
    if (Serial)
        Serial.println("Calibrate the scale. Provide weight in serial. (Press button when ready)");

    // wait until button press
    // while (digitalRead(btnPin) != LOW);

    bool loadCellConnected = loadCell.is_ready();
    float weight;

    float calibrationFactor;
    if (loadCellConnected) 
    {
        Serial.println("Referencing Weight");
        // .get_units() averages n number of readings in grams
        weight = loadCell.get_units(NUM_SAMPLES) / G_PER_KG;
        calibrationFactor = weight / knownWeight;

        delay(50);
        if (Serial) 
        {
            Serial.print("Raw Weight: ");
            Serial.println(weight);
            Serial.print("Calibration Factor: ");
            Serial.println(calibrationFactor);
        }
    } 
    loadCell.set_scale(calibrationFactor);
    delay(50);
    return calibrationFactor;
}

bool oledSetup(Adafruit_SSD1306 &display, const int SSD1306, const int i2cAddress)
{
    if (!display.begin(SSD1306, i2cAddress)) {
        if (Serial) Serial.println("SSD1306 allocation failed");
        delay(20);
        return false;
    }
    if (Serial) Serial.println("Found OLED!");    
    return true;   
}


