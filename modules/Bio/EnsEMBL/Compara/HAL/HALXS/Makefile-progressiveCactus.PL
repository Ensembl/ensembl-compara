
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

my $cactus = $ARGV[0] || $ENV{PROGRESSIVE_CACTUS_DIR};
die "The path to the progressiveCactus installation must be provided, either on the command-line or via the environment PROGRESSIVE_CACTUS_DIR" unless $cactus;

print "! Using progressiveCactus installation at $cactus\n";
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

    INC => "-I$cactus/submodules/hdf5/include -I$cactus/submodules/hal/chain/inc/ -I$cactus/submodules/hal/maf/inc/ -I$cactus/submodules/sonLib/lib",
    LIBS => [ "-L$cactus/submodules/hdf5/lib -L$cactus/submodules/hal/lib -L$cactus/submodules/sonLib/lib -lstdc++ -lhdf5 -lhdf5_cpp" ],
    MYEXTLIB => "$cactus/submodules/hal/lib/halChain.a $cactus/submodules/hal/lib/halLod.a $cactus/submodules/hal/lib/halLiftover.a $cactus/submodules/hal/lib/halLib.a $cactus/submodules/hal/lib/halMaf.a $cactus/submodules/sonLib/lib/sonLib.a",
    # Un-comment this if you add C files to link with later:
    # OBJECT            => '$(O_FILES)', # link all the C files too
);
