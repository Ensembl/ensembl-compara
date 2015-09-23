package EnsEMBL::Web::NewTable::Plugin;

use strict;
use warnings;

sub new {
  my ($proto,$table) = @_;
  my $class = ref($proto) || $proto;
  my $self = {
    table => $table
  };
  bless $self,$class;
  $self->init();
  return $self;
}

sub init {}

sub table { return $_[0]->{'table'}; }

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
