package EnsEMBL::Web::Interface::Table::Row;

use strict;
use warnings;

our @ISA = qw(EnsEMBL::Web::Interface::Table);

{

sub add_column {
  my ($self, $params) = @_;
  push @{ $self->elements }, $params;
}

sub render {
  my ($self) = @_;
  my $html = "";
  foreach my $column (@{ $self->elements }) {
    my $width = "";
    my $style = "";
    if ($column->{width}) {
      $width = "width=\"" . $column->{width} . "\"";
    }
    if ($column->{align}) {
      $style= "style='text-align: " . $column->{align} . "'";
    }
    $html .= "<td $width $style>" . $column->{content} . "</td>\n";
  }
  return $html;
} 

}

1;
