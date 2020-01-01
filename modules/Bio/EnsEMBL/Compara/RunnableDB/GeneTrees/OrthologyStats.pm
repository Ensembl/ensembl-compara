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

=cut

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::OrthologyStats

=head1 DESCRIPTION

This runnable will store statistics on a given homology MLSS ID.
For orthologs, it extracts:
 n_${homology_type}_(pairs|groups)
 n_${homology_type}_${genome_db_id}_genes
 avg_${homology_type}_${genome_db_id}_perc_id

=head1 CONTACT

Please email comments or questions to the public Ensembl developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

Questions may also be sent to the Ensembl help desk at <http://www.ensembl.org/Help/Contact>.

=cut

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::OrthologyStats;

use strict;
use warnings;
use Bio::EnsEMBL::Compara::Utils::FlatFile qw(map_row_to_header);

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub param_defaults {
    return {
        'member_type'       => undef,
    }
}

sub fetch_input {
    my $self = shift @_;
    
    my $mlss_id      = $self->param_required('mlss_id');
    my $mlss         = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor->fetch_by_dbID($mlss_id);
    my $genome_dbs   = $mlss->species_set->genome_dbs;
    my $gdb_id_1     = $genome_dbs->[0]->dbID;
    my $gdb_id_2     = $genome_dbs->[1]->dbID;
    
    # create map between (potential) component genome_db_ids and their principal genome_db_id
    my $gdb_map;
    foreach my $gdb ( @$genome_dbs ) {
        my $comp_gdbs = $gdb->component_genome_dbs;
        if ( defined $comp_gdbs->[0] ) {
            foreach my $comp_gdb ( @$comp_gdbs ) {
              $gdb_map->{$comp_gdb->dbID} = $gdb->dbID;
            }
        } else {
            $gdb_map->{$gdb->dbID} = $gdb->dbID;
        }
    }

    my $member_type  = lc $self->param('member_type');
    my $homology_flatfile = $self->param_required('homology_flatfile');
    
    # this stats logic has been converted from an SQL query with 2 subqueries
    my %stats1; # innermost SQL subquery
    open( my $hom_handle, '<', $homology_flatfile ) or die "Cannot open file: $homology_flatfile";
    my $header_line = <$hom_handle>;
    my @head_cols = split(/\s+/, $header_line);
    while ( my $line = <$hom_handle> ) {
        my $row = map_row_to_header($line, \@head_cols);
        my ($homology_type, $gene_tree_node_id, $gene_member_id, $hom_gene_member_id, $genome_db_id, $hom_genome_db_id, 
        $identity, $hom_identity) = ($row->{homology_type}, $row->{gene_tree_node_id}, $row->{gene_member_id}, $row->{hom_gene_member_id}, 
        $row->{genome_db_id}, $row->{hom_genome_db_id}, $row->{identity}, $row->{hom_identity});
        
        ( $genome_db_id, $hom_genome_db_id ) = ( $gdb_map->{$genome_db_id}, $gdb_map->{$hom_genome_db_id} );
        
        $stats1{$homology_type}->{$gene_tree_node_id}->{$gene_member_id}->{$genome_db_id}->{"num_homologies"} += 1; # n1
        $stats1{$homology_type}->{$gene_tree_node_id}->{$hom_gene_member_id}->{$hom_genome_db_id}->{"num_homologies"} += 1; # n2
        $stats1{$homology_type}->{$gene_tree_node_id}->{$gene_member_id}->{$genome_db_id}->{"sum_perc_id"} += $identity; # p1
        $stats1{$homology_type}->{$gene_tree_node_id}->{$hom_gene_member_id}->{$hom_genome_db_id}->{"sum_perc_id"} += $hom_identity; # p2
    }
    close $hom_handle;   
    
    my %stats2; # middle SQL subquery
    foreach my $hom_type ( keys %stats1 ) {
        foreach my $gtn_id ( keys %{$stats1{$hom_type}} ) {
            $stats2{$hom_type}->{$gtn_id}->{"${gdb_id_1}_genes"} = 0;
            $stats2{$hom_type}->{$gtn_id}->{"${gdb_id_2}_genes"} = 0;
            
            foreach my $gm_id ( keys %{$stats1{$hom_type}->{$gtn_id}} ) {
                # num_homologies
                $stats2{$hom_type}->{$gtn_id}->{"num_homologies"} += ($stats1{$hom_type}->{$gtn_id}->{$gm_id}->{$gdb_id_1}->{"num_homologies"} || 0);
                $stats2{$hom_type}->{$gtn_id}->{"num_homologies"} += ($stats1{$hom_type}->{$gtn_id}->{$gm_id}->{$gdb_id_2}->{"num_homologies"} || 0);
                
                # gene counts
                $stats2{$hom_type}->{$gtn_id}->{"${gdb_id_1}_genes"} += 1 if defined $stats1{$hom_type}->{$gtn_id}->{$gm_id}->{$gdb_id_1}->{'num_homologies'};
                $stats2{$hom_type}->{$gtn_id}->{"${gdb_id_2}_genes"} += 1 if defined $stats1{$hom_type}->{$gtn_id}->{$gm_id}->{$gdb_id_2}->{'num_homologies'};
                
                # identity
                $stats2{$hom_type}->{$gtn_id}->{"sum_perc_id"} += ($stats1{$hom_type}->{$gtn_id}->{$gm_id}->{$gdb_id_1}->{"sum_perc_id"} || 0);
                $stats2{$hom_type}->{$gtn_id}->{"sum_perc_id"} += ($stats1{$hom_type}->{$gtn_id}->{$gm_id}->{$gdb_id_2}->{"sum_perc_id"} || 0);
                $stats2{$hom_type}->{$gtn_id}->{"${gdb_id_1}_sum_perc_id"} += ($stats1{$hom_type}->{$gtn_id}->{$gm_id}->{$gdb_id_1}->{"sum_perc_id"} || 0);
                $stats2{$hom_type}->{$gtn_id}->{"${gdb_id_2}_sum_perc_id"} += ($stats1{$hom_type}->{$gtn_id}->{$gm_id}->{$gdb_id_2}->{"sum_perc_id"} || 0);
            }
        }
    }
    
    my %stats3; # outermost query
    foreach my $hom_type ( keys %stats2 ) {
        foreach my $gtn_id ( keys %{$stats2{$hom_type}} ) {
            my $c1 = $stats2{$hom_type}->{$gtn_id}->{"${gdb_id_1}_genes"} > 1 ? 'many' : 'one';
            my $c2 = $stats2{$hom_type}->{$gtn_id}->{"${gdb_id_2}_genes"} > 1 ? 'many' : 'one';
            
            $stats3{$c1}->{$c2}->{"groups"} += 1;
            $stats3{$c1}->{$c2}->{"${gdb_id_1}_genes"} += $stats2{$hom_type}{$gtn_id}->{"${gdb_id_1}_genes"};
            $stats3{$c1}->{$c2}->{"${gdb_id_2}_genes"} += $stats2{$hom_type}{$gtn_id}->{"${gdb_id_2}_genes"};
            $stats3{$c1}->{$c2}->{"pair_members"} += $stats2{$hom_type}->{$gtn_id}->{"num_homologies"};
            $stats3{$c1}->{$c2}->{"${gdb_id_1}_sum_perc_id"} += $stats2{$hom_type}->{$gtn_id}->{"${gdb_id_1}_sum_perc_id"};
            $stats3{$c1}->{$c2}->{"${gdb_id_2}_sum_perc_id"} += $stats2{$hom_type}->{$gtn_id}->{"${gdb_id_2}_sum_perc_id"};
        }
    }
    
    $self->param('orth_stats', \%stats3);
    $self->param('genome_db_id_1', $gdb_id_1);
    $self->param('genome_db_id_2', $gdb_id_2);
}

