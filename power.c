#include "power.h"

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
}

void myread(int file, char *cmd, char *buffer) {
	debug_message("READ1\n");

	struct timespec waittime;
	waittime.tv_sec = 0;
	waittime.tv_nsec = 100000000;
	int len;

	mywrite(file, cmd);
	nanosleep(&waittime, NULL);
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

			if (k == 0) mywrite(myfile[k], "CONF:VOLT:DC MIN");
			else mywrite(myfile[k], "CONF:VOLT:AC MIN");
	
			mywrite(myfile[k], "TRIG:COUN MIN"); 	
			mywrite(myfile[k], "SAMP:COUN MAX"); 
			mywrite(myfile[k], "SAMP:SOUR TIM"); 
			mywrite(myfile[k], "SAMP:TIM 1 ms");
			mywrite(myfile[k], "INIT"); 		
			myread(myfile[k], "SYST:ERR?", err);
			error_message("- POWER: meter %d initialized with error status %s", 
				k, err);	
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
	states[ch] = INIT;

	error_message("- reading channel %d\n", ch);
	while (states[ch] != HALTED) {
		int n;
		struct timeval curr;
    		gettimeofday(&curr, NULL);
		myread(myfile[ch], "DATA:POIN?", buffer);
		buffer[strlen(buffer)] = 0;
		n = atoi(buffer);
		//fprintf(stderr, "- POWER: %d readings are available at time %ld\n",n, (curr.tv_sec*1000+curr.tv_usec/1000)- (st.tv_sec*1000+st.tv_usec/1000));
		if (n > 0) {
			myread(myfile[ch], "R? 50000", buffer);
//			if (strlen(buffer) > 4) {
				parse_power(buffer, ch);
				if (states[ch] == INIT) states[ch] = RUNNING;
//			}
		}
	}
	states[ch] = HALTED;

	debug_message(("THREAD READ 2\n"));
	return 0;
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
		exit = pthread_join(threads[i], NULL);
		error_message("- POWER: terminated power thread # %d with return code %d\n",
			 i, exit);
	}

	// reset meters and tell worker threads to exit loops
	for(i = 0; i < NUM_PWR_CHANNELS; i++) {
		mywrite(myfile[i], "*RST"); 			
		close(myfile[i]);
	}

	debug_message(("CLEAUP2\n"));
}

