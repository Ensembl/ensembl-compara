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


=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::ComparaHMM::BlastFactoryUnannotatedMembers

=cut

package Bio::EnsEMBL::Compara::RunnableDB::ComparaHMM::BlastFactoryUnannotatedMembers;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BlastFactory');


sub fetch_input {
    my ($self) = @_;

    my $unannotated_member_ids;

    if($self->param('no_nulls')){
        $unannotated_member_ids = $self->compara_dba->get_HMMAnnotAdaptor->fetch_all_seqs_missing_annot('no_null');
    }else{
        $unannotated_member_ids = $self->compara_dba->get_HMMAnnotAdaptor->fetch_all_seqs_missing_annot();
    }

    my $members = $self->compara_dba->get_SeqMemberAdaptor->fetch_all_by_dbID_list($unannotated_member_ids);
    $self->param('query_members', $members);

}

sub flow_blast_jobs {
    my ($self, $output_id) = @_;
    $self->dataflow_output_id($output_id, 2);
}

1;
