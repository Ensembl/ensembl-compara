#$Id$
package EnsEMBL::Web::Data::Bio::Xref;

### NAME: EnsEMBL::Web::Data::Bio::Xref
### Base class - wrapper around a Bio::EnsEMBL::Xref API object 

### STATUS: Under Development
### Replacement for EnsEMBL::Web::Object::Xref

### DESCRIPTION:
### This module provides additional data-handling
### capabilities on top of those provided by the API

use strict;
use warnings;
no warnings qw(uninitialized);

use base qw(EnsEMBL::Web::Data::Bio);

sub convert_to_drawing_parameters {
### Converts a set of API objects into simple parameters 
### for use by drawing code and HTML components
### href parameter in $results is used for ZMenu drawing

  my $self = shift;
  my $data = $self->data_objects;
  my $results = [];
  my $hub = $self->hub;  
  my $ftype = $hub->param('ftype');

  foreach my $array (@$data) {    
    my $xref = shift @$array;  
    
    foreach my $g (@$array) {      
      my $loc   = $g->seq_region_name.':'.$g->start.'-'.$g->end;
      my $name  = $xref->display_id;
      $name     =~ s/ \[#\]//;
      $name     =~ s/^ //;
      push @$results, {
        'label'    => $xref->db_display_name,
        'xref_id'  => [ $xref->primary_id ],
        'extname'  => $xref->display_id,  
        'start'    => $g->start,
        'end'      => $g->end,
        'region'   => $g->seq_region_name,
        'strand'   => $g->strand,
        'length'   => $g->end-$g->start+1,
        'extra'    => {'description' => $g->description, 'dbname' => $xref->dbname},
        'href'     => $hub->url({ 
                        type      => 'ZMenu', 
                        action    => 'Feature', 
                        function  => 'Xref', 
                        ftype     => $ftype, 
                        id        => $xref->primary_id, 
                        name      => $name,
                        r         => $loc, 
                        g         => $g->stable_id, 
                        desc      => $g->description,
                      }),
      };
    }
  }  

  my $extra_columns = [{'key' => 'description', 'title' => 'Description'}];
  return [$results, $extra_columns];
}

1;
