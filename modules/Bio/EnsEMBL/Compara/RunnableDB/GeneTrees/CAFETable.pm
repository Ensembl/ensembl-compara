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

Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::CAFETable

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
use warnings;
use Data::Dumper;
use Bio::EnsEMBL::Compara::Graph::NewickParser;
use base ('Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::GeneGainLossCommon');

sub param_defaults {
    return {
            'tree_fmt'         => '%{o}%{":"d}',
            'norm_factor'      => 0.1,
            'norm_factor_step' => 0.1,
            'label'            => 'cafe',
            'no_split_genes'   => 0,
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

    my $cafe_tree = $self->compara_dba->get_SpeciesTreeAdaptor->fetch_by_method_link_species_set_id_label($self->param_required('mlss_id'), $self->param_required('label'))->root;
    $self->param('cafe_tree', $cafe_tree);

## Needed for lambda calculation
    if (! defined $self->param('lambda') && ! defined $self->param('cafe_shell')) {
        die ('cafe_shell is mandatory if lambda is not provided');
    }

    $self->param('adaptor', $self->compara_dba->get_GeneTreeAdaptor);

    if ($self->param('perFamTable')) {
        print STDERR "PER FAMILY CAFE ANALYSIS\n";
        $self->warning("Per-family CAFE Analysis");
    } else {
        print STDERR "ONLY ONE CAFE ANALYSIS\n";
        $self->warning("One CAFE Analysis for all the families");
    }

    return;
}

sub run {
    my ($self) = @_;

    $self->load_split_genes;

    if (defined $self->param('lambda') and defined $self->param('perFamTable')) {
        $self->get_per_family_cafe_table_from_db();
        return;
    }

    my $table = $self->get_full_cafe_table_from_db();
    if (!defined $self->param('lambda')) {
        $self->param('lambda', $self->get_lambda($table));
    }
    print STDERR "FINAL LAMBDA IS ", $self->param('lambda'), "\n";
    if (!defined $self->param('perFamTable') || $self->param('perFamTable') == 0) {
        my $cafe_tree_string = $self->param('cafe_tree')->newick_format('ryo', $self->param('tree_fmt'));
        my $sth = $self->compara_dba->dbc->prepare("INSERT INTO CAFE_data (tree, tabledata) VALUES (?,?);");
        $sth->execute($cafe_tree_string, $table);
        $sth->finish();
        my $fam_id = $self->compara_dba->dbc->db_handle->last_insert_id(undef, undef, 'CAFE_data', 'fam_id');
        $self->param('all_fams', [$fam_id]);
    } else {
        $self->get_per_family_cafe_table_from_db();
    }
}

sub write_output {
    my ($self) = @_;

    my $all_fams = $self->param('all_fams');
    my $lambda = $self->param('lambda');
    for my $fam_id (@$all_fams) {

        print STDERR "FIRING FAM: $fam_id\n" if($self->debug);

        $self->dataflow_output_id (
                                   {
                                    'fam_id' => $fam_id,
                                    'lambda' => $lambda,
                                   }, 2
                                  );
    }
}


###########################################
## Internal methods #######################
###########################################

sub get_full_cafe_table_from_db {
    my ($self) = @_;
    my $cafe_tree = $self->param('cafe_tree');

    my $species = [map {$_->node_id} @{$cafe_tree->get_all_leaves()}];

    my $table = "FAMILY_DESC\tFAMILY\t" . join("\t", @$species);
    $table .= "\n";

    my $all_trees = $self->get_all_trees($species); ## Returns a closure
    my $ok_fams = 0;

    while (my ($name, $id, $vals) = $all_trees->()) {
        last unless (defined $name);
        if ($self->has_member_at_root($vals)) {
            my @vals = map {$vals->{$_}} @$species;
            $ok_fams++;
            $table .= join ("\t", ($name, $id, @vals));
            $table .= "\n";
        }
    }

    print STDERR "$ok_fams families in final table\n" if ($self->debug());
    print STDERR "$table\n" if ($self->debug());
    return $table;
}

sub get_per_family_cafe_table_from_db {
    my ($self) = @_;
    my $fmt = $self->param('tree_fmt');
    my $cafe_tree = $self->param('cafe_tree');

    my $species = [map {$_->node_id} @{$cafe_tree->get_all_leaves()}];

    my $all_trees = $self->get_all_trees($species); ## Returns a closure
    my $ok_fams = 0;
    my @all_fams = ();
    while (my ($name, $id, $vals) = $all_trees->()) {
        last unless (defined $name);
        my @species_in_tree = grep {$vals->{$_}} @$species;
        print STDERR scalar @species_in_tree , " species for this tree\n";
        next if (scalar @species_in_tree < 4);

        #TODO: Should we filter out low-coverage genomes?
        my $lca = $self->lca($vals);
        next unless (defined $lca);
        my $lca_str = $lca->newick_format('ryo', $fmt);
        print STDERR "TREE FOR THIS FAM: \n$lca_str\n" if ($self->debug());
        my $fam_table = "FAMILY_DESC\tFAMILY";
        my $all_species_in_tree = $lca->get_all_leaves();
        for my $sp_node (@$all_species_in_tree) {
            my $sp = $sp_node->node_id();
            $fam_table .= "\t$sp";
        }
        $fam_table .= "\n";

        my @flds = ($name, $id, map {$vals->{$_->node_id}} @$all_species_in_tree);
        $fam_table .= join("\t", @flds). "\n";
        print STDERR "TABLE FOR THIS FAM:\n$fam_table\n" if ($self->debug());
        $ok_fams++;
        my $sth = $self->compara_dba->dbc->prepare("INSERT INTO CAFE_data (tree, tabledata) VALUES (?,?);");
        $sth->execute($lca_str, $fam_table);
        my $fam_id = $self->compara_dba->dbc->db_handle->last_insert_id(undef, undef, 'CAFE_data', 'fam_id');
        $sth->finish();
        push @all_fams, $fam_id;
    }

    print STDERR "$ok_fams families in final table\n" if ($self->debug());
    $self->param('all_fams', [@all_fams]);
    return;
}

sub lca {
    my ($self, $sps) = @_;
    my $cafe_tree = $self->param('cafe_tree');
    my $tree_leaves = $cafe_tree->get_all_leaves();
    my @leaves = grep {$sps->{$_->node_id}} @$tree_leaves;
    if (scalar @leaves == 0) {
        return undef;
    }
    return $cafe_tree->find_first_shared_ancestor_from_leaves([@leaves]);
}


sub has_member_at_root {
    my ($self, $sps) = @_;
    my $lca = $self->lca($sps);
    return ($lca && !$lca->has_parent());
}



########################################
## Subroutines for lambda calculation
########################################

sub get_lambda {
    my ($self, $table) = @_;
    my $cafe_shell = $self->param('cafe_shell');
    my $tmp_dir = $self->worker_temp_directory;
    my $norm_factor = $self->param('norm_factor');
    my $norm_factor_step = $self->param('norm_factor_step');
    my $lambda = 0;
LABEL:    while (1) {
        my $new_table = $self->get_normalized_table($table, $norm_factor);
        my $table_file = $self->get_table_file($new_table);
        my $script     = $self->get_script($table_file);
        print STDERR "NORM_FACTOR: $norm_factor\n" if ($self->debug());
        print STDERR "Table file is:  $table_file\n" if ($self->debug());
        print STDERR "Script file is: $script\n" if ($self->debug());
        chmod 0755, $script;
        $self->compara_dba->dbc->disconnect_if_idle();
        open my $cafe_proc, "-|", $script or die $!;  ## clean after! (cafe leaves output files)
        my $inf = 0;
        my $inf_in_row = 0;
        while (<$cafe_proc>) {
            chomp;
            next unless (/^Lambda\s+:\s+(0\.\d+)\s+&\s+Score\s*:\s+(.+)/);
            $lambda = $1;
            my $score = $2;
#            print STDERR "$_\n";
#            print STDERR "++ LAMBDA: $lambda, SCORE: $score\n";
            if ($score eq '-inf') {
                $inf++;
                $inf_in_row++;
                print STDERR "-inf score! => INF: $inf, INF_IN_ROW: $inf_in_row\n" if ($self->debug());
            } else {
                $inf_in_row = 0;
            }
            if ($inf >= 10 || $inf_in_row >= 4) {
                $norm_factor+=$norm_factor_step;
                print STDERR "FAILED LAMBDA CALCULATION -- RETRYING WITH $norm_factor\n" if ($self->debug());
                next LABEL;
            }
        }
        last LABEL;
    }
    die "lambda cannot be 0 !\n" unless $lambda;
    return $lambda;
}


sub get_table_file {
    my ($self, $table) = @_;
    my $tmp_dir = $self->worker_temp_directory;
    my $mlss_id = $self->param('mlss_id');
    my $table_file = "${tmp_dir}/cafe_${mlss_id}_lambda.tbl";
    $self->_spurt($table_file, $table);
    return $table_file;
}


sub get_script {
    my ($self, $table_file) = @_;
    my $tmp_dir = $self->worker_temp_directory;
    my $cafe_shell = $self->param('cafe_shell');
    my $mlss_id = $self->param('mlss_id');
    my $cafe_tree_string = $self->param('cafe_tree')->newick_format('ryo', $self->param('tree_fmt'));
    chop($cafe_tree_string); #remove final semicolon
    $cafe_tree_string =~ s/:\d+$//; # remove last branch length
    my $script_file = "${tmp_dir}/cafe_${mlss_id}_lambda.sh";

    $self->_spurt($script_file, join("\n",
            "#!$cafe_shell\n",
            "tree $cafe_tree_string\n",
            "load -i $table_file -t 1\n",
            'lambda -s',
        ));

    return $script_file;
}


sub n_headers {
    return 2;
}

1;
