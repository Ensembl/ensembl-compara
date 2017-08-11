use 5.014002;
use ExtUtils::MakeMaker;

my $linuxbrew_home = $ARGV[0] || $ENV{LINUXBREW_HOME};
die "The path to the linuxbrew installation must be provided, either on the command-line or via the environment LINUXBREW_HOME" unless $linuxbrew_home;

my $hal_location = $linuxbrew_home.'/Cellar/hal/451788f/lib';
my $sonLib_location = $linuxbrew_home.'/Cellar/sonlib/0.1/lib';

print "! Using linuxbrew installation at $ENV{LINUXBREW_HOME}\n";
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME              => 'HALXS',
    VERSION_FROM      => 'lib/HALXS.pm', # finds $VERSION
    PREREQ_PM         => {}, # e.g., Module::Name => 1.1
    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM  => 'lib/HALXS.pm', # retrieve abstract from module
       AUTHOR         => 'Carla Cummins <carlac@ebi.ac.uk>') : ()),
    DEFINE  => '', # e.g., '-DHAVE_SOMETHING'

    INC => "-I$hal_location",
    LIBS => [ "-lstdc++ -lhdf5 -lhdf5_cpp" ],
    MYEXTLIB => "$hal_location/halChain.a $hal_location/halLod.a $hal_location/halLiftover.a $hal_location/halLib.a $hal_location/halMaf.a $sonLib_location/sonLib.a",
    # Un-comment this if you add C files to link with later:
    # OBJECT            => '$(O_FILES)', # link all the C files too
);
