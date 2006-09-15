package EnsEMBL::Web::Interface::ZMenuItem::Text;

use strict;
use warnings;

use EnsEMBL::Web::Interface::ZMenuItem;
our @ISA = qw(EnsEMBL::Web::Interface::ZMenuItem);

{

sub new {
  my ($class, %params) = @_;
  my $self = $class->SUPER::new(%params);
  $self->type('text');
  return $self;
}

sub display {
  my $self = shift;
  return $self->text;
}

}

1;
