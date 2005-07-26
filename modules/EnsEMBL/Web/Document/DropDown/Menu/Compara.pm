package EnsEMBL::Web::Document::DropDown::Menu::Compara;

use strict;
use EnsEMBL::Web::Document::DropDown::Menu;

our @ISA =qw( EnsEMBL::Web::Document::DropDown::Menu );

sub new {
  my $class = shift;
  my $self = $class->SUPER::new(
    @_, ## This contains the menu containers as the first element
    'image_name'  => 'y-compara',
    'image_width' => 88,
    'alt'         => 'Compara'
  );
  my @menu_entries = @{$self->{'config'}->get('_settings','compara')||[]};

  my $num_checkboxes = 0;
  foreach ( @menu_entries ) { 
    next unless $self->{'config'}->is_available_artefact($_->[0]) || $self->{'scriptconfig'}->is_option( $_->[0]); 
    $self->add_checkbox( @$_ );
    $num_checkboxes++;
  }
  $num_checkboxes || return;

  if( $self->{'config'}->{'multi'} ){
    my $LINK = sprintf qq(/%s/%s?%s), $self->{'species'}, $self->{'script'}, $self->{'LINK'};
    my %species = (
      $self->{'config'}->{'species_defs'}->multi( 'BLASTZ_NET',       $self->{'species'} ),
      $self->{'config'}->{'species_defs'}->multi( 'BLASTZ_GROUP',     $self->{'species'} ),
      $self->{'config'}->{'species_defs'}->multi( 'PHUSION_BLASTN',   $self->{'species'} ),
      $self->{'config'}->{'species_defs'}->multi( 'BLASTZ_RECIP_NET', $self->{'species'} ),
      $self->{'config'}->{'species_defs'}->multi( 'TRANSLATED_BLAT',  $self->{'species'} ) 
    );
    foreach( keys %species ) {
      $self->add_link(
        "Add/Remove $_",
        $LINK."flip=$_",
        ''
      )
    }
  }
  return $self;
}

1;
