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

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::FlagHighConfidenceOrthologs

=cut

package Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::FlagHighConfidenceOrthologs;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub param_defaults {
    my $self = shift;
    return {
        %{$self->SUPER::param_defaults},
        'range_label'       => undef,
        'range_filter'      => undef,
    };
}


sub fetch_input {
    my $self = shift @_;

    my $mlss_id     = $self->param_required('mlss_id');
    my $thresholds  = $self->param_required('thresholds');
    my $mlss        = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor->fetch_by_dbID($mlss_id);

    # Common filter we'll apply to all the queries. By default it only filters by mlss_id but can
    # optionally filter by homology_id range (used if we want to apply different thresholds for
    # ncRNAs and protein-coding genes, for instance)
    my $homology_filter = 'method_link_species_set_id = ?';
    if ($self->param('range_filter')) {
        $homology_filter .= ' AND ('.$self->param('range_filter').')';
    }

    # The %identity filter always applies
    my $condition = "perc_id >= ".$thresholds->[2]." AND ";

    # Check whether there are GOC and WGA scores for this mlss_id
    my $sql_score_count = "SELECT COUNT(goc_score IS NOT NULL), COUNT(wga_coverage IS NOT NULL) FROM homology WHERE $homology_filter";
    my ($has_goc, $has_wga) = $self->compara_dba->dbc->db_handle->selectrow_array($sql_score_count, undef, $mlss_id);

    my @external_conditions;
    if ($has_goc and $thresholds->[0]) {
        push @external_conditions, "(goc_score IS NOT NULL AND goc_score >= ".$thresholds->[0].")";
    }
    if ($has_wga and $thresholds->[1]) {
        push @external_conditions, "(wga_coverage IS NOT NULL AND wga_coverage >= ".$thresholds->[1].")";
    }

    # Use the independent metrics if possible or fallback to is_tree_compliant
    if (@external_conditions) {
        $condition .= "(" . join(" OR ", @external_conditions) . ")";
    } else {
        $condition .= "is_tree_compliant = 1";
    }

    $self->param('mlss',                        $mlss);
    $self->param('homology_filter',             $homology_filter);
    $self->param('high_confidence_condition',   $condition);
}

sub write_output {
    my $self = shift @_;

    my $mlss                        = $self->param('mlss');
    my $mlss_id                     = $self->param('mlss_id');
    my $thresholds                  = $self->param('thresholds');
    my $range_label                 = $self->param('range_label') // '';
    my $homology_filter             = $self->param('homology_filter');
    my $high_confidence_condition   = $self->param('high_confidence_condition');

    if ($range_label) {
        $range_label .= '_';
    }

    # Initially I wanted to join both tables, group by homology_id and update homology, but I think
    # this approach here is more efficient: set everything to 1, and reset all the rows that don't
    # pass
    my $sql_sethc = "UPDATE homology SET is_high_confidence = 1 WHERE $homology_filter";
    my $sql_reset = "UPDATE homology JOIN homology_member USING (homology_id) SET is_high_confidence = 0 WHERE $homology_filter AND NOT ($high_confidence_condition)";
    $self->compara_dba->dbc->do($sql_sethc, undef, $mlss_id);
    $self->compara_dba->dbc->do($sql_reset, undef, $mlss_id);

    # Get some statistics for the mlss_tag table
    my $sql_hc_count         = "SELECT COUNT(*), SUM(is_high_confidence) FROM homology WHERE $homology_filter";
    my $sql_hc_per_gdb_count = "SELECT genome_db_id, COUNT(DISTINCT gene_member_id) FROM homology JOIN homology_member USING (homology_id) JOIN gene_member USING (gene_member_id) WHERE $homology_filter AND is_high_confidence = 1 GROUP BY genome_db_id";
    my ($n_hom, $n_hc) = $self->compara_dba->dbc->db_handle->selectrow_array($sql_hc_count, undef, $mlss_id);
    my $hc_per_gdb = $self->compara_dba->dbc->db_handle->selectall_arrayref($sql_hc_per_gdb_count, undef, $mlss_id);

    # There could be 0 homologies for this mlss
    return unless $n_hom;
    
    # Print them
    my $msg_for_gdb = join(" and ", map {$_->[1]." for genome_db_id=".$_->[0]} @$hc_per_gdb);
    $self->warning("$n_hc / $n_hom homologies are high-confidence ($msg_for_gdb)");
    # Store them
    $mlss->store_tag("n_${range_label}high_confidence", $n_hc);
    $mlss->store_tag("n_${range_label}high_confidence_".$_->[0], $_->[1]) for @$hc_per_gdb;

    # More stats for the metrics that were used for this mlss_id
    if ($high_confidence_condition =~ /goc_score/) {
        my $sql_goc_distribution = "SELECT goc_score, COUNT(*) FROM homology WHERE $homology_filter GROUP BY goc_score";
        $self->_write_distribution($mlss, 'goc', $thresholds->[0], $sql_goc_distribution);
    }
    if ($high_confidence_condition =~ /wga_coverage/) {
        my $sql_wga_distribution = "SELECT FLOOR(wga_coverage/25)*25, COUNT(*) FROM homology WHERE $homology_filter GROUP BY FLOOR(wga_coverage/25)";
        $self->_write_distribution($mlss, 'wga', $thresholds->[1], $sql_wga_distribution);
    }
}

sub _write_distribution {
    my ($self, $mlss, $label, $threshold, $sql) = @_;
    my $distrib_array = $self->compara_dba->dbc->db_handle->selectall_arrayref($sql, undef, $mlss->dbID);
    my $n_tot = 0;
    my $n_over_threshold = 0;
    foreach my $distrib_row (@$distrib_array) {
        my $tag = sprintf('n_%s_%s', $label, $distrib_row->[0] // 'null');
        $mlss->store_tag($tag, $distrib_row->[1]);
        $n_tot += $distrib_row->[1];
        if ((defined $distrib_row->[0]) and ($distrib_row->[0] > $threshold)) {
            $n_over_threshold += $distrib_row->[1];
        }
    }
    $mlss->store_tag($label.'_quality_threshold', $threshold);
    $mlss->store_tag('perc_orth_above_'.$label.'_thresh', 100*$n_over_threshold/$n_tot);
}

1;
