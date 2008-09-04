package Bio::EnsEMBL::GlyphSet::_simple;

use strict;
use base qw(Bio::EnsEMBL::GlyphSet_simple);

sub _das_type {  return 'simple'; }

sub features       { 
  my $self = shift;
  my $call = 'get_all_'.( $self->my_config( 'type' ) || 'SimpleFeatures' ); 
  my @F = map { @{$self->{'container'}->$call( $_ )||[]} }
          @{$self->my_config( 'logicnames' )||[]};
  return \@F;
}

sub colour {
  my( $self, $f ) = @_;
  return $self->my_colour(lc( $f->analysis->logic_name ));
}

sub feature_label {
  return undef;
}

sub title {
  my( $self, $f ) = @_;
  return $f->analysis->logic_name.': '.$f->display_label.'; Score: '.$f->score;
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
