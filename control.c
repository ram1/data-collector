#include "control.h"
#include "temperature.h"
#include "pws.h"
#include "utilities.h"
#include <unistd.h>
#include <errno.h>


//##Variables##
const double FREQ_MIN = 1.6;
const double FREQ_MAX = 2.8;

//##Functions##
int set_cpu_freq(double f_ghz);


void control_test(double t) {
	int i;
	if(t > 50) {
		set_cpu_freq(1.6);
		for(i = 0; i < NUM_PWS_CHANNELS; i++) 
			pws_i_control[i] = 3.0;
	} else {
		set_cpu_freq(2.8);
		for(i = 0; i < NUM_PWS_CHANNELS; i++) 
			pws_i_control[i] = 0.3;
	}

}

/*
@return 1 on sucess, 0 on failure
@input
	f_ghz This should be the nominal frequency to 
	set to. Do not include any corrections (+/- 0.05).
*/
int set_cpu_freq(double f_ghz) {
	if(f_ghz < FREQ_MIN || f_ghz > FREQ_MAX)
		return 0;

	//cpufreq-set works more consistently 
	//if it receives frequencies like 2.75 rather than
	//2.8
	f_ghz -= 0.05; 

	int i;
	for(i = 0; i < num_cores-1; i++) {
		int pid = fork();
		if(pid == 0) {
			char f_buf[50];
			char c_buf[50];
			snprintf(f_buf, sizeof(f_buf), "%0.2fg", f_ghz);
			snprintf(c_buf, sizeof(c_buf), "%d", i);
			execl("/usr/bin/cpufreq-set","cpufreq-set","-c",c_buf,
				"-f",f_buf, (char *)NULL);
			die("control: set_cpu_freq -- exec failed. %s\n", strerror(errno));
		} else if(pid < 0) 
			die("control: set_cpu_freq -- fork failed. %s\n", strerror(errno));
	}
	
	return 1;

}
