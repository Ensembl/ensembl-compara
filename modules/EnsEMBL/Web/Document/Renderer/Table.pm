package EnsEMBL::Web::Document::Renderer::Table;

use strict;
use Class::Std;

{
  my %Sheet_of    :ATTR( :get<sheet>  );
  my %Width_of    :ATTR( :set<width> :get<width> ); 
  my %Renderer_of :ATTR( :name<renderer> );

  sub _init             {warn "Must redefine this function ";}
  sub heading           {warn "Must redefine this function ";}
  sub print             {warn "Must redefine this function ";}
  sub next_row          {warn "Must redefine this function ";}
  sub write_cell        {warn "Must redefine this function ";}
  sub write_header_cell {warn "Must redefine this function ";}
  sub new_table         {warn "Must redefine this function ";}
  sub new_sheet         {warn "Must redefine this function ";}
}

