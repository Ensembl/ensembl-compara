package EnsEMBL::Web::Interface::Table;

use strict;
use warnings;

{

my %Style_of;
my %Class_of;
my %Elements_of;

sub new {
  ### c
  my ($class, %params) = @_;
  my $self = bless \my($scalar), $class;
  $Style_of{$self}   = defined $params{style} ? $params{style} : "";
  $Class_of{$self}   = defined $params{class} ? $params{class} : "";
  $Elements_of{$self}   = defined $params{elements} ? $params{elements} : [];
  return $self;
}

sub elements {
  ### a
  my $self = shift;
  $Elements_of{$self} = shift if @_;
  return $Elements_of{$self};
}

sub add_row {
  my ($self, $row) = @_;
  push @{ $self->elements }, $row;
}

sub style {
  ### a
  my $self = shift;
  $Style_of{$self} = shift if @_;
  return $Style_of{$self};
}

sub class {
  ### a
  my $self = shift;
  $Class_of{$self} = shift if @_;
  return $Class_of{$self};
}

sub render {
  my ($self) = @_;
  my $html = "<table class='" . $self->class . "' style='" . $self->style . "'>\n";
  my $count = 0;
  my $colour = 'bg1';
  foreach my $row (@{ $self->elements }) {
    $count++;
    $colour = 'bg1';
    if ($count % 2) {
      $colour = 'bg2';
    }
    $html .= "<tr class=\"$colour\">\n";
    $html .= $row->render;
    $html .= "</tr>";
  }
  $html .= "</table>";
  return $html;
} 

sub DESTROY {
  ### d
  my ($self) = shift;
  delete $Style_of{$self};
  delete $Class_of{$self};
  delete $Elements_of{$self};
}

}

1;
