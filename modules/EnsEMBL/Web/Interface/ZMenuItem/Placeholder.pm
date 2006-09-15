package EnsEMBL::Web::Interface::ZMenuItem::Placeholder;

use strict;
use warnings;

use EnsEMBL::Web::Interface::ZMenuItem;
our @ISA = qw(EnsEMBL::Web::Interface::ZMenuItem);

{

sub new {
  my ($class, %params) = @_;
  my $self = $class->SUPER::new(%params);
  $self->type('placeholder');
  return $self;
}

}

1;
