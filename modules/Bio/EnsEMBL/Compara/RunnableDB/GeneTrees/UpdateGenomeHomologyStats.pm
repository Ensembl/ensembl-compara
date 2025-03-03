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

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::UpdateGenomeHomologyStats

=cut

package Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::UpdateGenomeHomologyStats;

use strict;
use warnings;

use File::Spec::Functions qw(catfile);

use Bio::EnsEMBL::Hive::Utils qw(dir_revhash);

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub fetch_input {
    my $self = shift @_;

    my $homology_method_types = $self->param_required('homology_method_types');

    my $master_dba = $self->get_cached_compara_dba('master_db');
    my $method_dba = $master_dba->get_MethodAdaptor();

    my @hom_stat_names;
    foreach my $homology_method_type (@{$homology_method_types}) {
        my $method = $method_dba->fetch_by_type($homology_method_type);
        push(@hom_stat_names, $method->display_name);
    }
    @hom_stat_names = sort @hom_stat_names;

    $self->param('hom_stat_names', \@hom_stat_names);
}

sub run {
    my $self = shift @_;

    my $per_mlss_homology_dump_dir = $self->param_required('per_mlss_homology_dump_dir');
    my $genome_db_id = $self->param_required('genome_db_id');
    my $hom_stat_names = $self->param('hom_stat_names');

    my $mlss_dba = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor();
    my $helper = $self->compara_dba->dbc->sql_helper();

    my $member_group_sql = q/
        SELECT
            gene_member_id
        FROM
            gene_member
        WHERE
            genome_db_id = ?
        AND
            biotype_group = ?
    /;

    my $gene_tree_mlsses = $mlss_dba->fetch_current_gene_tree_mlsses();
    my %hom_stat_name_set = map { $_ => 1 } @{$hom_stat_names};

    my %gm_hom_stats;
    my %members_by_biotype_group;
    foreach my $gene_tree_mlss (@{$gene_tree_mlsses}) {

        # We should count homology stats for a gene-tree collection only if it contains this genome.
        my %gene_tree_gdb_id_set = map { $_->dbID => 1 } @{$gene_tree_mlss->species_set->genome_dbs};
        next unless exists $gene_tree_gdb_id_set{$genome_db_id};

        my $collection_biotype_groups = $gene_tree_mlss->get_gene_tree_member_biotype_groups();

        my %collection_hom_stats;
        foreach my $biotype_group (@{$collection_biotype_groups}) {
            if (!exists $members_by_biotype_group{$biotype_group}) {
                $members_by_biotype_group{$biotype_group} = $helper->execute_simple(
                    -SQL => $member_group_sql,
                    -PARAMS => [$genome_db_id, $biotype_group],
                );
            }

            # Initialising homology stats with relevant members now
            # will make it easier to count only relevant homologies.
            %collection_hom_stats = map { $_ => {} } @{$members_by_biotype_group{$biotype_group}};
        }

        my $homology_mlsses = $mlss_dba->fetch_gene_tree_homology_mlsses($gene_tree_mlss);
        foreach my $homology_mlss (@{$homology_mlsses}) {

            # We should count stats for a homology MLSS only if it contains this genome.
            my %homology_gdb_id_set = map { $_->dbID => 1 } @{$homology_mlss->species_set->genome_dbs};
            next unless exists $homology_gdb_id_set{$genome_db_id};

            # We should count stats for a homology MLSS only if it contains homologies of a relevant type.
            my $homology_type = $homology_mlss->method->display_name;
            next unless exists $hom_stat_name_set{$homology_type};

            my $hom_mlss_id = $homology_mlss->dbID;
            my $homology_dump_file = catfile(
                $per_mlss_homology_dump_dir,
                dir_revhash($hom_mlss_id),
                "${hom_mlss_id}.homologies.tsv",
            );

            open(my $fh, '<', $homology_dump_file) or $self->throw("Failed to open file [$homology_dump_file]");
            my $header = <$fh>;  # We can skip the header row.
            while ( my $line = <$fh> ) {
                chomp($line);
                my @hom_gene_member_ids = split(/\t/, $line);
                foreach my $gene_member_id (@hom_gene_member_ids) {
                    if (exists $collection_hom_stats{$gene_member_id}) {  # Count only relevant homologies.
                        $collection_hom_stats{$gene_member_id}{$homology_type} += 1;
                    }
                }
            }
            close($fh) or $self->throw("Failed to close file [$homology_dump_file]");
        }

        my $clusterset_id = $gene_tree_mlss->species_set->name =~ s/^collection-//r;
        $gm_hom_stats{$clusterset_id} = \%collection_hom_stats;
    }

    $self->param('gm_hom_stats', \%gm_hom_stats);
}

sub write_output {
    my $self = shift;

    my $hom_stat_names = $self->param('hom_stat_names');
    my $gm_hom_stats   = $self->param('gm_hom_stats');

    my @assignment_list = map { join(' ', ($_, '=', '?')) } @{$hom_stat_names};
    my $assignment_text = join(', ', @assignment_list);
    my $update_stats_sql = qq/
        UPDATE gene_member_hom_stats
        SET $assignment_text
        WHERE gene_member_id = ?
        AND collection = ?
    /;

    my $sth = $self->compara_dba->dbc->prepare($update_stats_sql);
    foreach my $clusterset_id (sort keys %{$gm_hom_stats}) {
        foreach my $gene_member_id (sort keys %{$gm_hom_stats->{$clusterset_id}}) {

            my @hom_stat_values = map { $gm_hom_stats->{$clusterset_id}{$gene_member_id}{$_} // 0 } @{$hom_stat_names};
            $sth->execute(@hom_stat_values, $gene_member_id, $clusterset_id);
        }
    }
    $sth->finish;
}


1;
