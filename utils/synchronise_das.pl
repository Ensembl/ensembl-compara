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

