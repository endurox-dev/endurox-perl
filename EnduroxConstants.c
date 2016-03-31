/*
 * EnduroxConstants.c
 *
 * This file contains a map of name/value pairs relating to endurox constants.
 * The map structure (namedConstants)contains a hash key that is used to 
 * locate the named value.  The first time a lookup occurs, the map structure 
 * is initialized and the hash values for all the entries in the map are 
 * calculated.
 *
 * To add a new constant, just add an entry to the namedConstants[] array.
 * You can specify an arbitrary value for the hash attribute when doing this 
 * because it will be overwritten when the actual hash value is calculated
 * doing the initialization.
 */

#ifdef WIN32
#include "perl.h"
#endif

#include <string.h>
#include <atmi.h>
#include <ubf.h>
#include <errno.h>
#include <stdlib.h>
#include <stdio.h>

#ifndef WIN32
#include <signal.h>
#endif

typedef  unsigned long int  u4;   /* unsigned 4-byte type */
typedef  unsigned     char  u1;   /* unsigned 1-byte type */

typedef struct
{
    u4    hash;
    char *name;
    long value;
} NamedConstant;

NamedConstant namedConstants[] =
{
    /* flags to service routines */
    { 0, "TPNOBLOCK", TPNOBLOCK },
    { 0, "TPSIGRSTRT", TPSIGRSTRT },
    { 0, "TPNOREPLY", TPNOREPLY },
    { 0, "TPNOTRAN", TPNOTRAN },
    { 0, "TPTRAN", TPTRAN },
    { 0, "TPNOTIME", TPNOTIME },
    { 0, "TPGETANY", TPGETANY },
    { 0, "TPNOCHANGE", TPNOCHANGE },
    { 0, "TPCONV", TPCONV },
    { 0, "TPSENDONLY", TPSENDONLY },
    { 0, "TPRECVONLY", TPRECVONLY },

    /* flags to tpreturn() */
    { 0, "TPFAIL", TPFAIL },
    { 0, "TPSUCCESS", TPSUCCESS },   

    /* tperrno values */
    { 0, "TPEABORT", TPEABORT },
    { 0, "TPEBADDESC", TPEBADDESC },
    { 0, "TPEBLOCK", TPEBLOCK },
    { 0, "TPEINVAL", TPEINVAL },
    { 0, "TPELIMIT", TPELIMIT },
    { 0, "TPENOENT", TPENOENT },
    { 0, "TPEOS", 	TPEOS },
    { 0, "TPEPERM", 	TPEPERM },
    { 0, "TPEPROTO", TPEPROTO },
    { 0, "TPESVCERR", TPESVCERR },
    { 0, "TPESVCFAIL", TPESVCFAIL },
    { 0, "TPESYSTEM", TPESYSTEM },
    { 0, "TPETIME", 	TPETIME },
    { 0, "TPETRAN", 	TPETRAN },
    { 0, "TPGOTSIG", TPGOTSIG },
    { 0, "TPERMERR", TPERMERR },
    { 0, "TPEITYPE", TPEITYPE },
    { 0, "TPEOTYPE", TPEOTYPE },
    { 0, "TPERELEASE", TPERELEASE },
    { 0, "TPEHAZARD", TPEHAZARD },
    { 0, "TPEHEURISTIC", TPEHEURISTIC },
    { 0, "TPEEVENT", TPEEVENT },
    { 0, "TPEMATCH", TPEMATCH },
    { 0, "TPEDIAGNOSTIC", TPEDIAGNOSTIC },
    { 0, "TPEMIB", 	TPEMIB },

    /* ubf constants */
    { 0, "BFLD_SHORT",  BFLD_SHORT },
    { 0, "BFLD_LONG",   BFLD_LONG },
    { 0, "BFLD_CHAR",   BFLD_CHAR },
    { 0, "BFLD_FLOAT",  BFLD_FLOAT },
    { 0, "BFLD_DOUBLE", BFLD_DOUBLE },
    { 0, "BFLD_STRING", BFLD_STRING },
    { 0, "BFLD_CARRAY", BFLD_CARRAY },
    { 0, "BBADFLDID", BBADFLDID },

    /* queue constants */
    { 0, "TPQCORRID", TPQCORRID },
    { 0, "TPQFAILUREQ", TPQFAILUREQ },
    { 0, "TPQBEFOREMSGID", TPQBEFOREMSGID },
    { 0, "TPQGETBYMSGIDOLD", TPQGETBYMSGIDOLD },
    { 0, "TPQMSGID", TPQMSGID },
    { 0, "TPQPRIORITY", TPQPRIORITY },
    { 0, "TPQTOP", TPQTOP },
    { 0, "TPQWAIT", TPQWAIT },
    { 0, "TPQREPLYQ", TPQREPLYQ },
    { 0, "TPQTIME_ABS", TPQTIME_ABS },
    { 0, "TPQTIME_REL", TPQTIME_REL },
    { 0, "TPQGETBYCORRIDOLD", TPQGETBYCORRIDOLD },
    { 0, "TPQPEEK", TPQPEEK },
    { 0, "TPQDELIVERYQOS", TPQDELIVERYQOS },
    { 0, "TPQREPLYQOS", TPQREPLYQOS },
    { 0, "TPQEXPTIME_ABS", TPQEXPTIME_ABS },
    { 0, "TPQEXPTIME_REL", TPQEXPTIME_REL },
    { 0, "TPQEXPTIME_NONE", TPQEXPTIME_NONE },
    { 0, "TPQGETBYMSGID", TPQGETBYMSGID },
    { 0, "TPQGETBYCORRID", TPQGETBYCORRID },
    { 0, "TPQQOSDEFAULTPERSIST", TPQQOSDEFAULTPERSIST },
    { 0, "TPQQOSPERSISTENT", TPQQOSPERSISTENT },
    { 0, "TPQQOSNONPERSISTENT", TPQQOSNONPERSISTENT }

#ifndef WIN32
    ,{ 0, "SIGHUP", SIGHUP },
    { 0, "SIGINT", SIGINT },
    { 0, "SIGQUIT", SIGQUIT },
    { 0, "SIGILL", SIGILL },
    { 0, "SIGTRAP", SIGTRAP },
    { 0, "SIGIOT", SIGIOT },
    { 0, "SIGABRT", SIGABRT },
    { 0, "SIGFPE", SIGFPE },
    { 0, "SIGKILL", SIGKILL },
    { 0, "SIGBUS", SIGBUS },
    { 0, "SIGSEGV", SIGSEGV },
    { 0, "SIGSYS", SIGSYS },
    { 0, "SIGPIPE", SIGPIPE },
    { 0, "SIGALRM", SIGALRM },
    { 0, "SIGTERM", SIGTERM },
    { 0, "SIGUSR1", SIGUSR1 },
    { 0, "SIGUSR2", SIGUSR2 },
    { 0, "SIGCLD", SIGCLD },
    { 0, "SIGCHLD", SIGCHLD },
    { 0, "SIGPWR", SIGPWR },
    { 0, "SIGWINCH", SIGWINCH },
    { 0, "SIGURG", SIGURG },
    { 0, "SIGPOLL", SIGPOLL },
    { 0, "SIGIO", SIGIO }
#endif
};

