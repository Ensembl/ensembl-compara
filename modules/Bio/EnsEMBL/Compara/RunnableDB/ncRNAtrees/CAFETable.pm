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

Bio::EnsEMBL::Compara::RunnableDB::ncRNAtrees::CAFEDynamics

=head1 SYNOPSIS

=head1 DESCRIPTION

This RunnableDB calculates the dynamics of a ncRNA family (based on the tree obtained and the CAFE software) in terms of gains losses per branch tree. It needs a CAFE-compliant species tree.

=head1 INHERITANCE TREE

Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with an underscore (_)

=cut

package Bio::EnsEMBL::Compara::RunnableDB::ncRNAtrees::CAFETable;

use strict;
use Data::Dumper;
use Bio::EnsEMBL::Compara::Graph::NewickParser;
use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub param_defaults {
    return {
        'clusterset_id'  => 1,
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

    unless ( $self->param('cafe_tree_string') ) {
        die ('cafe_species_tree can not be found');
    }

    unless ( $self->param('cafe_species') ) {
        # get the species you want to include and put then in $self->param('cafe_species')
    }

    unless ( $self->param('type') ) {
        die ('type is mandatory [prot|nc]');
    }

    if ($self->param('type') eq 'nc') {
        my $ncTree_Adaptor = $self->compara_dba->get_NCTreeAdaptor();
        $self->param('adaptor', $ncTree_Adaptor);
    } elsif ($self->param('type') eq 'prot') {
        my $protTree_Adaptor = $self->compara_dba->get_ProteinTreeAdaptor();
        $self->param('adaptor', $protTree_Adaptor);
    } else {
        die 'type must be [prot|nc]';
    }

    return;
}

sub run {
    my ($self) = @_;

    $self->get_cafe_tree_from_string();
    my $cafe_table = $self->get_cafe_table_from_db();
}

sub write_output {
    my ($self) = @_;
    my $cafe_table_file = $self->param('cafe_table_file');
    my $cafe_tree_string = $self->param('cafe_tree_string');
    print STDERR "$cafe_table_file\n" if ($self->debug());
    print STDERR "$cafe_tree_string\n" if ($self->debug());
    $self->dataflow_output_id (
                               {
                                'cafe_table_file' => $cafe_table_file,
                                'cafe_tree_string' => $cafe_tree_string,
                               }, 1
                              );
}


###########################################
## Internal methods #######################
###########################################

sub get_cafe_tree_from_string {
    my ($self) = @_;
    my $cafe_tree_string = $self->param('cafe_tree_string');
    print STDERR "$cafe_tree_string\n" if ($self->debug());
    my $cafe_tree = Bio::EnsEMBL::Compara::Graph::NewickParser::parse_newick_into_tree($cafe_tree_string);
    $self->param('cafe_tree', $cafe_tree);
    return;
}

sub get_cafe_table_from_db {
    my ($self) = @_;
    my $species = $self->param('cafe_species');
    my $adaptor = $self->param('adaptor');

    my $mlss_id = $self->param('mlss_id');

    my $cafe_table_file = "cafe_${mlss_id}.tbl";

    my $cafe_table_output = $self->param('work_dir') . "/" . $cafe_table_file;
    $self->param('cafe_table_file', $cafe_table_file);

    print STDERR "CAFE_TABLE_OUTPUT: $cafe_table_output\n" if ($self->debug());
    open my $cafe_fh, ">", $cafe_table_output or die $!;

    print $cafe_fh "FAMILY_DESC\tFAMILY\t", join("\t", @$species), "\n";

    print STDERR Dumper $adaptor if ($self->debug());
#    my $clusterset = $adaptor->fetch_node_by_node_id($self->param('clusterset_id'));
##    my $clusterset = $self->compara_dba->get_NCTreeAdaptor->fetch_node_by_node_id($self->param('clusterset_id'));
#    my $all_trees = $clusterset->children();
    my $all_trees = $adaptor->fetch_all();
    print STDERR scalar @$all_trees, " trees to process\n" if ($self->debug());
    my $ok_fams = 0;
    for my $subtree (@$all_trees) {
#        my $subtree = $tree->children->[0];
        my $root_id;
        if (defined $subtree) {
            $root_id = $subtree->node_id();
        } else {
            print STDERR "Undefined subtree for " . $subtree->node_id() . "\n";
            next;
        }
        next if ($root_id == 1); ## This is the clusterset! We have to avoid taking the trees with 'type' 'clusterset'. Should be included in the gene tree API (nc_tree / protein_tree) at some point.
        next if ($subtree->tree->tree_type() eq 'superproteintree'); ## For now you also get superproteintrees!!!
        print STDERR "ROOT_ID: $root_id\n" if ($self->debug());
        my $tree = $adaptor->fetch_node_by_node_id($root_id);
        my $name = $self->get_name($tree);
        print STDERR "MODEL_NAME: $name\n" if ($self->debug());
        my $tree_members = $tree->get_all_leaves();
        my %species;
        for my $member (@$tree_members) {
            my $sp;
            eval {$sp = $member->genome_db->name};
            next if ($@);
            $sp =~ s/_/\./;
            $species{$sp}++;
        }

        my @flds = ($name, $root_id);
        for my $sp (@$species) {
            push @flds, ($species{$sp} || 0);
        }
        if ($self->has_member_at_root([keys %species])) {
            $ok_fams++;
            print $cafe_fh join("\t", @flds), "\n";
        }
    }
    close($cafe_fh);
    print STDERR "$ok_fams families in final table\n" if ($self->debug());
    return;
}

sub has_member_at_root {
    my ($self, $sps) = @_;
    my $sp_tree = $self->param('cafe_tree');
    my $tree_leaves = $sp_tree->get_all_leaves();
    my @leaves;
    for my $sp (@$sps) {
        my $leaf = get_leaf($sp, $tree_leaves);
        if (defined $leaf) {
            push @leaves, $leaf
        }
    }
    if (scalar @leaves == 0) {
        return 0;
    }
    my $lca = $sp_tree->find_first_shared_ancestor_from_leaves([@leaves]);
    return !$lca->has_parent();
}

sub get_leaf {
    my ($sp, $leaves) = @_;
    for my $leaf (@$leaves) {
        if ($leaf->name() eq $sp) {
            return $leaf;
        }
    }
    return undef;
}

sub get_name {
    my ($self, $tree) = @_;
    my $name;
    if ($self->param('type') eq 'nc') {
        $name = $tree->tree->get_tagvalue('model_name');
    } else {
        $name = $tree->node_id();
    }
    return $name;
}

1;
