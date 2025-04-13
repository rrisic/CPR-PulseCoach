#include "loop.h"

float measureLoadCell(HX711 &loadCell, const int dataPin, const int clkPin)
{
    constexpr int NUM_SAMPLES = 3;
    constexpr int G_PER_KG = 1000;
    float load = 0.0f;
    // delay(5);

    // .get_units() averages n number of readings in grams
    load = loadCell.get_units();

    // if (Serial)
    // {
    //     Serial.print("LoadCell: AVG LOAD MEASUREMENT: ");
    //     Serial.println(load);
    // }
    // delay(5);

    return load;
}

void clearOled(Adafruit_SSD1306 &display)
{
    display.clearDisplay();
    display.setCursor(0, 0);
}

void setStackedText(Adafruit_SSD1306 &display, const char *line1, const char *line2, int textSize, int color)
{
    display.setTextSize(textSize);
    display.setTextColor(color);

    // Measure both lines
    int16_t x1, y1;
    uint16_t w1, h1;
    uint16_t w2, h2;

    display.getTextBounds(line1, 0, 0, &x1, &y1, &w1, &h1);
    display.getTextBounds(line2, 0, 0, &x1, &y1, &w2, &h2);

    // Determine tallest height
    int totalHeight = h1 + h2 + 2; // add spacing between lines
    int yStart = (display.height() - totalHeight) / 2;

    // Line 1 (top word)
    int x1_pos = (display.width() - w1) / 2;
    display.setCursor(x1_pos, yStart);
    display.println(line1);

    // Line 2 (bottom word)
    int x2_pos = (display.width() - w2) / 2;
    display.setCursor(x2_pos, yStart + h1 + 2); // +2 for spacing
    display.println(line2);
}



