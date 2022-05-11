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

package EnsEMBL::Web::Utils::Variation;

## Handy methods for formatting variation content

use base qw(Exporter);

our @EXPORT = our @EXPORT_OK = qw(render_sift_polyphen);

sub render_sift_polyphen {
  ## render a sift or polyphen prediction with colours and a hidden span with a rank for sorting
  my ($pred, $score) = @_;

  return '-' unless defined($pred) || defined($score);

  my %classes = (
    '-'                 => '',
    'probably damaging' => 'bad',
    'possibly damaging' => 'ok',
    'benign'            => 'good',
    'unknown'           => 'neutral',
    'tolerated'         => 'good',
    'deleterious'       => 'bad',

    # slightly different format for SIFT low confidence states
    # depending on whether they come direct from the API
    # or via the VEP's no-whitespace processing
    'tolerated - low confidence'   => 'neutral',
    'deleterious - low confidence' => 'neutral',
    'tolerated low confidence'     => 'neutral',
    'deleterious low confidence'   => 'neutral',
  );

  my %ranks = (
    '-'                 => 0,
    'probably damaging' => 4,
    'possibly damaging' => 3,
    'benign'            => 1,
    'unknown'           => 2,
    'tolerated'         => 1,
    'deleterious'       => 2,
  );

  my ($rank, $rank_str);

  if(defined($score)) {
    $rank = int(1000 * $score) + 1;
    $rank_str = "$score";
  }
  else {
    $rank = $ranks{$pred};
    $rank_str = $pred;
  }

  return qq(
    <span class="hidden">$rank</span><span class="hidden export">$pred(</span><div align="center"><div title="$pred" class="_ht score score_$classes{$pred}">$rank_str</div></div><span class="hidden export">)</span>
  );
}


1;
