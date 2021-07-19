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

package EnsEMBL::Web::ZMenu::Gene::RefSeq;

use strict;

use base qw(EnsEMBL::Web::ZMenu::Gene);

sub content {
  my $self      = shift;
  my $object    = $self->object;
  my $stable_id = $object->stable_id;
  my $gene      = $object->Obj;
  my $gene_xref   = $gene->display_xref->primary_id;

  $gene_xref ||= $stable_id;
  
  $self->SUPER::content;

  $self->delete_entry_by_type('Gene ID');
  $self->delete_entry_by_type('Gene Symbol');
  
  $self->caption($gene_xref);
  
  $self->add_entry({
    type     => 'RefSeq gene',
    label    => $gene_xref,
    link     => $self->hub->get_ExtURL_link($gene_xref, 'REFSEQ_GENEIMP', $gene_xref),
    abs_url  => 1,
    position => 1,
  });
  
  my $biotype = lc $gene->biotype;
    $biotype  =~ s/_/ /g;
    $biotype  =~ s/rna/RNA/;
  
  $self->modify_entry_by('type', {
    type  => 'Gene type',
    label => $biotype,
  });
  

}

1;
