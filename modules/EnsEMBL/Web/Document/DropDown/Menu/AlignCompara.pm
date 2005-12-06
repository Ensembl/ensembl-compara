package EnsEMBL::Web::Document::DropDown::Menu::AlignCompara;

use strict;
use EnsEMBL::Web::Document::DropDown::Menu;

our @ISA =qw( EnsEMBL::Web::Document::DropDown::Menu );

sub new {
  my $class = shift;
  my $self = $class->SUPER::new(
    @_, ## This contains the menu containers as the first element
    'image_name'  => 'y-compara',
    'image_width' => 88,
    'alt'         => 'Multiple Alignments'
  );
  
  my $species = $ENV{ENSEMBL_SPECIES};

### Get all MLAGAN alignment sets
### It is understood that all set ids will be like MLAGAN-XXX
  my @mlagan_alignments = grep { /MLAGAN-/ } keys %{$self->{'config'}->{'species_defs'}->{'_multi'}};

  if (@mlagan_alignments) {
      $self->add_text("Multiple Alignments");
  }

  foreach my $align (@mlagan_alignments) {
      my $h = $self->{'config'}->{'species_defs'}->{'_multi'}->{$align};
      next if (! defined($h->{$species}));
      $self->add_radiobutton( "opt_alignm_$align", $align );

      foreach my $sp (sort keys %$h ) { 
	  $self->add_checkbox( "opt_${align}_$sp", $sp ) if ($sp ne $species);
      }
      $self->add_text(" ");
  }

  my $align = 'BLASTZ_NET';
  my $h = $self->{'config'}->{'species_defs'}->{'_multi'}->{$align}->{$species};
  $self->add_text("Pairwise Alignments");  

  my @species = sort keys %$h ;
  foreach my $label ( @species ) {
      $self->add_radiobutton( "opt_alignp_${align}_$label", $label) 
  }
  
  return $self;
}

1;
