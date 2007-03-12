package Bio::EnsEMBL::GlyphSet::hap_clone_matches;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_simple;
@ISA = qw(Bio::EnsEMBL::GlyphSet_simple);

sub my_label { return "Haplotype Clones"; }

sub features {
  my ($self) = @_;
  return $self->{'container'}->get_all_MiscFeatures( 'hclone' );
}

sub colour {
  my ($self, $f ) = @_;
  return $self->my_config( 'colour' ), $self->my_config( 'label' );
}

sub href {
  my ($self,$f ) = @_;
  my ($contig_name,$start,$stop) = split ':' , $f->get_scalar_attribute('name');
  return sprintf "/%s/%s?contig=%s",
         $self->{'container'}{'_config_file_name_'},
         $ENV{'ENSEMBL_SCRIPT'},
         $contig_name;
}

sub zmenu {
  my ($self, $f ) = @_;
  my $zmenu = { 
    'caption' => "Haplotype clone: @{[$f->get_scalar_attribute('name')]}",
    "01:location: @{[$f->seq_region_start]}-@{[$f->seq_region_end]} bp" => '',
    "02:length: @{[$f->length]} bps" => '',
    "03:View this clone" => $self->href($f),
  };
  return $zmenu;
}

1;
