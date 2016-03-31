#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include <atmi.h>
#include <ubf.h>
#include <ubf.h>
#include <xa.h>
#include <userlog.h>

/*----------------------------------------------------------------------------
 * debinitions
 *----------------------------------------------------------------------------*/
#define PERL_ENDUROX_ERROR       (-0x0FFFFFFF)

#ifdef is_cplusplus
#  ifndef EXTERN_C
#    define EXTERN_C extern "C"
#  endif
#else
#  ifndef EXTERN_C
#    define EXTERN_C extern
#  endif
#endif

/*----------------------------------------------------------------------------
 * function prototypes
 *----------------------------------------------------------------------------*/
void InitEnduroxConstants();
long getEnduroxConstant( char *name );
void xs_init _((void)); 

/*----------------------------------------------------------------------------
 * type debinitions
 *----------------------------------------------------------------------------*/
typedef char *          CHAR_PTR;
typedef char *          STRING_PTR;
typedef TPINIT *        TPINIT_PTR;
typedef UBFH *        UBFH_PTR;
typedef CLIENTID *      CLIENTID_PTR;
typedef TPTRANID *      TPTRANID_PTR;
typedef XID *           XID_PTR;
typedef TPQCTL *        TPQCTL_PTR;
typedef TPEVCTL *       TPEVCTL_PTR;
typedef TPSVCINFO *     TPSVCINFO_PTR;


/*----------------------------------------------------------------------------
 * global variables
 *----------------------------------------------------------------------------*/
static HV * UnsolicitedHandlerMap = (HV *)NULL;
static HV * signum                = (HV *)NULL;
static HV * SignalHandlerMap      = (HV *)NULL;

/*----------------------------------------------------------------------------
 * 'C' functions used by this module
 *----------------------------------------------------------------------------*/
/*
 * Comment this function out because it get_hv doesn't work with
 * perl 5.005_03 on solaris.  I shouldn't really have this function
 * anyway.
 *
static void
signum_init()
{
    int signumIV;
    char *sig_num;
    char *sig_name;
    char *numDelim;
    char *nameDelim;
    STRLEN n_a;
    SV **svPtr;

    HV * Config = get_hv( "Config", FALSE );

    if ( Config == NULL )
        croak( "Could not access the %%Config variable to get signal names and numbers.\n" );

    svPtr = hv_fetch( Config, (char *)"sig_num", strlen("sig_num"), FALSE );
    if ( svPtr == (SV**)NULL )
        croak( "Could not get the value of $Config{sig_num}.\n" );
    sig_num = SvPV( *svPtr, n_a );

    svPtr = hv_fetch( Config, (char *)"sig_name", strlen("sig_name"), FALSE );
    if ( svPtr == (SV**)NULL )
        croak( "Could not get the value of $Config{sig_name}.\n" );
    sig_name = SvPV( *svPtr, n_a );

    signum = newHV();
    for ( ; ; )
    {
        numDelim  = strchr( sig_num + 1, ' ' );
        nameDelim = strchr( sig_name + 1, ' ' );

        if ( numDelim != NULL ) *numDelim = '\0';
        if ( nameDelim != NULL ) *nameDelim = '\0';

        sscanf( sig_num, "%d", &signumIV );

        hv_store( signum, 
                  (char*)sig_name, 
                  strlen(sig_name), 
                  newSViv(signumIV),
                  0
                  );

        if ( numDelim == NULL || nameDelim == NULL ) break;

        sig_num  = numDelim + 1;
        sig_name = nameDelim + 1;
    }

}

*/


static void
signal_handler( sig_num )
    int sig_num;
{
    dSP ;
    SV ** sv;

    /* get the callback handler associated with this context */
    sv = hv_fetch( SignalHandlerMap, 
                   (char *)&sig_num,
                   sizeof(sig_num),
                   FALSE
                   );

    if ( sv == (SV**)NULL )
        croak( "Could not find signal handler for signal %d.\n",
               sig_num
               );

    PUSHMARK( SP );
    XPUSHs( sv_2mortal(newSViv(sig_num)) );
    PUTBACK ;

    /* call the Perl sub */
    perl_call_sv( *sv, G_DISCARD );
}

int buffer_setref( SV * sv, char *buffer )
{
    char type[16];

    int rc = tptypes( buffer, type, NULL );
    if ( rc != -1 )
    {
        if ( !strcmp(type, "TPINIT") )
            sv_setref_pv(sv, "TPINIT_PTR", (void*)buffer);
        else if ( !strcmp(type, "UBF") )
            sv_setref_pv(sv, "UBFH_PTR", (void*)buffer);
        else if ( !strcmp(type, "STRING") )
            sv_setref_pv(sv, "STRING_PTR", (void*)buffer);
        else
            sv_setref_pv(sv, Nullch, (void*)buffer);
    }
    return rc;
}


