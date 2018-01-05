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

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::ReindexMembers::TableFactory

=head1 DESCRIPTION

This Runnable lists all the tables of "prev_rel_db" that are not empty in there,
but empty in the current database, and flows a job for each of them (using eHive's
Bio::EnsEMBL::Hive::RunnableDB::JobFactory.

It reuses fetch_input from Bio::EnsEMBL::Compara::RunnableDB::DBMergeCheck as the latter
has all the code needed to list tables and check their size.

=cut

package Bio::EnsEMBL::Compara::RunnableDB::ReindexMembers::TableFactory;

use strict;
use warnings;

use Bio::EnsEMBL::Compara::RunnableDB::DBMergeCheck;

use base ('Bio::EnsEMBL::Hive::RunnableDB::JobFactory');


# Merge the default parameters of both classes
sub param_defaults {
    my $self = shift;
    return {
        %{ $self->SUPER::param_defaults },
        %{ Bio::EnsEMBL::Compara::RunnableDB::DBMergeCheck::param_defaults($self) },

        'column_names'   => [ 'table' ],
    };
}


sub fetch_input {
    my $self = shift @_;

    # Special configuration of Bio::EnsEMBL::Compara::RunnableDB::DBMergeCheck
    $self->param('src_db_aliases', ['prev_rel_db']);
    $self->param('curr_rel_db', $self);
    $self->param('ignored_tables', {});
    $self->param('exclusive_tables', {});

    # dbconnections is a hash: { 'prev_rel_db' => dbc1, 'curr_rel_db' => dbc2 }
    # table_size is a hash: { 'prev_rel_db' => { 't1' => count_1 }, 'curr_rel_db' => { 't2' => count_2 } }

    # todo gene_tree_backup
    Bio::EnsEMBL::Compara::RunnableDB::DBMergeCheck::fetch_input($self);

    # All the tables of the reused database that are not empty, except if
    # they already have data in this database
    # NOTE: this luckily works for other_member_sequence:
    #       1. PT pipeline. The member db has other_member_sequence but the production hasn't
    #       2. NC pipeline. The member db has no other_member_sequence but the production db has
    my @tables_to_copy;
    foreach my $table (keys %{$self->param('table_size')->{prev_rel_db}}) {
        push @tables_to_copy, $table unless $self->param('table_size')->{'curr_rel_db'}->{$table};
    }
    $self->param('inputlist', \@tables_to_copy);
}

1;
