#ifndef OPTIONS_H
#define OPTIONS_H

#include <unistd.h> 
#include <getopt.h>
#include <stdlib.h>
#include "pws.h"

typedef struct options 
{
	int timeout; //timeout?
	int timeout_sec; //time to execute command for
	char *output_file; //NULL if unspecified
	char *error_file; //NULL if unspecified
	int append_error; //append data to existing error file?
	char *config_file; 
	char *cmd; //command to execute
	int num_dmm; //number of multimeters to record
	int num_pws; //number of power supplies to record
	char **dmm_files; //e.g. /dev/usbtmc0
	char **pws_files; //e.g. /dev/usbtmc0
	int timestamp; //print timestamp in output file
	int headers; //print headers in output file
	int csv; //csv output format (vs. columns)
	int interval_ms; //data collection period
	int temp; //print temperatures
	int debug; //debug messages?
	int num_processes; //number of processes to launch
	char *pws_current_string; //space-separated pws initial currents
	float pws_current[NUM_PWS_CHANNELS];
	int pws_delay;
} options;
extern options options_opt;

/*
@desc Fills options_opt with the relevant
options given on the command line and
through the configuration file. This function
is solely responsible for populating data -- it
does not open any files, for example.
@errors Will terminate program given argument
errors.
*/
void options_populate(int argc, char **argv);

#endif
