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

package EnsEMBL::Web::Component::Gene::RetirementNotice;

### Displays a warning box about the retirement of this display in human

use strict;

use base qw(EnsEMBL::Web::Component);

sub _init {
  my $self = shift;
  $self->cacheable(1);
  $self->ajaxable(0);
}

sub content {
  my $self           = shift;
  my $hub            = $self->hub;
  return unless $hub->species eq 'Homo_sapiens';

  my $message = qq(<h4>Human only - retirement of this view</h4>
<p>As of Ensembl release 93 this view will no longer be available for human, because we feel that the density of known human genetic variation is too great for the display to be informative in its current form.</p>
<p>Other species will not be affected, as they have less variation data.</p>
<p>For more information about the decision and on how to find variation data for a gene, please see <a href="http://www.ensembl.info/2018/06/05/gene-variant-image-retirement-for-human-e93/">our blog post</a>.</p>
                    );
  return $self->_warning('Retirement notice', $message);
}

1;