/*----------------------------------------------------------------------------
 * server only 'C' functions
 *----------------------------------------------------------------------------*/
static HV * serviceMap = (HV *)NULL;
static PerlInterpreter *embedded_perl;

EXTERN_C
int tpsvrinit( int argc, char *argv[] )
{
    char *embedding[] = { "", "perlsvr.pl" };
    int rc = 0;

    embedded_perl = perl_alloc();
    if ( embedded_perl == NULL )
    {
        userlog( "Failed to instantiated Perl interpretor." );
        return -1;
    }

    perl_construct( embedded_perl );
/* mv  porting to enduro/x: */
    rc = perl_parse( embedded_perl, xs_init, 2, embedding, NULL );
    /* rc = perl_parse( embedded_perl, NULL, 2, embedding, NULL );*/
    if ( rc != 0 )
    {
        userlog( "Failed to parse perlsvr.pl" );
        perl_destruct( embedded_perl );
        perl_free( embedded_perl );
        return -1;
    }

    perl_run( embedded_perl );
    return 0;
}

EXTERN_C
void tpsvrdone()
{
    perl_destruct( embedded_perl );
    perl_free( embedded_perl );
}

EXTERN_C
void PERL( TPSVCINFO * tpsvcinfo )
{
    int rc;
    char type[16];
    SV * rv;
    SV ** sub;
    SV   *rData = NULL;
    dSP;

    /* return values from perl function call */
    int rval    = TPFAIL;
    long rcode  = PERL_ENDUROX_ERROR;
    char *data  = NULL;
    long len    = 0;
    long flags  = 0;

    /* get the perl sub associated with this service */
    sub = hv_fetch( serviceMap, 
                    (char *)tpsvcinfo->name,
                    strlen(tpsvcinfo->name),
                    FALSE
                    );

    if ( sub == (SV**)NULL )
    {
        /* this is a serious error */
        data = tpalloc( "STRING", 0, 1024 );
        if ( data != NULL )
            sprintf( data, "%s is not associated with a perl sub", tpsvcinfo->name );
        tpreturn( TPFAIL, 0, data, 0, 0 );
    }

    /* set up the perl stack */
    ENTER;
    SAVETMPS;
    PUSHMARK(SP);
    PUTBACK;

    /* create the TPSVCINFO reference and push it onto the stack */
    rv = sv_newmortal();
    sv_setref_pv(rv, "TPSVCINFO_PTR", (void*)tpsvcinfo);
    XPUSHs( rv );
    PUTBACK;

    /* call the perl sub */
    rc = perl_call_sv( *sub, G_EVAL | G_ARRAY );

    SPAGAIN;

    /* check the eval first */
    if ( SvTRUE(ERRSV) )
    {
        /* the sub died somewhere */
        data = tpalloc( "STRING", 0, 1024 );
        if ( data != NULL )
        {
            sprintf( data, "%s failed with exception: %s", 
                     tpsvcinfo->name, SvPV(ERRSV, PL_na)
                     );
        }

        POPs;
    }
    else if ( rc != 5 )
    {
        /* insufficient parameters returned from the sub */
        data = tpalloc( "STRING", 0, 1024 );
        if ( data != NULL )
        {
            sprintf( data, "%s only returned %d arguments", 
                     tpsvcinfo->name, rc
                     );
        }
    }
    else
    {
        /* extract return values from the stack in reverse order */
        flags = POPl; len = POPl; rData = POPs; rcode = POPl; rval = POPi; 

        /* rData must be a reference to a endurox buffer */
        if ( SvROK(rData) ) 
        {
            data = (CHAR_PTR)SvIV((SV*)SvRV(rData));
        }
        else
        {
            data = tpalloc( "STRING", 0, 1024 );
            if ( data != NULL )
            {
                sprintf( data, "%s returned invalid data reference", 
                         tpsvcinfo->name
                         );
            }
            rval   = TPFAIL; 
            rcode  = PERL_ENDUROX_ERROR; 
            data   = data; 
            len    = 0; 
            flags  = 0; 
        }
    }

    /* clear the perl stack and cleanup */
    PUTBACK;
    FREETMPS;
    LEAVE;

    tpreturn( rval, rcode, data, len, flags );
}

typedef void (* ENDUROXSERVICE)(TPSVCINFO *);
ENDUROXSERVICE gdispatch = PERL;

/*-----------------------------------------------------------------------------
 * xsub functions 
 *----------------------------------------------------------------------------*/
MODULE = Endurox    PACKAGE = Endurox        

BOOT:
    InitEnduroxConstants();


long
constant( name, arg )
    char * name
    int arg
    CODE:
        RETVAL = getEnduroxConstant( name );
    OUTPUT:
        RETVAL

int
tpabort( flags )
    long flags

