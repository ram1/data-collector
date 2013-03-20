#include "utilities.h"
#include "string.h"
#include <stdarg.h>
#include <stdlib.h>

FILE *error_file_handle;

//the maximum number of words the benchmark to run can contain
const unsigned int MAX_MATCHES = 100;

void set_error_file(FILE *efh)
{
	error_file_handle = efh;
}

void die(const char *format, ...)
{
	va_list argptr;
	va_start(argptr, format);
	vfprintf(error_file_handle, format, argptr);
	va_end(argptr);
	fprintf(stderr, "Program failure\n");
	exit(1);
}

void error_message(const char *format, ...)
{
	va_list argptr;
	va_start(argptr, format);
	vfprintf(error_file_handle, format, argptr);
	va_end(argptr);
}

int debug_message(const char *format, ...)
{
	if(options_opt.debug)
	{
		va_list argptr;
		va_start(argptr, format);
		vfprintf(stderr, format, argptr);
		va_end(argptr);
		return 1;
	}
	
	return 0;
}

/*
@desc Given a regular expression error, gets a related error message. 
Prints the message to stderr and terminates the program. 
*/
void print_regerror(int errcode, regex_t *compiled)
{
  size_t length = regerror(errcode, compiled, NULL, 0);
  char *buffer = malloc(length*sizeof(char));
  (void) regerror(errcode, compiled, buffer, length);

	//The program will terminate before we have the chance
	//to free buffer.
	die("regex error %d. %s\n", errcode, buffer);
}

/*
@desc Splits a string on whitespace.
@input
	char *cmd -- a null terminated string
@output
	char** -- a null terminated array of null-terminated strings. It is
	the responsibility of the caller to free allocated memory by calling
	free_runstring
@error
	If there is an error in constructing regular expressions, the function
	will print a message and terminate the program. 
*/
char **split_runstring(const char *cmd)
{
	//##
	//Construct a regular expression that will split the
	//cmd on whitespace. An alternative option
	//would be to use strtok.
	//char *whitespace_separated = "\\([^[:space:]]+\\)[:space:]";
	char *whitespace_separated = "[^[:space:]]+";
	regex_t whitespace_separated_regex;
	
	int error;
	if(error = regcomp(&whitespace_separated_regex, whitespace_separated, 
		REG_EXTENDED))
	{
		print_regerror(error, &whitespace_separated_regex);
	}

	//##
	//Continually find matches in the string cmd until there are no more matches
	//or the end of the string is reached. Note that offset changes on each
	//loop.

	//On each iteration, examine cmd+offset for a match. This allows
	//finding a new match on each iteration.
	int offset = 0;

	//The number of matches thus far.
	int index = 0;

	int nmatch = 1;
	regmatch_t word [nmatch];

	//Allocate an extra char* to allow array to be null terminated.
	char **array = (char**)malloc((MAX_MATCHES+1)*sizeof(char*));

	while((error = regexec(&whitespace_separated_regex, cmd+offset*sizeof(char), nmatch, word, 0)) != REG_NOMATCH
		&& (index < 100))
	{
		if(error)
		{
			print_regerror(error, &whitespace_separated_regex);
		}
		
		//Allocate space to copy the match to. Append an extra char to allow
		//for null termination. rm_so marks one character past the substring
		// match.
		int match_length = word[0].rm_eo - word[0].rm_so;
		char *match = (char*)malloc((match_length+1)*sizeof(char));
		strncpy(match, cmd+offset+word[0].rm_so, match_length);
		match[match_length] = 0;
		array[index] = match;

		offset = offset+word[0].rm_eo;
		index++;
		
		//Check if the last character matched was null.
		//Matches will include null characters since we
		//haven't excluded them in whitespace_separated
		if(*(cmd+offset)==0)
		{
			break;
		}
	}

	array[index] = NULL;


	if(offset==0)
	{
		die("The provided command to execute is empty.\n");
	}
	
	regfree(&whitespace_separated_regex);
	return array;
}

int size_runstring(char **array)
{
	int offset = 0;
	while(array[offset] != NULL)
	{
		offset++;
	}
	return offset;
}

/*
@desc Frees the array and contained strings.
*/
void free_runstring(char **array)
{
	int offset = 0;
	while(array[offset] != NULL)
	{
		free(array[offset]);
		offset++;
	}
	free(array);
}

void print_runstring(char **array)
{
	int offset = 0;
	while(array[offset] != NULL)
	{
		printf("%s\n", array[offset]);
		offset++;
	}
}
