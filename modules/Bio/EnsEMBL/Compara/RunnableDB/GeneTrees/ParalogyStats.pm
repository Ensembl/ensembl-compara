=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2019] EMBL-European Bioinformatics Institute

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

Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::ParalogyStats

=head1 DESCRIPTION

This runnable will store statistics on a given paralogy MLSS ID
both globally and at the species-tree-node level:
 n_{$homology_type}_groups
 n_{$homology_type}_pairs
 n_{$homology_type}_genes
 avg_{$homology_type}_perc_id

Note that for a given gene-tree, the number of groups would be 1,
and the number of pairs: n_genes*(n_genes-1)/2. But here, numbers
are aggregated over many gene-trees, so the formula does not apply
any more.

=head1 CONTACT

Please email comments or questions to the public Ensembl developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

Questions may also be sent to the Ensembl help desk at <http://www.ensembl.org/Help/Contact>.

=cut

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::ParalogyStats;

use strict;
use warnings;

use Data::Dumper;
use Bio::EnsEMBL::Compara::Utils::FlatFile qw(map_row_to_header);
# $Data::Dumper::Maxdepth=1;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub fetch_input {
    my $self = shift @_;

    my $member_type  = $self->param_required('member_type');
    my $mlss_id      = $self->param_required('mlss_id');
    my $mlss         = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor->fetch_by_dbID($mlss_id);

    my $homology_flatfile = $self->param_required('homology_flatfile');
    open( my $hom_handle, '<', $homology_flatfile ) or die "Cannot open file: $homology_flatfile";
    my $header_line = <$hom_handle>;
    my @head_cols = split(/\s+/, $header_line);
    my (%stats_raw, %stats_taxon_raw);
    while ( my $line = <$hom_handle> ) {
        my $row = map_row_to_header($line, \@head_cols);
        my ( $homology_type, $gene_tree_root_id, $species_tree_node_id, $seq_member_id, $hom_seq_member_id, $identity,
        $hom_identity ) = ($row->{homology_type}, $row->{gene_tree_root_id}, $row->{species_tree_node_id}, $row->{seq_member_id},
        $row->{hom_seq_member_id}, $row->{identity}, $row->{hom_identity});
        
        
        # homology counts
        $stats_raw{$homology_type}->{$gene_tree_root_id}->{"num_homologies"} += 1;        
        # unique seq_members
        $stats_raw{$homology_type}->{$gene_tree_root_id}->{"seq_members"}->{$seq_member_id} = 1;
        $stats_raw{$homology_type}->{$gene_tree_root_id}->{"seq_members"}->{$hom_seq_member_id} = 1;
        # sum perc_id
        $stats_raw{$homology_type}->{$gene_tree_root_id}->{'perc_id'} += $identity;
        $stats_raw{$homology_type}->{$gene_tree_root_id}->{'perc_id'} += $hom_identity;
        
        
        # same as above, grouping on species_tree_node_id instead of homology type
        next if $homology_type eq 'gene_split';
        $stats_taxon_raw{$species_tree_node_id}->{$gene_tree_root_id}->{"num_homologies"} += 1;
        $stats_taxon_raw{$species_tree_node_id}->{$gene_tree_root_id}->{"seq_members"}->{$seq_member_id} = 1;
        $stats_taxon_raw{$species_tree_node_id}->{$gene_tree_root_id}->{"seq_members"}->{$hom_seq_member_id} = 1;
        $stats_taxon_raw{$species_tree_node_id}->{$gene_tree_root_id}->{'perc_id'} += $identity;
        $stats_taxon_raw{$species_tree_node_id}->{$gene_tree_root_id}->{'perc_id'} += $hom_identity;        
    }
    
    my (%para_stats, %taxon_stats);
    foreach my $ht ( keys %stats_raw ) {
        foreach my $gtr ( keys %{$stats_raw{$ht}} ) {
            # next unless defined $stats_raw{$ht}->{$gtr}->{'num_homologies'};
            $para_stats{$ht}->{'count'} += 1;
            $para_stats{$ht}->{'sum_n_homologies'} += $stats_raw{$ht}->{$gtr}->{'num_homologies'};
            $para_stats{$ht}->{'sum_n_genes'} += scalar(keys(%{$stats_raw{$ht}->{$gtr}->{'seq_members'}}));
            $para_stats{$ht}->{'sum_perc_id'} += $stats_raw{$ht}->{$gtr}->{'perc_id'};
        }
    }
    foreach my $stn ( keys %stats_taxon_raw ) {
        foreach my $gtr ( keys %{$stats_taxon_raw{$stn}} ) {
            # next unless defined $stats_taxon_raw{$stn}->{$gtr}->{'num_homologies'};
            $taxon_stats{$stn}->{'count'} += 1;
            $taxon_stats{$stn}->{'sum_n_homologies'} += $stats_taxon_raw{$stn}->{$gtr}->{'num_homologies'};
            $taxon_stats{$stn}->{'sum_n_genes'} += scalar(keys(%{$stats_taxon_raw{$stn}->{$gtr}->{'seq_members'}}));
            $taxon_stats{$stn}->{'sum_perc_id'} += $stats_taxon_raw{$stn}->{$gtr}->{'perc_id'};
        }
    }

    $self->param('paralog_stats', \%para_stats);
    $self->param('taxon_stats', \%taxon_stats);
}