/* The mixing step */
#define mix(a,b,c) \
{ \
  a=a-b;  a=a-c;  a=a^(c>>13); \
  b=b-c;  b=b-a;  b=b^(a<<8);  \
  c=c-a;  c=c-b;  c=c^(b>>13); \
  a=a-b;  a=a-c;  a=a^(c>>12); \
  b=b-c;  b=b-a;  b=b^(a<<16); \
  c=c-a;  c=c-b;  c=c^(b>>5);  \
  a=a-b;  a=a-c;  a=a^(c>>3);  \
  b=b-c;  b=b-a;  b=b^(a<<10); \
  c=c-a;  c=c-b;  c=c^(b>>15); \
}

/* The whole new hash function */
u4 hash( k, initval)
register u1 *k;        /* the key */
u4           initval;  /* the previous hash, or an arbitrary value */
{

   register u4 a,b,c;  /* the internal state */
   u4          length = strlen( (char *)k );
   u4          len;    /* how many key bytes still need mixing */

   /* Set up the internal state */
   len = length;
   a = b = 0x9e3779b9;  /* the golden ratio; an arbitrary value */
   c = initval;         /* variable initialization of internal state */

   /*---------------------------------------- handle most of the key */
   while (len >= 12)
   {
      a=a+(k[0]+((u4)k[1]<<8)+((u4)k[2]<<16) +((u4)k[3]<<24));
      b=b+(k[4]+((u4)k[5]<<8)+((u4)k[6]<<16) +((u4)k[7]<<24));
      c=c+(k[8]+((u4)k[9]<<8)+((u4)k[10]<<16)+((u4)k[11]<<24));
      mix(a,b,c);
      k = k+12; len = len-12;
   }

   /*------------------------------------- handle the last 11 bytes */
   c = c+length;
   switch(len)              /* all the case statements fall through */
   {
   case 11: c=c+((u4)k[10]<<24);
   case 10: c=c+((u4)k[9]<<16);
   case 9 : c=c+((u4)k[8]<<8);
      /* the first byte of c is reserved for the length */
   case 8 : b=b+((u4)k[7]<<24);
   case 7 : b=b+((u4)k[6]<<16);
   case 6 : b=b+((u4)k[5]<<8);
   case 5 : b=b+k[4];
   case 4 : a=a+((u4)k[3]<<24);
   case 3 : a=a+((u4)k[2]<<16);
   case 2 : a=a+((u4)k[1]<<8);
   case 1 : a=a+k[0];
     /* case 0: nothing left to add */
   }
   mix(a,b,c);
   /*-------------------------------------------- report the result */
   return c;
}


static int compare( const void *a, const void *b )
{
    if ( ((NamedConstant *)a)->hash < ((NamedConstant *)b)->hash ) return -1;
    if ( ((NamedConstant *)a)->hash > ((NamedConstant *)b)->hash ) return  1;
    return ( strcmp( ((NamedConstant *)a)->name, ((NamedConstant *)b)->name ) );
}

static int tableInitialized = 0;

void InitEnduroxConstants()
{
    u4 hashVal = 0;
    long tableSize = sizeof(namedConstants)/sizeof(NamedConstant);
    long i = 0;

    if ( tableInitialized )
        return;

    for ( i = 0; i < tableSize; i++ )
    {
        hashVal = hash( namedConstants[i].name, 0 );
        namedConstants[i].hash = hashVal;
    }

    qsort( namedConstants, 
           sizeof(namedConstants)/sizeof(NamedConstant),
           sizeof(NamedConstant),
           compare
           );

    tableInitialized = 1;
}

long 
getEnduroxConstant( char *name )
{
    NamedConstant key, * nc;
    key.name = name;
    key.hash = hash( name, 0 );
    nc = (NamedConstant *)bsearch( &key, 
                                   namedConstants,
                                   sizeof(namedConstants)/sizeof(NamedConstant),
                                   sizeof(NamedConstant),
                                   compare
                                   );
    if ( nc != NULL )
    {
        errno = 0;
        return nc->value;
    }

   errno = EINVAL;
   return 0;
}


