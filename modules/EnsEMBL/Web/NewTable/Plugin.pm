package EnsEMBL::Web::NewTable::Plugin;

use strict;
use warnings;

sub new {
  my ($proto) = @_;
  my $class = ref($proto) || $proto;
  my $self = {};
  bless $self,$class;
  return $self;
}

sub children { return []; }
sub js_plugin { return undef; }
sub js_config { return {}; }
sub configure { $_[0]->{'config'} = $_[1]; }
sub requires { return []; }

1;
