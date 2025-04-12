#include <Vector.h>

int oldest_val = 0;
Vector<int> last_five;
int size = 0;

void setup() {
    pinMode(2, OUTPUT);
    pinMode(3, INPUT);
    pinMode(LED_BUILTIN, OUTPUT);
}

void loop() {
    int time = millis();
    if (1) { // Replace with bpm beat sensor
        int new_time = millis();
        if (size == 5) {
            last_five[oldest_val] = new_time;
            oldest_val = (oldest_val + 1) % 5;
        } else {
            last_five[size] = new_time;
            size++;
        }

        int last5_avg = (last_five[oldest_val] - last_five[(oldest_val + 1) % 5]) / 4;
        if (100 < (60000 / last5_avg) && 120 > (60000 / last5_avg)) {
            digitalWrite(LED_BUILTIN, LOW);
        } else {
            digitalWrite(LED_BUILTIN, HIGH);
        }
    }
}
