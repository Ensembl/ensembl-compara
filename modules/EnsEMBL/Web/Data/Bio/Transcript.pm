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

sub trans_description {
  my ($self, $transcript) = @_;
  my $gene = $self->gene($transcript);
  my %description_by_type = ( 'bacterial_contaminant' => 'Probable bacterial contaminant' );

  if ($gene) {
    return $gene->description || $description_by_type{$gene->biotype} || 'No description';
  }

  return 'No description';
}

sub gene {
  my $self = shift;
  my $transcript = shift;
  my $hub = $self->hub;

  if (@_) {
    $self->{'_gene'} = shift;
  } 
  elsif (!$self->{'_gene'} || $hub->action eq 'Genome' ) {
    eval {
      my $db = $hub->param('db') || 'core';
      my $adaptor_call = $hub->param('gene_adaptor') || 'get_GeneAdaptor';
      my $GeneAdaptor = $hub->database($db)->$adaptor_call;
      my $Gene = $GeneAdaptor->fetch_by_transcript_stable_id($transcript->stable_id);
      $self->{'_gene'} = $Gene if $Gene;
    };
  }

  return $self->{'_gene'};
}


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
      my $desc = $self->trans_description($t);
      push @$results, {
        'region'   => $t->seq_region_name,
        'start'    => $t->start,
        'end'      => $t->end,
        'strand'   => $t->strand,
        'length'   => $t->end-$t->start+1,
        'extname'  => $t->external_name,
        'label'    => $t->stable_id,
        'trans_id' => [ $t->stable_id ],
        'extra'    => {'description' => $desc},
      }

    }
  }
  my $extra_columns = [{'key' => 'description', 'title' => 'Description'}];
  return [$results, $extra_columns];
}

1;
