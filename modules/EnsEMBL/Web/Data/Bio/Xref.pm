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
        'desc'     => $xref->description, 
        'xref_id'  => [ $xref->primary_id ],
        'extname'  => $xref->display_id,  
        'start'    => $g->start,
        'end'      => $g->end,
        'region'   => $g->seq_region_name,
        'strand'   => $g->strand,
        'length'   => $g->end-$g->start+1,
        'extra'    => {'description' => $g->description, 'dbname' => $xref->dbname},
        'href'     => {
                        type      => 'ZMenu', 
                        action    => 'Feature', 
                        function  => 'Xref', 
                        ftype     => $ftype, 
                        id        => $xref->primary_id, 
                        name      => $name,
                        r         => $loc, 
                        g         => $g->stable_id, 
                        desc      => $g->description,
                      },
      };
    }
  }  

  my $extra_columns = [{'key' => 'description', 'title' => 'Description'}];
  return [$results, $extra_columns];
}

1;
