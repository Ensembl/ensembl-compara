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

package EnsEMBL::Web::Component::Gene::Compara_Portal;

use strict;

use base qw(EnsEMBL::Web::Component::Portal);

sub content {
  my $self         = shift;
  my $hub          = $self->hub;
  my $availability = $self->object->availability;
  my $location     = $hub->url({ type => 'Location',  action => 'Compara' });

  $self->{'buttons'} = [
    { title => 'Genomic alignments', img => 'compara_align', url => $availability->{'has_alignments'} ? $hub->url({ action => 'Compara_Alignments' }) : '' },
    { title => 'Gene tree',          img => 'compara_tree',  url => $availability->{'has_gene_tree'}  ? $hub->url({ action => 'Compara_Tree'       }) : '' },
    { title => 'Orthologues',        img => 'compara_ortho', url => $availability->{'has_orthologs'}  ? $hub->url({ action => 'Compara_Ortholog'   }) : '' },
    { title => 'Paralogues',         img => 'compara_para',  url => $availability->{'has_paralogs'}   ? $hub->url({ action => 'Compara_Paralog'    }) : '' },
    { title => 'Families',           img => 'compara_fam',   url => $availability->{'family'}         ? $hub->url({ action => 'Family'             }) : '' },
  ];

  my $html  = $self->SUPER::content;
     $html .= qq{<p class="center">More views of comparative genomics data, such as multiple alignments and synteny, are available on the <a href="$location">Location</a> page for this gene.</p>};

  return $html;
}

1;
