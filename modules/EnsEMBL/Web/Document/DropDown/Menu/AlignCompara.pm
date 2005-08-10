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
    'alt'         => 'Compara'
  );
  my @menu_entries = @{$self->{'config'}->get('_settings','aligncompara')||[]};

  my $LINK = sprintf qq(/%s/%s?%s), $self->{'species'}, $self->{'script'}, $self->{'LINK'};

  
  # Find one that is active;
  my $active_option = $self->{'config'}->get('aligncompara', 'align_species');

  foreach my $me ( @menu_entries ) {
      my ($option, $label) = @$me;
      my $link = "$LINK&align=$option";
      if ($option eq $active_option) {
	  $label = "* $label";
      }
      $self->add_link( $label, $link, '' );
  }

  return $self;
}

1;
