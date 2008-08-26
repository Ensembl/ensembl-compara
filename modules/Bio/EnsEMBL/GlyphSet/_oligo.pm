package Bio::EnsEMBL::GlyphSet::_oligo;

use strict;

use base qw(Bio::EnsEMBL::GlyphSet_feature);

sub my_label { 
  my $self = shift;
  return $self->my_config('caption') || 'Oligo microarray';
}

## Retrieve all MiscFeatures from the misc_set table of the database
## corresponding to the misc_set_code (UserConfig FEATURES key)

sub features {
  my ($self) = @_;
  my $T = $self->{'container'}->get_all_OligoFeatures( $self->my_config('FEATURES') );
  return $T;
}

## Return the image label and the position of the label
## (overlaid means that it is placed in the centre of the
## feature.

sub image_label {
  my ($self, $f ) = @_;
  return '';
}

## Link back to this page centred on the map fragment

sub href {
  my ($self, $id, $f ) = @_;
  my $tmpl = "/%s/featureview?type=OligoProbe;id=%s";
  return sprintf( "/%s/featureview?type=OligoProbe;id=%s", $self->{container}{_config_file_name_}, $f->probeset );
}

## Create the zmenu...
## Include each accession id separately
sub zmenu {
  my ($self, $id, $f ) = @_;
  return {
    'caption' => "Oligo feature: ".$f->probeset,
    'Probe set details: ' => $self->href( $id, $f )
  };
}
sub feature_group{
  my( $self, $f ) = @_;
  return $f->probeset();
}



1;
