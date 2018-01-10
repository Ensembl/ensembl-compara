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

Bio::EnsEMBL::Compara::RunnableDB::ComparaHMM::DumpUnannotatedMembersIntoFasta

=head1 DESCRIPTION

This is a Compara-specific module that dumps the all sequences
that lack an HMM annnotation into a file in Fasta format.

Supported keys:

    'fasta_dir' => <directory_path>
        Location to write fasta file

=cut


package Bio::EnsEMBL::Compara::RunnableDB::ComparaHMM::DumpUnannotatedMembersIntoFasta;

use strict;
use warnings;

use Bio::EnsEMBL::Compara::MemberSet;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub fetch_input {
    my $self = shift @_;

    my $member_ids;

    if($self->param('no_nulls')){
        $member_ids = $self->compara_dba->get_HMMAnnotAdaptor->fetch_all_seqs_missing_annot('no_null');
    }else{
        $member_ids = $self->compara_dba->get_HMMAnnotAdaptor->fetch_all_seqs_missing_annot();
    }

    if (scalar(@{$member_ids}) < 1){
        $self->input_job->autoflow(0);
        my $exit_msg = "No unannotated members were found.";
        $self->complete_early($exit_msg);
    }

    my $unannotated_members = $self->compara_dba->get_SeqMemberAdaptor->fetch_all_by_dbID_list($member_ids);

    # write fasta file:
    my $member_set = Bio::EnsEMBL::Compara::MemberSet->new(-members => $unannotated_members);
    Bio::EnsEMBL::Compara::Utils::Preloader::load_all_sequences($self->compara_dba->get_SequenceAdaptor, undef, $member_set);
    $member_set->print_sequences_to_file($self->param('fasta_file'));
}

sub write_output {
    my $self = shift @_;

    $self->input_job->autoflow(0);
    $self->dataflow_output_id( { 'fasta_name' => $self->param('fasta_file') } , 1);
}


1;

