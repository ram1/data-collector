#include <errno.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <time.h>
#include <sys/types.h>
#include <sys/wait.h>
#define _GNU_SOURCE
#define __USE_GNU
#include <sched.h>
#include "temperature.h"
#include "options.h"
#include "utilities.h"
#include "power.h"
#include "pws.h"

//###constants and variables###
//data collection intervals [ms]
//INTERVAL must be greater than MIN_INTERVAL
const long INTERVAL = 1000;
const unsigned int MIN_INTERVAL = 50;



sigset_t mask_chld; //a signal mask for blocking SIGCHLD
int done = 0; //child terminated?
long timeout_ms; //runtime specification
long completed_ms; //runtime so far
FILE *output_file_handle;



//###functions###

/*
@desc 
Collects data, like core temperature, at the specified timing
interval. 

@inputs
	signum -- the signal triggering the function call
*/
void collect(int signum);


void collect_data();
void kill_command(int pid);
void setup();

//###code###

void kill_command(int pid)
{
	if(kill(pid,9) == -1)
	{
		die("%s. Could not terminate child pid %d\n", 
			strerror(errno), pid);
	}
}

/*
@desc Prints collected data to an output file, and
manages benchmark execution.
@input
	int pid -- child process id
@errors
	print_data will terminate the program if:
		-the output file already exists
		-the output file is invalid or can't be opened
*/
void collect_data()
{
	//##launch benchmark##
	int *pids = (int *)malloc(sizeof(int)*options_opt.num_processes);

	//0 = not exited. 1 = exited.
	int *pid_exited = (int *)malloc(sizeof(int)*options_opt.num_processes);
	int k;
	for(k = 0; k < options_opt.num_processes; k++)
	{
		int pid = launch_command(options_opt.cmd);
		pid_exited[k] = 0;
		pids[k] = pid;
	}

	completed_ms = 0;

	//##output data##
	const struct timespec delay = {INTERVAL/1000,(INTERVAL%1000)*10e6};
	while(!done)
	{
		if(options_opt.timeout&&completed_ms>timeout_ms)
		{
			for(k = 0; k < options_opt.num_processes; k++)
			{
						kill_command(pids[k]);	
			}
		}

		done = 1;
		for(k = 0; k < options_opt.num_processes; k++)
		{
			if(!pid_exited[k])
				if(waitpid(pids[k], 0, WNOHANG))			
					pid_exited[k] = 1;
		}
		for(k = 0; k < options_opt.num_processes; k++)
		{
			if(!pid_exited[k])
			{
				done = 0;
				break;
			}
		}


		//temperatures
		int i;
		for(i = 0; i < num_cores; i++)
		{
			double t;
			int temp_status = temp_read(i, &t);
			if(temp_status != 0)
			{
				die("error %d: reading core %d T",
           temp_status, i);
			}
			fprintf(output_file_handle, "%-15.1f", t);
		}


		//power
	  	for(i = 0; i < NUM_PWR_CHANNELS; i++) {
	  	  fprintf(output_file_handle, "%-15.5f ", curr_pwr[i]);
	  	}

		//fan speeds
		double fspeed;
		for(i = 0; i < NUM_FANS; i++)
		{
			fan_read(i,&fspeed);
			fprintf(output_file_handle, "%-15.5f", fspeed);
		}


		//power supplies
		#ifdef COLLECT_PWS
		double pws_v, pws_i;	
		for(i = 0; i < NUM_PWS_CHANNELS; i++)
		{
			fprintf(output_file_handle, "%-15.5f", curr_pws_v[i]);
			fprintf(output_file_handle, "%-15.5f", curr_pws_i[i]);
		}
		#endif
		
		//timestamp [ms]
		fprintf(output_file_handle, "%-15d\n", (int)completed_ms);

		//nanosleep can be interrupted by signals, but
		//this case doesn't need to be handled in any special way.
		//If the child terminates, done will be set and data
		//collection will finish.
		nanosleep(&delay, NULL);
		completed_ms += INTERVAL;
	}

	free(pids);
	free(pid_exited);
}

void collect(int signum)
{
	//Block SIGCHLD during collect, so that collect takes
	//a full set of data. Subsequently, the program can
	//handle SIGCHLD. The final argument of sigprocmask,
	//the old sigset being replaced, is irrelevant here. 	
	sigprocmask(SIG_BLOCK, &mask_chld, 0);

	int i;
	for(i = 0; i < num_cores; i++)
	{
		double t;
		int temp_status = temp_read(i, &t);
		if(temp_status != 0)
		{
			die("error %d: reading core %d T", temp_status, i);
		}
		printf("%d: %f\n", i, t);
	}

	alarm(INTERVAL);
	sigprocmask(SIG_UNBLOCK, &mask_chld, 0);
}

