package Test::Mocking;

use warnings;
use strict;

use base qw(Exporter);

use EnsEMBL::Web::RegObj;
use EnsEMBL::Mock::RegObj;

our @EXPORT    = qw(mock_registry);
our @EXPORT_OK = qw(mock_registry);

{

sub mock_registry {
  my $mock = EnsEMBL::Mock::RegObj->mock_registry();
  *EnsEMBL::Web::RegObj::ENSEMBL_WEB_REGISTRY = \$mock;
}

}

1;
