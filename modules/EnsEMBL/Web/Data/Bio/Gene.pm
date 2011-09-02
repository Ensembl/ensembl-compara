package EnsEMBL::Web::Data::Bio::Gene;

### NAME: EnsEMBL::Web::Data::Bio::Gene
### Base class - wrapper around a Bio::EnsEMBL::Gene API object 

### STATUS: Under Development
### Replacement for EnsEMBL::Web::Object::Gene

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
  my $self = shift;
  my $data = $self->data_objects;
  my $results = [];
  my $hub = $self->hub;

  foreach my $g (@$data) {
    if (ref($g) =~ /UnmappedObject/) {
      my $unmapped = $self->unmapped_object($g);
      push(@$results, $unmapped);
    }
    else {
      push @$results, {
        'region'   => $g->seq_region_name,
        'start'    => $g->start,
        'end'      => $g->end,
        'strand'   => $g->strand,
        'length'   => $g->end-$g->start+1,
        'extname'  => $g->external_name,
        'label'    => $g->stable_id,
        'gene_id'  => [ $g->stable_id ],
        'extra'    => {'description' => $g->description},
        'href'     => $hub->url({ type => 'ZMenu', action => 'Gene', g => $g->stable_id, r => ($g->seq_region_name . ':' . $g->seq_region_start . '-' . $g->seq_region_end)}),        
      }
    }
  }
  my $extra_columns = [{'key' => 'description', 'title' => 'Description'}];
  return [$results, $extra_columns];
}

1;
