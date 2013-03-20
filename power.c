#include "power.h"
#include <stdio.h>
#include <stdlib.h>
#include <fcntl.h>
#include <time.h>
#include <string.h>
#include <sys/time.h>
#include <pthread.h>
#include <errno.h>
#include <unistd.h>

int NUM_PWR_CHANNELS = 1;
pthread_t threads[10];
enum state_t states[10];
double curr_pwr[10];		
struct timeval st;
int myfile[10];

void mywrite(int file, char *cmd) {
	int size = strlen(cmd);
	char str[50];
	sprintf(str, "%s\n", cmd);
	write(file, str, size + 1);

	/*The associated nanosleep determines the reading
	rate for the multimeter. Note that all commands, including
	reads, will sleep for the specified time.*/
	struct timespec waittime;
	waittime.tv_sec = 0;
	waittime.tv_nsec = 100000000;
	nanosleep(&waittime, NULL);
}

void myread(int file, char *cmd, char *buffer) {
	debug_message("READ1\n");

	int len;
	mywrite(file, cmd);
	len = read(file, buffer, BUFFER_SIZE);

	if (len >= 0) buffer[len] = 0; 
	else buffer[0] = 0;

	debug_message("BUFFER: %s\n", buffer);
	debug_message("READ2\n");
}

int getcond(int file, char *buffer) {
	myread(file, "STAT:OPER:COND?", buffer);
	return atoi(buffer);
}

void init_power() {
	debug_message("INIT1\n");
	int k;
	char fname[100];
	char err[256];
	int h;

	gettimeofday(&st, NULL);

	for(k=0; k < NUM_PWR_CHANNELS; k++) {
		sprintf(fname, "/dev/usbtmc%d", k);

		if ((h = open(fname, O_RDWR)) >= 0) {
			fprintf(stderr, "- POWER: preparing meter %s\n", fname);
			myfile[k] = h;
			mywrite(myfile[k], "*RST"); 											

			//Minimum (mV) range, default resolution. printf controls
			//how much resolution prints -- see data_collector.c
			if (k == 0) mywrite(myfile[k], "CONF:VOLT:DC MIN,DEF");
			else mywrite(myfile[k], "CONF:VOLT:AC MIN");

			mywrite(myfile[k], "TRIG:SOUR IMM");
			//mywrite(myfile[k], "TRIG:COUN MIN"); 	
			//mywrite(myfile[k], "SAMP:COUN MAX"); 
			//mywrite(myfile[k], "SAMP:SOUR TIM"); 
			//mywrite(myfile[k], "SAMP:TIM 1 ms");
			//mywrite(myfile[k], "INIT"); 		
			do
			{
				myread(myfile[k], "SYST:ERR?", err);
				error_message("- POWER: meter %d initialized with error status %s", 
					k, err);
			} while(strncmp(err,"+0",2) != 0);
		}	
	}
	error_message("- detected %d power meters\n", k);
	debug_message("INIT2\n");
}

void parse_power(char *buffer, int ch) {
	char *val;
	
	val = strtok(buffer, ",*\\+");
	while (val != NULL) {
		curr_pwr[ch] = atof(val);
		val = strtok(NULL, ",*\\+"); 
	}	
}

void *read_power(void *chan) {
	debug_message(("THREAD READ 1\n"));

	char buffer[BUFFER_SIZE];
	int ch = *((int *)chan);

	/*Initialize after grabbing the input parameter, which is on the
	stack of the caller. Subsequently, the caller is allowed to 
	terminate*/
	states[ch] = INIT;

	error_message("- reading channel %d\n", ch);
	while (states[ch] != HALTED) {
		int n;
		struct timeval curr;
    		gettimeofday(&curr, NULL);

		/*Issue a read request. Since the trigger mode is immediate,
		a read will occur immediately and the data will be put
		on the output buffer. See the SCPI 34410A Agilent Programmer's
		Manual. Another method is to set the meter to read chunks of
		data on its own.*/
		myread(myfile[ch], "READ?", buffer);
		//myread(myfile[ch], "DATA:POIN?", buffer);
		//buffer[strlen(buffer)] = 0;
		//n = atoi(buffer);
		//fprintf(stderr, "- POWER: %d readings are available at time %ld\n",n, (curr.tv_sec*1000+curr.tv_usec/1000)- (st.tv_sec*1000+st.tv_usec/1000));
//		if (n > 0) {
//			myread(myfile[ch], "R? 50000", buffer);
//			if (strlen(buffer) > 4) {
				parse_power(buffer, ch);
				if (states[ch] == INIT) states[ch] = RUNNING;
//			}
//		}
	}

	debug_message(("THREAD READ 2\n"));
	states[ch] = TERMINATED;
	pthread_exit((void *)2);
}

void start_power() {
	int i;
	int inds[NUM_PWR_CHANNELS];	

	// initialize meter settings
	init_power(); 

	// create worker threads for all meters
	for (i = 0; i < NUM_PWR_CHANNELS; i++) {
		int exit;
		inds[i] = i;
		exit = pthread_create(&threads[i], NULL, read_power, (void *) &inds[i]);
		error_message("- POWER: created power thread #%d with return code %d\n", 
			i, exit);
	}

	// wait for all threads to be running
	int running = 0;
	while(!running) {
		running = 1;
		for (i = 0; i < NUM_PWR_CHANNELS; i++) {
			if (states[i] == INIT) running = 0;
		}		
	}
}

void power_cleanup() {
	debug_message(("CLEAUP1\n"));

	int i;

	for(i = 0; i < NUM_PWR_CHANNELS; i++) {
		int exit;
		states[i] = HALTED;
		void *retval;
		while(states[i] != TERMINATED)
		{
			sleep(1);
		}

		/*On my version of Linux, pthread_join seems not to work.
		It cancels the thread. Hence, the while loop above to guarantee
		the important I/O operations complete. pthread_join doesn't
		read the return value properly either. It should read 2.
		This avoids putting the multimeter in the Query Interrupted
		error state*/
		pthread_detach(threads[i]);
		//exit = pthread_join(threads[i], &retval);
		//error_message("- POWER: Terminated power thread # %d with return code %d, exit val %d\n",
		//	 i, exit,retval);
	}

	// reset meters and tell worker threads to exit loops
	for(i = 0; i < NUM_PWR_CHANNELS; i++) {
		/*Do not send any commands to the power supply from this point onwards.
		Since the handle will close soon, the commands are likely to be
		sent only partially and put the multimeter into a bad state.*/

		close(myfile[i]);
	}

	debug_message(("CLEAUP2\n"));
}

