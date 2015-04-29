# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
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

use strict;

use FindBin qw($Bin);
use File::Basename qw( dirname );

use vars qw( $SERVERROOT );
BEGIN{
  $SERVERROOT = dirname( $Bin );
  unshift @INC, "$SERVERROOT/conf";
  eval{ require SiteDefs };
  if ($@){ die "Can't use SiteDefs.pm - $@\n"; }
  map{ unshift @INC, $_ } @SiteDefs::ENSEMBL_LIB_DIRS;
}

use EnsEMBL::Web::Tools::SynchroniseDAS;
use Getopt::Long;

my $verbose;
GetOptions ("verbose|v" => \$verbose);
if ($verbose) {
  Bio::EnsEMBL::Utils::Exception::verbose('INFO');
}

if (rebuild_das() == DAS_CHANGED) {
  print "DAS config changed - server restart required\n";
} else {
  print "DAS config unchanged\n";
}