/*@desc SIGCHLD handler*/
void child_terminated(int signum)
{
	//int status;

	//In addition to obtaining exit status, wait will
	//free up resources allocated to the child process.
	//pid_t exit = wait(&status);
	error_message("child exit");
	//done = 1;
}


/*
@desc Forks and launches the specified command.
@input
	char *cmd -- A string to execute. The full paths of binaries
	should be specified if possible, even though execvp is used.
@output
	int -- The pid of the launched child process.
@errors
	-fork failed
	-exec failed
*/
int num_launched = 0;
int launch_command(char *cmd)
{
	num_launched++;
	int pid = fork();
	if(pid > 0)
	{
		return pid;
	}
	else if(pid == 0)
	{
		//The child launches the specified command.
		char **cmd_array = split_runstring(cmd);

		//Set the affinity of the process to the 
		//processor it should run on. Note affinities
		//are preserved over execve calls.
		if(options_opt.affinities != NULL)
		{
			cpu_set_t afty;
			CPU_ZERO(&afty);
			CPU_SET(options_opt.affinities[num_launched-1],&afty);
			if(sched_setaffinity(0, sizeof(cpu_set_t), &afty)==-1)
			{
				//If we terminate here, there is no cleanup to
				//do because we are in the child process.
				char buf[100];
				sprintf(buf, "affinity failure: %s\n", strerror(errno));
				die(buf);
			}
		}
		//Note that in the list of arguments, the command
		//being executed is the first argument.
		execvp(cmd_array[0], cmd_array);

		//A successful exec should never return
		//fprintf(stderr, "Error. exec failed.\n");
		die("%s. exec failed.\n", strerror(errno));
	}
	else
	{
		die("Error %d: failed to fork\n", pid);
	}
}



int main(int argc, char **argv)
{
	

	//#setup#
	//data_collector is responsible for processing 
	//any files specified in the user-specified options.
	set_error_file(stderr);


	int temp_status = temp_init();
	if(temp_status != 0)
	{
		die("error %d: temperature sensor initialization", 
			temp_status);
	}

	if(INTERVAL < MIN_INTERVAL)
	{
		die("error: INTERVAL %d is less than %d\n", 
			(int)INTERVAL,	(int)MIN_INTERVAL);
	}

//	sigemptyset(&mask_chld);
//	sigaddset(&mask_chld, SIGCHLD);

	//if(signal(SIGCHLD, child_terminated) == SIG_ERR)
	//{
	//	die("setting SIGCHLD handler failed\n");
	//}

	options_populate(argc, argv);

	//Determine the proper error file ASAP.
	//Otherwise keep the default, stderr, set above.
	if(options_opt.error_file != NULL)
	{
		if(!options_opt.append_error && 
			(access(options_opt.output_file, F_OK) != -1))
		{
			die("Error file %s already exists and -a not specified\n", 
				options_opt.error_file);
		}

		//Open in append mode. If the file doesn't exist,
		//it will be created.
		set_error_file(fopen(options_opt.error_file, "a"));
	}
		
	timeout_ms = options_opt.timeout_sec*1000;
		
	//##open file##
	//If an output file is unspecified by the user, output
	//to stdout.
	if(options_opt.output_file != NULL)
	{
		if(access(options_opt.output_file, F_OK) != -1)
		{
			die("File %s already exists\n", options_opt.output_file);
		}

		output_file_handle = fopen(options_opt.output_file, "w");
	}
	else
	{
		output_file_handle = stdout;
	}

	start_power();

	#ifdef COLLECT_PWS
	init_pws();
	start_pws();	
	#endif 
	//signal typically returns a pointer to the previous
	//signal handler, but can also error
	//if(signal(SIGALRM, collect) == SIG_ERR)
	//{
	//	fprintf(stderr, "error: could not set SIGALRM signal handler\n");
	//	exit(1);
	//}

	//#debug#
	collect_data();
	


		


	
	//#loop#
//	alarm(INTERVAL);
//	pause();

	//#cleanup#
	fclose(output_file_handle);
	temp_cleanup();
	power_cleanup();
	delete_options();

	#ifdef COLLECT_PWS
	pws_cleanup();
	#endif

}