int
tpadvertise( svcname, callback )
    char *svcname
    SV * callback
    PREINIT:
    CODE:
        RETVAL = tpadvertise( svcname, gdispatch );
        if ( RETVAL != -1 )
        {
            if ( serviceMap == (HV*)NULL )
                serviceMap = newHV();

            hv_store( serviceMap, 
                      svcname,
                      strlen(svcname), 
                      newSVsv(callback),
                      0
                      );
        }
    OUTPUT:
        RETVAL

void
tpalloc(type,subtype,size)
    char *type
    char *subtype
    long size
    PREINIT:
        char *ptr;
    CODE:
        ptr = tpalloc( type, subtype, size );
        ST(0) = sv_newmortal();
        if ( ptr )
        {
            if ( !strcmp(type, "TPINIT") )
                sv_setref_pv(ST(0), "TPINIT_PTR", (void*)ptr);
            else if ( !strcmp(type, "UBF") )
                sv_setref_pv(ST(0), "UBFH_PTR", (void*)ptr);
            else if ( !strcmp(type, "STRING") )
                sv_setref_pv(ST(0), "STRING_PTR", (void*)ptr);
            else
                sv_setref_pv(ST(0), Nullch, (void*)ptr);
        }
        else
        {
            ST(0) = &PL_sv_undef;
        }

int
tpbegin( timeout, flags )
    unsigned long timeout
    long flags

int
tpcancel( cd )
    int cd

int
tpclose()

int
tpcommit( flags )
    long flags

int
tpconnect( svc, data, len, flags )
    char * svc
    SV * data
    long len
    long flags
    PREINIT:
        CHAR_PTR data_  = NULL;
    CODE:
        if ( data != &PL_sv_undef )
        {
            if (!SvROK(data)) 
                croak("data is not a reference");
            data_ = (CHAR_PTR)SvIV((SV*)SvRV(data));
        }

        RETVAL = tpconnect( svc, data_, len, flags );
    OUTPUT:
        RETVAL

int
tpdequeue( qspace, qname, ctl, data, len, flags )
    char * qspace
    char * qname
    TPQCTL_PTR ctl
    SV * data
    long len
    long flags
    PREINIT:
    char *obuf;
    CODE:
	if (SvROK(data)) {
	    IV tmp = SvIV((SV*)SvRV(data));
	    obuf = (CHAR_PTR) tmp;
	}
	else
	    croak("data is not a reference");

        RETVAL = tpdequeue( qspace, qname, ctl, &obuf, &len, flags );
	sv_setiv(SvRV(data), (IV)obuf);
    OUTPUT:
        RETVAL
        len

int
tpdiscon( cd )
    int cd

int
tpenqueue( qspace, qname, ctl, data, len, flags )
    char * qspace
    char * qname
    TPQCTL_PTR ctl
    CHAR_PTR data
    long len
    long flags
    CODE:
        RETVAL = tpenqueue( qspace, qname, ctl, data, len, flags );
    OUTPUT:
        RETVAL

int
tperrno()
    CODE:
        RETVAL = tperrno;
    OUTPUT:
        RETVAL

void
tpfree( ptr )
    SV * ptr
    PREINIT:
    char *buf;
    CODE:
	if (SvROK(ptr)) {
	    IV tmp = SvIV((SV*)SvRV(ptr));
	    buf = (CHAR_PTR) tmp;
	}
	else
	    croak("idata is not a reference");

        tpfree( buf );

        /* set the reference to NULL so that we
         *  know not to free the buffer again.
         */
	sv_setiv(SvRV(ptr), NULL);

int
tpgetlev()

int
tpgetrply( cd, odata, olen, flags )
    int cd
    SV * odata
    long olen
    long flags
    PREINIT:
    char *obuf;
    CODE:
	if (SvROK(odata)) {
	    IV tmp = SvIV((SV*)SvRV(odata));
	    obuf = (CHAR_PTR) tmp;
	}
	else
	    croak("odata is not a reference");

        RETVAL = tpgetrply( &cd, &obuf, &olen, flags );
	sv_setiv(SvRV(odata), (IV)obuf);
    OUTPUT:
        RETVAL
        cd
        olen

int
tpinit( tpinitdata )
    TPINIT_PTR tpinitdata

int
tpopen()

int
tppost( eventname, data, len, flags )
    char * eventname
    SV *   data
    long   len
    long   flags
    PREINIT:
    CHAR_PTR data_  = NULL;
    CODE:
        if ( data != &PL_sv_undef )
        {
            if (!SvROK(data)) 
                croak("data is not a reference");
            data_ = (CHAR_PTR)SvIV((SV*)SvRV(data));
        }

        RETVAL = tppost( eventname, data_, len, flags );
    OUTPUT:
        RETVAL

