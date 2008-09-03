package Bio::EnsEMBL::GlyphSet::annotation_status;
use strict;
use base qw(Bio::EnsEMBL::GlyphSet_simple);

sub features {
  my $self = shift;
  
  my @features;
  push @features,
      @{ $self->{'container'}->get_all_MiscFeatures('NoAnnotation') },
      @{ $self->{'container'}->get_all_MiscFeatures('CORFAnnotation') };


  foreach my $f (@features) {
    my ($ms) = @{ $f->get_all_MiscSets('NoAnnotation') };
       ($ms) = @{ $f->get_all_MiscSets('CORFAnnotation') } unless $ms;
    $f->{'_miscset_code'} = $ms->code;
  }
  
  return \@features;
}

sub colour
  my( $self, $f ) = @_;
  return $self->my_colour( $f->{'_miscset_code'} );
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

  return {
    'style'   => 'join',
    'tag'     => $f->{'start'}.'-'.$f->{'end'},
    'colour'  => $self->my_colour( $f->{'_miscset_code'} )
    'zindex'  => -20,
  };
}

1;
