=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2018] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Data::Bio::RegulatoryFeature;

### NAME: EnsEMBL::Web::Data::Bio::RegulatoryFeature
### Base class - wrapper around a Bio::EnsEMBL::RegulatoryFeature API object 

### STATUS: Under Development
### Replacement for EnsEMBL::Web::Object::RegulatoryFeature

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

  foreach my $reg (@$data) {
    my ($gene_links, @stable_ids, $mirna_id);
    if (ref($reg) =~ /Mirna/) {
      my $stable_id = $reg->gene_stable_id;
      @stable_ids   = ($stable_id);
      $mirna_id     = $reg->accession;
    }
    else {
      my $db_ent = $reg->get_all_DBEntries;
      foreach ( @{ $db_ent} ) {
        push @stable_ids, $_->primary_id;
      }
    }

    foreach my $stable_id (@stable_ids) {
      my $url = $self->hub->url({'type' => 'Gene', 'action' => 'Summary', 'g' => $stable_id });
      $gene_links .= qq(<a href="$url">$stable_id</a>);
    }

    my @extra_results = $reg->analysis->description;
    ## Sort out any links/URLs
    if ($extra_results[0] =~ /tarbase/i) {
      @extra_results = ($self->hub->get_ExtURL_link($mirna_id, 'TARBASE_V8', $mirna_id));
    }
    elsif ($extra_results[0] =~ /a href/i) {
      $extra_results[0] =~ s/a href/a rel="external" href/ig;
    }
    else {
      $extra_results[0] =~ s/(https?:\/\/\S+[\w\/])/<a rel="external" href="$1">$1<\/a>/ig;
    }
    ## Final value has to be a string, to aid auto-display
    my $analyses = join(', ', @extra_results);

    push @$results, {
      'region'   => $reg->seq_region_name,
      'start'    => $reg->start,
      'end'      => $reg->end,
      'strand'   => $reg->strand,
      'length'   => $reg->end-$reg->start+1,
      'label'    => $reg->display_label,
      'gene_id'  => \@stable_ids,
      'extra'    => {
                    'gene'      => $gene_links,
                    'analysis'  => $analyses,
      },
    }
  }
   my $extra_columns = [
                    {'key' => 'gene',     'title' => 'Associated gene'},
                    {'key' => 'analysis', 'title' => 'Link to Tarbase', 'sort' => 'html'},
  ];
  return [$results, $extra_columns];
}

1;
