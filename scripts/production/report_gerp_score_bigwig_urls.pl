#!/usr/bin/env perl
# See the NOTICE file distributed with this work for additional information
# regarding copyright ownership.
#
# Licensed under the Apache License, Version 2.0 (the 'License');
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an 'AS IS' BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

=head1 NAME

report_gerp_score_bigwig_urls.pl

=head1 DESCRIPTION

This script reports expected GERP conservation-score bigWig
file URLs for each genome in the specified Compara database.

=head1 SYNOPSIS

     ${ENSEMBL_ROOT_DIR}/ensembl-compara/scripts/production/report_gerp_score_bigwig_urls.pl \
    --url mysql://ensro@mysql-ens-compara-prod-1:4485/ensembl_compara_master \
    --release 116 \
    --outfile e116_verts_gerp_score_bigwig_urls.json

=head1 OPTIONS

=over

=item B<[--help]>

Prints help message and exits.

=item B<[--url STR]>

Ensembl Compara database URL.

=item B<[--release INT]>

Ensembl release.

=item B<[-o|--outfile PATH]>

Output JSON file with the expected URLs
of GERP conservation-score bigWig files.

=back

=cut

use strict;
use warnings;

use Getopt::Long;
use JSON;
use Pod::Usage;

use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Utils::IO qw(spurt);

my $help;
my $url;
my $release;
my $outfile;

GetOptions(
    'help|?'      => \$help,
    'url=s'       => \$url,
    'release=i'   => \$release,
    'o|outfile=s' => \$outfile,
);
pod2usage(-exitvalue => 0, -verbose => 1) if $help;
pod2usage(-verbose => 1) if (!($url && $release && $outfile));


my $compara_dba = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->go_figure_compara_dba($url);
my $mlss_adaptor = $compara_dba->get_MethodLinkSpeciesSetAdaptor();
my $gdb_adaptor = $compara_dba->get_GenomeDBAdaptor();

my $division =  $compara_dba->get_division();
my $base_url = $division eq 'vertebrates'
             ? sprintf('https://ftp.ensembl.org/pub/release-%d/', $release)
             : sprintf('https://ftp.ensemblgenomes.ebi.ac.uk/pub/%s/release-%d/', $division, $release - 53)
             ;

my $all_genome_dbs = $gdb_adaptor->fetch_all_by_release($release);
my @rel_genome_dbs = grep { $_->name ne 'ancestral_sequences' && !defined $_->genome_component } @{$all_genome_dbs};

@rel_genome_dbs = sort { $a->name cmp $b->name } @rel_genome_dbs;

my @recs;
foreach my $genome_db (@rel_genome_dbs) {

    my $mlsses = $mlss_adaptor->fetch_all_by_method_link_type_GenomeDB(
        'GERP_CONSERVATION_SCORE',
        $genome_db,
    );

    my @curr_mlsses = grep { $_->is_in_release($release) } @{$mlsses};

    next if (scalar(@curr_mlsses) == 0);

    @curr_mlsses = sort { $b->species_set->size <=> $a->species_set->size } @curr_mlsses;

    my $mlss_filename = $curr_mlsses[0]->_get_unique_filename();

    my $prod_name = $genome_db->name;
    my $bigwig_url = sprintf(
        '%scompara/conservation_scores/%s/gerp_conservation_scores.%s.%s.bw',
        $base_url,
        $mlss_filename,
        $prod_name,
        $genome_db->assembly,
    );

    my $rec = {
        'production_name' => $prod_name,
        'mlss_filename' => $mlss_filename,
        'bigwig_url' => $bigwig_url,
    };

    push(@recs, $rec);
}

spurt($outfile, JSON->new->pretty->encode(\@recs));
