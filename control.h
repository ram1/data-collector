#pragma once
/*
Parameters
-CONTROL_INTERVAL is defined as a multiple of INTERVAL [ms], which is a constant
in data_collector.c. If data is collected every 1000 [ms], 
control decisions may happen every 10000 [ms], for example. In this
case, CONTROL_INTERVAL would be 10. It should be a positive integer.
TODO Put a check in code on the restrictions.


*/
#include "data_collector.h"

#define CONTROL_ENABLE
#define CONTROL_NUM_PARAMS 9
typedef struct control_info {
	double ts[NUM_CORES];
	double ptec;
	double pcpu;
} control_info_t;

typedef struct control_parameters {
	int interval;
	float tmax;
	float pmax;
	float imin;
	float imax;
	float fstep;
	float istep;
	float t_hyst;
	float p_hyst;
} control_parameters_t;

void control_test(double t);
void control_simple(control_info_t info);