void
tprealloc( ptr, size )
    SV * ptr
    long     size
    PREINIT:
    CHAR_PTR ptr_;
    CHAR_PTR rval;
    CODE:
        if (!SvROK(ptr)) 
            croak("ptr is not a reference");
        ptr_ = (CHAR_PTR)SvIV((SV*)SvRV(ptr));

        rval = tprealloc( ptr_, size );
        sv_setiv( SvRV(ptr), (IV)rval );

        if ( rval )
        {
            ST(0) = newRV_inc( SvRV(ptr) );
        }
        else
        {
            ST(0) = &PL_sv_undef;
        }

int
tprecv( cd, data, len, flags, revent )
    int cd
    SV * data
    long len
    long flags
    long revent
    PREINIT:
    char * data_ = NULL;
    CODE:
	if (SvROK(data)) {
	    IV tmp = SvIV((SV*)SvRV(data));
	    data_ = (CHAR_PTR) tmp;
	}
	else
	    croak("data is not a reference");

        RETVAL = tprecv( cd, &data_, &len, flags, &revent );
        sv_setiv( SvRV(data), (IV)data_ );
    OUTPUT: 
        RETVAL
        revent

int
tpresume( tranid, flags )
    TPTRANID_PTR tranid
    long flags

int
tpsend( cd, data, len, flags, revent )
    int cd
    SV * data
    long len
    long flags
    long revent
    PREINIT:
    char * data_ = NULL;
    CODE:
        if ( data != &PL_sv_undef )
        {
            if (!SvROK(data)) 
                croak("data is not a reference");
            data_ = (CHAR_PTR)SvIV((SV*)SvRV(data));
        }

        RETVAL = tpsend( cd, data_, len, flags, &revent );
    OUTPUT:
        RETVAL
        revent

char *
tpstrerror( error )
    int error

long
tpsubscribe( eventexpr, filter, ctl, flags )
    char * eventexpr
    char * filter
    SV * ctl
    long flags
    PREINIT:
    TPEVCTL_PTR ctl_ = NULL;
    CODE:
        if ( ctl != &PL_sv_undef )
        {
            if (!SvROK(ctl) || !sv_isa(ctl, "TPEVCTL_PTR") )
                croak("ctl is not a TPEVCTL_PTR reference");
            ctl_ = (TPEVCTL_PTR)SvIV((SV*)SvRV(ctl));
        }
        RETVAL = tpsubscribe( eventexpr, filter, ctl_, flags );
    OUTPUT:
        RETVAL

int
tpsuspend( tranid, flags )
    TPTRANID_PTR tranid
    long flags

int
tpterm()

long
tptypes( ptr, type, subtype )
    CHAR_PTR ptr
    SV * type
    SV * subtype
    PREINIT:
        char type_[8];
        char subtype_[16];
    CODE:
        RETVAL = tptypes( ptr, type_, subtype_ );
        if ( type != &PL_sv_undef )
            sv_setpv( type, type_ );
        if ( subtype != &PL_sv_undef )
            sv_setpv( subtype, subtype_ );
    OUTPUT:
        RETVAL
        type
        subtype

int
tpunsubscribe( subscription, flags )
    long subscription
    long flags

int
tpcall( svc, idata, ilen, odata, len, flags )
    char * svc
    SV * idata
    long ilen
    SV * odata
    long len
    long flags
    PREINIT:
    char *inbuf;
    char *obuf;
    CODE:

	if (SvROK(idata)) {
	    IV tmp = SvIV((SV*)SvRV(idata));
	    inbuf = (CHAR_PTR) tmp;
	}
	else
	    croak("idata is not a reference");

	if (SvROK(odata)) {
	    IV tmp = SvIV((SV*)SvRV(odata));
	    obuf = (CHAR_PTR) tmp;
	}
	else
	    croak("odata is not a reference");

        RETVAL = tpcall( svc, inbuf, ilen, &obuf, &len, flags );

        /* we don't want the destructor called when
         * we update the odata reference, so we can't call
         * sv_setref_pv, because this will decrement the reference
         * counter of the odata reference, and potentially call the
         * destructor.  Instead I explicitely set the value of the
         * pointer held by the odata reference.
         */
	sv_setiv(SvRV(odata), (IV)obuf);

        if ( RETVAL == TPFAIL && tpurcode == PERL_ENDUROX_ERROR )
        {
            croak( "tpcall failed with server side perl error: %s", obuf );
        }

    OUTPUT:
        RETVAL
        len

int
tpacall( svc, idata, ilen, flags )
    char * svc
    CHAR_PTR idata
    long ilen
    long flags
    CODE:
        RETVAL = tpacall( svc, idata, ilen, flags );
    OUTPUT:
        RETVAL

int
userlog( message )
    char * message

int
Berror()
    CODE:
        RETVAL = Berror;
    OUTPUT:
        RETVAL

char *
Bstrerror( err )
    int err
    
