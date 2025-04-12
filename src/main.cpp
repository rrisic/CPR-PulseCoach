#include <vector>
#include <Arduino.h>
#include <Wire.h>


#include "setup.h"
#include "loop.h"


using namespace std;

int oldest_val = 0;
vector<int> last_five;

#define SCREEN_WIDTH 128
#define SCREEN_HEIGHT 64

#define  LC_DATA_PIN   3
#define  LC_CLK_PIN    7
#define  BTN_1_PIN     2

-1 = no reset pin
#define OLED_RESET     -1
#define I2C_ADDRESS    0x3C  // Most SSD1306 I2C displays use 0x3C

int len = 0;
float calibrationFactor;

HX711 loadCell;
Adafruit_SSD1306 display(SCREEN_WIDTH, SCREEN_HEIGHT, &Wire, OLED_RESET);

void setup() {
    Serial.begin(9600);

    calibrationFactor = loadCellCalibrate(loadCell, LC_DATA_PIN, LC_CLK_PIN, BTN_1_PIN, 1.0);
  
}

void loop() {
    int time = millis();
    float force;

    force = measureLoadCell(loadCell, LC_DATA_PIN, LC_CLK_PIN);
    Serial.println(force);
    delay(200);
}


// void setup() {
//   Serial.begin(9600);
//   while (!Serial);

//   Serial.println("Initializing SSD1306...");

//   if (!display.begin(SSD1306_SWITCHCAPVCC, I2C_ADDRESS)) {
//     Serial.println("SSD1306 allocation failed");
//     while (true);  // Stay here forever
//   }

//   display.clearDisplay();
//   display.setTextSize(1);
//   display.setTextColor(SSD1306_WHITE);
//   display.setCursor(0, 0);
//   display.println("Hello, SSD1306!");
//   display.display();

//   delay(2000);
//   display.println("User 1");
//   display.display();
//   delay(2000);
// }

// void loop() {}