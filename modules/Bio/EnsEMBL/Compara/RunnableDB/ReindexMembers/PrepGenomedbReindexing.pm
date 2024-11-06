=head1 LICENSE

See the NOTICE file distributed with this work for additional information
regarding copyright ownership.

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

Bio::EnsEMBL::Compara::RunnableDB::ReindexMembers::PrepGenomedbReindexing

=head1 DESCRIPTION

This runnable prepares for genome reindexing by verifying that reindexing
is possible between the previous and current gene-tree MLSSes, generating
a set of reindexing maps, and writing each reindexing map to a JSON file.

It also sets a pipeline-wide parameter ('num_reindexed_genomes'),
which indicates the number of genomes that are to be reindexed.

=cut

package Bio::EnsEMBL::Compara::RunnableDB::ReindexMembers::PrepGenomedbReindexing;

use strict;
use warnings;

use File::Spec::Functions qw(catfile);
use JSON qw(encode_json);
use List::Compare;

use Bio::EnsEMBL::Hive::Utils qw(stringify);

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub run {
    my $self = shift;

    my $prev_mlss_id = $self->param_required('prev_mlss_id');
    my $curr_mlss_id = $self->param_required('mlss_id');

    return if ($curr_mlss_id == $prev_mlss_id);

    my $prev_tree_dba = $self->get_cached_compara_dba('prev_tree_db');
    my $prev_mlss_dba = $prev_tree_dba->get_MethodLinkSpeciesSetAdaptor();
    my $prev_mlss = $prev_mlss_dba->fetch_by_dbID($prev_mlss_id);
    my %prev_gdbs_by_id = map { $_->dbID => $_ } @{$prev_mlss->species_set->genome_dbs};
    my @prev_gdb_ids = keys %prev_gdbs_by_id;

    my $curr_compara_dba = $self->compara_dba();
    my $curr_mlss_dba = $curr_compara_dba->get_MethodLinkSpeciesSetAdaptor();
    my $curr_mlss = $curr_mlss_dba->fetch_by_dbID($curr_mlss_id);
    my %curr_gdbs_by_id = map { $_->dbID => $_ } @{$curr_mlss->species_set->genome_dbs};
    my @curr_gdb_ids = keys %curr_gdbs_by_id;

    my $gdb_id_comparison = List::Compare->new({
        lists    => [\@prev_gdb_ids, \@curr_gdb_ids],
        unsorted => 1,
    });

    my %prev_only_gdb_name_to_id = map { $prev_gdbs_by_id{$_}->name => $_ } $gdb_id_comparison->get_Lonly();
    my %curr_only_gdb_name_to_id = map { $curr_gdbs_by_id{$_}->name => $_ } $gdb_id_comparison->get_Ronly();

    my $gdb_name_comparison = List::Compare->new({
        lists    => [[keys %prev_only_gdb_name_to_id], [keys %curr_only_gdb_name_to_id]],
        unsorted => 1,
    });

    my @unmappable_genome_dbs = $gdb_name_comparison->get_symmetric_difference();
    if (@unmappable_genome_dbs) {
        $self->die_no_retry(
            sprintf(
                "cannot reindex genomes: %d GenomeDBs are absent from either the current or previous MLSS",
                scalar(@unmappable_genome_dbs),
            )
        );
    }

    my @mappable_gdb_names = $gdb_name_comparison->get_union();

    if ($self->param_is_defined('genome_dumps_dir')) {
        $curr_compara_dba->get_GenomeDBAdaptor->dump_dir_location($self->param('genome_dumps_dir'));
    }

    my %gdb_reindexing_map;
    foreach my $gdb_name (@mappable_gdb_names) {
        my $prev_gdb_id = $prev_only_gdb_name_to_id{$gdb_name};
        my $prev_gdb = $prev_gdbs_by_id{$prev_gdb_id};
        my $prev_dnafrags = $prev_tree_dba->get_DnaFragAdaptor->fetch_all_by_GenomeDB($prev_gdb);
        my %prev_dnafrags_by_name = map { $_->name => $_ } @{$prev_dnafrags};

        my $curr_gdb_id = $curr_only_gdb_name_to_id{$gdb_name};
        my $curr_gdb = $curr_gdbs_by_id{$curr_gdb_id};
        my $curr_dnafrags = $curr_compara_dba->get_DnaFragAdaptor->fetch_all_by_GenomeDB($curr_gdb);
        my %curr_dnafrags_by_name = map { $_->name => $_ } @{$curr_dnafrags};

        my $dnafrag_name_comparison = List::Compare->new({
            lists    => [[keys %prev_dnafrags_by_name], [keys %curr_dnafrags_by_name]],
            unsorted => 1,
        });

        my @unmappable_dnafrags = $dnafrag_name_comparison->get_symmetric_difference();
        if (@unmappable_dnafrags) {
            $self->die_no_retry(
                sprintf(
                    "cannot reindex genome %s: %d dnafrags are absent from either the current or previous GenomeDB",
                    $gdb_name,
                    scalar(@unmappable_dnafrags),
                )
            );
        }

        my @dnafrag_names = $dnafrag_name_comparison->get_union();
        foreach my $dnafrag_name (@dnafrag_names) {

            my $prev_dnafrag = $prev_dnafrags_by_name{$dnafrag_name};
            my $prev_locus = $prev_dnafrag->as_locus();

            my $curr_dnafrag = $curr_dnafrags_by_name{$dnafrag_name};
            my $curr_locus = $curr_dnafrag->as_locus();

            if (uc($curr_locus->get_sequence()) ne uc($prev_locus->get_sequence())) {
                $self->die_no_retry(
                    sprintf(
                        "cannot reindex genome %s: sequence mismatch found in dnafrag %s",
                        $gdb_name,
                        $dnafrag_name,
                    )
                );
            }
        }

        $gdb_reindexing_map{$prev_gdb->dbID} = $curr_gdb->dbID;
    }


    my %mlss_reindexing_map = ( $prev_mlss_id => $curr_mlss_id );

    # We fetch homology method types from the previous database as that is the source of the homology data.
    # If there has been a change to homology types, you should probably run the gene-tree pipeline afresh.
    my $prev_method_dba = $prev_tree_dba->get_MethodAdaptor();
    my $homology_methods = $prev_method_dba->fetch_all_by_class_pattern('^Homology\.homology$');
    my @homology_method_types = map { $_->type } @{$homology_methods};

    foreach my $method_type (@homology_method_types) {
        foreach my $i ( 0 .. $#prev_gdb_ids ) {
            my $prev_gdb1_id = $prev_gdb_ids[$i];
            foreach my $j ( $i .. $#prev_gdb_ids ) {
                my $prev_gdb2_id = $prev_gdb_ids[$j];

                my @prev_hom_mlss_gdb_ids;
                if ($prev_gdb2_id == $prev_gdb1_id) {  # e.g. homoeology MLSS
                    @prev_hom_mlss_gdb_ids = ($prev_gdb1_id);
                } else {  # e.g. orthology MLSS
                    @prev_hom_mlss_gdb_ids = ($prev_gdb1_id, $prev_gdb2_id);
                }

                my $prev_hom_mlss = $prev_mlss_dba->fetch_by_method_link_type_GenomeDBs($method_type, \@prev_hom_mlss_gdb_ids);
                next unless defined $prev_hom_mlss;

                my @curr_hom_mlss_gdb_ids = map { exists $gdb_reindexing_map{$_} ? $gdb_reindexing_map{$_} : $_ } @prev_hom_mlss_gdb_ids;
                my $curr_hom_mlss = $curr_mlss_dba->fetch_by_method_link_type_GenomeDBs($method_type, \@curr_hom_mlss_gdb_ids);
                next unless defined $curr_hom_mlss;

                if ($curr_hom_mlss->dbID != $prev_hom_mlss->dbID) {
                    $mlss_reindexing_map{$prev_hom_mlss->dbID} = $curr_hom_mlss->dbID;
                }
            }
        }
    }

    $self->param('gdb_reindexing_map', \%gdb_reindexing_map);
    $self->param('mlss_reindexing_map', \%mlss_reindexing_map);
}


sub write_output {
    my ($self) = @_;

    my $reindexing_dir = $self->param_required('genome_reindexing_dir');
    my $gdb_reindexing_map = $self->param('gdb_reindexing_map') // {};
    my $mlss_reindexing_map = $self->param('mlss_reindexing_map') // {};

    $self->add_or_update_pipeline_wide_parameter('num_reindexed_genomes', scalar(keys %{$gdb_reindexing_map}));

    my $gdb_map_file = catfile($reindexing_dir, 'genome_db_id.json');
    $self->_spurt($gdb_map_file, encode_json($gdb_reindexing_map));

    my $mlss_map_file = catfile($reindexing_dir, 'method_link_species_set_id.json');
    $self->_spurt($mlss_map_file, encode_json($mlss_reindexing_map));
}


1;
