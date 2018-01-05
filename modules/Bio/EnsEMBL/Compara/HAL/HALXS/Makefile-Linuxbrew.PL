
# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2018] EMBL-European Bioinformatics Institute
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#      http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


use 5.014002;
use ExtUtils::MakeMaker;

my $linuxbrew_home = $ARGV[0] || $ENV{LINUXBREW_HOME};
die "The path to the linuxbrew installation must be provided, either on the command-line or via the environment LINUXBREW_HOME" unless $linuxbrew_home;

my $lib_location = $linuxbrew_home.'/lib';
# We need a specific version of hdf5 that is not the default one
my $hdf5_location = $linuxbrew_home.'/Cellar/hdf5@1.8/1.8.19';

print "! Using linuxbrew installation at $ENV{LINUXBREW_HOME}\n";
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

    # Since we don't use the default hdf5, we need to give the full paths
    # here for 1) the header files and 2) the library.
    # The headers from the version 1.10 seem to work, but I want to make
    # sure the correct ones are in the path
    INC => "-I$hdf5_location/include",
    # Somehow, it needs both -L and -rpath !
    LIBS => [ "-L$hdf5_location/lib -Wl,-rpath,$hdf5_location/lib -lhdf5 -lhdf5_cpp" ],
    # HAL and sonLib .a files all are in linuxbrew's lib/
    MYEXTLIB => "$lib_location/halChain.a $lib_location/halLod.a $lib_location/halLiftover.a $lib_location/halLib.a $lib_location/halMaf.a $lib_location/sonLib.a",
    # Un-comment this if you add C files to link with later:
    # OBJECT            => '$(O_FILES)', # link all the C files too
);
