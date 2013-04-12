#include "options.h"
#include "utilities.h"
#include "control.h"
#include "pws.h"
//TODO put all these global parameters in one file
options options_opt;

void delete_options()
{
	free(options_opt.affinities);
}

void options_populate(int argc, char **argv)
{
	//#defaults
	options_opt.timeout_sec = 0;
	options_opt.cmd = NULL;
	options_opt.output_file = NULL;
	options_opt.timeout = 0;
	options_opt.error_file = NULL;
	options_opt.append_error = 0;
	options_opt.debug = 0;
	options_opt.num_processes = 1;
	options_opt.pws_current_string = NULL;
	options_opt.pws_delay = 0;
	options_opt.affinities = NULL;
	options_opt.control_params.interval = 10;
	options_opt.control_params.tmax = 80;
	options_opt.control_params.pmax = 1000;
	options_opt.control_params.imin = PWS_I_DEFAULT;
	options_opt.control_params.imax = 4;
	options_opt.control_params.fstep = 0.1;
	options_opt.control_params.istep = 0.5;
	options_opt.control_params.t_hyst = 5;
	options_opt.control_params.p_hyst = 3;

	//#command line arguments
	//Since we don't know whether there is a valid
	//error file when parsing command line arguments,
	//output to the default set.
	opterr = 0; //getopt should not print errors
	int c, i;
	int num_aftys;
	char **aftys;
	char **cont_params;
	
	while((c = getopt(argc, argv, "c:f:l:i:n:t:o:e:r:ad")) != -1)
	{
		switch(c)
		{
			case 'c':
				#ifndef CONTROL_ENABLE
					die("Control parameters specified and control disabled\n");
				#endif
				cont_params = split_runstring(optarg);
				if(size_runstring(cont_params) != CONTROL_NUM_PARAMS)
					die("Invalid number of control parameters. %d supplied."
						"%d required.\n", size_runstring(cont_params),
						CONTROL_NUM_PARAMS);
				options_opt.control_params.interval = atoi(cont_params[0]);
				options_opt.control_params.tmax = atof(cont_params[1]);
				options_opt.control_params.pmax = atof(cont_params[2]);
				options_opt.control_params.imin = atof(cont_params[3]);
				options_opt.control_params.imax = atof(cont_params[4]);
				options_opt.control_params.fstep = atof(cont_params[5]);
				options_opt.control_params.istep = atof(cont_params[6]);
				options_opt.control_params.t_hyst = atof(cont_params[7]);
				options_opt.control_params.p_hyst = atof(cont_params[8]);
				free_runstring(cont_params);
				break;
			case 'f':
				aftys = split_runstring(optarg);
				num_aftys = size_runstring(aftys);
				options_opt.affinities = (int *)malloc(num_aftys*sizeof(int));
				for(i = 0; i < num_aftys; i++)
				{
					options_opt.affinities[i] = atoi(aftys[i]);
				}
				free_runstring(aftys);
				break;
			case 'l':
				options_opt.pws_delay = atoi(optarg);
				break;
			case 'n':
				options_opt.num_processes = atoi(optarg);
				break;
			case 'd':
				options_opt.debug = 1;
				break;
			case 'a':
				options_opt.append_error = 1;
				break;
			case 'r':
				options_opt.error_file = optarg;
				break;
			case 't':
				options_opt.timeout_sec = atoi(optarg);
				options_opt.timeout = 1;
				break;
			case 'o':
				options_opt.output_file = optarg;
				break;
			case 'e':
				options_opt.cmd = optarg;
				break;
			case 'i':
				options_opt.pws_current_string = optarg;
				break;
			case '?':
				if(optopt == 'e' || optopt == 'o' || optopt == 't' || optopt == 'n' || optopt == 'i' || optopt == 'l' || optopt == 'c') 
				{
					die("-%c requires an argument\n", optopt);
				}
				else
				{
					die("Unrecognized option -%c\n", optopt);
				}
				break;
			default:
				die("Getopt error. Character %d\n", c);
		}

	}

	if(optind < argc)
	{
		die("Unrecognized non-option arguments\n");
	}

	//#argument checking
	if(options_opt.timeout)
	{
		if(options_opt.timeout_sec <= 0)
		{
			die("Specify a positive timeout, not %d [s]\n", 
				options_opt.timeout_sec);
		}
	}

	if(options_opt.cmd == NULL)
	{
		die("Please specify a program to execute with -e\n");
	}
	if(options_opt.num_processes < 1)
		die("Please specify a positive number of processes to execute\n");

	if(options_opt.affinities != NULL)
	{
		if(num_aftys != options_opt.num_processes)
		{
			die("The number of affinities must match" 
				"the number of processes\n");
		}

		int i;
		int num_procr = (int)sysconf(_SC_NPROCESSORS_ONLN);
		for(i = 0; i < num_aftys; i++)
		{
			if(options_opt.affinities[i] < 0 ||
				options_opt.affinities[i] >= num_procr)
			{
				die("Affinities must range in [0,# processors)\n");
			}
		}
	}

	#ifdef COLLECT_PWS
		if(options_opt.pws_current_string != NULL)
		{
			char** values = split_runstring(options_opt.pws_current_string);
			int size = 0;

			while(values[size] != NULL)
			{
				float val = atof(values[size]);
				if(val < 0 || val > 5)
					die("Power supply currents must be between 0 and 5 [A]\n");
				else
					options_opt.pws_current[size] = val;
				size++;
			}
			
			if(size != NUM_PWS_CHANNELS)
				die("Please specify currents for each of the %d power supplies\n", NUM_PWS_CHANNELS);

			free_runstring(values);	
		}
		else
			die("Please specify initial currents for the power supplies\n");

		if(options_opt.pws_delay < 0)
			die("Please specify a positive power supply delay [s]\n");
		if(options_opt.timeout && 
			options_opt.pws_delay > options_opt.timeout_sec)
			die("Power supply delay is greater than timeout time\n");

	#endif


		/*
		Control Parameters Checking. 
		There are no constraints on tmax, pmax
		*/
		if(options_opt.control_params.interval < 1)
			die("Control interval should be >= 1, not %d\n",
				options_opt.control_params.interval);
		if(options_opt.control_params.imin < 0)
			die("Control minimum current should be >= 0, not %f\n",
				options_opt.control_params.imin);
		if(options_opt.control_params.imax < 0)
			die("Control max current should be >= 0, not %f\n",
				options_opt.control_params.imax);
		if(options_opt.control_params.fstep < 0)
			die("Frequency step should be >= 0, not %f\n",
				options_opt.control_params.fstep);
		if(options_opt.control_params.istep < 0)
			die("Current step should be >= 0, not %f\n",
				options_opt.control_params.istep);
		if(options_opt.control_params.t_hyst < 0)
			die("T hysteresis should be >= 0, not %f\n",
				options_opt.control_params.t_hyst);
		if(options_opt.control_params.p_hyst < 0)
			die("P hysteresis should be >= 0, not %f\n",
				options_opt.control_params.p_hyst);

}