sub run {
    my $self = shift;
    
    my $gdb_id_1 = $self->param('genome_db_id_1');
    my $gdb_id_2 = $self->param('genome_db_id_2');
    my $member_type  = lc $self->param('member_type');
    
    # print summary of stats
    if ( $self->debug ) {
        my $orth_stats = $self->param_required('orth_stats');
        foreach my $c1 ( keys %$orth_stats ) {
            foreach my $c2 ( keys %{$orth_stats->{$c1}} ) {
                my $homology_type = sprintf('%s_%s-to-%s', $member_type, $c1, $c2);
                $orth_stats->{$c1}->{$c2}->{"pairs"} = $orth_stats->{$c1}->{$c2}->{"pair_members"}/2;
                printf("n_%s_pairs : %s\n", $homology_type, $orth_stats->{$c1}->{$c2}->{"pairs"});
                printf("n_%s_groups : %s\n", $homology_type, $orth_stats->{$c1}->{$c2}->{"groups"});
                printf("n_%s_%d_genes : %s\n", $homology_type, $gdb_id_1, $orth_stats->{$c1}->{$c2}->{"${gdb_id_1}_genes"});
                printf("n_%s_%d_genes : %s\n", $homology_type, $gdb_id_2, $orth_stats->{$c1}->{$c2}->{"${gdb_id_2}_genes"});
                printf("avg_%s_%d_perc_id : %s\n", $homology_type, $gdb_id_1, ($orth_stats->{$c1}->{$c2}->{"${gdb_id_1}_sum_perc_id"} / $orth_stats->{$c1}->{$c2}->{"pairs"}));
                printf("avg_%s_%d_perc_id : %s\n", $homology_type, $gdb_id_2, ($orth_stats->{$c1}->{$c2}->{"${gdb_id_2}_sum_perc_id"} / $orth_stats->{$c1}->{$c2}->{"pairs"}));
                print "\n";
            }
        }
    }
}

