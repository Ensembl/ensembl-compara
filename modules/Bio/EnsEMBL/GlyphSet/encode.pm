package Bio::EnsEMBL::GlyphSet::encode;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_simple;
@ISA = qw(Bio::EnsEMBL::GlyphSet_simple);

sub my_label { return "Encode regions"; }

sub features {
  my ($self) = @_;
  return $self->{'container'}->get_all_MiscFeatures( 'encode' );
}

sub colour {
  my ($self, $f ) = @_;
  return $self->my_config( 'colour' ), $self->my_config( 'label' );
}

sub href {
  my ($self,$f ) = @_;
  return sprintf "/%s/%s?l=%s:%d-%d", $self->{'container'}{'_config_file_name_'},
         $ENV{'ENSEMBL_SCRIPT'}, $f->seq_region_name,
         $f->seq_region_start, $f->seq_region_end;
}

sub image_label {
  my ($self, $f ) = @_;
  return (@{[$f->get_scalar_attribute('name')]},'overlaid');
}

sub zmenu {
  my ($self, $f ) = @_;
  my $zmenu = { 
    'caption' => "Encode region: @{[$f->get_scalar_attribute('name')]}",
    $f->get_scalar_attribute('description') => '',
    "01:bp: @{[$f->seq_region_start]}-@{[$f->seq_region_end]}" => '',
    "02:length: @{[$f->length]} bps" => '',
    "03:View this region" => $self->href($f),
  };
  if( $self->{'container'}{'_config_file_name_'} ne 'Homo_sapiens' ) {
    $zmenu->{'04:View in human Ensembl'} = 'http://www.ensembl.org/Homo_sapiens/cytoview?misc_feature='.$f->get_scalar_attribute('description');
  }

  return $zmenu;
}

1;
