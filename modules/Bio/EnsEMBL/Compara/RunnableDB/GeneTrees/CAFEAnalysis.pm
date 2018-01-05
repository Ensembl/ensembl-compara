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

=cut

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::CAFEAnalysis

=head1 DESCRIPTION

This RunnableDB calculates the dynamics of a ncRNA family (based on the tree obtained and the CAFE software) in terms of gains losses per branch tree. It needs a CAFE-compliant species tree.

=head1 INHERITANCE TREE

Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with an underscore (_)

=cut

package Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::CAFEAnalysis;

use strict;
use warnings;
use Data::Dumper;

use Bio::EnsEMBL::Hive::Utils 'stringify';

use Bio::EnsEMBL::Compara::Graph::NewickParser;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub param_defaults {
    return {
            'pvalue_lim' => 1,
           };
}

=head2 fetch_input

    Title     : fetch_input
    Usage     : $self->fetch_input
    Function  : Fetches input data from database
    Returns   : none
    Args      : none

=cut

sub fetch_input {
    my ($self) = @_;

    $self->param_required('fam_id');
    $self->param_required('mlss_id');
    $self->param_required('lambda');

    my $cafeTree_Adaptor = $self->compara_dba->get_CAFEGeneFamilyAdaptor;
    $self->param('cafeTree_Adaptor', $cafeTree_Adaptor);

    my $speciesTree_Adaptor = $self->compara_dba->get_SpeciesTreeAdaptor;
    $self->param('speciesTree_Adaptor', $speciesTree_Adaptor);

    my $genomeDB_Adaptor = $self->compara_dba->get_GenomeDBAdaptor;
    $self->param('genomeDB_Adaptor', $genomeDB_Adaptor);

    # cafe_shell is also defined parameters

    return;
}

sub run {
    my ($self) = @_;
    $self->run_cafe_script;
}

sub write_output {
    my ($self) = @_;
    $self->parse_cafe_output;
}

###########################################
## Internal methods #######################
###########################################


sub run_cafe_script {
    my ($self) = @_;

    my $mlss_id = $self->param('mlss_id');
    my $fam_id = $self->param('fam_id');
    my $pval_lim = $self->param('pvalue_lim');

    my $tmp_dir = $self->worker_temp_directory;
    my $cafe_table_file = $tmp_dir . "/cafe_${mlss_id}_${fam_id}.in";
    my $cafe_out_file   = $tmp_dir . "/cafe_${mlss_id}_${fam_id}.out";
    my $script_file     = $tmp_dir . "/cafe_${mlss_id}_${fam_id}.sh";
    print STDERR "CAFE results will be written into [$cafe_out_file]\n";
    print STDERR "Script file is [$script_file]\n" if ($self->debug());
    $self->param('cafe_out_file', $cafe_out_file);

    my ($cafe_tree_str, $cafe_table) = $self->get_tree_and_table_from_db($fam_id);
    $self->_spurt($cafe_table_file, $cafe_table);

    # Populate the script file
    open my $sf, ">", $script_file or die $!;

    my $cafe_shell = $self->param_required('cafe_shell');
    chop($cafe_tree_str); #remove final semicolon
    $cafe_tree_str =~ s/:\d+$//; # remove last branch length

    my $lambda = $self->param('lambda');  ## For now, it only works with 1 lambda
    #my $cafe_struct_tree = $self->param('cafe_struct_tree_str');

    print $sf '#!' . $cafe_shell . "\n\n";
    print $sf "tree $cafe_tree_str\n\n";
    print $sf "load -p ${pval_lim} -i $cafe_table_file -t 1\n\n";
    print $sf "lambda -l $lambda\n";
#    print $sf $cafe_lambdas ? " -l $cafe_lambdas\n\n" : " -s\n\n";
#    print $sf $cafe_lambdas ? "-l $cafe_lambdas -t $cafe_struct_tree\n\n" : " -s\n\n";
    print $sf "report $cafe_out_file\n\n";
    close ($sf);

    print STDERR "CAFE output in [$cafe_out_file]\n" if ($self->debug());

    chmod 0755, $script_file;

    my $run_cmd = $self->run_command($script_file);
    my $err = $run_cmd->exit_code;
    unless ($err == 16) {
        print STDERR "CAFE returning error $err\n";
    }
    return;
}

sub get_tree_and_table_from_db {
    my ($self, $fam_id) = @_;

    my $sth = $self->compara_dba->dbc->prepare("SELECT tree, tabledata FROM CAFE_data WHERE fam_id = ?");
    $sth->execute($fam_id);
    my ($tree, $table) = $sth->fetchrow_array();
    $sth->finish();
    return ($tree, $table);
}

