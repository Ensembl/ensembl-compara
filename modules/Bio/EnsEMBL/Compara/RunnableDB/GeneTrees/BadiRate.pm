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

Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::BadiRate

=head1 DESCRIPTION

This RunnableDB calculates the dynamics of a GeneTree family (based on the tree obtained and the CAFE software) in terms of gains losses per branch tree. It needs a CAFE-compliant species tree.

NOTE: This code is missing parse_badiRate_output, so it won't do much !

=head1 INHERITANCE TREE

Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::GeneGainLossCommon
Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with an underscore (_)

=cut

package Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::BadiRate;

use strict;
use warnings;

use Data::Dumper;
use Bio::EnsEMBL::Compara::Graph::NewickParser;
use base ('Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::GeneGainLossCommon', 'Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub param_defaults {
    return {
            'tree_fmt'           => '%{n}%{":"d}',
            'norm_factor'        => 0,
            'norm_factor_step'   => 0.1,
            'no_split_genes'     => 1,   # For testing
           };
}

sub fetch_input {
    my ($self) = @_;

    $self->param('cafe_tree_string', $self->get_tree_string_from_mlss_tag());
    $self->get_cafe_tree_from_string();

    unless ( $self->param('mlss_id') ) {
        die ('mlss_id is mandatory');
    }

    $self->param('adaptor', $self->compara_dba->get_GeneTreeAdaptor);

    return;
}

sub run {
    my ($self) = @_;

    $self->load_split_genes unless ($self->param('no_split_genes'));
    $self->get_full_cafe_table_from_db();
    $self->run_badiRate();
    return;
}

sub write_output {
    my ($self) = @_;

    $self->parse_badiRate_output();
}

sub get_full_cafe_table_from_db {
    my ($self) = @_;
    my $cafe_tree = $self->param('cafe_tree');

    my $species;
    for my $sp (@{$cafe_tree->get_all_leaves()}) {
        push @$species, $sp->name();
    }

    my $table = "FAMILY_DESC\t" . join ("\t", @$species);
    $table .= "\n";

    my $all_trees = $self->get_all_trees($species); ## Returns a closure
    while (my ($name, undef, $vals) = $all_trees->()) {
        last unless (defined $name);
        my @vals = map {$_->{members}} @$vals;
        $table .= join ("\t", ($name, @vals));
        $table .= "\n";
    }

    print STDERR "$table\n" if ($self->debug());
    $self->param('table', $table);
    return;
}

sub run_badiRate {
    my ($self) = @_;

    my $table        = $self->param('table');
    my $tree         = $self->param('cafe_tree_string');
    my $mlss_id      = $self->param('mlss_id');
    my $badiRate_exe = $self->param('badiRate_exe');

    my $tmp_dir    = $self->worker_temp_directory();
    my $table_file = "${tmp_dir}/badiRate_${mlss_id}.tbl";
    my $tree_file  = "${tmp_dir}/badiRate_${mlss_id}.nwk";

    $self->_spurt($table_file, $table);
    $self->_spurt($tree_file, $tree);

    # perl /software/ensembl/compara/badirate-1.35/BadiRate.pl --treefile /nfs/users/nfs_m/mp12/ensembl_main/tests/test.badirate.nwk --sizefile table_0.1.out -anc -rmodel L -out /lustre/scratch110/ensembl/mp12/badirate_test_0.1.out
    my $cmd = "perl $badiRate_exe --treefile $tree_file --sizefile $table_file -anc -rmodel L"; ## output in STDOUT
    my $runCmd = $self->run_command($cmd, { die_on_failure => 1 });
    if ($runCmd->out =~ /#Likelihood: -inf/) {
        print STDERR "-inf likelihood reported by badiRate\n";
        my $norm_factor = $self->param('norm_factor') + $self->param('norm_factor_step');
        $self->param('norm_factor', $norm_factor);
        my $shavedTable = $self->get_normalized_table($table, $norm_factor);
        $self->run_badiRate();
    } else {
        $self->param('badiRate_out', $runCmd->out);
        return;
    }
}

sub parse_badiRate_output {
    my ($self) = @_;

}

## This method gives the number of header columns present in the table.
## BadiRate uses only 1 column while CAFE uses 2.
sub n_headers {
    return 1;
}

1;
