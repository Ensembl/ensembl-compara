=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2022] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Draw::GlyphSet::_transcript;

### Default module for drawing Ensembl transcripts (i.e. where rendering
### does not need to be tweaked to fit a particular display)

use strict;

use List::Util qw(min max);

use base qw(EnsEMBL::Draw::GlyphSet_transcript_new);

sub export_feature {
  my ($self, $feature, $transcript_id, $transcript_name, $gene_id, $gene_name, $gene_type, $gene_source) = @_;
  
  return $self->_render_text($feature, 'Exon', {
    headers => [ 'gene_id', 'gene_name', 'transcript_id', 'transcript_name', 'exon_id', 'gene_type' ],
    values  => [ $gene_id, $gene_name, $transcript_id, $transcript_name, $feature->stable_id, $gene_type ]
  }, { source => $gene_source });
}

sub href {
  my ($self, $gene, $transcript) = @_;
  my $hub    = $self->{'config'}->hub;
  my $params = {
    %{$hub->multi_params},
    species    => $self->species,
    type       => $transcript ? 'Transcript' : 'Gene',
    action     => $self->my_config('zmenu') ? $self->my_config('zmenu') : $hub->action,
    g          => $gene->stable_id,
    db         => $self->my_config('db'),
    calling_sp => $hub->species,
    real_r     => $hub->param('r'),
  };

  $params->{'r'} = undef                  if $self->{'container'}{'web_species'} ne $self->species;
  $params->{'t'} = $transcript->stable_id if $transcript;

  return $self->_url($params);
}

1;
