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
  ( my $script  = $ENV{'ENSEMBL_SCRIPT'} ) =~ s/^multi//g;
  return "$domain/$species/$script?$chr_pos";
}

sub zmenu {
  my ($self, $id, $chr_pos, $text ) = @_;
  my $domain  = $self->my_config('linkto');
  return { 'caption' => $id } if $domain eq 'nolink';
  (my $species_2 = $self->my_config('species')) =~ s/_/ /; 
  return { 
    'caption'    => $id, 
    "Jump to $species_2" => $self->href( $chr_pos ), 
    $text => ''
  };
}


sub unbumped_zmenu {
  my ($self, $ref, $target,$width, $text, $text2, $ori, $type ) = @_;
  my ($chr,$pos) = @$target;
  my $domain  = $self->my_config('linkto'); 
  my $first_species  = $self->{container}{_config_file_name_};
  my $second_species = $self->my_config('species');
  (my $species_2 = $second_species) =~ s/_/ /; 
  my $chr_pos = "l=$chr:".($pos-$width)."-".($pos+$width);
  my $O2 = $ori =~/orward/ ? 1 : -1;
  return { 'caption' => "$species_2 $chr_pos"} if $domain eq 'linkto'; #if linkto defined then there is no core!!

  return { 'caption' => $text,
    "Jump to $species_2" => $self->href( $chr_pos ),
    $ori => '' } if $domain;
  
  my %extra = (); 
  my $C=1;
  if( $self->{'config'}->{'compara'} ) {
    my %pars;
    foreach my $T ( @{$self->{'config'}->{'other_slices'}||[] } ) {
      if( $T->{'species'} eq $first_species ) {
        $pars{"c"}  = join ':', @$ref;
        $pars{"w"}  = 2*$width;
      } elsif( $T->{'species'} eq $second_species ) {
        $pars{"s1"} = $second_species;
        $pars{"c1"} = "$chr:$pos:$O2"; 
        $pars{"w1"} = 2*$width;
      } else {
        $C++;
        $pars{"s$C"} = $T->{'species'}
      }
    }
    $extra{ "Centre on this match" } = "/$first_species/multicontigview?".join( '&', map { "$_=$pars{$_}" } sort keys %pars );
  } else {
    my %pars = (               'c' => join( ':', @$ref ), 'w'  => 2 * $width,
      's1' => $second_species, 'c1' => "$chr:$pos:$O2",  'w1' => 2 * $width );
    $extra{ "MultiContigView" } = "/$first_species/multicontigview?".join( '&', map { "$_=$pars{$_}" } sort keys %pars );
  } 
  return { 
    %extra,
    'caption'    => $text,
    'Dotter' => $self->unbumped_href( $ref, $target ),
    'Alignment' => sprintf( "/%s/alignview?module=DNADNA&l=%s&s1=%s&l1=%s&type=%s", $first_species, $text2, $second_species, $text, $type ),
    "Jump to $species_2" => $self->href( $chr_pos ), 
    $ori => '' };
}

sub unbumped_href {
  my ($self, $ref, $target ) = @_;
  my $domain  = $self->my_config('linkto');
  return undef if $domain; # if linkto defined then there is no core!!
  my $species = $self->my_config('species');
  return "/@{[$self->{container}{_config_file_name_}]}/dotterview?ref=@{[join(':',$self->{container}{_config_file_name_},@$ref)]}&hom=@{[join(':',$species, @$target )]}" ;
}

1;
