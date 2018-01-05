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

package Bio::EnsEMBL::Compara::RunnableDB::ncRNAtrees::NCStoreTree;

use strict;
use warnings;

use Bio::EnsEMBL::Compara::Graph::NewickParser;

use base ('Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::StoreTree');


sub _load_species_tree_string_from_db {
    my ($self) = @_;
    my $species_tree = $self->param('gene_tree')->method_link_species_set->species_tree('default');
    $self->param('species_tree', $species_tree);
    return $species_tree->root->newick_format('ryo', '%{o}');
}

sub store_newick_into_nc_tree {
    my ($self, $tag, $newick_file) = @_;

    print STDERR "load from file $newick_file\n" if($self->debug);
    my $newick = $self->_slurp($newick_file);
    $self->param('output_clusterset_id', lc $tag);
    $self->store_alternative_tree($newick, $tag, $self->param('gene_tree'), undef, 1);
    if (defined($self->param('model'))) {
        my $bootstrap_tag = $self->param('model') . "_bootstrap_num";
        $self->param('gene_tree')->store_tag($bootstrap_tag, $self->param('bootstrap_num'));
    }
}


sub _dumpMultipleAlignmentToWorkdir {
    my ($self, $tree, $nj) = @_;

    my $root_id = $tree->root_id;
    my $leafcount = scalar(@{$tree->get_all_leaves});
    if(!$nj && $leafcount<4) {
        $self->input_job->autoflow(0);
        $self->complete_early("tree cluster $root_id has <4 proteins - can not build a raxml tree\n");
    }

    my $file_root = $self->worker_temp_directory. "/nctree_". $root_id;
    $file_root    =~ s/\/\//\//g;  # converts any // in path to /

    my $aln_file = $file_root . ".aln";
    print STDERR "ALN FILE IS: $aln_file\n" if ($self->debug());

    my $sa = $tree->print_alignment_to_file($aln_file,
        -FORMAT => 'phylip',
        -ID_TYPE => 'MEMBER',
        -APPEND_SPECIES_TREE_NODE_ID => $self->param('species_tree')->get_genome_db_id_2_node_hash,
    );

    $self->param('tag_residue_count', $sa->num_sequences * $sa->length);
    # Phylip body

        # Here we do a trick for all Ns sequences by changing the first
        # nucleotide to an A so that raxml can at least do the tree for
        # the rest of the sequences, instead of giving an error
        # FIXME
        #if ($seq =~ /N+/) { $seq =~ s/^N/A/; }

    return $aln_file;
}

sub _dumpStructToWorkdir {
    my ($self, $tree) = @_;

    my $root_id = $tree->root_id;
    my $file_root = $self->worker_temp_directory. "/nctree_". $root_id;
       $file_root =~ s/\/\//\//g;  # converts any // in path to /
    my $struct_file = $file_root . ".struct";

    my $struct_string = $tree->get_value_for_tag('ss_cons_filtered');
    # Allowed Characters are "( ) < > [ ] { } " and "."
    $struct_string =~ s/[^\(^\)^\<^\>^\[^\]^\{^\}^\.]/\./g;
    ## We should have a "clean" structure now?
    if ($struct_string =~ /^\.+$/) {
        $self->input_job->autoflow(0);
        $self->complete_early("struct string is $struct_string\n");
    } else {
        $self->_spurt($struct_file, $struct_string."\n");
    }
    return $struct_file;
}

1;
1;
