package EnsEMBL::Web::Document::Renderer::Table::HTML;

use strict;
use Class::Std;

{
  my %Renderer_of       :ATTR( :name<renderer> );
  my %Formats_of        :ATTR( :get<formats>   );
  my %Started_of        :ATTR;
  my %Table_HTML_of     :ATTR( :get<table_html> :set<table_html> );
  my %Row_HTML_of       :ATTR( :get<row_html>   :set<row_html>   );
  my %Heading_of        :ATTR( :get<heading>    :set<heading>    );
  sub BUILD { 
    my( $self, $ident, $arg_ref ) = @_;
    $Started_of{ $ident }    = 0;
    $Table_HTML_of{ $ident } = ''; 
    $Heading_of{ $ident }    = ''; 
  }

  sub set_width {
    my( $self, $width ) = @_;
  }

  sub new_sheet {
### Start a new sheet
### Set start and End to 1
    my( $self, $name ) = @_;
    $self->new_table;
  }

  sub _flush {
    my $self = shift;
    $self->_flush_row;
    my $table = $self->get_table_html;
    if( $table ) { 
      $self->get_renderer->print( qq(<table width="100%">\n$table</table>\n) );
      $self->set_table_html( '' );
    }
  }

  sub _flush_row {
    my $self = shift ;
    my $row =  $self->get_row_html;
    if( $row ) {
      $self->add_table_html( "  <tr>\n$row  </tr>\n" );
      $self->set_row_html( '' );
    }
  } 

  sub new_table {
### Start a new table
### In Excel this just moves down two rows...
    my $self = shift;
    if( $Started_of{ ident $self } ) {
      $self->_flush;
    } else {
      $Started_of{ ident $self } = 1;
    }
  }

  sub new_row {
### Start a new row
    my $self = shift;
    $self->_flush_row;
    $self->set_row_html('');
  }

  sub new_cell {
### Move right one cell...
    my $self = shift;
#    $self->get_renderer->new_cell;
  }

  sub new_format {
    my $self = shift;
    return $self->get_renderer->new_cell_format( shift );
  }
  sub print {
### Print a spanning row of plain text...
    my $self = shift;
    $self->get_renderer->print( '<p>', @_, '</p>' );
  }

  sub heading {
### Print a spanning row of bold/centered text...
    my( $self, $content, $format ) = @_;
    $self->get_renderer->print( '<h3>', $content, '</h3>' );
  }

  sub add_table_html {
    my($self,$text) =@_;
    $Table_HTML_of{ ident $self }.= $text; 
  }

  sub add_row_html {
    my($self,$text) =@_;
    $Row_HTML_of{ ident $self }.= $text; 
  }

  sub write_header_cell {
### Equivalent of "TH"
    my( $self, $content, $format ) = @_;
    $format = $self->new_format({'bold'=>1,'align'=>'center'}) unless $format;
    $self->add_row_html( sprintf( "    <th%s>%s</th>\n", $format->evaluate, $content ) );
  }

  sub write_cell {
### Equivalent of "TD"
    my( $self, $content, $format ) = @_;
    $format = $self->new_format({}) unless $format;
    $self->add_row_html( sprintf( "    <td%s>%s</td>\n", $format->evaluate, $content ) );
  }

  sub clean_up {
### Clean up - nothing requried...
    my $self = shift;
    $self->_flush;
  }

}
1;
