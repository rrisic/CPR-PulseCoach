#ifndef LOOP_H
#define LOOP_H

#include <HX711.h>
#include <Arduino.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>

float measureLoadCell(HX711 &loadCell, const int dataPin, const int clkPin);

void clearOled(Adafruit_SSD1306 &display);

void setText(Adafruit_SSD1306 &display, const char* message, int textSize=1, int color=SSD1306_WHITE, int x=0, int y=0);

#endif