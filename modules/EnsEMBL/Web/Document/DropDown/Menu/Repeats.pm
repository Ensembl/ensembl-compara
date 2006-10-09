package EnsEMBL::Web::Document::DropDown::Menu::Repeats;

use strict;
use EnsEMBL::Web::Document::DropDown::Menu;
our @ISA =qw( EnsEMBL::Web::Document::DropDown::Menu );

sub new {
  my $class  = shift;
  my $self = $class->SUPER::new( 
    @_, ## This contains the menu containers as the first element
    'image_name'  => 'y-repeats',
    'image_width' => 64,
    'alt'         => 'Repeats'
  ); 
  return unless $self->{'config'}->_is_available_artefact( 'database_tables ENSEMBL_DB.repeat_feature ' );
  $self->add_checkbox( 'repeat_lite', 'All repeats' );

  my %T;
  foreach my $c ( @{$self->{'configs'}||[]}, $self->{'config'} ) {
    my $S = $c->{'species'};
    foreach my $T (sort keys %{  $self->{'config'}->{'species_defs'}->other_species($S, 'REPEAT_TYPES') ||{}} ) {
      $T{$T}=1;
    }
  }

  foreach my $T (sort keys %T ) { 
    (my $T2 = $T ) =~ s/\W+/_/g;
    $self->add_checkbox( "managed_repeat_$T2", $T );  
  }
  return $self;
}

1;
