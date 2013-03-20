#ifndef POWER_H
#define POWER_H

#define BUFFER_SIZE 100000

#include "utilities.h"

enum state_t {
  INIT,
  RUNNING,
  HALTED,
  TERMINATED
};

extern int NUM_PWR_CHANNELS; 
extern double curr_pwr[10];
void start_power();
void power_cleanup();
#endif
