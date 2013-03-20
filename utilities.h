#ifndef UTILITIES_H
#define UTILITIES_H

#include <regex.h>
#include "options.h"
#include <stdio.h>


/*
@desc Prints an error message and exits.
set_error_file must be called prior to calling this.
*/
void die(const char *format, ...);


/*
@desc Prints an error/info message. set_error_file
must be called prior to calling this.
*/
void error_message(const char *format, ...);

/*
@desc Prints a debug message to stderr, if debugging
is enabled.
@output
	int -- 1 if message printed, 0 otherwise.
*/
int debug_message(const char *format, ...);

/*
@desc Set where error output from die gets written.
*/
void set_error_file(FILE *efh);

/*
Regular Expressions
*/
void print_regerror(int errcode, regex_t *compiled);
char **split_runstring(const char *cmd);
void free_runstring(char **array);
void print_runstring(char **array);
int size_runstring(char **array);
#endif