int
Badd( ubfh, fieldid, value, len )
    UBFH_PTR  ubfh
    BFLDID     fieldid
    SV *        value
    BFLDLEN    len
    PREINIT:
    IV          iv_val;
    double      nv_val;
    char *      pv_val;
    STRLEN      pv_len;
    char *      value_ptr;
    CODE:
        if ( SvROK( value ) )
        {
	    IV tmp = SvIV((SV*)SvRV(value));
	    value_ptr = (char *) tmp;
        }
        else if ( SvIOK(value) )
        {
            iv_val = SvIV( value );
            value_ptr = (char *)&iv_val;
        }
        else if ( SvNOK(value) )
        {
            nv_val = SvNV( value );
            value_ptr = (char *)&nv_val;
        }
        else if ( SvPOK(value) )
        {
            pv_val = SvPV( value, pv_len );
            value_ptr = pv_val;
        }

        RETVAL = Badd( ubfh, fieldid, value_ptr, len );
    OUTPUT:
        RETVAL

int
Bget( ubfh, fieldid, oc, loc, maxlen )
    UBFH_PTR  ubfh
    BFLDID     fieldid
    BFLDOCC    oc
    SV *        loc
    SV *    maxlen
    PREINIT:
    char *      val;
    char        cval;
    long        lval;
    short       sval;
    float       fval;
    double      dval;
    BFLDLEN    len = 0;
    CODE:
        /* get the length of the field */
        val = Bfind( ubfh, fieldid, oc, &len );
        if ( val != NULL )
        {
            switch ( Bfldtype(fieldid) )
            {
                case BFLD_SHORT:
                    Bget( ubfh, fieldid, oc, (char *)&sval, &len );
                    sv_setiv( loc, sval );
                    break;

                case BFLD_LONG:
                    Bget( ubfh, fieldid, oc, (char *)&lval, &len );
                    sv_setiv( loc, lval );
                    break;

                case BFLD_CHAR:
                    Bget( ubfh, fieldid, oc, (char *)&cval, &len );
                    sv_setiv( loc, cval );
                    break;

                case BFLD_FLOAT:
                    Bget( ubfh, fieldid, oc, (char *)&fval, &len );
                    sv_setnv( loc, fval) ;
                    break;

                case BFLD_DOUBLE:
                    Bget( ubfh, fieldid, oc, (char *)&dval, &len );
                    sv_setnv( loc, dval );
                    break;

                case BFLD_STRING:
                case BFLD_CARRAY:
                    sv_setpvn( loc, val, len );
                    break;
            }

            if ( maxlen != &PL_sv_undef )
            {
                sv_setuv(maxlen, (UV)len);
                SvSETMAGIC(maxlen);
            }
        }
        else
        {
            RETVAL = -1;
        }
    OUTPUT:
        RETVAL
        loc

int
Bindex( ubfh, intvl )
    UBFH_PTR ubfh
    BFLDOCC   intvl

int
Bprint( ubfh )
    UBFH_PTR ubfh

BFLDID
Bmkfldid( type, num )
    int type
    BFLDID num



MODULE = Endurox        PACKAGE = CHAR_PTR        

void
DESTROY( char_ptr )
    CHAR_PTR  char_ptr
    CODE:
        /* printf( "CHAR_PTR::DESTROY()\n" ); */
        if ( char_ptr != NULL )
        {
	    /* printf( "calling tpfree( 0x%p )\n", char_ptr ); */
            tpfree( char_ptr );
            /* printf( "finished calling tpfree\n" ); */
        }

MODULE = Endurox        PACKAGE = STRING_PTR        

char *
value( obj, ... )
    STRING_PTR obj
    PREINIT:
    char *value = NULL;
    long size   = 0;
    STRLEN n_a;
    CODE:
        if ( items > 1 )
        {
            value = (char *)SvPV( ST(1), n_a );

            /* get the size of the buffer */
            size = tptypes( obj, NULL, NULL );
            if ( size == -1 )
	        croak( "STRING_PTR::value() failed: %s", tpstrerror(tperrno) );

            if ( size <= (long)strlen(value) )
            {
                /* need to allocate more space */
                obj = tprealloc( obj, strlen(value) + 1 );
                if ( obj == NULL )
	            croak( "STRING_PTR::value() failed: %s", tpstrerror(tperrno) );

                /* the obj pointer could have changed, so reset the reference */
                sv_setref_pv(ST(0), "STRING_PTR", (void*)obj);
            }

            strcpy( obj, value );
        }
        RETVAL = obj;
    OUTPUT:
        RETVAL


MODULE = Endurox        PACKAGE = TPINIT_PTR        

char *
usrname( obj, ... )
    TPINIT_PTR obj
    PREINIT:
    char *usrname;
    STRLEN n_a;
    CODE:
        if ( items > 1 )
        {
            usrname = (char *)SvPV( ST(1), n_a );
            strcpy( obj->usrname, usrname );
        }
        RETVAL = obj->usrname;
    OUTPUT:
        RETVAL

