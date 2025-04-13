#include "setup.h"
#include <Arduino.h>
#include <HX711.h>

void buttonSetup(const int pinNum)
{
    if (Serial)
        Serial.println("Settting up button");

    pinMode(pinNum, INPUT_PULLUP);
}

bool oledSetup(Adafruit_SSD1306 display, const int SSD1306, const int i2cAddress)
{
    if (!display.begin(SSD1306, i2cAddress)) {
        if (Serial) Serial.println("SSD1306 allocation failed");
            delay(20);
            return false;
    }
    if (Serial) Serial.println("Found OLED!");    
    return true;   
}


