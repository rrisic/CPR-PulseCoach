#ifndef SETUP_H
#define SETUP_H

#include <HX711.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>

void buttonSetup(const int pinNum);

float loadCellCalibrate(HX711 loadCell, const int dataPin, const int clkPin, const int btnPin, const float knownWeight);

bool oledSetup(Adafruit_SSD1306 display, const int SSD1306, const int i2cAddress);

#endif