package EnsEMBL::Web::TextSequence::Markup;

use strict;
use warnings;

sub new {
  my ($proto,$p) = @_;

  my $class = ref($proto) || $proto;
  my $self = {
    phases => $p,
    view => undef,
  };
  bless $self,$class;
  return $self;
}

sub view { $_[0]->{'view'} = $_[1] if @_>1; return $_[0]->{'view'}; }
sub phases { $_[0]->{'phases'} = $_[1] if @_>1; return $_[0]->{'phases'}; }

sub name { return ref $_[0]; }
sub replaces { return undef; }

sub expect {
  my ($self,$what) = @_;

  $self->view->legend->expect($what) if $self->view;
}

sub prepare {}
sub pre_markup {}

1;
