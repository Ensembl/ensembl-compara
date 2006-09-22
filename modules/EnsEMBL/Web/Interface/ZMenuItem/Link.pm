package EnsEMBL::Web::Interface::ZMenuItem::Link;

use strict;
use warnings;

use EnsEMBL::Web::Interface::ZMenuItem;
our @ISA = qw(EnsEMBL::Web::Interface::ZMenuItem);

{

my %URL_of;

sub new {
  ### c
  my ($class, %params) = @_;
  my $self = $class->SUPER::new(%params);
  $URL_of{$self}    = defined $params{url} ? $params{url} : "";

  $self->type('text');
  return $self;
}

sub display {
  my $self = shift;
  return "<a href=\\'" . $self->url . "\\'>" . $self->text . "</a>";
}

sub url {
  ### a
  my $self = shift;
  $URL_of{$self} = shift if @_;
  return $URL_of{$self};
}

sub DESTROY {
  ### d
  my $self = shift;
  delete $URL_of{$self};
}

}

1;
