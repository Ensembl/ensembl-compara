package EnsEMBL::Web::Document::DropDown::MenuItem::Text;

use strict;
use EnsEMBL::Web::Document::DropDown::MenuItem;
our @ISA =qw( EnsEMBL::Web::Document::DropDown::MenuItem );

sub new {
  my ($class,$label) = @_;
  return $class->SUPER::new('label' => $label );
}

sub render {
  my $self = shift;
  return qq(    new dd_Item("text","","$self->{'label'}",""));
}

1;
