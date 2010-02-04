package EnsEMBL::Web::Document::Renderer::Excel::Table;

use strict;

sub new {
  my ($class, $renderer) = @_;
  my $self = { renderer => $renderer };
  bless $self, $class;
  return $self;
}

sub renderer { return $_[0]->{'renderer'}; }

sub set_width {
  my ($self, $width) = @_;
  $self->renderer->set_width($width);
}

sub new_sheet {
  ### Start a new sheet
  ### Set start and End to 1
  my ($self, $name) = @_;
  $self->renderer->new_sheet($name);
}

sub new_table {
  ### Start a new table
  ### In Excel this just moves down two rows
  my $self = shift;
  $self->renderer->new_row;
  $self->renderer->new_row;
}

sub new_row {
  ### Start a new row
  my $self = shift;
  $self->renderer->new_row;
}

sub new_cell {
  ### Move right one cell
  my $self = shift;
  $self->renderer->new_cell;
}

sub new_format {
  my $self = shift;
  return $self->renderer->new_cell_renderer(shift);
}

sub print {
  ### Print a spanning row of plain text
  my $self = shift;
  $self->renderer->print(@_);
}

sub heading {
  ### Print a spanning row of bold/centered text
  my ($self, $content, $format) = @_;
  
  if (!$format) {
    $format = $self->new_format({
      colspan => 2,
      bold    => 1,
      bgcolor => 'ffffcc',
      fgcolor => '993333',
      align   => 'center'
    });
  }
  
  $self->renderer->print($content, $format);
}

sub write_header_cell {
  ### Equivalent of "TH"
  my ($self, $content, $format) = @_;
  
  if (!defined $format) {
    $format = $self->new_format({
      bold    => 1,
      align   => 'center',
      bgcolor => 'ffffdd'
    });
  }
  
  $self->write_cell($content, $format);
}

sub write_cell {
  ### Equivalent of "TD"
  my $self = shift;
  $self->renderer->write_cell(@_);
}

sub clean_up {} # nothing required

1;
