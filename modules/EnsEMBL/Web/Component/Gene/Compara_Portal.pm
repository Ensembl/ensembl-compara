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

use parent qw(EnsEMBL::Web::Component::Gene);

sub _init {
  my $self = shift;

  $self->cacheable(1);
  $self->ajaxable(0);
}

sub content {
  my $self          = shift;
  my $hub           = $self->hub;
  my $availability  = $self->object->availability;
  my $location      = $hub->url({ type => 'Location',  action => 'Compara' });

  my $buttons       = [
    { title => 'Genomic alignments', img => '80/compara_align.gif', url => $availability->{'has_alignments'} ? $hub->url({ action => 'Compara_Alignments' }) : '' },
    { title => 'Gene tree',          img => '80/compara_tree.gif',  url => $availability->{'has_gene_tree'}  ? $hub->url({ action => 'Compara_Tree'       }) : '' },
    { title => 'Orthologues',        img => '80/compara_ortho.gif', url => $availability->{'has_orthologs'}  ? $hub->url({ action => 'Compara_Ortholog'   }) : '' },
    { title => 'Paralogues',         img => '80/compara_para.gif',  url => $availability->{'has_paralogs'}   ? $hub->url({ action => 'Compara_Paralog'    }) : '' },
    { title => 'Families',           img => '80/compara_fam.gif',   url => $availability->{'family'}         ? $hub->url({ action => 'Family'             }) : '' },
  ];

  my $html  = $self->button_portal($buttons, 'portal-small');
     $html .= qq{<p>More views of comparative genomics data, such as multiple alignments and synteny, are available on the <a href="$location">Location</a> page for this gene.</p>};

  return $html;
}

1;
