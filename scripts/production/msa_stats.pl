#!/usr/bin/env perl
# See the NOTICE file distributed with this work for additional information
# regarding copyright ownership.
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#      http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

=head1 NAME

msa_stats.pl

=head1 DESCRIPTION

Generates and prints the MSA coverage stats (sorted by species name) for the given MLSS ID and
Compara database URL.

=head1 SYNOPSIS

    perl $ENSEMBL_ROOT_DIR/ensembl-compara/scripts/production/msa_stats.pl \
        --url <db_url> --mlss_id <mlss_id> [--html]

=head1 EXAMPLES

    perl $ENSEMBL_ROOT_DIR/ensembl-compara/scripts/production/msa_stats.pl \
         --url mysql://ensro@mysql-ens-compara-prod-8:4618/ivana_mammals_epo_with_ext_105 \
         --mlss_id 1996 --html

=head1 OPTIONS

=over

=item B<[--help]>

Prints help message and exits.

=item B<[--url url_to_gene_tree_db]>

MSA database URL.

=item B<[--mlss_id|--mlss-id mlss_id]>

MLSS ID to get the statistics from.

=item B<[--html]>

Optional. Print the stats in HTML format. By default, use TSV format.

=back

=cut

use strict;
use warnings;

use DBI;
use Getopt::Long;
use Pod::Usage;

use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;

my ( $help, $url, $mlss_id, $html );
GetOptions(
    "help|?"    => \$help,
    "url=s"     => \$url,
    "mlss_id=i" => \$mlss_id,
    "html"      => \$html,
) or pod2usage(-verbose => 2);

# Handle "print usage" scenarios
pod2usage(-exitvalue => 0, -verbose => 1) if $help;
pod2usage(-verbose => 1) if !$url or !$mlss_id;

my $dba = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->go_figure_compara_dba($url);

my $mlss = $dba->get_MethodLinkSpeciesSetAdaptor->fetch_by_dbID($mlss_id);
my $mlss_id = $mlss->dbID;

my @cols = (
	'species_name', 'mlss_id', 'genome_len', 'genome_cov(bp)', 
	'g_cov(%)', 'coding_exon_len', 'coding_exon_cov(bp)', 'e_cov(%)'
);

my $html_output;
if ( $html ) {
	$html_output  = "<table style=\"width:100%\">\n\t<tr>\n\t\t";
	$html_output .= _html_tag_list( \@cols, 'th' );
	$html_output .= "\n\t</tr>\n";
} else {
	print join("\t", @cols) . "\n";
}

for my $stn (@{$mlss->species_tree->root->get_all_leaves}) {
    my $coding_exon_bp_coverage = $stn->get_tagvalue("coding_exon_coverage");
    my $coding_exon_length      = $stn->get_tagvalue("coding_exon_length");
    my $genome_bp_coverage      = $stn->get_tagvalue("genome_coverage");
    my $genome_length           = $stn->get_tagvalue("genome_length");

    my $genome_cov_perc = $genome_length ? sprintf("%.3f", ($genome_bp_coverage/$genome_length) * 100) : 'N/A';
    my $exon_cov_perc   = $coding_exon_length ? sprintf("%.3f", ($coding_exon_bp_coverage/$coding_exon_length) * 100) : 'N/A';

    if ( $html ) {
        $html_output .= '<tr>' . _html_tag_list( [ $stn->name, $mlss_id, _commify($genome_length), _commify($genome_bp_coverage), $genome_cov_perc, _commify($coding_exon_length), _commify($coding_exon_bp_coverage), $exon_cov_perc ], 'td' ) . '</tr>';
        $html_output .= "\n";
    } else {
        print join("\t", $stn->name, $mlss_id, _commify($genome_length), _commify($genome_bp_coverage), $genome_cov_perc, _commify($coding_exon_length), _commify($coding_exon_bp_coverage), $exon_cov_perc);
        print "\n";
    }
}

if ( $html ) {
	$html_output .= "</table>";
	print "$html_output\n";
}

sub _html_tag_list {
	my ( $list, $tag ) = @_;

	my $output = "<$tag>";
	$output .= join( "</$tag><$tag>", @$list );
	$output .= "</$tag>";

	return $output;
}

sub _commify {
    my $text = reverse $_[0];
    $text =~ s/(\d\d\d)(?=\d)(?!\d*\.)/$1,/g;
    return scalar reverse $text
}
