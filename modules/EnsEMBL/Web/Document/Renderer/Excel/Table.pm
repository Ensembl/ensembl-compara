=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2021] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

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
