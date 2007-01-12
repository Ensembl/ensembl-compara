package EnsEMBL::Web::Document::Renderer::Table::Excel;

use strict;
use Class::Std;

{
  my %Renderer_of       :ATTR( :name<renderer> );
  my %Formats_of        :ATTR( :get<formats>   );

  sub BUILD { 
    my( $self, $ident, $arg_ref ) = @_;
  }

  sub set_width {
    my( $self, $width ) = @_;
    $self->get_renderer->set_width( $width );
  }
  sub new_sheet {
### Start a new sheet
### Set start and End to 1
    my( $self, $name ) = @_;
    $self->get_renderer->new_sheet( $name );
  }

  sub new_table {
### Start a new table
### In Excel this just moves down two rows...
    my $self = shift;
    $self->get_renderer->new_row;
    $self->get_renderer->new_row;
  }

  sub new_row {
### Start a new row
    my $self = shift;
    $self->get_renderer->new_row;
  }

  sub new_cell {
### Move right one cell...
    my $self = shift;
    $self->get_renderer->new_cell;
  }

  sub new_format {
    my $self = shift;
    return $self->get_renderer->new_cell_format( shift );
  }
  sub print {
### Print a spanning row of plain text...
    my $self = shift;
    $self->get_renderer->print( @_ );
  }

  sub heading {
### Print a spanning row of bold/centered text...
    my( $self, $content, $format ) = @_;
    unless( $format ) {
      $format = $self->new_format({
        'colspan' => 2,
        'bold'    => 1,
        'bgcolor' => 'ffffcc',
        'fgcolor' => '993333',
        'align'   => 'center',
      });
    }
    $self->get_renderer->print( $content, $format );
  }

  sub write_header_cell {
### Equivalent of "TH"
    my( $self, $content, $format ) = @_;
    unless( defined( $format ) ) {
      $format = $self->new_format({
        'bold'  => 1,
        'align' => 'center',
        'bgcolor' => 'ffffdd',
      });
    }
    $self->write_cell( $content, $format);
  }

  sub write_cell {
### Equivalent of "TD"A
    my $self = shift;
    $self->get_renderer->write_cell( @_ );
  }

  sub clean_up {
### Clean up - nothing requried...
    my $self = shift;
  }

}
1;