char *
cltname( obj, ... )
    TPINIT_PTR obj
    PREINIT:
    char *cltname;
    STRLEN n_a;
    CODE:
        if ( items > 1 )
        {
            cltname = (char *)SvPV( ST(1), n_a );
            strcpy( obj->cltname, cltname );
        }
        RETVAL = obj->cltname;
    OUTPUT:
        RETVAL

char *
passwd( obj, ... )
    TPINIT_PTR obj
    PREINIT:
    char *passwd;
    STRLEN n_a;
    CODE:
        if ( items > 1 )
        {
            passwd = (char *)SvPV( ST(1), n_a );
            strcpy( obj->passwd, passwd );
        }
        RETVAL = obj->passwd;
    OUTPUT:
        RETVAL

char *
grpname( obj, ... )
    TPINIT_PTR obj
    PREINIT:
    char *grpname;
    STRLEN n_a;
    CODE:
        if ( items > 1 )
        {
            grpname = (char *)SvPV( ST(1), n_a );
            strcpy( obj->grpname, grpname );
        }
        RETVAL = obj->grpname;
    OUTPUT:
        RETVAL

long
flags( obj, ... )
    TPINIT_PTR obj
    PREINIT:
    long flags;
    CODE:
        if ( items > 1 )
        {
            flags = (long)SvIV( ST(1) );
            obj->flags = flags;
        }
        RETVAL = obj->flags;
    OUTPUT:
        RETVAL

long
datalen( obj, ... )
    TPINIT_PTR obj
    PREINIT:
    long datalen;
    CODE:
        if ( items > 1 )
        {
            datalen = (long)SvIV( ST(1) );
            obj->datalen = datalen;
        }
        RETVAL = obj->datalen;
    OUTPUT:
        RETVAL

char *
data( obj, ... )
    TPINIT_PTR obj
    PREINIT:
    char *data;
    STRLEN n_a;
    CODE:
        if ( items > 1 )
        {
            data = (char *)SvPV( ST(1), n_a );
            strcpy( (char *)&(obj->data), data );
        }
        RETVAL = (char *)&(obj->data);
    OUTPUT:
        RETVAL


MODULE = Endurox        PACKAGE = UBFH_PTR        


MODULE = Endurox        PACKAGE = CLIENTID_PTR

void
new()
    PREINIT:
        char *ptr;
    CODE:
        /* ptr = calloc( 1, sizeof(CLIENTID) ); */
        ptr = malloc( sizeof(CLIENTID) );
        memset( ptr, 0, sizeof(CLIENTID) );
	/* printf( "calloc returned 0x%p\n", ptr ); */
        ST(0) = sv_newmortal();
        if ( ptr != NULL )
            sv_setref_pv(ST(0), "CLIENTID_PTR", ptr);
        else
            ST(0) = &PL_sv_undef;

void
DESTROY( clientid_ptr )
    CLIENTID_PTR  clientid_ptr
    CODE:
        /* printf( "CLIENTID_PTR::DESTROY()\n" ); */
        if ( clientid_ptr != NULL )
        {
	    /* printf( "free( 0x%p )\n", clientid_ptr ); */
            free( (char *)clientid_ptr );
            /* printf( "finished calling free.\n" ); */
        }

void
clientdata( obj, ... )
    CLIENTID_PTR obj
    PREINIT:
        long arraysize;
        int i;
    PPCODE:
        arraysize = sizeof(obj->clientdata)/sizeof(long);
        if ( items > 1 )
        {
            if ( items > 5 )
                croak( "More than 4 elements provided for clientdata.\n" );

            for ( i = 1; i < items; i++ )
                obj->clientdata[i-1] = SvIV((SV*)ST(i));
        }

        EXTEND(SP, arraysize);
        for ( i = 0; i < arraysize; i++ )
            PUSHs( sv_2mortal(newSViv( obj->clientdata[i])) );


MODULE = Endurox        PACKAGE = TPTRANID_PTR
void
new()
    PREINIT:
        char *ptr;
    CODE:
        /* ptr = calloc( 1, sizeof(TPTRANID) ); */
        ptr = malloc( sizeof(TPTRANID) );
        memset( ptr, 0, sizeof(TPTRANID) );
        ST(0) = sv_newmortal();
        if ( ptr != NULL )
            sv_setref_pv(ST(0), "TPTRANID_PTR", ptr);
        else
            ST(0) = &PL_sv_undef;

void
DESTROY( tptranid_ptr )
    TPTRANID_PTR  tptranid_ptr
    CODE:
        /* printf( "TPTRANID_PTR::DESTROY()\n" ); */
        if ( tptranid_ptr != NULL )
        {
            /* printf( "free( 0x%p )\n", tptranid_ptr ); */
            free( (char *)tptranid_ptr );
            /* printf( "finished calling free.\n" ); */
        }

