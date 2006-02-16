package EnsEMBL::Web::Document::DropDown::Menu::SNPContext;

use strict;
use EnsEMBL::Web::Document::DropDown::Menu;
our @ISA =qw( EnsEMBL::Web::Document::DropDown::Menu );


sub new {
  my $class  = shift;
  my $self = $class->SUPER::new( 
    @_, ## This contains the menu containers as the first element
    'image_name'  => 'y-context',
    'image_width' => 68,
    'alt'         => 'Context'
  ); 
  my $LINK = sprintf qq(/%s/%s?%s), $self->{'species'}, $self->{'script'}, $self->{'LINK'};
  my $current = $self->{'scriptconfig'}->get('context');
  foreach( qw(20 50 100 200 500 1000 2000 5000 ) ) {
    $self->add_link( ($_== $current ? "* " : '' ). "Context $_".'bp', $LINK."context=$_", '' );
  }
  $self->add_link( ( $current eq 'FULL' ? "* " : '' ). "Full introns", $LINK."context=FULL", '' );
  return $self;
}

1;
