package Bio::EnsEMBL::GlyphSet::_oligo;

use strict;

use base qw(Bio::EnsEMBL::GlyphSet::_alignment);

sub features { ## Hack in db in the future!!
  my ($self) = @_;
  $self->timer_push( 'Preped');
  my $T = $self->{'container'}->get_all_OligoFeatures( $self->my_config('array') );
  $self->timer_push( 'Retrieved oligos', undef, 'fetch' );
  return ( $self->my_config('array') => [$T] );
}

sub feature_group {
  my( $self, $f ) = @_;
  return $f->probeset;    ## For core features this is what the sequence name is...
}

sub feature_title {
  my( $self, $f ) = @_;
  return "Probe set: ".$f->probeset;
}

sub href {
### Links to /Location/Feature with type of 'OligoProbe'
  my ($self, $f ) = @_;
  return $self->_url({
    'object' => 'Location',
    'action' => 'Genome',
    'db'     => $self->my_config('db'),
    'ftype'  => 'OligoFeature',
    'id'     => $f->probeset
  });
}

1;
