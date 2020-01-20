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

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::FlagHighConfidenceOrthologs

=cut

=head1 DESCRIPTION

This runnable uses homologies and attributes from flatfiles (homology_file,
wga_file, goc_file) to decide whether a homology can be considered 'high confidence'.
Writes output in TSV format to 'high_conf_file'.

=cut

package Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::FlagHighConfidenceOrthologs;

use strict;
use warnings;

use POSIX qw(floor);
use File::Basename;

use Bio::EnsEMBL::Compara::Utils::FlatFile qw(map_row_to_header);

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

    # The %identity filter always applies
    my %conditions = (perc_id => $thresholds->[2]);

    # Check whether there are GOC and WGA scores for this mlss_id
    my ($n_hom, $has_goc, $has_wga) = $self->_check_homology_counts;

    # There could be 0 homologies for this mlss
    unless ($n_hom) {
        $self->complete_early("No homologies for mlss_id=$mlss_id. Nothing to do");
    }

    my %external_conditions;
    if ($has_goc and $thresholds->[0]) {
        $external_conditions{goc_score} = $thresholds->[0];
    }
    if ($has_wga and $thresholds->[1]) {
        $external_conditions{wga_coverage} = $thresholds->[1];
    }

    # Use the independent metrics if possible or fallback to is_tree_compliant
    $conditions{is_tree_compliant} = 1 unless scalar(keys %external_conditions) > 0;

    $self->param('mlss',                 $mlss);
    $self->param('conditions',           \%conditions);
    $self->param('external_conditions',  \%external_conditions);
    $self->param('num_homologies',       $n_hom);
}

sub write_output {
    my $self = shift @_;

    $self->disconnect_from_hive_database;

    my $mlss                = $self->param('mlss');
    my $range_label         = $self->param('range_label');
    my $range_filter        = $self->param('range_filter') ? $self->param('range_filter')->{$range_label} : undef;
    my $conditions          = $self->param('conditions');
    my $external_conditions = $self->param('external_conditions');
    my $n_hom               = $self->param('num_homologies'),

    my $homology_file = $self->param_required('homology_file');
    my $wga_file      = $self->param('wga_file');
    my $goc_file      = $self->param('goc_file');
    my $output_file   = $self->param_required('high_conf_file');
    $self->run_command( "mkdir -p " . dirname($output_file)) unless -e dirname($output_file);

    my ( $wga_coverage, $goc_scores );
    $wga_coverage = $self->_parse_flatfile_into_hash($wga_file, $range_filter) if $wga_file;
    $goc_scores   = $self->_parse_flatfile_into_hash($goc_file, $range_filter) if $goc_file;

    open(my $hfh, '<', $homology_file) or die "Cannot open $homology_file for reading";
    open(my $ofh, '>', $output_file  ) or die "Cannot open $output_file for writing";
    print $ofh "homology_id\tis_high_confidence\n";
    my $header_line = <$hfh>;
    my @header_cols = split( /\s+/, $header_line );
    my (%hc_counts, $n_hc);
    while ( my $line = <$hfh> ) {
        my $row = map_row_to_header($line, \@header_cols);
        my ($homology_id, $is_tree_compliant, $gdb_id_1, $gm_id_1, $perc_id_1, $gdb_id_2, $gm_id_2, $perc_id_2) = (
            $row->{homology_id}, $row->{is_tree_compliant}, $row->{genome_db_id}, $row->{gene_member_id}, $row->{identity},
            $row->{hom_genome_db_id}, $row->{hom_gene_member_id}, $row->{hom_identity},
        );

        if ( $range_filter ) {
            next unless $self->_match_range_filter($homology_id, $range_filter);
        }

        # decide if homology is high confidence
        my $is_high_conf = ($perc_id_1 >= $conditions->{perc_id} && $perc_id_2 >= $conditions->{perc_id}) ? 1 : 0;

        if ( %$external_conditions ) {
            my ($goc_pass, $wga_pass);
            if ( $is_high_conf && $external_conditions->{goc_score} ) {
                $goc_pass = 1 if (defined $goc_scores->{$homology_id}) && ($goc_scores->{$homology_id} >= $external_conditions->{goc_score});
            }
            if ( $is_high_conf && $external_conditions->{wga_coverage} ) {
                $wga_pass = 1 if (defined $wga_coverage->{$homology_id}) && ($wga_coverage->{$homology_id} >= $external_conditions->{wga_coverage});
            }
            $is_high_conf = ($goc_pass || $wga_pass) ? 1 : 0;
        } elsif ( $is_high_conf ) {
            $is_high_conf = $is_tree_compliant;
        }
        print $ofh "$homology_id\t$is_high_conf\n";

        # collect some statistics for the mlss_tag table
        $n_hc += $is_high_conf;
        $hc_counts{$gdb_id_1}->{$gm_id_1} = 1 if $is_high_conf;
        $hc_counts{$gdb_id_2}->{$gm_id_2} = 1 if $is_high_conf;
    }
    close $hfh;
    close $ofh;

    # Print them
    my %hc_per_gdb = map { $_ => scalar(keys %{$hc_counts{$_}}) } keys %hc_counts;
    my $msg_for_gdb = join(" and ", map {$hc_per_gdb{$_} . " for genome_db_id=" . $_} keys %hc_per_gdb);
    $self->warning("$n_hc / $n_hom homologies are high-confidence ($msg_for_gdb)");
    # Store them
    $mlss->store_tag("n_${range_label}_high_confidence", $n_hc);
    $mlss->store_tag("n_${range_label}_high_confidence_" . $_, $hc_per_gdb{$_}) for keys %hc_per_gdb;

    # More stats for the metrics that were used for this mlss_id
    if ( defined $external_conditions->{goc_score} ) {
        $self->_write_distribution($mlss, 'goc', $external_conditions->{goc_score}, $goc_scores);
    }
    if ( defined $external_conditions->{wga_coverage} ) {
        # unlike goc, wga is calculated on both protein and ncrna - add the range_label to ensure mergeability
        $self->_write_distribution($mlss, "${range_label}wga", $external_conditions->{wga_coverage}, $wga_coverage);
    }
}

