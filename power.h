#ifndef POWER_H
#define POWER_H

#define BUFFER_SIZE 100000

#include "utilities.h"
#include <stdio.h>
#include <stdlib.h>
#include <fcntl.h>
#include <time.h>
#include <string.h>
#include <sys/time.h>
#include <pthread.h>
#include <errno.h>
#include <unistd.h>

enum state_t {
  INIT,
  RUNNING,
  HALTED
};

extern int NUM_PWR_CHANNELS; 
extern double curr_pwr[10];
void start_power();
void power_cleanup();
#endif