sub run {
    my $self = shift;
    
    if ( $self->debug ) {
        my $member_type  = $self->param_required('member_type');
        my $para_stats  = $self->param_required('paralog_stats');
        foreach my $ht ( keys %$para_stats ) {
            my $stat_type = sprintf('%s_%s', $member_type, $ht);
            print "$ht:\n";
            printf( "\tn_%s_groups : %s\n", $stat_type, $para_stats->{$ht}->{'count'} );
            printf( "\tn_%s_pairs : %s\n", $stat_type, $para_stats->{$ht}->{'sum_n_homologies'} );
            printf( "\tn_%s_genes : %s\n", $stat_type, $para_stats->{$ht}->{'sum_n_genes'} );
            printf( "\tavg_%s_perc_id : %s\n", $stat_type, ($para_stats->{$ht}->{'sum_perc_id'}/(2*$para_stats->{$ht}->{'sum_n_homologies'})) );
        }
        print "\n";
        my $taxon_stats = $self->param_required('taxon_stats');
        foreach my $stn ( keys %$taxon_stats ) {
            my $stat_type = sprintf('%s_paralogs_%s', $member_type, $stn);
            print "$stn:\n";
            printf( "\tn_%s_groups : %s\n", $stat_type, $taxon_stats->{$stn}->{'count'} );
            printf( "\tn_%s_pairs : %s\n", $stat_type, $taxon_stats->{$stn}->{'sum_n_homologies'} );
            printf( "\tn_%s_genes : %s\n", $stat_type, $taxon_stats->{$stn}->{'sum_n_genes'} );
            printf( "\tavg_%s_perc_id : %s\n", $stat_type, ($taxon_stats->{$stn}->{'sum_perc_id'}/(2*$taxon_stats->{$stn}->{'sum_n_homologies'})) );
        }
        print "\n";
    }
}

sub write_output {
    my $self = shift;
    
    my $member_type  = $self->param_required('member_type');
    my $mlss_id      = $self->param_required('mlss_id');
    my $mlss         = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor->fetch_by_dbID($mlss_id);
    
    my $para_stats  = $self->param_required('paralog_stats');
    foreach my $ht ( keys %$para_stats ) {
        my $stat_type = sprintf('%s_%s', $member_type, $ht);
        $mlss->store_tag(sprintf("n_%s_groups", $stat_type), $para_stats->{$ht}->{'count'});
        $mlss->store_tag(sprintf("n_%s_pairs", $stat_type), $para_stats->{$ht}->{'sum_n_homologies'});
        $mlss->store_tag(sprintf("n_%s_genes", $stat_type), $para_stats->{$ht}->{'sum_n_genes'});
        $mlss->store_tag(sprintf("avg_%s_perc_id", $stat_type), ($para_stats->{$ht}->{'sum_perc_id'}/(2*$para_stats->{$ht}->{'sum_n_homologies'})));
    }
    
    my $taxon_stats = $self->param_required('taxon_stats');
    foreach my $stn ( keys %$taxon_stats ) {
        my $stat_type = sprintf('%s_paralogs_%s', $member_type, $stn);
        $mlss->store_tag(sprintf("n_%s_groups", $stat_type), $taxon_stats->{$stn}->{'count'});
        $mlss->store_tag(sprintf("n_%s_pairs", $stat_type), $taxon_stats->{$stn}->{'sum_n_homologies'});
        $mlss->store_tag(sprintf("n_%s_genes", $stat_type), $taxon_stats->{$stn}->{'sum_n_genes'});
        $mlss->store_tag(sprintf("avg_%s_perc_id", $stat_type), ($taxon_stats->{$stn}->{'sum_perc_id'}/(2*$taxon_stats->{$stn}->{'sum_n_homologies'})));
    }
}

1;
