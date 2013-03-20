#include <stdio.h>
#include <stdlib.h>
#include <fcntl.h>
#include <string.h>
#include <pthread.h>
#include <errno.h>
#include <unistd.h>
#include <time.h>
#include "power.h"
#include "pws.h"


pthread_t threads[10];
enum state_t states[10];
double curr_pws_v[10];		
double curr_pws_i[10];
int files[10];


/*
Writes a command to the file, appending a newline
*/
void pws_mywrite(int file, char *cmd) {
	int size = strlen(cmd);
	char str[50];
	sprintf(str, "%s", cmd);
	if(write(file, str, size)==-1)
		die("power supply write error: %s", strerror(errno));	

	//Instrument bandwidth limitations make pauses between
	//commands necessary. The TEK4000 Series Programmer's Guide gives
	//20 [ms] as the latency to send and receive every command.
	//Only set the current if the MCR_INTERFACE is enabled.
	//This should avoid any BROKEN_PIPE issues regarding I/O.
	//Note that pws_myread calls pws_mywrite.
	long pause_ms = 20;
	long pause_seconds = pause_ms/1000;
	pause_ms -= pause_seconds*1000;
	struct timespec pausetime;
	pausetime.tv_sec = pause_seconds;
	pausetime.tv_nsec = pause_ms*1e6;
	nanosleep(&pausetime, NULL);
}

/*
Reads the result of cmd into buffer
*/
void pws_myread(int file, char *cmd, char *buffer) {
	pws_mywrite(file, cmd);
	int len = read(file, buffer, PWS_BUFFER_SIZE);

	if (len >= 0) buffer[len] = 0; 
	else buffer[0] = 0;
}

//Delay variables
struct timeval starttime;
int engaged[NUM_PWS_CHANNELS];
struct timeval now[NUM_PWS_CHANNELS];

/*
Opens the handles for each instrument
*/
void init_pws() {
	//i instrument number
	//h handle
	int i, h;
	char fname[100];
	gettimeofday(&starttime, 0);

	for (i = 0; i < NUM_PWS_CHANNELS; i++) {
		engaged[i] = 0;
		//Assume that the power supply devices start from 
		//usbtmc1 and up
		sprintf(fname, "/dev/usbtmc%d", i+1);

		if ((h = open(fname, O_RDWR)) >= 0) {
			files[i] = h;

			char buffer[100];
			pws_mywrite(files[i], "*RST");
			pws_mywrite(files[i], "SYST:REM");
			pws_mywrite(files[i], "SOUR:VOLT 20V");
			
			/*Start at a low current that prevents the RSV power
			supply error, but allows observation of dynamic
			behavior.*/
			if(options_opt.pws_delay != 0 && 
				options_opt.pws_current[i] != 0)
			{
				sprintf(buffer,"SOUR:CURR %fA", 
					0.3);
				pws_mywrite(files[i], buffer);
				pws_mywrite(files[i], "OUTPUT 1");
			}
			else
			{
				pws_mywrite(files[i], "OUTPUT 0");
			}

				

	//		#ifdef ENABLE_MCR 
	//			pws_mywrite(files[i], "SOUR:CURR 0A");
	//			pws_mywrite(files[i], "OUTPUT 1");
	//		#endif

		}	
		else {
			files[i] = -1;
		}
	}
}

/*
Places the current reading in the array
*/
void parse_pws(char *buffer, int ch, double *dataArray) {
	dataArray[ch] = atof(buffer);
}

/*
Instrument read and write loop.
*/
void *rw_pws(void *chan) {
	
	char buffer[PWS_BUFFER_SIZE];
	int ch = *((int *)chan);

	//Loop. 
	while (states[ch] != HALTED) {
		/*
		After the specified delay time, turn the power supplies
		on. Startime is initialized in pws_init. An alternative
		design would use a separate thread to start up the power
		supplies. However, that design requires avoiding some race
		conditions with mutexes. For example, the supplies
		should not start after cleanup has been started. This design,
		though slowing down the read loop, avoids those complexities.
		*/
		if(!engaged[ch])
		{
			gettimeofday(&now[ch], 0);	
			if(options_opt.pws_delay == 0 || 
				(now[ch].tv_sec-starttime.tv_sec > options_opt.pws_delay))
			{
				sprintf(buffer,"SOUR:CURR %fA", 
					options_opt.pws_current[ch]);
				pws_mywrite(files[ch], buffer);
				pws_mywrite(files[ch], "OUTPUT 1");
				engaged[ch] = 1;
			}
		}

		pws_myread(files[ch], "MEAS:VOLT:DC?", buffer);
		parse_pws(buffer, ch, curr_pws_v);

		pws_myread(files[ch], "MEAS:CURR:DC?", buffer);
		parse_pws(buffer, ch, curr_pws_i);

		//#ifdef ENABLE_MCR
			//if (activate_control) {
			//	char iset_cmd[50];
			//	sprintf(iset_cmd, "SOUR:CURR %fA", pws_i_control[ch]);
			//	pws_mywrite(files[ch], iset_cmd); 
			//	sleep(pause_seconds);
			//}
		//#endif

		if (states[ch] == INIT) states[ch] = RUNNING;
	}
	states[ch] = TERMINATED;

	return 0;
}

void start_pws() {
	int i;
	int inds[NUM_PWS_CHANNELS];	

	// initialize meter settings
	init_pws(); 

	// create worker threads for all meters
	for (i = 0; i < NUM_PWS_CHANNELS; i++) {
		if (files[i] >= 0) {
			int exit;
			inds[i] = i;
			states[i] = INIT;
			exit = pthread_create(&threads[i], NULL, rw_pws, (void *) &inds[i]);
		}
	}

	// wait for all threads to be running
	int running = 0;
	while (!running) {
		running = 1;
		for (i = 0; i < NUM_PWS_CHANNELS; i++) {
			if (states[i] == INIT && files[i] >= 0) running = 0;
		}		
	}
}

void pws_cleanup() {
	int i;
	for (i = 0; i < NUM_PWS_CHANNELS; i++) {
		if (files[i] >= 0) {
			int exit;
			states[i] = HALTED;
			while(states[i] != TERMINATED)
			{
				sleep(1);
			}
			//exit = pthread_join(threads[i], NULL);
			pws_mywrite(files[i], "OUTPUT 0");
			close(files[i]);
		}
	}
}



