#pragma once
/*
Parameters
-CONTROL_INTERVAL is defined as a multiple of INTERVAL [ms], which is a constant
in data_collector.c. If data is collected every 1000 [ms], 
control decisions may happen every 10000 [ms], for example. In this
case, CONTROL_INTERVAL would be 10. It should be a positive integer.
TODO Put a check in code on the restrictions.


*/

#define CONTROL_ENABLE
#define CONTROL_INTERVAL 10
void control_test(double t);


