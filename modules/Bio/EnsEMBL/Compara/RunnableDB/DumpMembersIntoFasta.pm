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

Bio::EnsEMBL::Compara::RunnableDB::DumpMembersIntoFasta

=head1 DESCRIPTION

This is a Compara-specific module that dumps the sequences related to
a given genome_db_id into a file in Fasta format.

Supported keys:
    'genome_db_id' => <number>
        The id of the genome. Obligatory

    'fasta_dir' => <directory_path>
        Location to write fasta file

=cut


package Bio::EnsEMBL::Compara::RunnableDB::DumpMembersIntoFasta;

use strict;
use warnings;

use Bio::EnsEMBL::Compara::MemberSet;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');



sub param_defaults {
    return {
        'only_representative' => 0, # if seq_member_projection table is populated, dump only representative sequences
    };
}


sub fetch_input {
    my $self = shift @_;

    # accept either single genome_db_ids or an arrayref of them
    my @gdb_ids;
    die "Params 'genome_db_id' and 'genome_db_ids' are mutually exclusive!" if ( $self->param('genome_db_id') && $self->param('genome_db_ids') );
    if ( $self->param('genome_db_id') ) {
        @gdb_ids = ( $self->param('genome_db_id') );
    } elsif ( $self->param('genome_db_ids') ) {
        @gdb_ids = @{ $self->param('genome_db_ids') };
    } else {
        die "Param 'genome_db_id' or 'genome_db_ids' must be defined!";
    }

    my $gdb_adaptor = $self->compara_dba->get_GenomeDBAdaptor;

    # set output filename
    my $fasta_file;
    if ( scalar @gdb_ids == 1 ) {
        my $genome_db_id = $gdb_ids[0];
        my $genome_db = $gdb_adaptor->fetch_by_dbID($genome_db_id) or die "cannot fetch GenomeDB with id '$genome_db_id'";

        $fasta_file = $self->param('fasta_dir') . '/' . $genome_db->name() . '_' . $genome_db->assembly() . ($genome_db->genome_component ? '_comp_'.$genome_db->genome_component : '') . '.fasta';
    } else {
        $fasta_file = $self->param('fasta_dir') . '/multispecies_dump.fasta';
    }

    $fasta_file =~ s/\s+/_/g;    # replace whitespace with '_' characters
    $fasta_file =~ s/\/\//\//g;  # converts any // in path to /
    $self->param('fasta_file', $fasta_file);

    # fetch members
    my @members;
    if ( $self->param('only_representative') ) {
        foreach my $gdb ( @gdb_ids ) {
            # push(@members, @{ $self->compara_dba->get_SeqMemberAdaptor->_fetch_all_canonical_for_blast_by_genome_db_id($gdb) });
            push(@members, @{ $self->compara_dba->get_SeqMemberAdaptor->_fetch_all_representative_for_blast_by_genome_db_id($gdb) });
        }
    } else {
        foreach my $gdb ( @gdb_ids ) {
            push(@members, @{ $self->compara_dba->get_SeqMemberAdaptor->fetch_all_by_GenomeDB($gdb) });
        }
    }
    $self->param('members', \@members);
}

sub run {
    my $self = shift @_;

    my $members = $self->param('members');
    my $fasta_file = $self->param('fasta_file');

    # write fasta file:
    my $member_set = Bio::EnsEMBL::Compara::MemberSet->new(-members => $members);
    Bio::EnsEMBL::Compara::Utils::Preloader::load_all_sequences($self->compara_dba->get_SequenceAdaptor, undef, $member_set);
    $member_set->print_sequences_to_file($fasta_file);

    my $n_seq_expected = scalar(@$members);
    my $n_seq_in_file = `grep -c "^>" "$fasta_file"`;
    chomp $n_seq_in_file;
    die "Found $n_seq_in_file sequences in the file instead of $n_seq_expected. Please investigate.\n" if $n_seq_expected ne $n_seq_in_file;
}

sub write_output {
    my $self = shift @_;

    $self->input_job->autoflow(0);
    if ( $self->param('genome_db_id') ) {
        $self->dataflow_output_id( { 'fasta_name' => $self->param('fasta_file'), 'genome_db_id' => $self->param('genome_db_id') } , 1 );
    } elsif ( $self->param('genome_db_ids') ) {
        $self->dataflow_output_id( { 'fasta_name' => $self->param('fasta_file'), 'genome_db_ids' => $self->param('genome_db_ids') } , 1 );
    }
}


1;

