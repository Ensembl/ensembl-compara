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

  foreach my $array (@$data) {
    my $xref = shift @$array;
    
    push @$results, {
      'label'     => $xref->primary_id,
      'xref_id'   => [ $xref->primary_id ],
      'extname'   => $xref->display_id,      
      'extra'     => [ $xref->description, $xref->dbname ]
    };
    ## also get genes
    foreach my $g (@$array) {
      push @$results, {
        'region'   => $g->seq_region_name,
        'start'    => $g->start,
        'end'      => $g->end,
        'strand'   => $g->strand,
        'length'   => $g->end-$g->start+1,
        'extname'  => $g->external_name,
        'label'    => $g->stable_id,
        'gene_id'  => [ $g->stable_id ],
        'extra'    => [ $g->description ],
        'href'      => $hub->url({ type => 'Zmenu', action => 'Gene'}),
      }
    }
  }

  return [$results, ['Description'], 'Xref'];
}

1;