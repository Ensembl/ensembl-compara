package EnsEMBL::Web::Document::DropDown::Menu::Individuals;

use strict;
use EnsEMBL::Web::Document::DropDown::Menu;
our @ISA =qw( EnsEMBL::Web::Document::DropDown::Menu );

sub new {
  my $class = shift;
  my $self = $class->SUPER::new(
    @_, ## This contains the menu containers as the first element
    'image_name'  => 'y-individuals',
    'image_width' => 81,
    'alt'         => 'Individuals'
  );
  my @menu_entries = @{ $self->{'config'}{'Populations'} || [] };
  return undef unless scalar @menu_entries;
  my $reference = $self->{'config'}{'snp_haplotype_reference'};

  $self->add_link( "Reset options", sprintf(
    qq(/%s/%s?%sdefault=%s;reference=$reference),
    $self->{'species'}, $self->{'script'}, $self->{'LINK'}, "populations" ), '' );
  foreach my $pop (  @menu_entries ) {
    $self->add_checkbox( "opt_pop_$pop", $pop ); 
  }
  return $self;
}

1;