MODULE = Endurox        PACKAGE = XID_PTR
void
new()
    PREINIT:
        char *ptr;
    CODE:
        /* ptr = calloc( 1, sizeof(XID) ); */
        ptr = malloc( sizeof(XID) );
        memset( ptr, 0, sizeof(XID) );
        ST(0) = sv_newmortal();
        if ( ptr != NULL )
            sv_setref_pv(ST(0), "XID_PTR", ptr);
        else
            ST(0) = &PL_sv_undef;

void
DESTROY( obj )
    XID_PTR  obj
    CODE:
        if ( obj != NULL )
        {
            /* printf( "%s:%d free( 0x%p )\n", __FILE__, __LINE__, obj ); */
            free( (char *)obj );
            /* printf( "finished calling free.\n" ); */
        }

long 
formatID( obj, ... )
    XID_PTR obj
    CODE:
        if ( items > 1 )
            obj->formatID = (long)SvIV((SV*)ST(1));

        RETVAL = obj->formatID;
    OUTPUT:
        RETVAL

long 
gtrid_length( obj, ... )
    XID_PTR obj
    CODE:
        if ( items > 1 )
            obj->gtrid_length = (long)SvIV((SV*)ST(1));

        RETVAL = obj->gtrid_length;
    OUTPUT:
        RETVAL

long 
bqual_length( obj, ... )
    XID_PTR obj
    CODE:
        if ( items > 1 )
            obj->bqual_length = (long)SvIV((SV*)ST(1));

        RETVAL = obj->bqual_length;
    OUTPUT:
        RETVAL

char *
data( obj, ... )
    XID_PTR obj
    PREINIT:
    STRLEN n_a;
    CODE:
        if ( items > 1 )
            strcpy( obj->data, SvPV((SV*)ST(1), n_a) );

        RETVAL = obj->data;
    OUTPUT:
        RETVAL

MODULE = Endurox        PACKAGE = TPQCTL_PTR

void
new()
    PREINIT:
        char *ptr;
    CODE:
        /* ptr = calloc( 1, sizeof(TPQCTL) ); */
        ptr = malloc( sizeof(TPQCTL) );
        memset( ptr, 0, sizeof(TPQCTL) );
        ST(0) = sv_newmortal();
        if ( ptr != NULL )
            sv_setref_pv(ST(0), "TPQCTL_PTR", ptr);
        else
            ST(0) = &PL_sv_undef;

void
DESTROY( obj )
    TPQCTL_PTR  obj
    CODE:
        if ( obj != NULL )
        {
            /* printf( "%s:%d free( 0x%p )\n", __FILE__, __LINE__, obj ); */
            free( (char *)obj );
        }

long 
flags( obj, ... )
    TPQCTL_PTR obj
    CODE:
        if ( items > 1 )
            obj->flags = (long)SvIV((SV*)ST(1));
        RETVAL = obj->flags;
    OUTPUT:
        RETVAL

long 
deq_time( obj, ... )
    TPQCTL_PTR obj
    CODE:
        if ( items > 1 )
            obj->deq_time = (long)SvIV((SV*)ST(1));
        RETVAL = obj->deq_time;
    OUTPUT:
        RETVAL


long 
priority( obj, ... )
    TPQCTL_PTR obj
    CODE:
        if ( items > 1 )
            obj->priority = (long)SvIV((SV*)ST(1));
        RETVAL = obj->priority;
    OUTPUT:
        RETVAL


long 
diagnostic( obj, ... )
    TPQCTL_PTR obj
    CODE:
        if ( items > 1 )
            obj->diagnostic = (long)SvIV((SV*)ST(1));
        RETVAL = obj->diagnostic;
    OUTPUT:
        RETVAL


char *
msgid( obj, ... )
    TPQCTL_PTR obj
    PREINIT:
    STRLEN n_a;
    CODE:
        if ( items > 1 )
            strcpy( obj->msgid, (char *)SvPV((SV*)ST(1), n_a) );
        RETVAL = obj->msgid;
    OUTPUT:
        RETVAL


char *
corrid( obj, ... )
    TPQCTL_PTR obj
    PREINIT:
    STRLEN n_a;
    CODE:
        if ( items > 1 )
            strcpy( obj->corrid, (char *)SvPV((SV*)ST(1), n_a) );
        RETVAL = obj->corrid;
    OUTPUT:
        RETVAL


char *
replyqueue( obj, ... )
    TPQCTL_PTR obj
    PREINIT:
    STRLEN n_a;
    CODE:
        if ( items > 1 )
            strcpy( obj->replyqueue, (char *)SvPV((SV*)ST(1), n_a) );
        RETVAL = obj->replyqueue;
    OUTPUT:
        RETVAL


