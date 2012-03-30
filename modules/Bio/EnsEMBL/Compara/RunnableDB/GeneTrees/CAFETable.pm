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

Bio::EnsEMBL::Compara::RunnableDB::ncRNAtrees::CAFETable

=head1 SYNOPSIS

=head1 DESCRIPTION

This RunnableDB calculates the dynamics of a GeneTree family (based on the tree obtained and the CAFE software) in terms of gains losses per branch tree. It needs a CAFE-compliant species tree.

=head1 INHERITANCE TREE

Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with an underscore (_)

=cut

package Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::CAFETable;

use strict;
use Data::Dumper;
use Bio::EnsEMBL::Compara::Graph::NewickParser;
use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub param_defaults {
    return {
        'clusterset_id'  => 1,
        'tree_fmt'       => '%{n}%{":"d}',
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

    unless ( $self->param('cafe_tree_string_meta_key') ) {
        die ('cafe_species_tree_meta_key needs to be defined to get the speciestree from the meta table');
    }
    $self->param('cafe_tree_string', $self->get_tree_string_from_meta());

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

    if ($self->param('perFamTable')) {
        $self->warning("Per-family CAFE Analysis");
    } else {
        $self->warning("One CAFE Analysis for all the families");
    }

    return;
}

sub run {
    my ($self) = @_;

    $self->get_cafe_tree_from_string();
    if ($self->param('perFamTable')) {
        $self->get_per_family_cafe_table_from_db();
    } else {
        $self->get_full_cafe_table_from_db();
    }
}

sub write_output {
    my ($self) = @_;

    my $number_of_fams = $self->param('number_of_fams');
    my $all_fams = $self->param('all_fams');
    for my $fam_id (@$all_fams) {
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

sub get_full_cafe_table_from_db {
    my ($self) = @_;
    my $species = $self->param('cafe_species');
    my $adaptor = $self->param('adaptor');

    my $mlss_id = $self->param('mlss_id');

    my $table = "FAMILY_DESC\tFAMILY\t" . join("\t", @$species);
    $table .= "\n";

#    print $cafe_fh "FAMILY_DESC\tFAMILY\t", join("\t", @$species), "\n";

    my $all_trees = $adaptor->fetch_all();
    print STDERR scalar @$all_trees, " trees to process\n" if ($self->debug());
    my $ok_fams = 0;
    for my $tree (@$all_trees) {
        my $root_id;
        if (defined $tree) {
            $root_id = $tree->node_id();
        } else {
            next;
        }
        ## Warning: I think this is not needed anymore.
#        next if ($root_id == 1); ## This is the clusterset! We have to avoid taking the trees with 'type' 'clusterset'. Should be included in the gene tree API (nc_tree / protein_tree) at some point.
#        next if ($subtree->tree->tree_type() eq 'supertree'); ## For now you also get superproteintrees!!!
#        my $tree = $adaptor->fetch_node_by_node_id($root_id);
        my $name = $self->get_name($tree);
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
            $table .= join ("\t", @flds);
            $table .= "\n";
#            print $cafe_fh join("\t", @flds), "\n";
        }
    }
#    close($cafe_fh);

    my $sth = $self->compara_dba->dbc->prepare("INSERT INTO CAFE_data (fam_id, tree, tabledata) VALUES (?,?,?);");
    $sth->execute(1, $self->param('cafe_tree_string'), $table);
    $sth->finish();

    $self->param('all_fams', [1]);
    $self->param('number_of_fams', 1);
    print STDERR "$ok_fams families in final table\n" if ($self->debug());
    return;
}

sub get_per_family_cafe_table_from_db {
    my ($self) = @_;
    my $fmt = $self->param('tree_fmt');
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
#        my $tree = $adaptor->fetch_node_by_node_id($root_id);
        my $name = $self->get_name($tree);
        my $tree_members = $tree->get_all_leaves();
        my %species;
        for my $member (@$tree_members) {
            my $sp;
            eval {$sp = $member->genome_db->name};
            next if ($@);
            $sp =~ s/_/\./;
            $species{$sp}++;
        }
        next if (scalar (keys %species) < 4);

        ## TODO: Should we filter out low-coverage genomes?
        my $species = [keys %species];

        my @leaves = ();
        for my $node (@{$sp_tree->get_all_leaves}) {
            if (is_in($node->name, $species)) {
                push @leaves, $node;
            }
        }
        next unless (scalar @leaves > 1);

        my $lca = $sp_tree->find_first_shared_ancestor_from_leaves([@leaves]);
        next unless (defined $lca);
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

        my $sth = $self->compara_dba->dbc->prepare("INSERT INTO CAFE_data (fam_id, tree, tabledata) VALUES (?,?,?);");
        $sth->execute($name, $lca_str, $fam_table);
        $sth->finish();

        push @all_fams, $name;
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
