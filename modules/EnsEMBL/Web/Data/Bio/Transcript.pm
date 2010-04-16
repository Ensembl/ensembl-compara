package EnsEMBL::Web::Data::Bio::Transcript;

### NAME: EnsEMBL::Web::Data::Bio::Transcript
### Base class - wrapper around a Bio::EnsEMBL::Transcript API object 

### STATUS: Under Development
### Replacement for EnsEMBL::Web::Object::Transcript

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

  foreach my $t (@$data) {
    if (ref($t) =~ /UnmappedObject/) {
      my $unmapped = $self->unmapped_object($t);
      push(@$results, $unmapped);
    }
    else {
      my $desc = $t->trans_description();
      push @$results, {
        'region'   => $t->seq_region_name,
        'start'    => $t->start,
        'end'      => $t->end,
        'strand'   => $t->strand,
        'length'   => $t->end-$t->start+1,
        'extname'  => $t->external_name,
        'label'    => $t->stable_id,
        'trans_id' => [ $t->stable_id ],
        'extra'    => [ $desc ]
      }

    }
  }

  return [$results, ['Description'], 'Transcript'];
}

1;