sub _write_distribution {
    my ($self, $mlss, $label, $threshold, $scores) = @_;

    my %distrib_hash;
    foreach my $score ( values %$scores ) {
        my $floor_score = floor($score/25)*25;
        $distrib_hash{$floor_score} += 1;
    }

    my $n_tot = 0;
    my $n_over_threshold = 0;
    foreach my $distrib_score ( keys %distrib_hash ) {
        my $tag = sprintf('n_%s_%s', $label, $distrib_score // 'null');
        $mlss->store_tag($tag, $distrib_hash{$distrib_score});
        $n_tot += $distrib_hash{$distrib_score};
        if ((defined $distrib_score) and ($distrib_score > $threshold)) {
            $n_over_threshold += $distrib_hash{$distrib_score};
        }
    }

    if ( $label =~ /goc/ ) {
        $mlss->store_tag('goc_quality_threshold', $threshold);
        $mlss->store_tag('perc_orth_above_'.$label.'_thresh', 100*$n_over_threshold/$n_tot);
    } elsif ( $label =~ /wga/ ) {
        # for wga, we want to store the values seperately, so that they can be
        # summarised across protein and ncrna later
        $mlss->store_tag('wga_quality_threshold', $threshold);
        $mlss->store_tag('orth_above_'.$label.'_thresh', $n_over_threshold);
        $mlss->store_tag('total_'.$label.'_orth_count', $n_tot);
    }
}

sub _check_homology_counts {
    my $self = shift;

    my $homology_file = $self->param_required('homology_file');
    my $wc_hom = $self->_lines_in_file($homology_file);
    return (0,0,0) if $wc_hom == 0;

    my $goc_file = $self->param('goc_file');
    my $wc_goc = ( $goc_file && -e $goc_file ) ? $self->_lines_in_file($goc_file) : 0;
    my $wga_file = $self->param('wga_file');
    my $wc_wga = ( $wga_file && -e $wga_file ) ? $self->_lines_in_file($wga_file) : 0;
    return ($wc_hom, $wc_goc, $wc_wga);
}

sub _lines_in_file {
    my ( $self, $filename ) = @_;

    my @wc_out = split( /\s+/, $self->get_command_output("wc -l $filename") );
    my $wc_l   = shift @wc_out;
    return $wc_l - 1; # account for header line
}

sub _parse_flatfile_into_hash {
    my ($self, $filename, $filter) = @_;

    my %flatfile_hash;
    open(my $fh, '<', $filename) or die "Cannot open $filename for reading";
    my $header = <$fh>;
    while ( my $line = <$fh> ) {
        chomp $line;
        my ( $id, $val ) = split(/\s+/, $line);
        next if $val eq '';
        next if $filter && ! $self->_match_range_filter($id, $filter);
        $flatfile_hash{$id} = $val;
    }
    close $fh;

    return \%flatfile_hash;
}

sub _match_range_filter {
    my ($self, $id, $filter) = @_;

    my $match = 0;
    foreach my $range ( @$filter ) {
        die "Bad range declaration: at least one value expected, 0 found." unless defined $range->[0];
        if ( defined $range->[1] ) {
            $match = 1 if $id >= $range->[0] && $id <= $range->[1];
        } else {
            $match = 1 if $id >= $range->[0];
        }
    }

    return $match;
}

1;
