
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
