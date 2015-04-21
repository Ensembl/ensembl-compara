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

Bio::EnsEMBL::Compara::RunnableDB::DumpMembersIntoFasta

=head1 DESCRIPTION

This is a Compara-specific module that dumps the sequences related to
a given genome_db_id into a file in Fasta format.

Supported keys:
    'genome_db_id' => <number>
        The id of the genome. Obligatory

    'fasta_dir' => <directory_path>
        Location to write fasta file

    'only_canonical' => 0/1 [default: 1]
        Do we dump all the members or only the canonical ones ?

=cut


package Bio::EnsEMBL::Compara::RunnableDB::DumpMembersIntoFasta;

use strict;

use Bio::EnsEMBL::Compara::MemberSet;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');



sub param_defaults {
    return {
        'only_canonical'    => 1,
    };
}


sub fetch_input {
    my $self = shift @_;

    my $genome_db_id = $self->param_required('genome_db_id');
    my $genome_db = $self->compara_dba->get_GenomeDBAdaptor->fetch_by_dbID($genome_db_id) or die "cannot fetch GenomeDB with id '$genome_db_id'";

    my $fasta_file = $self->param('fasta_dir') . '/' . $genome_db->name() . '_' . $genome_db->assembly() . ($genome_db->genome_component ? '_comp_'.$genome_db->genome_component : '') . '.fasta';
    $fasta_file =~ s/\s+/_/g;    # replace whitespace with '_' characters
    $fasta_file =~ s/\/\//\//g;  # converts any // in path to /
    $self->param('fasta_file', $fasta_file);

    my $members;
    if ($self->param('only_canonical')) {
        $members = $self->compara_dba->get_SeqMemberAdaptor->fetch_all_canonical_by_GenomeDB($genome_db_id);
    } else {
        $members = $self->compara_dba->get_SeqMemberAdaptor->fetch_all_by_GenomeDB($genome_db_id);
    }

    # write fasta file:
    Bio::EnsEMBL::Compara::MemberSet->new(-members => $members)->print_sequences_to_file($fasta_file);
}

sub write_output {
    my $self = shift @_;

    $self->input_job->autoflow(0);
    $self->dataflow_output_id( { 'fasta_name' => $self->param('fasta_file'), 'genome_db_id' => $self->param('genome_db_id') } , 1);
}


1;

