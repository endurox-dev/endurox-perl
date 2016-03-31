package testflds;

use strict;
use vars qw($VERSION @ISA @EXPORT);
require Exporter;

$VERSION = 1.00;

@ISA = qw(Exporter);
@EXPORT = qw(
	TEST_UBF
	TEST_DOUBLE
);

# subs
sub TEST_UBF { 335594322; }
sub TEST_DOUBLE { 134267729; }

1; #
