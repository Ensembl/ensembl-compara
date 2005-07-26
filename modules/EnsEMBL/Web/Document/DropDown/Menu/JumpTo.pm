package EnsEMBL::Web::Document::DropDown::Menu::JumpTo;

use strict;
use EnsEMBL::Web::Document::DropDown::Menu;
our @ISA =qw( EnsEMBL::Web::Document::DropDown::Menu );


sub new {
  my $class  = shift;
  my $self = $class->SUPER::new( 
    @_, ## This contains the menu containers as the first element
    'image_name'  => 'y-jumpto',
    'image_width' => 66,
    'alt'         => 'Jump to'
  ); 
  my $location = $self->{'location'};
  my $FLAG = 0;
  my %species = ( map {  $self->{'config'}->{'species_defs'}->multi($_) } qw(BLASTZ_RAW BLASTZ_NET BLASTZ_RECIP_NET PHUSION_BLASTN TRANSLATED_BLAT BLASTZ_GROUP) );
  
  foreach( keys %species ) {
    next if $_ eq 'Apis_mellifera';
    $self->add_link(
      "MultiContigView ($_)",
      sprintf( "/%s/multicontigview?s1=%s&c=%s:%s&w=%s",
        $self->{'species'}, $_, $location->seq_region_name, $location->centrepoint, $location->length ) ,
        ''
      ) 
  }
}

1;
