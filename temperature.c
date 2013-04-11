#include "temperature.h"
#include <sensors/sensors.h>
#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>
#include <regex.h>
#include "utilities.h"

/*
@author Ryan Cochran; Modified by Sriram Jayakumar
*/

//##Variables##
int num_cores;

//A list of sensors_chip_names, one per available
//input fan sensor. 
const sensors_chip_name *fan_chip_names[NUM_FANS];

//A list of subfeature numbers, one per available
//input fan sensor. There is typically one per
//core.
int fan_subfeature_numbers[NUM_FANS];

/*
@desc Determines the chips and subfeature numbers corresponding
	to the given string. The provided arrays will be populated.
	
@inputs
	const sensors_chip_name **chip_n -- preallocated array
	int *subfeat_n -- preallocated array
	int size -- number of entries in each array
	const char *to_match -- regular expression used to match subfeatures
	sensors_chip_name wildcard -- match for chip name

@errors
	Can terminate the program if an error is encountered.
*/
void determine_sensors(const sensors_chip_name **chip_n, int *subfeat_n,
	int size,	const char *to_match, sensors_chip_name wildcard);

int temp_init()
{
	FILE *config;
	int errnum;
	num_cores = sysconf(_SC_NPROCESSORS_ONLN);
	
	//##initialization##
	//Open configuration file	
	if((config = fopen("/etc/sensors3.conf", "r")) == NULL)
	{
		die("error: opening /etc/sensors3.conf\n");
	}
	
	//Initialize sensors	
	if((errnum = sensors_init(config)))
	{
		die("error %d: sensors_init\n", errnum);
	}
	fclose(config);


	
	//##determine the available temperature sensors##
	//Get wildcard description of coretemp	
	sensors_chip_name wildcard, fan_wildcard;	
	//nct6776-isa-* ASUS Z77 EXTREME
	//Gigabyte it8718-*
	if((errnum = sensors_parse_chip_name("nct6776-isa-*", &fan_wildcard)))
	{		
		die("error %d: sensors_parse_chip_name\n", errnum);
	}	

	if((errnum = sensors_parse_chip_name("coretemp-isa-*", &wildcard)))
	{		
		die("error %d: sensors_parse_chip_name\n", errnum);
	}	

	//Temperature sensor arrays
	core_chip_names = (const sensors_chip_name**) malloc(num_cores*sizeof(sensors_chip_name*));
	core_subfeature_numbers = (int*) malloc(num_cores*(sizeof(int*)));
	determine_sensors(core_chip_names, core_subfeature_numbers, 
		num_cores, "temp.*input", wildcard);
	determine_sensors(fan_chip_names, fan_subfeature_numbers, 
		NUM_FANS, "fan.*input", fan_wildcard);

	return 0;
}

void determine_sensors(const sensors_chip_name **chip_n, int *subfeat_n,
	int size,	const char *to_match, sensors_chip_name wildcard)
{
	//Construct a regular expression to match the temperature sensor
	//subfeature name. In this case, there is no need for options like
	//REG_EXTENDED or REG_NEWLINE.
	regex_t tsensor;
	if(regcomp(&tsensor, to_match, 0) != 0)
	{
		die("error: regex construction\n");
	}

	//Iterate through each of the subfeatures of each sensor chip,
	//looking for relevant sensors.
	int core_i = 0;
	int nr_chp = 0;
	const sensors_chip_name *chip_name;
	while((chip_name = sensors_get_detected_chips(&wildcard, &nr_chp)) != NULL)
	{
		int nr_ft = 0;
		const sensors_feature *ft;
		while((ft = sensors_get_features(chip_name, &nr_ft)) != NULL)
		{
			int nr_sft = 0;
			const sensors_subfeature *sft;
			while((sft = sensors_get_all_subfeatures(chip_name, ft, &nr_sft)) != NULL)
			{
				int reg_status = regexec(&tsensor, (*sft).name, 0, NULL, 0);
				if(reg_status == 0)
				{
					if(core_i < size)
					{
						chip_n[core_i] = chip_name;
						subfeat_n[core_i] = (*sft).number;
						core_i++;				
						error_message("detected %s\n", (*sft).name);
					}
				}
				else if(reg_status == REG_ESPACE)
				{
					fprintf(stderr, "error: regex out of memory\n");
				}
			}
		}
	}
	
	regfree(&tsensor);	
}
void temp_cleanup()
{
	free(core_chip_names);
	free(core_subfeature_numbers);
	sensors_cleanup();
}

int temp_read(int core, double *temperature)
{
	int errnum;

	if(core < 0 || core >= num_cores){
		return -2;
	}

	if((errnum = 
		sensors_get_value(core_chip_names[core], core_subfeature_numbers[core], temperature)))
	{
		return errnum;
	}

	return 0;
}

void fan_read(int num, double *speed)
{
	if(num < 0 || num > NUM_FANS)
	{
		die("Attempted read of fan number %d\n", num);
	}

	int errnum;
	if((errnum = 
		sensors_get_value(fan_chip_names[num], fan_subfeature_numbers[num], 
			speed)))
	{
		die("Reading fan speed failed with error %d\n", errnum);
	}
}
