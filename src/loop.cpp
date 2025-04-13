#include "loop.h"

float measureLoadCell(HX711 &loadCell, const int dataPin, const int clkPin)
{
    constexpr int NUM_SAMPLES = 3;
    constexpr int G_PER_KG = 1000;
    float load = 0.0f;
    delay(50);

    // .get_units() averages n number of readings in grams
    load = loadCell.get_units(NUM_SAMPLES);

    if (Serial)
    {
        Serial.print("LoadCell: AVG LOAD MEASUREMENT: ");
        Serial.println(load);
    }
    delay(10);

    return load;
}

void clearOled(Adafruit_SSD1306 &display)
{
    display.clearDisplay();
    display.setCursor(0, 0);
}

void setText(Adafruit_SSD1306 &display, const char *message, int textSize, int color, int x, int y)
{
    display.setTextSize(textSize);
    display.setTextColor(color);
    display.setCursor(x, y);
    display.println(message);
    // display.display();
}


