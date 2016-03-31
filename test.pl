# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

######################### We start with some black magic to print on failure.

# Change 1..1 below to 1..last_test_to_print .
# (It may become useful if the test is moved to ./t subdirectory.)

BEGIN { $| = 1; print "1..1\n"; }
END {print "not ok 1\n" unless $loaded;}
use Endurox;
use tpadm;
use testflds;
require "genubbconfig.pl";


# Insert your test code below (better if it prints "ok 13"
# (correspondingly "not ok 13") depending on the success of chunk 13
# of the test code):

###################################################################
# Create a ubbconfig and boot the endurox system that this test
# script will connect to as a workstation endurox client.
###################################################################
ndrxputenv( "NDRXCONFIG=" . get_ndrxconfig() );
$path = ndrxgetenv( "PATH" );
ndrxputenv( "PATH=$path;./blib/arch/auto/Endurox" );
system( "tmshutdown -y" );

gen_ubbconfig();
if ( system( "tmloadcf -y ubbconfig" ) ) { die "tmloadcf failed\n"; }
system( "tmboot -y" );

$loaded = 1;
print "ok 1\n";

######################### End of black magic.

###################################################################
# Connect to the endurox system
###################################################################
# TEST 1: tpalloc
my $password = "00000031". "\377" . "0" . "\377" . "utp_tester1" . "\377"  . "utputp1" . "\377";
my $buffer = tpalloc( "TPINIT", "", 100 );
if ( $buffer == undef ) {
    die "tpalloc failed: " . tpstrerror(tperrno) . "\n";
}

$buffer->usrname( "utp_tester1" );
$buffer->cltname( "perl" );
$buffer->flags( TPMULTICONTEXTS );
$buffer->passwd( "SVEndurox" );
$buffer->data( $password );
print "usrname: " . $buffer->usrname . "\n";
print "cltname: " . $buffer->cltname . "\n";
print "flags:   " . $buffer->flags   . "\n";
print "data:    " . $buffer->data    . "\n";
print "datalen: " . $buffer->datalen . "\n";
print "ok 2\n";

# TEST 2: tptypes
my ($size, $type, $subtype);
$size = tptypes( $buffer, $type, $subtype );
if ( $size == -1 ) {
    die "tptypes failed: " . tpstrerror(tperrno) . "\n";
}
print "SIZE:    " . $size . "\n";
print "TYPE:    " . $type . "\n";
print "SUBTYPE: " . $subtype . "\n";
print "ok 3\n";

# TEST 3: ndrxputenv and ndrxgetenv

print "NDRXCONFIG = " . ndrxgetenv( "NDRXCONFIG" ) . "\n";

# TEST 4: tpinit, tperrno and tpstrerror
my $rval = tpinit( $buffer );
if ( $rval == -1 ) {
    print "tpinit failed: " . tpstrerror(tperrno) . "\n";
}

###################################################################
# Make some MIB service calls
###################################################################
# TEST: Fappend32
my $inubf = tpalloc( "UBF", 0, 1024 );
my $outubf = tpalloc( "UBF", 0, 1024 );
if ( $inubf == undef || $outubf == undef ) {
    die "tpalloc failed: " . tpstrerror(tperrno) . "\n";
}

#$rval = Fappend32( $inubf, BBBADFLDID, 12345, 0 );
#if ( $rval == -1 ) {
#    print "Fappend32 failed: " . Bstrerror( Berror ) . "\n";
#}

$rval = Fappend32( $inubf, TA_CLASS, "T_CLIENT", 0 );
$rval = Fappend32( $inubf, TA_OPERATION, "GET", 0 );
$rval = Bindex( $inubf, 0 );
print "Bindex returned " . $rval . "\n";

ndrxputenv( "FIELDTBLS32=tpadm" );
ndrxputenv( "FLDTBLDIR32=" . ndrxgetenv("NDRX_HOME") . "/udataobj" );
$rval = Bprint( $inubf );

print "calling tpcall...\n";
$rval = tpcall( ".TMIB", $inubf, 0, $outubf, $olen, 0 );
if ( $rval == -1 ) {
    die ( "tpcall failed: " . tpstrerror(tperrno) . ".\n" );
}
$rval = Bprint( $outubf );
print "finished tpcall\n";
print "Press <enter> to continue...";
#$line = <STDIN>;

print "calling tpacall...\n";
$cd = tpacall( ".TMIB", $inubf, 0, 0 );
if ( $cd == -1 ) {
    die ( "tpacallfailed: " . tpstrerror(tperrno) . ".\n" );
}

$rval = tpgetrply( $rcd, $outubf, $olen, TPGETANY );
if ( $rval == -1 ) {
    die ( "tpgetrply failed: " . tpstrerror(tperrno) . ".\n" );
}
$rval = Bprint( $outubf );
print "finished tpacall\n";
print "Press <enter> to continue...";
#$line = <STDIN>;


$rval = Bget( $outubf, TA_OCCURS, 0, $val, $len );
if ( $rval == -1 ) { 
    die ( "Bget failed: " . Bstrerror(Berror) . ".\n" );
}
print "TA_OCCURS = " . $val . "\n";

# TEST : embedded UBF buffers
$childubf = tpalloc( "UBF", 0, 1024 );
Badd( $childubf, TA_CLASS, "CHILD", 0 );
Badd( $childubf, TA_OPERATION, "BUFFER", 0 );

