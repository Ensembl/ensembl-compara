package Bio::EnsEMBL::ColourMap;
use strict;
use base qw(Sanger::Graphics::ColourMap);

sub new {
  my $class = shift;
  my $species_defs = shift;
  my $self = $class->SUPER::new( @_ );

  my %new_colourmap = qw(
    CONTRAST_BORDER   background0
    CONTRAST_BG       background3

    IMAGE_BG1         background1
    IMAGE_BG2         background2

    CONTIGBLUE1       contigblue1
    CONTIGBLUE2       contigblue2

    HIGHLIGHT1        highlight1
    HIGHLIGHT2        highlight2
  );
  while(my($k,$v) = each %{$species_defs->ENSEMBL_STYLE||{}} ) {
    my $k2 = $new_colourmap{ $k };
    next unless $k2;
    $self->{$k2} = $v;
  }
  return $self;
}

1;
