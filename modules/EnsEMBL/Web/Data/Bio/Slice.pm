package EnsEMBL::Web::Data::Bio::Slice;

### NAME: EnsEMBL::Web::Data::Bio::Slice
### Wrapper around a Bio::EnsEMBL::Slice object 

### STATUS: Under Development

### DESCRIPTION:
### This module and its children provide additional data-handling
### capabilities on top of those provided by the API

use strict;
use warnings;
no warnings qw(uninitialized);

use base qw(EnsEMBL::Web::Data::Bio);

sub convert_to_drawing_parameters {
### Stub - individual object types probably need to implement this separately
  my $self = shift;
  my $slice = $self->data_object;
  my $result;
  if (ref($slice) =~ /UnmappedObject/) {
    $result = $self->unmapped_object($slice);
  }
  else {
    (my $number = $slice->seq_region_name) =~ s/^LRG_//i;
    $result = {
        'number'   => $number,
        'region'   => $slice->seq_region_name,
        'start'    => $slice->start,
        'end'      => $slice->end,
        'strand'   => $slice->strand,
        'length'   => $slice->seq_region_length,
        'label'    => $slice->name,
    };
  }
  return [$result, []];

}

1;
