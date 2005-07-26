package EnsEMBL::Web::Document::DropDown::MenuItem::Link;

use strict;
use EnsEMBL::Web::Document::DropDown::MenuItem;
our @ISA =qw( EnsEMBL::Web::Document::DropDown::MenuItem );

sub new {
  my ($class,$label,$URL,$target) = @_;
  return $class->SUPER::new( 'target' => $target, 'label' => $label, 'URL' => $URL );
}

sub render {
  my $self = shift;
  return qq(    new dd_Item("link","$self->{'target'}","$self->{'label'}","$self->{'URL'}"));
}

1;
