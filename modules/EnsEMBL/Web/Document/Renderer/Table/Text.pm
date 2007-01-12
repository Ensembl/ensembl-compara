package EnsEMBL::Web::Document::Renderer::Table::Text;

use strict;
use Class::Std;

{
  my %Renderer_of       :ATTR( :name<renderer> );
  my %Formats_of        :ATTR( :get<formats>   );
  my %Started_of        :ATTR;

  sub BUILD { 
    my( $self, $ident, $arg_ref ) = @_;
    $Started_of{ $ident } = 0;
  }

  sub set_width {
    return;
  }

  sub new_sheet {
### Start a new sheet
### Set start and End to 1
    my( $self, $name ) = @_;
    $self->new_table;
  }

  sub new_table {
### Start a new table
### In Text this just moves down two rows...
    my $self = shift;
    if( $Started_of{ ident $self } ) {
      $self->get_renderer->print("\n\n");
    } else {
      $Started_of{ ident $self } = 1;
    }
  }

  sub new_row {
### Start a new row
    my $self = shift;
    $self->get_renderer->print("\n");
  }

  sub new_cell {
### Move right one cell...
    my $self = shift;
    $self->get_renderer->print("\t");
  }

  sub new_format {
    my $self = shift;
    return undef; 
  }

  sub print {
### Print a spanning row of plain text...
    my $self = shift;
    $self->get_renderer->print( @_,"\n" );
  }

  sub heading {
### Print a spanning row of bold/centered text...
    my( $self, $content, $format ) = @_;
    $self->get_renderer->print( $content,"\n" );
    $self->get_renderer->print( '=' x length( $content ),"\n" );
  }

  sub write_header_cell {
### Equivalent of "TH"
    my $self = shift;
    $self->get_renderer->print( @_,"\t" );
  }

  sub write_cell {
### Equivalent of "TD"
    my $self = shift;
    $self->get_renderer->print( @_,"\t" );
  }

  sub clean_up {
### Clean up - nothing requried...
    my $self = shift;
    if( $Started_of{ ident $self } )  {
      $self->get_renderer->print( "\n" );
    }
  }

}
1;
