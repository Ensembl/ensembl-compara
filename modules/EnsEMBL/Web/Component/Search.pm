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

package EnsEMBL::Web::Component::Search;

use strict;

use EnsEMBL::Web::Component::Help::Faq;
use base qw(EnsEMBL::Web::Component);


sub no_results {
  my ($self, $search_term) = @_;

  my $html = qq{<p>Your query <strong>- $search_term  -</strong> did not match any records in the database. Please make sure all terms are spelled correctly</p>};

  my $faq = EnsEMBL::Web::Component::Help::Faq->new($self->hub, $self->builder, $self->renderer);
  my $just_faq = $self->object->species_defs->ENSEMBL_SITETYPE eq 'Vega' ? 1 : 0; 
  $html .= $faq->content(373,$just_faq);

  return $html;

}

1;
