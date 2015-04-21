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


=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::BlastpWithReuse

=head1 DESCRIPTION

Create fasta file containing batch_size number of sequences. Run ncbi_blastp and parse the output into
PeptideAlignFeature objects. Store PeptideAlignFeature objects in the compara database
Supported keys:

=cut


package Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::BlastpWithReuse;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BlastAndParsePAF');


sub get_queries {
    my $self = shift @_;

    my $start_member_id = $self->param_required('start_member_id');
    my $end_member_id   = $self->param_required('end_member_id');
    my $genome_db_id    = $self->param_required('genome_db_id');

    #Get list of members and sequences
    return $self->compara_dba->get_SeqMemberAdaptor->generic_fetch("mg.genome_db_id=$genome_db_id AND m.seq_member_id BETWEEN $start_member_id AND $end_member_id", [[['gene_member', 'mg'], 'mg.canonical_member_id = m.seq_member_id']]);
}


1;
