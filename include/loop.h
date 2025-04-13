#ifndef LOOP_H
#define LOOP_H

#include <HX711.h>
#include <Arduino.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>

float measureLoadCell(HX711 &loadCell, const int dataPin, const int clkPin);

void clearOled(Adafruit_SSD1306 &display);

void setStackedText(Adafruit_SSD1306 &display, const char *line1, const char *line2, int textSize, int color);

#endif