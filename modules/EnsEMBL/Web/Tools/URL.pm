package EnsEMBL::Web::Tools::URL;

use strict;

{

my %URL_of;

sub new {
  ### c
  my ($class, %params) = @_;
  my $self = bless \my($scalar), $class;
  $URL_of{$self} = defined $params{url} ? $params{url} : "";
  if ($params{url}) {
    $self->parse;
  }
  return $self;
}

sub url {
  ### a
  my $self = shift;
  $URL_of{$self} = shift if @_;
  return $URL_of{$self};
}

sub parse {
  my $self = shift;
  my $url = $self->url;
}

sub DESTROY {
  my $self = shift;
  delete $URL_of{$self};
}

}

1;