sub write_output {
    my $self = shift;
    
    my $mlss_id      = $self->param_required('mlss_id');
    my $mlss         = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor->fetch_by_dbID($mlss_id);
    my $genome_dbs   = $mlss->species_set->genome_dbs;
    my $gdb_id_1     = $genome_dbs->[0]->dbID;
    my $gdb_id_2     = $genome_dbs->[1]->dbID;

    my $member_type  = lc $self->param('member_type');
    
    # Default values (in case some categories are not found in the data)
    foreach my $c1 ('one', 'many') {
        foreach my $c2 ('one', 'many') {
            my $homology_type = sprintf('%s_%s-to-%s', $member_type, $c1, $c2);
            $mlss->store_tag(sprintf('n_%s_pairs', $homology_type), 0);
            $mlss->store_tag(sprintf('n_%s_groups', $homology_type), 0);
            $mlss->store_tag(sprintf('n_%s_%d_genes', $homology_type, $gdb_id_1), 0);
            $mlss->store_tag(sprintf('n_%s_%d_genes', $homology_type, $gdb_id_2), 0);
        }
    }
    
    my $orth_stats = $self->param_required('orth_stats');
    foreach my $c1 ( keys %$orth_stats ) {
        foreach my $c2 ( keys %{$orth_stats->{$c1}} ) {
            my $homology_type = sprintf('%s_%s-to-%s', $member_type, $c1, $c2);
            $orth_stats->{$c1}->{$c2}->{"pairs"} = $orth_stats->{$c1}->{$c2}->{"pair_members"}/2;
            $mlss->store_tag(sprintf("n_%s_pairs", $homology_type), $orth_stats->{$c1}->{$c2}->{"pairs"});
            $mlss->store_tag(sprintf("n_%s_groups", $homology_type), $orth_stats->{$c1}->{$c2}->{"groups"});
            $mlss->store_tag(sprintf("n_%s_%d_genes", $homology_type, $gdb_id_1), $orth_stats->{$c1}->{$c2}->{"${gdb_id_1}_genes"});
            $mlss->store_tag(sprintf("n_%s_%d_genes", $homology_type, $gdb_id_2), $orth_stats->{$c1}->{$c2}->{"${gdb_id_2}_genes"});
            $mlss->store_tag(sprintf("avg_%s_%d_perc_id", $homology_type, $gdb_id_1), ($orth_stats->{$c1}->{$c2}->{"${gdb_id_1}_sum_perc_id"} / $orth_stats->{$c1}->{$c2}->{"pairs"}));
            $mlss->store_tag(sprintf("avg_%s_%d_perc_id", $homology_type, $gdb_id_2), ($orth_stats->{$c1}->{$c2}->{"${gdb_id_2}_sum_perc_id"} / $orth_stats->{$c1}->{$c2}->{"pairs"}));
        }
    }
}

1;
