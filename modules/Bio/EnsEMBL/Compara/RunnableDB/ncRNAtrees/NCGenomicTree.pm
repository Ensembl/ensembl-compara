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

package Bio::EnsEMBL::Compara::RunnableDB::ncRNAtrees::NCGenomicTree;

use strict;
use warnings;
use Data::Dumper;

use Bio::EnsEMBL::Compara::Graph::NewickParser;

use base ('Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::TreeBest');

sub fetch_input {
    my ($self) = @_;
    my $nc_tree_id = $self->param('gene_tree_id');
    my $nc_tree = $self->compara_dba->get_GeneTreeAdaptor->fetch_by_dbID($nc_tree_id);
    $self->param('gene_tree', $nc_tree);
    $self->_load_species_tree_string_from_db();
    my $alignment_id = $self->param('alignment_id');
    $nc_tree->gene_align_id($alignment_id);
    print STDERR "ALN INPUT ID: " . $alignment_id . "\n" if ($self->debug);
    my $aln = $self->compara_dba->get_GeneAlignAdaptor->fetch_by_dbID($alignment_id);
    my $aln_file = $self->dumpTreeMultipleAlignmentToWorkdir($aln, 'fasta', {-APPEND_SPECIES_TREE_NODE_ID => $self->param('species_tree')->get_genome_db_id_2_node_hash});
    if (! defined $aln_file) {
        $self->throw("I can not dump the alignment in $alignment_id");
    }
    $self->param('aln_input',$aln_file);
    $self->throw("need a method") unless (defined $self->param('method'));
    $self->throw("need an alignment output file to build the tree") unless (defined $self->param('aln_input'));
    $self->throw("tree with id $nc_tree_id is undefined") unless (defined $nc_tree);

}

sub run {
    my ($self) = @_;
    $self->run_ncgenomic_tree($self->param('method'));
}


sub run_ncgenomic_tree {
    my ($self, $method) = @_;
    my $cluster = $self->param('gene_tree');
    my $nc_tree_id = $self->param('gene_tree_id');
    my $input_aln = $self->param('aln_input');
    print STDERR "INPUT ALN: $input_aln\n";
    die "$input_aln doesn't exist" unless (-e $input_aln);
    if ($method eq "phyml" && (scalar(@{$cluster->get_all_leaves}) < 4)) {
        $self->input_job->autoflow(0);
        $self->complete_early(sprintf("tree cluster %d has %d proteins - can not build a phyml tree.\n", $nc_tree_id, scalar(@{$cluster->get_all_leaves})));
    }

    my $newick;
    if ($method eq 'nj') {
        $newick = $self->run_treebest_nj($input_aln);
    } elsif ($method eq 'phyml') {
        $newick = $self->run_treebest_phyml($input_aln);
    } else {
        die "unknown method: $method\n";
    }

    return if ($newick =~ /^_null_;/);
    my $tag = "pg_it_" . $method;
    $self->store_alternative_tree($newick, $tag, $cluster);
}

1;
