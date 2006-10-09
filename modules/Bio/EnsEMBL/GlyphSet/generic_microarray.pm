package Bio::EnsEMBL::GlyphSet::generic_microarray;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_feature;
@ISA = qw(Bio::EnsEMBL::GlyphSet_feature);

sub my_label { 
  my $self = shift;
  return $self->my_config('caption') || 'Affy microarray';
}

## Retrieve all MiscFeatures from the misc_set table of the database
## corresponding to the misc_set_code (UserConfig FEATURES key)

sub features {
  my ($self) = @_;
warn $self->my_config('FEATURES');
  my $T = $self->{'container'}->get_all_OligoFeatures( $self->my_config('FEATURES') );
warn @$T;
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
  my ($self, $id, $fd ) = @_;
  my $f = $fd->[0][2];
  my $tmpl = "/%s/featureview?type=AffyProbe;id=%s";
  return sprintf( "/%s/featureview?type=AffyProbe;id=%s", $self->{container}{_config_file_name_}, $f->probeset );
}

## Create the zmenu...
## Include each accession id separately
sub zmenu {
  my ($self, $id, $fd ) = @_;
  my $f = $fd->[0][2];
  return {
    'caption' => "Affy feature: ".$f->probeset,
    'Probe set details: ' => $self->href( $id, $fd )
  };
}
sub feature_group{
  my( $self, $f ) = @_;
  return $f->probeset();
}



1;
