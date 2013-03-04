//Dependency: libsensors4-dev
#ifndef TEMPERATURE_H
#define TEMPERATURE_H
#include <sensors/sensors.h>

#define NUM_FANS 2

//A list of sensors_chip_names, one per available
//input temperature sensor. There is typically one per
//core.
const sensors_chip_name **core_chip_names;

//A list of subfeature numbers, one per available
//input temperature sensor. There is typically one per
//core.
int *core_subfeature_numbers;
int num_cores;

int temp_init();
void temp_cleanup();
int temp_read(int core, double *temperature);
void fan_read(int num, double *speed);
#endif
