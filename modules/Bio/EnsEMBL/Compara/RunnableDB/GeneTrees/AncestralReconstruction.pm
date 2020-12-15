=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2020] EMBL-European Bioinformatics Institute

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

Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::AncestralReconstruction;

=head1 DESCRIPTION

This Analysis/RunnableDB is designed to calculate ancestral sequences for a given gene tree

NOTE: This code was working back in 2012 but may well be broken now. Use it for inspiration only !

=head1 APPENDIX

The rest of the documentation details each of the object methods. 
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::AncestralReconstruction;

use strict;
use warnings;

use Data::Dumper;

use Bio::AlignIO;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable'); 


sub param_defaults {
    ## Most of these are here only for testing the package during development
    ## So, remember to remove these defaults in production
    return {
#            'gene_stable_id' => 'ENSTGUP00000005108',
            'phylofit_exe'   => '/software/ensembl/compara/phast-1.3/bin/phyloFit',
            'prequel_exe'    => '/software/ensembl/compara/phast-1.3/bin/prequel',
           }
}


sub fetch_input {
    my ($self) = @_;

    # In Parameters
    my $tree_id = $self->param('gene_tree_id');

    my $tree = $self->compara_dba->get_GeneTreeAdaptor->fetch_by_root_id($tree_id) or $self->die_no_retry("Could not fetch gene_tree with tree_id='$tree_id'");

    $self->_dumpMultipleAlignmentToWorkDir($tree);
    $self->_dumpNewickTreeToWorkDir($tree);

    # Out Paramters
    $self->param('gene_tree', $tree);

    return;
}

sub run {
    my ($self) = @_;
    $self->_runAncestralReconstruction();
}

sub write_output {
    my ($self) = @_;
    $self->_parseAncestralReconstruction();
    $self->_storeAncestralSequences();
}

sub _dumpMultipleAlignmentToWorkDir {
    my ($self, $tree) = @_;

    my $aln = $tree->get_SimpleAlign(-id_type => 'MEMBER',
                                     -keep_gaps => 1,
                                     $self->aln_options());
    my $outfile = $self->worker_temp_directory . $tree->stable_id . ".aln";
    my $out_aln = Bio::AlignIO->new(-file => ">".$outfile,
                                    -format => "fasta",
                                    -displayname_flat => 1);
    $out_aln->write_aln($aln);

    # Out Parameters
    $self->param('aln_file', $outfile);
    return;
}

sub _dumpNewickTreeToWorkDir {
    my ($self, $tree) = @_;
    my $tree_str = $tree->newick_format('ryo', '%{-m}%{o-}:%{d}');
    # We remove last ":0;" but I don't know if it is necessary or not (depends on the program)
    $tree_str =~ s/:0;$/;/;

    my $outfile = $self->worker_temp_directory . $tree->stable_id . ".nwk";
    $self->_spurt($outfile, "$tree_str\n");

    # Out Parameters
    $self->param('tree_file', $outfile);
    return;
}

sub _storeAncestralSequences {
    my ($self) = @_;

    # In Parameters
    my $tree = $self->param('gene_tree');
    my $anc_seqs = $self->param('ancestral_sequences');

    for my $node (@{$tree->get_all_nodes()}) {
        next if ($node->is_leaf);
        my ($node_id) = $node->node_id();
        my $anc_seq = $anc_seqs->{$node->node_id()};
        $node->store_tag('dna_ancestral_sequence', $anc_seq);
    }


    return;
}

1;


