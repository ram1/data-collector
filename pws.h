#ifndef PWS_H
#define PWS_H

#define COLLECT_PWS
#define PWS_BUFFER_SIZE 100
#define NUM_PWS_CHANNELS 2

extern double curr_pws_v[10];		
extern double curr_pws_i[10];

void pws_cleanup();
void start_pws(); 
void init_pws(); 


#endif