sub parse_cafe_output {
    my ($self) = @_;
    my $fmt = '%{-n}%{":"o}';

    my $cafeTree_Adaptor = $self->param('cafeTree_Adaptor');  # A CAFEGeneFamilyAdaptor
    my $mlss_id = $self->param('mlss_id');
#    my $pvalue_lim = $self->param('pvalue_lim');
    my $cafe_out_file = $self->param('cafe_out_file') . ".cafe";
    my $genomeDB_Adaptor = $self->param('genomeDB_Adaptor');

    print STDERR "CAFE OUT FILE [$cafe_out_file]\n" if ($self->debug);

    open my $fh, "<". $cafe_out_file or die "$!: $cafe_out_file";

    my $tree_line = <$fh>;
    my $tree_str = substr($tree_line, 5, length($tree_line) - 6);
    $tree_str .= ";";
    my $tree = Bio::EnsEMBL::Compara::Graph::NewickParser::parse_newick_into_tree($tree_str);
    print STDERR "CAFE TREE: $tree_str\n" if ($self->debug);

    my $lambda_line = <$fh>;
    my $lambda = substr($lambda_line, 8, length($lambda_line) - 9);
    print STDERR "CAFE LAMBDAS: $lambda\n" if ($self->debug);

    my $ids_line = <$fh>;
    my $ids_tree_str = substr($ids_line, 15, length($ids_line) - 16);
    my %cafeIDs2nodeIDs = ();
    while ($ids_tree_str =~ /(\d+)<(\d+)>/g) {
        $cafeIDs2nodeIDs{$2} = $1;
    }
    print STDERR "CAFE IDs: ", stringify(\%cafeIDs2nodeIDs), "\n" if ($self->debug);


    my $format_ids_line = <$fh>;
    my ($formats_ids) = (split /:/, $format_ids_line)[2];
    $formats_ids =~ s/^\s+//;
    $formats_ids =~ s/\s+$//;
    my @format_pairs_cafeIDs = split /\s+/, $formats_ids;
    my @format_pairs_nodeIDs = map {my ($fst,$snd) = $_ =~ /\((\d+),(\d+)\)/; [($cafeIDs2nodeIDs{$fst}, $cafeIDs2nodeIDs{$snd})]} @format_pairs_cafeIDs;
    print STDERR "PAIR IDs: ", stringify(\@format_pairs_nodeIDs), "\n" if ($self->debug);

    while (<$fh>) {
        last if $_ =~ /^'ID'/;
    }

    while (my $fam_line = <$fh>) {
        print STDERR "FAM_LINE:\n", $fam_line, "\n";
        my @flds = split/\s+/, $fam_line;
        my $gene_tree_root_id = $flds[0];
        my $fam_tree_str = $flds[1];
        my $pvalue_avg = $flds[2];
        my $pvalue_pairs = $flds[3];

        # Tree with member counts
        my $fam_tree = Bio::EnsEMBL::Compara::Graph::NewickParser::parse_newick_into_tree($fam_tree_str . ";");

        print STDERR "pvalue_pairs $pvalue_pairs\n" if ($self->debug);
        my @pvalue_pairs;
        while ($pvalue_pairs =~ /\(([^,(]+),([^,)]+)\)/g) {
            push @pvalue_pairs, [$1 eq '-' ? undef : $1+0,$2 eq '-' ? undef : $2+0];
        }

        my %pvalue_by_node;
        for (my $i=0; $i<scalar(@pvalue_pairs); $i++) {
            my ($val_fst, $val_snd) = @{$pvalue_pairs[$i]};
            my ($node_id1, $node_id2) = @{$format_pairs_nodeIDs[$i]};
            $pvalue_by_node{$node_id1} = $val_fst if (! defined $pvalue_by_node{$node_id1} || $pvalue_by_node{$node_id1} > $val_fst);
            $pvalue_by_node{$node_id2} = $val_snd if (! defined $pvalue_by_node{$node_id2} || $pvalue_by_node{$node_id2} > $val_snd);
        }

        $tree->print_tree(0.2) if ($self->debug());

        my $speciesTree = $self->param('speciesTree_Adaptor')->fetch_by_method_link_species_set_id_label($mlss_id, 'cafe');

        my $cafeGeneFamily = Bio::EnsEMBL::Compara::CAFEGeneFamily->new_from_SpeciesTree($speciesTree);

        my $lca_node_id = $tree->root->name;

        print STDERR "LCA NODE ID IS $lca_node_id\n" if ($self->debug);

        $cafeGeneFamily->lca_id($lca_node_id);
        $cafeGeneFamily->gene_tree_root_id($gene_tree_root_id);
        $cafeGeneFamily->pvalue_avg($pvalue_avg);
        $cafeGeneFamily->lambdas($lambda);

        my %cafe_nodes_lookup = map {$_->node_id => $_} @{ $cafeGeneFamily->root->get_all_nodes };

        my $n_nonzero_internal_nodes = 0;

        # We store the attributes
        for my $node (@{$fam_tree->get_all_nodes()}) {
            my ($node_id, $n_members) = split /_/, $node->name();
            print STDERR "Storing node name $node_id\n" if ($self->debug);

            $n_members //= 0; ## It may be absent from the orig data (but in the tree)
            my $pvalue = $pvalue_by_node{$node_id};
            my $cafe_node = $cafe_nodes_lookup{$node_id} || die "Could not find the node '$node_id'";

            print STDERR "Storing N_MEMBERS: $n_members, PVALUE: ".($pvalue//'NULL')."\n" if ($self->debug);

                $cafe_node->n_members($n_members);
                $cafe_node->pvalue($pvalue);
                $n_nonzero_internal_nodes++ if $n_members;

        }
        if ($n_nonzero_internal_nodes > 1) {
            $cafeTree_Adaptor->store($cafeGeneFamily);
            $self->dataflow_output_id( { 'gene_tree_id' => $gene_tree_root_id }, 2);
        }
    }
    return
}

1;
