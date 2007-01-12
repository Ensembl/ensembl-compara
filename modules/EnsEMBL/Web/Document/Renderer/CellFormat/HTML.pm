package EnsEMBL::Web::Document::Renderer::CellFormat::HTML;

use strict;
use Class::Std;
use base qw( EnsEMBL::Web::Document::Renderer::CellFormat );
{ 
  sub evaluate {
    my $self = shift;
    my $key = $self->key;
    my $f_hashref = $self->get_format_hashref;
    unless( exists( $f_hashref->{$key} ) ) {
      my $format = ' style="';
      if( $self->get_bold ) { $format .= 'font-weight: bold; '; }
      if( $self->get_italic ) { $format .= 'font-style:  italic; '; }
      $format .= 'color: #'.           $self->get_fgcolor.';';
      $format .= 'background-color: #'.$self->get_bgcolor.';';
      $format .= 'text-align: '.$self->get_align.';';
      $format .= '" valign="'.$self->get_valign.'"';
      $f_hashref->{$key} = $format;
    }
    return $f_hashref->{$key};
  }  
}

1;
