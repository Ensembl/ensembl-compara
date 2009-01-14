package EnsEMBL::Web::Document::Renderer::CellFormat::Excel;

use strict;
use Class::Std;
use base qw( EnsEMBL::Web::Document::Renderer::CellFormat );
{ 
  my %Colour_hashref_of :ATTR( :name<colour_hashref> );
  my %Workbook_of       :ATTR( :name<workbook> );

  sub evaluate {
    my $self = shift;
    my $key = $self->key;
    my $f_hashref = $self->get_format_hashref;
    unless( exists( $f_hashref->{$key} ) ) {
      my $format = $self->get_workbook->add_format(
        'bold'    => $self->get_bold,
        'italic'  => $self->get_italic,
        'bg_color' => $self->_colour( $self->get_bgcolor ),
        'color'   => $self->_colour( $self->get_fgcolor ),
        'align'   => $self->get_align,
        'valign'  => $self->get_valign,
      );
      $f_hashref->{$key} = $format;
    }
    return $f_hashref->{$key};
  }  

  sub _colour {
    my( $self, $hex ) = @_;
     
    my $c_hashref = $self->get_colour_hashref;
    unless( exists $c_hashref->{$hex} ) {
      if( $c_hashref->{'_max_value'} < 63 ) {
        $c_hashref->{'_max_value'}++;
        $c_hashref->{$hex} = $self->get_workbook->set_custom_color( $c_hashref->{'_max_value'}, "#$hex" );
      } else {
        $c_hashref->{$hex} = undef;
      }
    }

    return $c_hashref->{$hex};
  }
}

1;