char *
failurequeue( obj, ... )
    TPQCTL_PTR obj
    PREINIT:
    STRLEN n_a;
    CODE:
        if ( items > 1 )
            strcpy( obj->failurequeue, (char *)SvPV((SV*)ST(1), n_a) );
        RETVAL = obj->failurequeue;
    OUTPUT:
        RETVAL


void 
cltid( obj, ... )
    TPQCTL_PTR obj
    CODE:
        ST(0) = sv_newmortal();
		sv_setref_pv(ST(0), "CLIENTID_PTR", (void*)&obj->cltid);
        SvREFCNT_inc( SvRV(ST(0)) );


long 
urcode( obj, ... )
    TPQCTL_PTR obj
    CODE:
        if ( items > 1 )
            obj->urcode = (long)SvIV((SV*)ST(1));
        RETVAL = obj->urcode;
    OUTPUT:
        RETVAL


long 
appkey( obj, ... )
    TPQCTL_PTR obj
    CODE:
        if ( items > 1 )
            obj->appkey = (long)SvIV((SV*)ST(1));
        RETVAL = obj->appkey;
    OUTPUT:
        RETVAL


long 
delivery_qos( obj, ... )
    TPQCTL_PTR obj
    CODE:
        if ( items > 1 )
            obj->delivery_qos = (long)SvIV((SV*)ST(1));
        RETVAL = obj->delivery_qos;
    OUTPUT:
        RETVAL


long 
reply_qos( obj, ... )
    TPQCTL_PTR obj
    CODE:
        if ( items > 1 )
            obj->reply_qos = (long)SvIV((SV*)ST(1));
        RETVAL = obj->reply_qos;
    OUTPUT:
        RETVAL


long 
exp_time( obj, ... )
    TPQCTL_PTR obj
    CODE:
        if ( items > 1 )
            obj->exp_time = (long)SvIV((SV*)ST(1));
        RETVAL = obj->exp_time;
    OUTPUT:
        RETVAL

MODULE = Endurox        PACKAGE = TPEVCTL_PTR

void
new()
    PREINIT:
        char *ptr;
    CODE:
        /* ptr = calloc( 1, sizeof(TPEVCTL) ); */
        ptr = malloc( sizeof(TPEVCTL) );
        memset( ptr, 0, sizeof(TPEVCTL) );
        ST(0) = sv_newmortal();
        if ( ptr != NULL )
            sv_setref_pv(ST(0), "TPEVCTL_PTR", ptr);
        else
            ST(0) = &PL_sv_undef;

void
DESTROY( obj )
    TPEVCTL_PTR  obj
    CODE:
        if ( obj != NULL )
        {
            /* printf( "%s:%d free( 0x%p )\n", __FILE__, __LINE__, obj ); */
            free( (char *)obj );
        }

long 
flags( obj, ... )
    TPEVCTL_PTR obj
    CODE:
        if ( items > 1 )
            obj->flags = (long)SvIV((SV*)ST(1));
        RETVAL = obj->flags;
    OUTPUT:
        RETVAL

char *
name1( obj, ... )
    TPEVCTL_PTR obj
    PREINIT:
    STRLEN n_a;
    CODE:
        if ( items > 1 )
            strcpy( obj->name1, (char *)SvPV((SV*)ST(1), n_a) );
        RETVAL = obj->name1;
    OUTPUT:
        RETVAL

char *
name2( obj, ... )
    TPEVCTL_PTR obj
    PREINIT:
    STRLEN n_a;
    CODE:
        if ( items > 1 )
            strcpy( obj->name2, (char *)SvPV((SV*)ST(1), n_a) );
        RETVAL = obj->name2;
    OUTPUT:
        RETVAL

MODULE = Endurox        PACKAGE = TPSVCINFO_PTR

void 
data( obj )
    TPSVCINFO_PTR obj
    CODE:
        ST(0) = sv_newmortal();
        buffer_setref( ST(0), obj->data );

char *
name( obj )
    TPSVCINFO_PTR obj
    CODE:
        RETVAL = obj->name;
    OUTPUT:
        RETVAL

long
flags( obj )
    TPSVCINFO_PTR obj
    CODE:
        RETVAL = obj->flags;
    OUTPUT:
        RETVAL

long
len( obj )
    TPSVCINFO_PTR obj
    CODE:
        RETVAL = obj->len;
    OUTPUT:
        RETVAL

int
cd( obj )
    TPSVCINFO_PTR obj
    CODE:
        RETVAL = obj->cd;
    OUTPUT:
        RETVAL

long
appkey( obj )
    TPSVCINFO_PTR obj
    CODE:
        RETVAL = obj->appkey;
    OUTPUT:
        RETVAL

void 
cltid( obj )
    TPSVCINFO_PTR obj
    CODE:
        ST(0) = sv_newmortal();
		sv_setref_pv(ST(0), "CLIENTID_PTR", (void*)&obj->cltid);
        SvREFCNT_inc( SvRV(ST(0)) );

