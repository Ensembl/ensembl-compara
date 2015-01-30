=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

package EnsEMBL::Draw::GlyphSet::_prediction_transcript;

### Draws prediction transcripts, e.g. Genscan

use strict;

use Bio::EnsEMBL::Gene;

use base qw(EnsEMBL::Draw::GlyphSet::_transcript);

sub _das_type { return 'prediction_transcript'; }

sub _make_gene {
  my ($self, $transcript) = @_;
  my $gene = Bio::EnsEMBL::Gene->new;
  
  $gene->add_Transcript($transcript);
  $gene->stable_id($transcript->stable_id); # fake a stable id so that the data structures returned by features are correct.
  
  return $gene;
}

sub features {
  my $self     = shift;
  my $slice    = $self->{'container'};
  my $db_alias = $self->my_config('db');

  return $self->SUPER::features(map $self->_make_gene($_), map @{$slice->get_all_PredictionTranscripts($_, $db_alias) || []}, @{$self->my_config('logic_names')});
}

## Hacked url for prediction transcripts pt=xxx
sub href {
  my ($self, $gene, $transcript) = @_;
  
  return $self->SUPER::href($gene) unless $transcript;
  
  return $self->_url({
    type   => 'Transcript',
    action => 'Summary',
    pt     => $transcript->stable_id,
    g      => undef,
    db     => $self->my_config('db')
  });
}

sub export_feature {
  my $self = shift;
  my ($feature, $transcript_id, $source) = @_;
  
  return $self->_render_text($feature, "$source prediction", { headers => [ 'transcript_id' ], values => [ $transcript_id ] });
}

1;
