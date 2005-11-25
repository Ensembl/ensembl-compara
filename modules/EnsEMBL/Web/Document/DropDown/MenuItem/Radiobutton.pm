package EnsEMBL::Web::Document::DropDown::MenuItem::Radiobutton;

use strict;
use EnsEMBL::Web::Document::DropDown::MenuItem;
our @ISA =qw( EnsEMBL::Web::Document::DropDown::MenuItem );

sub new {
  my ($class,$label,$name,$value) = @_;
  return $class->SUPER::new( 'name' => $name, 'label' => $label, 'value' => $value );
}

sub render {
  my $self = shift;
  return qq(    new dd_Item("radio","$self->{'name'}","$self->{'label'}","$self->{'value'}"));
}

1;
