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

Bio::EnsEMBL::Compara::RunnableDB::HomologyAnnotation::DiamondBlastp

=head1 DESCRIPTION

Create fasta file containing batch_size number of sequences. Run DIAMOND blastp and parse
the output into PeptideAlignFeature objects. Store PeptideAlignFeature objects in the compara
database

=cut

package Bio::EnsEMBL::Compara::RunnableDB::HomologyAnnotation::DiamondBlastp;

use strict;
use warnings;

use Data::Dumper;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BlastAndParsePAF');

sub fetch_input {
    my $self = shift @_;

    my $member_id_list = $self->param_required('member_id_list');

    my $members = $self->compara_dba->get_SeqMemberAdaptor->fetch_all_by_dbID_list($member_id_list);

    $self->param('query_set', Bio::EnsEMBL::Compara::MemberSet->new(-members => $members));
    $self->param('expected_members', scalar @$members);

    if ( $self->debug ) {
        print "Loaded " . $self->param('expected_members') . " query members\n";
    }

    my $fastafile = $self->param_required('blast_db');

    if ($fastafile) {
        my @files = glob("$fastafile*");
        die "Cound not find diamond_db .dmnd" unless @files;
        foreach my $file (@files) {
            # All files exist and have a nonzero size
            die "Missing blast index: $file\n" unless -e "$file" and -s "$file";
        }
    }
    # Load all the genome specific fasta files into memory
    $self->preload_file_in_memory("$fastafile*");

    if ($self->param('output_db')) {
        $self->param('output_dba', $self->get_cached_compara_dba('output_db'));
    } else {
        $self->param('output_dba', $self->compara_dba);
    }

}

sub run {
    my $self = shift @_;

    my $diamond_exe           = $self->param('diamond_exe');
    my $blast_db              = $self->param_required('blast_db');
    my $blast_params          = $self->param('blast_params')  || '';  # no parameters to C++ binary means having composition stats on and -seg masking off
    my $evalue_limit          = $self->param('evalue_limit');
    my $worker_temp_directory = $self->worker_temp_directory;
    my $blast_infile          = $worker_temp_directory . '/blast.in.' . $$;
    my $blast_outfile         = $worker_temp_directory . '/blast.out.' . $$;
    my $ref_db                = $self->param('rr_ref_db');

    Bio::EnsEMBL::Compara::Utils::Preloader::load_all_sequences($self->compara_dba->get_SequenceAdaptor, undef, $self->param('query_set'));

    $self->param('query_set')->print_sequences_to_file($blast_infile, -format => 'fasta');

    $self->compara_dba->dbc->disconnect_if_idle();

    my $cross_pafs = [];

    my $target_genome_db_id = $self->param_required('target_genome_db_id');

    my $cmd = "$diamond_exe blastp -d $blast_db --query $blast_infile --evalue $evalue_limit --out $blast_outfile --outfmt 6 qseqid sseqid evalue score nident pident qstart qend sstart send length positive ppos qseq_gapped sseq_gapped $blast_params";

    my $run_cmd = $self->run_command($cmd, { 'die_on_failure' => 1});
    print "Time for diamond search " . $run_cmd->runtime_msec . " msec\n";

    my $features = $self->parse_blast_table_into_paf($blast_outfile, $self->param_required('genome_db_id'), $target_genome_db_id, $ref_db);

    unless ($self->param('expected_members') == scalar(keys(%{$self->param('num_query_member')}))) {
        # Most likely, this is happening due to MEMLIMIT, so make the job sleep if it parsed 0 sequences, to wait for MEMLIMIT to happen properly.
        sleep(5);
    }

    push @$cross_pafs, @$features;
    print Dumper $blast_outfile if $self->debug;
    unlink $blast_outfile unless $self->debug;

    $self->param('cross_pafs', $cross_pafs);
}

sub write_output {
    my ($self) = @_;
    my $cross_pafs = $self->param('cross_pafs');

    $self->call_within_transaction(sub {
        $self->param('output_dba')->get_PeptideAlignFeatureAdaptor->filter_top_PAFs(@$cross_pafs);
    });
}

1;
