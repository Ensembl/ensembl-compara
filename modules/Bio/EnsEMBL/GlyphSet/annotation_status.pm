package Bio::EnsEMBL::GlyphSet::annotation_status;
use strict;
use base qw(Bio::EnsEMBL::GlyphSet_simple);

#annotation status display for vega

sub features {
  my $self = shift;
  my @features = @{ $self->{'container'}->get_all_MiscFeatures('NoAnnotation') };
  foreach my $f (@features) {
    my ($ms) = @{ $f->get_all_MiscSets('NoAnnotation') };
    $f->{'_miscset_code'} = $ms->code;
  }
  return \@features;
}

sub colour_key {
  my $self = shift;
  return 'NoAnnotation';
}

sub feature_label {
  return undef;
}

sub title {
  my( $self, $f ) = @_;
  return $self->my_colour( $f->{'_miscset_code'}, 'text' );
}

sub href {
  my( $self, $f ) = @_;
  return undef;
}

sub tag {
  my ($self, $f) = @_;
  my $colour = $self->my_colour( $f->{'_miscset_code'},'join' );
  return {
    'style'  => 'join',
    'tag'    => $f->{'start'}.'-'.$f->{'end'},
    'colour' => $colour,
    'zindex' => -20,
  };
}


1;
