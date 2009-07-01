package EnsEMBL::Web::Component::Transcript::OligoArrays;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Transcript);

sub _init {
  my $self = shift;
  $self->cacheable( 1 );
  $self->ajaxable(  1 );
}

sub caption {
  return undef;
}

sub content {
  my $self = shift;

  my $transcript = $self->object;
  $transcript->get_oligo_probe_data;
  my $html = $self->_matches('oligo_arrays', 'Oligo Matches', 'ARRAY' );

  return $html;
}
1;

