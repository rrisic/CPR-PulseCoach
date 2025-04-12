#ifndef SETUP_H
#define SETUP_H
#include <HX711.h>

void buttonSetup(int pinNum);

float loadCellCalibrate(HX711 loadCell, const int dataPin, const int clkPin, const int btnPin, const float knownWeight);

#endif