package Bio::EnsEMBL::GlyphSet::generic_match;
use strict;
use Bio::EnsEMBL::GlyphSet_feature2;
@Bio::EnsEMBL::GlyphSet::generic_match::ISA = qw(Bio::EnsEMBL::GlyphSet_feature2);

sub my_label {
  my $self = shift;
  return $self->my_config('label');
}

sub features {
  my ($self) = @_;
    
  my $species = $self->my_config('species');
  (my $species_2 = $species) =~ s/_/ /; 
  my $assembly = 
    EnsWeb::species_defs->other_species($species,'ENSEMBL_GOLDEN_PATH');
  return $self->{'container'}->get_all_compara_DnaAlignFeatures(
    $species_2, $assembly, $self->my_config('method')
  );

}

sub href {
  my ($self, $chr_pos ) = @_;
  my $species = $self->my_config('species');
  my $domain  = $self->my_config('linkto');
  return "$domain/$species/$ENV{'ENSEMBL_SCRIPT'}?$chr_pos";
}

sub zmenu {
  my ($self, $id, $chr_pos, $text ) = @_;
  my $domain  = $self->my_config('linkto');
  return { 'caption' => $id } if $domain eq 'nolink';
  (my $species_2 = $self->my_config('species')) =~ s/_/ /; 
  return { 
    'caption'    => $id, 
    "Jump to $species_2" => $self->href( $chr_pos ), 
  };
}


sub unbumped_zmenu {
  my ($self, $ref, $target,$width, $text ) = @_;
  my ($chr,$pos) = @$target;
  my $domain  = $self->my_config('linkto'); 
  (my $species_2 = $self->my_config('species')) =~ s/_/ /; 
  my $chr_pos = "l=$chr:".($pos-$width)."-".($pos+$width);
  return { 'caption' => "$species_2 $chr_pos"} if $domain eq 'linkto'; #if linkto defined then there is no core!!

  return { 'caption' => $text,
    "Jump to $species_2" => $self->href( $chr_pos ) } if $domain;
  
  return { 
    'caption'    => $text,
    'Dotter' => $self->unbumped_href( $ref, $target ),
    "Jump to $species_2" => $self->href( $chr_pos ), 
  };
}

sub unbumped_href {
  my ($self, $ref, $target ) = @_;
  my $domain  = $self->my_config('linkto');
  return undef if $domain; # if linkto defined then there is no core!!
  my $species = $self->my_config('species');
  return "/@{[$self->{container}{_config_file_name_}]}/dotterview?ref=@{[join(':',$self->{container}{_config_file_name_},@$ref)]}&hom=@{[join(':',$species, @$target )]}" ;
}

1;
