=head1 LICENSE

See the NOTICE file distributed with this work for additional information
regarding copyright ownership.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

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

use File::Basename qw/dirname/;

use Bio::EnsEMBL::Compara::MemberSet;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');



sub param_defaults {
    return {
        'only_representative' => 0, # if seq_member_projection table is populated, dump only representative sequences
        'only_canonical'      => 0, # only dump canonical members
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
        my $genome_db = $gdb_adaptor->fetch_by_dbID($genome_db_id) or $self->die_no_retry("cannot fetch GenomeDB with id '$genome_db_id'");

        $fasta_file = $genome_db->_get_members_dump_path($self->param('members_dumps_dir'));
    } else {
        $fasta_file = $self->param('members_dumps_dir') . '/multispecies_dump.fasta';
    }

    unless ( -d dirname($fasta_file) ) {
        $self->run_command('mkdir -p ' . dirname($fasta_file));
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
    } elsif ($self->param('only_canonical')) {
        foreach my $gdb ( @gdb_ids ) {
            push @members, @{ $self->compara_dba->get_SeqMemberAdaptor->fetch_all_canonical_by_GenomeDB($gdb) };
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
    my $header_id  = $self->param('fasta_header_id');

    # write fasta file:
    my $member_set = Bio::EnsEMBL::Compara::MemberSet->new(-members => $members);
    Bio::EnsEMBL::Compara::Utils::Preloader::load_all_sequences($self->compara_dba->get_SequenceAdaptor, undef, $member_set);
    $member_set->print_sequences_to_file($fasta_file, $header_id);

    my $n_seq_expected = scalar(@$members);
    my $n_seq_in_file = $self->run_command(['grep', '-c', '^>', $fasta_file])->out;
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
