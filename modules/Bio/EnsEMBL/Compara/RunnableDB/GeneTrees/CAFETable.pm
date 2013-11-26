=head1 LICENSE

Copyright [1999-2013] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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
  developers list at <dev@ensembl.org>.

  Questions may also be sent to the Ensembl help desk at
  <helpdesk@ensembl.org>.

=cut

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::CAFETable

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
use base ('Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::GeneGainLossCommon');

sub param_defaults {
    return {
            'tree_fmt'         => '%{n}%{":"d}',
            'norm_factor'      => 0.1,
            'norm_factor_step' => 0.1,
            'label'            => 'cafe',
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

#    $self->param('cafe_tree_string', $self->get_tree_string_from_mlss_tag());
    $self->get_species_tree_string;
    print STDERR "SPECIES TREE STRING IS: ", $self->param('species_tree_string'), "\n";
    $self->get_cafe_tree_from_string();

    $self->param_required('mlss_id');

## Needed for lambda calculation
    if (! defined $self->param('lambda') && ! defined $self->param('cafe_shell')) {
        die ('cafe_shell is mandatory if lambda is not provided');
    }

    $self->param_required('type');

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
        my $sth = $self->compara_dba->dbc->prepare("INSERT INTO CAFE_data (fam_id, tree, tabledata) VALUES (?,?,?);");
        $sth->execute(1, $self->param('species_tree_string'), $table);
        $sth->finish();
        $self->param('all_fams', [1]);
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
    my $species   = $self->param('cafe_species');

    unless (ref $species eq "ARRAY" and scalar @$species) { ## if we don't have an arrayref or have an arrayref that is empty
        my @sps;
        for my $sp (@{$cafe_tree->get_all_leaves()}) {
            push @sps, $sp->name();
        }
        $species = [@sps];
    }

    my $table = "FAMILY_DESC\tFAMILY\t" . join("\t", @$species);
    $table .= "\n";

    my $all_trees = $self->get_all_trees($species); ## Returns a closure
    my $ok_fams = 0;

    while (my ($name, $id, $vals) = $all_trees->()) {
        my %species;
        for my $href (@$vals) {
            $species{$href->{species}} = $href->{members};
        }

        last unless (defined $name);
        my @species_in_tree = grep {$species{$_} != 0} keys %species;
        if ($self->has_member_at_root([@species_in_tree])) {
            my @vals = map {$_->{members}} @$vals;
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

    my $species;
    for my $sp (@{$cafe_tree->get_all_leaves()}) {
        push @$species, $sp->name();
    }

    my $all_trees = $self->get_all_trees($species); ## Returns a closure
    my $ok_fams = 0;
    my @all_fams = ();
    while (my ($name, $id, $vals) = $all_trees->()) {
        my %species;
        for my $href (@$vals) {
            $species{$href->{species}} = $href->{members};
        }

        last unless (defined $name);
        my @species_in_tree = grep {$species{$_} != 0} keys %species;

        print STDERR scalar @species_in_tree , " species for this tree\n";
        next if (scalar @species_in_tree < 4);

        #TODO: Should we filter out low-coverage genomes?
        my @leaves = ();
        for my $node (@{$cafe_tree->get_all_leaves}) {
            if (is_in($node->name, \@species_in_tree)) {
                push @leaves, $node;
            }
        }
        next unless (scalar @leaves > 1);
        my $lca = $cafe_tree->find_first_shared_ancestor_from_leaves([@leaves]);
        next unless (defined $lca);
        my $lca_str = $lca->newick_format('ryo', $fmt);
        print STDERR "TREE FOR THIS FAM: \n$lca_str\n" if ($self->debug());
        my $fam_table = "FAMILY_DESC\tFAMILY";
        my $all_species_in_tree = $lca->get_all_leaves();
        for my $sp_node (@$all_species_in_tree) {
            my $sp = $sp_node->name();
            $fam_table .= "\t$sp";
        }
        $fam_table .= "\n";

        my @flds = ($name, $id);
        for my $sp_node (@$all_species_in_tree) {
            my $sp = $sp_node->name();
            push @flds, ($species{$sp} || 0);
        }
        $fam_table .= join ("\t", @flds), "\n";
        print STDERR "TABLE FOR THIS FAM:\n$fam_table\n" if ($self->debug());
        $ok_fams++;
        my $sth = $self->compara_dba->dbc->prepare("INSERT INTO CAFE_data (fam_id, tree, tabledata) VALUES (?,?,?);");
        $sth->execute($name, $lca_str, $fam_table);
        $sth->finish();
        push @all_fams, $name;
    }

    print STDERR "$ok_fams families in final table\n" if ($self->debug());
    $self->param('all_fams', [@all_fams]);
    return;
}

sub has_member_at_root {
    my ($self, $sps) = @_;
    my $cafe_tree = $self->param('cafe_tree');
    my $tree_leaves = $cafe_tree->get_all_leaves();
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
    my $lca = $cafe_tree->find_first_shared_ancestor_from_leaves([@leaves]);
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
        $name = $tree->root_id();
    } else {
        $name = $tree->root_id();
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
        $self->compara_dba->dbc->disconnect_when_inactive(0);
        open my $cafe_proc, "-|", $script or die $!;  ## clean after! (cafe leaves output files)
        my $inf;
        my $inf_in_row;
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
    return $lambda;
}

sub get_normalized_table {
    my ($self, $table, $n) = @_;
    my ($header, @table) = split /\n/, $table;
    my @species = split /\t/, $header;
    my @headers = @species[0,1];
    @species = @species[2..$#species];

    my $data;
    my $fams;

    for my $row (@table) {
        chomp $row;
        my @flds = split/\t/, $row;
        push @$fams, [@flds];
        for my $i (2..$#flds) {
            push @{$data->{$species[$i-2]}}, $flds[$i];
        }
    }
    my $means_a;
    for my $sp (@species) {
        my $mean = mean(@{$data->{$sp}});
        my $stdev = stdev($mean, @{$data->{$sp}});
        #  $means->{$sp} = {mean => $mean, stdev => $stdev};
        push @$means_a, {mean => $mean, stdev => $stdev};
    }

    my $newTable = join "\t", @headers, @species;
    $newTable .= "\n";
    my $nfams = 0;
    for my $famdata (@$fams) {
        my $v = 0;
        for my $i (0 .. $#species) {
            my $vmean = $means_a->[$i]->{mean};
            my $vstdev = $means_a->[$i]->{stdev};
            my $vreal = $famdata->[$i+2];

            $v++ if (($vreal > ($vmean - $vstdev/$n)) && ($vreal < ($vmean + $vstdev/$n)));
        }
        if ($v == scalar(@species)) {
            $newTable .= join "\t", @$famdata;
            $newTable .= "\n";
            $nfams++;
        }
    }
    print STDERR "$nfams families written in tbl file\n" if ($self->debug());
    return $newTable;
}

sub get_table_file {
    my ($self, $table) = @_;
    my $tmp_dir = $self->worker_temp_directory;
    my $mlss_id = $self->param('mlss_id');
    my $table_file = "${tmp_dir}/cafe_${mlss_id}_lambda.tbl";
    open my $table_fh, ">", $table_file or die "$!: $table_file\n";
    print $table_fh $table;
    close ($table_fh);
    return $table_file;
}


sub get_script {
    my ($self, $table_file) = @_;
    my $tmp_dir = $self->worker_temp_directory;
    my $cafe_shell = $self->param('cafe_shell');
    my $mlss_id = $self->param('mlss_id');
    my $cafe_tree_string = $self->param('species_tree_string');
    chop($cafe_tree_string); #remove final semicolon
    $cafe_tree_string =~ s/:\d+$//; # remove last branch length
    my $script_file = "${tmp_dir}/cafe_${mlss_id}_lambda.sh";

    open my $sf, ">", $script_file or die "$!: $script_file\n";
    print $sf '#!' . $cafe_shell . "\n\n";
    print $sf "tree $cafe_tree_string\n\n";
    print $sf "load -i $table_file\n\n";
    print $sf "lambda -s\n";
    close ($sf);

    return $script_file;
}

sub mean {
    my (@items) = @_;
    return sum(@items) / (scalar @items);
}

sub sum {
    my (@items) = @_;
    my $res;
    for my $next (@items) {
        die unless (defined $next);
        $res += $next;
    }
    return $res;
}

sub stdev {
    my ($mean, @items) = @_;
    my $var = 0;
    my $n_items = scalar @items;
    for my $item (@items) {
        $var += ($mean - $item) * ($mean - $item);
    }
    return sqrt($var / (scalar @items));
}


sub n_headers {
    return 2;
}

1;
