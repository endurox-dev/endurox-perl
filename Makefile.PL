use ExtUtils::MakeMaker;
use ExtUtils::Embed;
use Config;

# create the xsinit routine
xsinit("perlxsi.c");

my $os = $^O;

# get the ldopts used to build perl
chop(my $ldopts = ldopts);

#get the library paths from the ldopts.
@ldopts_elements = split( / /, $ldopts);
@tmp = grep /^-L/, @ldopts_elements;
my $libpaths = join " ", @tmp;

#get the DynaLoader archive for linking with AIX
@tmp = grep /DynaLoader/, @ldopts_elements;
my $dynaloader_lib = join " ", @tmp;

# can get rid of the libpaths from the ldopts now
$ldopts =~ s/\s-L\S*//g;

my %opts = (
    NAME         => 'Endurox',
    VERSION_FROM => 'Endurox.pm',
    'C'          => [ 'EnduroxConstants.c', 'perlxsi.c' ],
    'OBJECT'     => 'EnduroxConstants.o Endurox.o perlxsi.o',
    'INC'        => "-I $ENV{NDRX_HOME}/include",
    'DL_FUNCS'   => { "\$(NAME)" => ["boot_\$(NAME)" ] },
    'FUNCLIST'   => [ "PERL", "tpsvrinit", "tpsvrdone", "settmsvrargs" ],
    'clean'      => { FILES => "ULOG.* ubbconfig NDRXCONFIG *.tar.gz stderr stdout" }
);


# --- How shall we link with Endurox?
if ( $os eq 'MSWin32' )
{
    $opts{LIBS} = [ "-L$ENV{NDRX_HOME}/lib -llibndrx -llibbuft -llibubf -llibubf -llibengine -lwsock32 -lkernel32 -ladvapi32 -luser32 -lgdi32 -lcomdlg32 -lwinspool" ];
    $opts{DEFINE} = "-D__TURBOC__";
}

# -- unix variants..tested on solaris
else
{
    $buildclient_cmd = `buildclient -v 2>/dev/null`;
    @buildclient_options = split( / /, $buildclient_cmd ); 
    @lib_options = grep /-[LlR]/, @buildclient_options;
    $libs = join " ", @lib_options;
    $libs =~ s/\${NDRX_HOME}/$ENV{NDRX_HOME}/;
    #print "libs = $libs\n";
    $opts{LIBS} = [ $libs ];
    $opts{LDDLFLAGS} = $Config{lddlflags} . " " . $dynaloader_lib;
}

WriteMakefile( %opts );


sub MY::postamble 
{
    my $string = <<EOS;

###########################################################
# PERLSVR - perl interpretor endurox server
###########################################################
PERL_EMBED_LIBS=$ldopts

PERL_TARGET=PERLSVR\$(EXE_EXT)

\$(PERL_TARGET): \$(INST_DYNAMIC) 
EOS
if ( $os eq 'MSWin32' ) {
	$string = $string . <<EOS;
	set CC="$Config{cc} $libpaths"
	#buildserver -o \$@ -k -s "PERL" -f "-DTMMAINEXIT \$(INST_STATIC)"
	buildserver -o \$@ -k -s "PERL" -f "EnduroxConstants.o Endurox.o perlxsi.o \$(INST_STATIC)"
EOS
}
else {
	$string = $string . <<EOS;
	CC="$Config{cc} $libpaths"; export CC; \$(NDRX_HOME)/bin/buildserver -o \$@ -s ":PERL" -f "EnduroxConstants.o Endurox.o perlxsi.o \$(PERL_EMBED_LIBS)"
EOS
}


$string = $string . <<EOS;

pure_all :: \$(PERL_TARGET)

clean ::
	\$(RM_RF) \$(PERL_TARGET) perlxsi.c

EOS

    return $string;
}
