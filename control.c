#include "control.h"
#include "temperature.h"
#include "pws.h"
#include "utilities.h"
#include "options.h"
#include <unistd.h>
#include <errno.h>
#include <assert.h>

//##Variables and Parameters##
/*
-units: [ghz], [a], [c], [w]
-I_MIN -- see pws.c for initial current value
*/
#define FREQ_MIN 1.6
const double FREQ_MAX = 2.8;

double i_curr; 
double f_curr = FREQ_MIN;
int first_control_decision = 1;

//##Functions##
int set_cpu_freq(double f_ghz);
int change_freq();
int change_i();

/*
@input
	>= 0 increment
	< 0 decrement
@output
	success = 1, 0 = failure
*/
int change_i(int dir) {
	if(first_control_decision) {
		double i_curr = options_opt.control_params.imin;
		first_control_decision = 0;
	}
	double i_next;
	if(dir >= 0) 
		i_next = i_curr + options_opt.control_params.istep;
	else 
		i_next = i_curr - options_opt.control_params.istep;
	if(i_next >= options_opt.control_params.imin-1e-4 && 
		i_next <= options_opt.control_params.imax+1e-4) {
		i_curr = i_next;
		int j;
		for(j = 0; j < NUM_PWS_CHANNELS; j++)
			pws_i_control[j] = i_curr;	
		return 1;
	} else
		return 0;
	
}

int change_freq(int dir) {
	double f_next;
	if(dir >= 0)
		f_next = f_curr + options_opt.control_params.fstep;
	else
		f_next = f_curr - options_opt.control_params.fstep;
	if(f_next >= FREQ_MIN-1e-4 && f_next <= FREQ_MAX+1e-4) {
		f_curr = f_next;
		assert(set_cpu_freq(f_curr));	
		return 1;
	} else
		return 0;

}


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
	if(f_ghz < FREQ_MIN-1e-4 || f_ghz > FREQ_MAX+1e-4)
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


void control_simple(control_info_t info) {
	assert(NUM_CORES > 0);

	double core_t_max = info.ts[0];
	int j;
	for(j = 0; j < NUM_CORES; j++) {
		if(info.ts[j] > core_t_max)
			core_t_max = info.ts[j];
	}
	double ptotal = info.pcpu + info.ptec;

	//change_* handles f and i thresholds. Returns 0
	//if changes fail threshold checks.
	int set_success;
	if(core_t_max < options_opt.control_params.tmax && ptotal < options_opt.control_params.pmax) {
		set_success = 0;
		if(core_t_max < (options_opt.control_params.tmax-options_opt.control_params.t_hyst) && ptotal < (options_opt.control_params.pmax-options_opt.control_params.p_hyst))
			set_success = change_freq(1);
		if(core_t_max < (options_opt.control_params.tmax-options_opt.control_params.t_hyst) && set_success==0)
			change_i(-1);
	}

	if(core_t_max < options_opt.control_params.tmax && ptotal > options_opt.control_params.pmax) {
		set_success = change_i(-1);
		if(set_success == 0)
			set_success = change_freq(-1);
		if(set_success == 0)
			error_message("simple control: Power constraint failed.\n");
	}
	
	if(core_t_max > options_opt.control_params.tmax && ptotal < options_opt.control_params.pmax) {
		set_success = 0;
		if(ptotal < options_opt.control_params.pmax-options_opt.control_params.p_hyst)
			set_success = change_i(1);
		if(set_success == 0)
			set_success = change_freq(-1);
		if(set_success == 0)
			error_message("simple control: Temperature constraint failed.\n");
	}

	if(core_t_max > options_opt.control_params.tmax && ptotal > options_opt.control_params.pmax) {
		set_success = change_freq(-1);
		if(set_success == 0)
			error_message("simple control: T and P constraint failed.\n");
	}

}