$parentubf = tpalloc( "UBF", 0, 1024 );
$rval = Badd( $parentubf, TEST_UBF, $childubf, 0 );
if ( $rval == -1 ) {
    die ( "Badd failed: " . Bstrerror(Berror) . "\n" ) 
}

Badd( $parentubf, TEST_DOUBLE, 123.432, 0 );
Bprint( $parentubf );

#my $val, $len;
$rval = Bget( $parentubf, TEST_UBF, 0, $val, $len );
if ( $rval == -1 ) {
    die ( "Bget failed: " . Bstrerror(Berror) . "\n" ) 
}
Bprint( $val );
$tempvar = $val;
$rval = Bget( $parentubf, TEST_DOUBLE, 0, $val, $len );
print "val = " . $val . "\n";
print "len = " . $len . "\n";


# TEST: CLIENTID ptr

$ubfin = tpalloc( "UBF", 0, 1024 );
Badd( $ubfin, TA_CLASS, "T_CLIENT", 0 );
Badd( $ubfin, TA_OPERATION, "GET", 0 );
printf( "MIB_SELF = " . MIB_SELF . "\n" );
Badd( $ubfin, TA_FLAGS, MIB_SELF, 0 );
Bprint( $ubfin );
$rval = tpcall( ".TMIB", $ubfin, 0, $ubfin, $len, 0 );
if ( $rval == -1 ) {
    die ( "tpcall failed: " . tpstrerror(tperrno) . "\n" );
}
Bprint( $ubfin );
$rval = Bget( $ubfin, TA_CLIENTID, 0, $ta_clientid, $len );
printf( "TA_CLIENTID = $ta_clientid\n" );

#$rval = tpconvert( $ta_clientid, $clientid, TPCONVCLTID );
#@clientdata = $clientid->clientdata;
#printf ( "The size of clientdata = " . @clientdata . "\n" );
#printf ( "clientdata = " . "@clientdata" . "\n" );
#$rval = tpconvert( $strrep, $clientid, TPTOSTRING | TPCONVCLTID );
#printf ( "clientid = $strrep\n" );

$tptranid = TPTRANID_PTR::new();
@info = $tptranid->info( 1, 2, 3, 4, 5, 6 );
printf ( "tptranid->info = @info\n" );

$xid = XID_PTR::new();
$xid->data( "fat" );

printf ( "xid->data = " . $xid->data . "\n" );

# TEST: TPQCTL
$tpqctl = TPQCTL_PTR::new();
$tpqctl->flags( TPQMSGID );
$rval = tpconvert( $ta_clientid, $tpqctl->cltid, TPCONVCLTID );
@clientdata = $tpqctl->cltid->clientdata;
printf ( "clientid->clientdata = @clientdata\n" );
printf ( "tpqctl->flags = " . $tpqctl->flags . "\n" );

# TEST tpexport
$rval = tpexport( $ubfin, 0, $ostr, $olen, 0 );
if ( $rval == -1 ) {
    die ( "tpexport failed: " . tpstrerror(tperrno) . "\n" );
}
printf( "ostr = $ostr\n" );
printf( "olen = $olen\n" );

#$importbuf = tprealloc( $importbuf, 2056 );
$rval = Bget( $importbuf, TA_CLIENTID, 0, $ta_clientid, $len );
printf( "TA_CLIENTID = $ta_clientid\n" );
printf( "done\n" );

# TEST tpgetlev
$rval = tpgetlev();
if ( $rval == -1 ) {
    die ( "tpgetlev failed: " . tpstrerror(tperrno) . "\n" );
}
printf( "tpgetlev returned $rval\n" );

# TEST Usignal
Usignal( 17, \&sigusr2 );
printf( "My process id is $$\n" );


# Test STRING buffer
my $string = tpalloc( "STRING", 0, 1024 );
if ( not defined $string ) {
    die ( "tpalloc failed: " . tpstrerror(tperrno) . "\n" );
}
$string->value( "fat boy" );
printf( "\$string = " . $string->value . "\n" );

# Test PERLSVR TOUPPER
$rval = tpcall( "TOUPPER", $string, 0, $string, $len, 0 );
if ( $rval == -1 ) {
    die ( "tpcall failed: " . tpstrerror(tperrno) . "\n" );
}
printf( "\$string = " . $string->value . "\n" );

# Test PERLSVR REVERSE
$rval = tpcall( "REVERSE", $string, 0, $string, $len, 0 );
if ( $rval == -1 ) {
    die ( "tpcall failed: " . tpstrerror(tperrno) . "\n" );
}
printf( "\$string = " . $string->value . "\n" );

# TEST 5: tpterm
$rval = tpterm();
if ( $rval == -1 ) {
    print "tpterm failed: " . tpstrerror(tperrno) . "\n";
}

userlog( "Finished test of activendrx for perl." . "  You are FAT!" );

system( "tmshutdown -y" );

exit(0);

sub pants
{
    my( $buffer, $len, $flags ) = @_;
    Bprint( $buffer );
    printf( "Inside PANTS!\n" );
}

sub sigusr2
{
    my( $signum ) = @_;
    printf( "Caught SIGUSR2\n" );
}
