#include <stdio.h>
#include <time.h>
#include <string.h>
//#define    CLK_TCK 1000000 
#define CLK_TCK CLOCKS_PER_SEC  
/* microseconds */
void iqtime_(char *str)
{
    char *pc ;
    time_t *t, ii;
    t=&ii;
    time(t);
    pc=ctime(t) ;
    strncpy(str,pc+11,8) ; 
    return ; 
    }
void iqdate_(char *str)
{
    char *pc ;
    time_t *t, ii;
    t=&ii;
    time(t);
    pc=ctime(t) ;
    strncpy(str,pc+4,3) ; 
    strncpy(str+3,pc+8,3) ; 
    strncpy(str+6,pc+22,2) ; 

    return ; 
    }
void iqsecs_(float *sec)
{
    clock_t start;
    float secs ;
    start = clock() ; 
    secs=(float) start;
    *sec=secs/CLK_TCK ;
    return ;
    }
    
