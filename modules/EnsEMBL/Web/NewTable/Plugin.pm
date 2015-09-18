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
sub configure { $_[0]->{'config'} = $_[1]; }
sub requires { return []; }
sub position { return []; }

sub js_config {
  my ($self) = @_;

  return {
    position => $self->{'config'}->{'position'} || $self->position,
  };
}

1;
