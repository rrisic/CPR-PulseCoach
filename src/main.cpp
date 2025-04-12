#include <vector>
#include <Arduino.h>
#include "setup.h"

using namespace std;

int oldest_val = 0;
vector<int> last_five;

#define  LC_DATA_PIN   3
#define  LC_CLK_PIN    7
#define  BTN_1_PIN     2

int len = 0;
float calibrationFactor;

HX711 loadCell;
void setup() {
    Serial.begin(9600);

    calibrationFactor = loadCellCalibrate(loadCell, LC_DATA_PIN, LC_CLK_PIN, BTN_1_PIN, 1.0);
  
}

void loop() {
    int time = millis();
    

}
