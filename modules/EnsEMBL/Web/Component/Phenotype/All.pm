package EnsEMBL::Web::Component::Phenotype::All;

use strict;
use warnings;
no warnings 'uninitialized';

use base qw(EnsEMBL::Web::Component);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(0);
}

sub content {
  my $self = shift;
  my $object = $self->object;
  my $html;

  $html = "Content goes here";  

  return $html;
}

1;
