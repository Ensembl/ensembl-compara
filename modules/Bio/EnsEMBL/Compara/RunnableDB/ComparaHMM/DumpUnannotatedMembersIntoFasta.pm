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

Bio::EnsEMBL::Compara::RunnableDB::ComparaHMM::DumpUnannotatedMembersIntoFasta

=head1 SYNOPSIS


=head1 DESCRIPTION

This is a Compara-specific module that dumps the all sequences
that lack an HMM annnotation into a file in Fasta format.

Supported keys:

    'fasta_dir' => <directory_path>
        Location to write fasta file

=cut


package Bio::EnsEMBL::Compara::RunnableDB::ComparaHMM::DumpUnannotatedMembersIntoFasta;

use strict;

use Bio::EnsEMBL::Compara::MemberSet;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub fetch_input {
    my $self = shift @_;

    my $sth = $self->compara_dba->get_HMMAnnotAdaptor->fetch_all_genes_missing_annot();
    my $member_ids = [map {$_->[0]} @{$sth->fetchall_arrayref}];
    my $unannotated_members = $self->compara_dba->get_SeqMemberAdaptor->fetch_all_by_dbID_list($member_ids);

    # write fasta file:
    Bio::EnsEMBL::Compara::MemberSet->new(-members => $unannotated_members)->print_sequences_to_file($self->param('fasta_file'));
}

sub write_output {
    my $self = shift @_;

    $self->input_job->autoflow(0);
    $self->dataflow_output_id( { 'fasta_name' => $self->param('fasta_file') } , 1);
}


1;

