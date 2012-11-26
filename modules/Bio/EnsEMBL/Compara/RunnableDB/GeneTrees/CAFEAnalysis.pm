=head1 LICENSE

  Copyright (c) 1999-2012 The European Bioinformatics Institute and
  Genome Research Limited.  All rights reserved.

  This software is distributed under a modified Apache license.
  For license details, please see

    http://www.ensembl.org/info/about/code_licence.html

=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <dev@ensembl.org>.

  Questions may also be sent to the Ensembl help desk at
  <helpdesk@ensembl.org>.

=cut

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::CAFEAnalysis

=head1 SYNOPSIS

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
use Data::Dumper;

use Bio::EnsEMBL::Compara::Graph::NewickParser;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub param_defaults {
    return {
            'pvalue_lim' => 0.01,
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

    unless ( $self->param('fam_id') ) {
        die ('fam_id is not set');
    }

    unless ( $self->param('mlss_id') ) {
        die ('mlss_id must be set')
    }

    unless ( $self->param('lambda') ) {
        die ('lambda is an obligatory parameter');
    }

    my $cafetree_Adaptor = $self->compara_dba->get_CAFEGeneFamilyAdaptor;
    $self->param('cafeTree_Adaptor', $cafetree_Adaptor);

    my $genomeDB_Adaptor = $self->compara_dba->get_GenomeDBAdaptor;
    $self->param('genomeDB_Adaptor', $genomeDB_Adaptor);

    # cafe_shell is also defined parameters

    return;
}

sub run {
    my ($self) = @_;
    $self->run_cafe_script;
    $self->parse_cafe_output;
}

sub write_output {
    my ($self) = @_;

    my $lambda = $self->param('lambda');
    $self->dataflow_output_id ( {
                                 'cafe_lambda' => $self->param('lambda'),
                                 'cafe_table_file' => $self->param('work_dir') . "/" . $self->param('cafe_table_file'),
                                 'cafe_tree_string' => $self->param('cafe_tree_string'),
                                }, 3);

}

###########################################
## Internal methods #######################
###########################################

# sub get_tree_string_from_meta {
#     my ($self) = @_;
#     my $cafe_tree_string_meta_key = $self->param('cafe_tree_string_meta_key');

#     my $sql = "SELECT meta_value FROM meta WHERE meta_key = ?";
#     my $sth = $self->compara_dba->dbc->prepare($sql);
#     $sth->execute($cafe_tree_string_meta_key);

#     my ($cafe_tree_string) = $sth->fetchrow_array();
#     $sth->finish;
#     print STDERR "CAFE_TREE_STRING: $cafe_tree_string\n" if ($self->debug());
#     return $cafe_tree_string;
# }

sub run_cafe_script {
    my ($self) = @_;

    my $mlss_id = $self->param('mlss_id');
    my $fam_id = $self->param('fam_id');
    my $pval_lim = $self->param('pvalue_lim');

    my $tmp_dir = $self->worker_temp_directory;
    my $cafe_table_file = $tmp_dir . "cafe_${mlss_id}_${fam_id}.in";
    my $cafe_out_file   = $tmp_dir . "cafe_${mlss_id}_${fam_id}.out";
    my $script_file     = $tmp_dir . "cafe_${mlss_id}_${fam_id}.sh";
    print STDERR "CAFE results will be written into [$cafe_out_file]\n";
    print STDERR "Script file is [$script_file]\n" if ($self->debug());
    $self->param('cafe_out_file', $cafe_out_file);

    my ($cafe_tree_str, $cafe_table) = $self->get_tree_and_table_from_db($fam_id);
    open my $table_fh, ">", $cafe_table_file or die $!;
    print $table_fh $cafe_table;
    close($table_fh);

    # Populate the script file
    open my $sf, ">", $script_file or die $!;

    my $cafe_shell = $self->param('cafe_shell');
    chop($cafe_tree_str); #remove final semicolon
    $cafe_tree_str =~ s/:\d+$//; # remove last branch length

#    my $cafe_table_file = $self->param('work_dir') . "/" . $self->param('cafe_table_file');
    my $lambda = $self->param('lambda');  ## For now, it only works with 1 lambda
    my $cafe_struct_tree = $self->param('cafe_struct_tree_str');

    print $sf '#!' . $cafe_shell . "\n\n";
    print $sf "tree $cafe_tree_str\n\n";
    print $sf "load -p ${pval_lim} -i $cafe_table_file\n\n";
    print $sf "lambda -l $lambda\n";
#    print $sf $cafe_lambdas ? " -l $cafe_lambdas\n\n" : " -s\n\n";
#    print $sf $cafe_lambdas ? "-l $cafe_lambdas -t $cafe_struct_tree\n\n" : " -s\n\n";
    print $sf "report $cafe_out_file\n\n";
    close ($sf);

    print STDERR "CAFE output in [$cafe_out_file]\n" if ($self->debug());

    chmod 0755, $script_file;

    $self->compara_dba->dbc->disconnect_when_inactive(0);
    unless ((my $err = system($script_file)) == 4096) {
        print STDERR "CAFE returning error $err\n";
#         for my $f (glob "$cafe_out_file*") {
#             system(`head $f >> /lustre/scratch101/ensembl/mp12/kkkk`);
#         }
        # It seems that CAFE doesn't exit with error code 0 never (usually 4096?)
#        $self->throw("problem running script $cafe_out_file: $err\n");
    }
    $self->compara_dba->dbc->disconnect_when_inactive(1);
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
    my $pvalue_lim = $self->param('pvalue_lim');
    my $cafe_out_file = $self->param('cafe_out_file') . ".cafe";
    my $genomeDB_Adaptor = $self->param('genomeDB_Adaptor');

    print STDERR "CAFE OUT FILE [$cafe_out_file]\n" if ($self->debug);

    open my $fh, "<". $cafe_out_file or die "$!: $cafe_out_file\n";

    my $tree_line = <$fh>;
    my $tree_str = substr($tree_line, 5, length($tree_line) - 6);
    $tree_str .= ";";
    my $tree = Bio::EnsEMBL::Compara::Graph::NewickParser::parse_newick_into_tree($tree_str, "Bio::EnsEMBL::Compara::CAFEGeneFamily");
    print STDERR "CAFE TREE: $tree_str\n" if ($self->debug);

    my $lambda_line = <$fh>;
    my $lambda = substr($lambda_line, 8, length($lambda_line) - 9);
    print STDERR "CAFE LAMBDAS: $lambda\n" if ($self->debug);

    my $ids_line = <$fh>;
    my $ids_tree_str = substr($ids_line, 15, length($ids_line) - 16);
    $ids_tree_str =~ s/<(\d+)>/:$1/g;
    $ids_tree_str .= ";";
    print STDERR "CAFE IDs TREE: $ids_tree_str\n" if ($self->debug);

    my $idsTree = Bio::EnsEMBL::Compara::Graph::NewickParser::parse_newick_into_tree($ids_tree_str);
    print STDERR $idsTree->newick_format('ryo', '%{-n}%{":"d}'), "\n" if ($self->debug);

    my %cafeIDs2nodeIDs = ();
    for my $node (@{$idsTree->get_all_nodes()}) {
        $cafeIDs2nodeIDs{$node->distance_to_parent()} = $node->node_id;
    }

    my $format_ids_line = <$fh>;
    my ($formats_ids) = (split /:/, $format_ids_line)[2];
    $formats_ids =~ s/^\s+//;
    $formats_ids =~ s/\s+$//;
    my @format_pairs_cafeIDs = split /\s+/, $formats_ids;
    my @format_pairs_nodeIDs = map {my ($fst,$snd) = $_ =~ /\((\d+),(\d+)\)/; [($cafeIDs2nodeIDs{$fst}, $cafeIDs2nodeIDs{$snd})]} @format_pairs_cafeIDs;


# Store the tree

    while (<$fh>) {
        last if $. == 10; # We skip several lines and go directly to the family information.
# Is it always 10?? Even if lambda is set??
    }

    while (my $fam_line = <$fh>) {
        print STDERR "FAM_LINE:\n", $fam_line, "\n";
        my @flds = split/\s+/, $fam_line;
        my $gene_tree_root_id = $flds[0];
        my $fam_tree_str = $flds[1];
        my $pvalue_avg = $flds[2];
        my $pvalue_pairs = $flds[3];


        my $fam_tree = Bio::EnsEMBL::Compara::Graph::NewickParser::parse_newick_into_tree($fam_tree_str . ";");

        my %info_by_nodes;
        for my $node (@{$fam_tree->get_all_nodes()}) {
            my $name = $node->name();
            my ($n_members) = $name =~ /_(\d+)/;
            $n_members = 0 if (! defined $n_members); ## It may be absent from the orig data (but in the tree)
            $name =~ s/_\d+//;
            $name =~ s/\./_/g;
            $info_by_nodes{$name}{'n_members'} = $n_members;

            my $taxon_id;
            if (! $node->is_leaf()) {
                $taxon_id = $name;
            } else {
                my $genomeDB = $genomeDB_Adaptor->fetch_by_name_assembly($name);
                $taxon_id = $genomeDB->taxon_id();
            }

            $info_by_nodes{$name}{'taxon_id'} = $taxon_id;
        }

        $pvalue_pairs =~ tr/(/[/;
        $pvalue_pairs =~ tr/)/]/;
        $pvalue_pairs =~ tr/-/1/;
        $pvalue_pairs = eval $pvalue_pairs;

        die "Problem processing the $pvalue_pairs\n" if (ref $pvalue_pairs ne "ARRAY");

        for (my $i=0; $i<scalar(@$pvalue_pairs); $i++) {
            my ($val_fst, $val_snd) = @{$pvalue_pairs->[$i]};
            my ($id_fst, $id_snd) = @{$format_pairs_nodeIDs[$i]};
            my $name1 = $idsTree->find_node_by_node_id($id_fst)->name();
            my $name2 = $idsTree->find_node_by_node_id($id_snd)->name();
            $name1 =~ s/\./_/g;
            $name2 =~ s/\./_/g;

            $info_by_nodes{$name1}{'pvalue'} = $val_fst;
            $info_by_nodes{$name2}{'pvalue'} = $val_snd;

        }

        $tree->print_tree(0.2) if ($self->debug());

        my $sth2 = $self->compara_dba->dbc->prepare("SELECT root_id FROM species_tree_root WHERE method_link_species_set_id = ?");
        $sth2->execute($self->param('mlss_id'));
        my ($root_id) = $sth2->fetchrow_array();
        $sth2->finish;
        print STDERR "ROOT_ID is $root_id\n" if ($self->debug());

        my $lca_name = $tree->root->name;
        print STDERR "LCA name is $lca_name\n" if ($self->debug);
        my $sth = $self->compara_dba->dbc->prepare("SELECT node_id FROM species_tree_node_tag WHERE tag = 'taxon_id' AND value = ?");
        $sth->execute($lca_name);
        my ($lca_id) = $sth->fetchrow_array();
        my $cafe_gene_family_id = $cafeTree_Adaptor->store_gene_family($root_id, $lca_id, $gene_tree_root_id, $pvalue_avg, $lambda);


        # We store the attributes
        for my $node (@{$tree->get_all_nodes()}) {
            my $n = $node->name();
            print STDERR "Storing node name $n\n" if ($self->debug);
            $n =~ s/\./_/g;

            my $taxon_id = $info_by_nodes{$n}{taxon_id};
            my $n_members = $info_by_nodes{$n}{n_members};
            my $pvalue = $info_by_nodes{$n}{pvalue};

            print STDERR "Retrieving node_id for taxon $taxon_id\n" if ($self->debug);
            print STDERR "Storing TAXON_ID: $taxon_id, N_MEMBERS: $n_members, PVALUE: $pvalue\n\n" if ($self->debug);
            my $sth = $self->compara_dba->dbc->prepare("SELECT node_id FROM species_tree_node_tag WHERE tag = 'taxon_id' AND value = ?");
            $sth->execute($taxon_id);
            while (my ($species_tree_node_id) = $sth->fetchrow_array()) {
#            my ($species_tree_node_id) = $sth->fetchrow_array();
                $cafeTree_Adaptor->store_species_gene($cafe_gene_family_id, $species_tree_node_id, $taxon_id, $n_members, $pvalue);
            }
            $sth->finish();
        }
        $sth->finish();
    }
    return
}

1;
