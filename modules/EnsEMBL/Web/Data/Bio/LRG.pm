package EnsEMBL::Web::Data::Bio::LRG;

### NAME: EnsEMBL::Web::Data::Bio::LRG
### Wrapper around a hashref containing two Bio::EnsEMBL:: objects, one on
### LRG coordinates and one on standard Ensembl chromosomal coordinates 

### STATUS: Under Development

### DESCRIPTION:
### This module and its children provide additional data-handling
### capabilities on top of those provided by the API

use strict;
use warnings;
no warnings qw(uninitialized);

use base qw(EnsEMBL::Web::Data::Bio);

sub convert_to_drawing_parameters {
  my $self = shift;
  my $data = $self->data_objects;
  my $results = [];

  foreach my $slice_pair (@$data) {
    my $lrg = $slice_pair->{'lrg'};
    my $chr = $slice_pair->{'chr'};
    if (ref($lrg) =~ /UnmappedObject/) {
      my $unmapped = $self->unmapped_object($lrg);
      push(@$results, $unmapped);
    }
    else {
      (my $lrg_number = $lrg->seq_region_name) =~ s/^LRG_//i; 
      push @$results, {
        'lrg_name'    => $lrg->seq_region_name,
        'lrg_number'  => $lrg_number,
        'lrg_start'   => $lrg->start,
        'lrg_end'     => $lrg->end,
        'region'      => $chr->seq_region_name,
        'start'       => $chr->start,
        'end'         => $chr->end,
        'strand'      => $chr->strand,
        'length'      => $chr->seq_region_length,
        'label'       => $chr->name,
      };
    }
  }

  return [$results, [], 'LRG'];
}

1;
