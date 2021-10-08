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

Bio::EnsEMBL::Compara::RunnableDB::HomologyAnnotation::DiamondFromFilePAF

=head1 DESCRIPTION

Run DIAMOND blastp and parse the output into PeptideAlignFeature objects.
Store PeptideAlignFeature objects in the compara database.

Supported parameters:
    'ref_fasta'    : the query fasta sequences already in fasta file format per genome (Mandatory)
    'blast_db'     : the predefined and indexed diamond database name (Mandatory)
    'genome_db_id' : the genome_db_id of the query genome (single genome in ref_fasta) (Mandatory)
    'blast_params' : additional blast parameters that are not the default (Optional)
    'evalue_limit' : the minimum allowed evalue to filter results - blast/diamond parameter (Optional)
    'target_genome_db_id' : the genome_db_id of the target genome (Optional)

=cut

package Bio::EnsEMBL::Compara::RunnableDB::HomologyAnnotation::DiamondFromFilePAF;

use warnings;
use strict;

use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BlastAndParsePAF');


sub fetch_input {
    my $self = shift;

    my $output_dba = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->go_figure_compara_dba( $self->param('output_db') );
    $self->param('output_dba', $output_dba);
}

sub run {
    my $self = shift;

    my $ref_fasta    = $self->param_required('ref_fasta');
    my $diamond_db   = $self->param_required('blast_db');
    my $diamond_exe  = $self->param('diamond_exe');
    my $blast_params = $self->param('blast_params')  || '';
    my $evalue_limit = $self->param('evalue_limit');
    my $ref_db       = $self->param('rr_ref_db');

    my $cross_pafs = [];
    my $worker_temp_directory = $self->worker_temp_directory;
    my $blast_outfile         = $worker_temp_directory . '/blast.out.' . $$;
    my $target_genome_db_id   = $self->param('target_genome_db_id');

    my $cmd = "$diamond_exe blastp -d $diamond_db --query $ref_fasta --evalue $evalue_limit --out $blast_outfile --outfmt 6 qseqid sseqid evalue score nident pident qstart qend sstart send length positive ppos qseq_gapped sseq_gapped $blast_params";

    my $run_cmd = $self->run_command($cmd, { 'die_on_failure' => 1});
    print "Time for diamond search " . $run_cmd->runtime_msec . " msec\n";

    my $features = $self->parse_blast_table_into_paf($blast_outfile, $self->param_required('genome_db_id'), $target_genome_db_id, $ref_db);

    push @$cross_pafs, @$features;
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
