=head1 LICENSE

  Copyright (c) 1999-2010 The European Bioinformatics Institute and
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

Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::CAFEDynamics

=head1 SYNOPSIS

=head1 DESCRIPTION

This RunnableDB calculates the dynamics of a ncRNA family (based on the tree obtained and the CAFE software) in terms of gains losses per branch tree. It needs a CAFE-compliant species tree.

=head1 INHERITANCE TREE

Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with an underscore (_)

=cut

package Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::CAFETable_PerFamTree;

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

    unless ( $self->param('cafe_tree_string_meta_key') ) {  # only the meta key is passed
        die "cafe_tree_string_meta_key needs to be defined to get the species tree from the meta table\n";
    }
    $self->param('cafe_tree_string', $self->get_tree_string_from_meta());
    ### Here we have a full species tree. We will prune it in a "per-family" basis

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

    my $number_of_fams = $self->param('number_of_fams');
    my $all_fams = $self->param('all_fams');
    for my $fam_id (@$all_fams) {

        print STDERR "FIRING FAM: $fam_id\n";

        $self->dataflow_output_id (
                                   {
                                    'fam_id' => $fam_id,
                                    'number_of_fams' => $number_of_fams,
                                   }, 2
                                  );
    }
}


###########################################
## Internal methods #######################
###########################################

sub get_tree_string_from_meta {
    my ($self) = @_;
    my $cafe_tree_string_meta_key = $self->param('cafe_tree_string_meta_key');

    my $sql = "SELECT meta_value FROM meta WHERE meta_key = ?";
    my $sth = $self->compara_dba->dbc->prepare($sql);
    $sth->execute($cafe_tree_string_meta_key);

    my ($cafe_tree_string) = $sth->fetchrow_array();
    $sth->finish;
    print STDERR "CAFE_TREE_STRING: $cafe_tree_string\n" if ($self->debug());
    return $cafe_tree_string;
}

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
    my $fmt = $self->param('tree_fmt') || '%{n}%{":"d}';
    my $adaptor = $self->param('adaptor');
    my $sp_tree = $self->param('cafe_tree');
    my $mlss_id = $self->param('mlss_id');

#    my $clusterset = $adaptor->fetch_node_by_node_id($self->param('clusterset_id'));

#    my $all_trees = $clusterset->children();
    my $all_trees = $adaptor->fetch_all();
    print STDERR scalar @$all_trees, " trees to process\n" if ($self->debug());
    my $ok_fams = 0;
    my @all_fams;
    for my $tree (@$all_trees) {
#        my $subtree = $tree->children->[0];
        my $root_id;
        if (defined $tree) {
            $root_id = $tree->node_id();
        } else {
            print STDERR "Undefined tree for " . $tree->node_id() . "\n";
            next;
        }
        print STDERR "ROOT_ID: $root_id\n" if ($self->debug());
#        my $tree = $adaptor->fetch_node_by_node_id($root_id);
        my $name = $self->get_name($tree);
        print STDERR "MODEL_NAME: $name\n" if ($self->debug());
        my $tree_members = $tree->get_all_leaves();
        print STDERR "NUMBER_OF_LEAVES: ", scalar @$tree_members, "\n" if ($self->debug());
        my %species;
        for my $member (@$tree_members) {
            my $sp;
            eval {$sp = $member->genome_db->name};
            next if ($@);
            $sp =~ s/_/\./;
            $species{$sp}++;
        }
        print STDERR scalar (keys %species) , " species for this tree\n";
        next if (scalar (keys %species) < 4);

        ## TODO: Should we filter out low-coverage genomes?
        my $species = [keys %species];
#        print STDERR "SPECIES IN THE TREE:\n" if ($self->debug());
#        print STDERR Dumper $species if ($self->debug());

        my @leaves = ();
        for my $node (@{$sp_tree->get_all_leaves}) {
#            print STDERR "NODE : ", $node->name(), "\n" if ($self->debug());
            if (is_in($node->name, $species)) {
                push @leaves, $node;
            }
        }

#        print STDERR "LEAVES: ", Dumper \@leaves;
        my $lca = $sp_tree->find_first_shared_ancestor_from_leaves([@leaves]);
#        print STDERR "LCA: ", $lca->name(), "\n" if ($self->debug());
        my $lca_str = $lca->newick_format('ryo', $fmt);
        print STDERR "TREE FOR THIS FAM:\n$lca_str\n" if ($self->debug());
        my $fam_table = "FAMILY_DESC\tFAMILY";
        my $all_species_in_tree = $lca->get_all_leaves();
        for my $sp_node (@$all_species_in_tree) {
            my $sp = $sp_node->name();
#        for my $sp (@$species) {
            $fam_table .= "\t$sp";
        }
        $fam_table .= "\n";

        my @flds = ($name, $root_id);
        for my $sp_node (@$all_species_in_tree) {
            my $sp = $sp_node->name();
#       for my $sp (@$species) {
            push @flds, ($species{$sp} || 0);
        }

        $fam_table .= join ("\t", @flds), "\n";
        print STDERR "TABLE FOR THIS FAM:\n$fam_table\n" if ($self->debug());
        $ok_fams++;

        my $sth = $self->compara_dba->dbc->prepare("insert into CAFE_data (fam_id, tree, tabledata) values (?,?,?);");
        $sth->execute($name, $lca_str, $fam_table);
        $sth->finish();

        push @all_fams, $name;
#        push @all_fams, {tree => $lca_str, table => $fam_table, id => $name};
        $tree->release_tree;
    }

    print STDERR "$ok_fams families in final table\n" if ($self->debug());
    $self->param('all_fams', [@all_fams]);
    $self->param('number_of_fams', $ok_fams);
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

sub is_in {
    my ($name, $listref) = @_;
    for my $item (@$listref) {
        return 1 if ($item eq $name);
    }
    return 0;
}

1;
