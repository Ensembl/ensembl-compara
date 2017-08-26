use 5.014002;
use ExtUtils::MakeMaker;

die "Need to run this makefile with 3 paths: hdf5, sonLib and HAL" if scalar(@ARGV) != 3;

my ($hdf5_location, $sonLib_location, $hal_location) = @ARGV;

# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME              => 'HALXS',
    VERSION_FROM      => 'lib/HALXS.pm', # finds $VERSION
    PREREQ_PM         => {}, # e.g., Module::Name => 1.1
    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM  => 'lib/HALXS.pm', # retrieve abstract from module
       AUTHOR         => 'Ensembl Compara') : ()),
    DEFINE  => '', # e.g., '-DHAVE_SOMETHING'
    PL_FILES          => {},

    INC => "-I$hdf5_location/include -I$hal_location/lib -I$sonLib_location/lib",
    LIBS => [ "-L$hdf5_location/lib -L$hal_location/lib -L$sonLib_location/lib -lstdc++ -lhdf5 -lhdf5_cpp" ],
    MYEXTLIB => "$hal_location/lib/halChain.a $hal_location/lib/halLod.a $hal_location/lib/halLiftover.a $hal_location/lib/halLib.a $hal_location/lib/halMaf.a $sonLib_location/lib/sonLib.a",
    # Un-comment this if you add C files to link with later:
    # OBJECT            => '$(O_FILES)', # link all the C files too
);
