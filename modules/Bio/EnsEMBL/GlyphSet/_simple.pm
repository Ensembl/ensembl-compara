package Bio::EnsEMBL::GlyphSet::_simple;

use strict;
use base qw(Bio::EnsEMBL::GlyphSet_simple);

sub _das_type {  return 'simple'; }

sub features       { 
  my $self = shift;
  my $call = 'get_all_'.( $self->my_config( 'type' ) || 'SimpleFeatures' ); 
  return $self->{'container'}->$call( $self->my_config( 'code' ), $self->my_config( 'threshold' ) );
}

sub colour {
  my( $self, $f ) = @_;
  return $self->my_colour( $f->analysis->logic_name );
}

sub feature_label {
  return undef;
}

sub title {
  my( $self, $f ) = @_;
  return $f->analysis->name.': '.$f->display_label.'; Score: '.$f->score;
}

sub href {
  my ($self, $f ) = @_;
  return undef;
}

sub tag {
  my ($self, $f ) = @_;
  return; 
}
1;
