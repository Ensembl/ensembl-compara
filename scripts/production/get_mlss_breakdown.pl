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

get_mlss_breakdown.pl

=head1 DESCRIPTION

This script generates an MLSS breakdown in TSV format.

=head1 SYNOPSIS

    perl get_mlss_breakdown.pl --url <db1_url> [--url <db2_url> ... --url <dbN_url>] --outfile breakdown.tsv

=head1 OPTIONS

=over

=item B<[--help]>

Prints help message and exits.

=item B<[--url STR]>

Compara database URL.

=item B<[--outfile PATH]>

Output TSV file path containing MLSS breakdown.

=back

=cut

use strict;
use warnings;

use Getopt::Long;
use Pod::Usage;
use Text::CSV;

use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Utils::Exception qw(throw);


# Before the minimum release, it gets
# harder to keep track of guest genomes.
my $min_release = 100;

my %div_to_guest_genomes = (
    'vertebrates' => [
        'caenorhabditis_elegans',
        'drosophila_melanogaster',
        'saccharomyces_cerevisiae',
    ],
    'plants' => [
        'caenorhabditis_elegans',
        'ciona_savignyi',
        'drosophila_melanogaster',
        'homo_sapiens',
        'saccharomyces_cerevisiae',
    ],
);


my ($help, $outfile);
my @urls;

GetOptions(
    'help|?'    => \$help,
    'url=s'     => \@urls,
    'outfile=s' => \$outfile,
);
pod2usage(-exitvalue => 0, -verbose => 1) if $help;
pod2usage(-verbose => 1) if !scalar(@urls) or !$outfile;


my @recs;
my %method_type_set;
foreach my $url (@urls) {

    my $dba = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->go_figure_compara_dba($url);
    my $mlss_dba = $dba->get_MethodLinkSpeciesSetAdaptor();
    my $genome_dba = $dba->get_GenomeDbAdaptor();

    my $division =  $dba->get_division();
    my $release = $dba->dbc->sql_helper->execute_single_result(
        "SELECT meta_value FROM meta WHERE meta_key = 'schema_version'"
    );

    if ($release < $min_release) {
        throw("Ensembl release ($release) is below the minimum supported release ($min_release)");
    }

    my @rel_gdbs = grep { $_->name ne 'ancestral_sequences' && !defined $_->genome_component } @{$genome_dba->fetch_all()};

    if (exists $div_to_guest_genomes{$division}) {
        my %guest_genome_set = map { $_ => 1 } @{$div_to_guest_genomes{$division}};
        @rel_gdbs = grep { !exists $guest_genome_set{$_->name} } @rel_gdbs;
    }

    foreach my $gdb (@rel_gdbs) {
        my @gdb_mlsses = @{$mlss_dba->fetch_all_by_GenomeDB($gdb)};
        @gdb_mlsses = grep { $_->is_in_release($release) && $_->name } @gdb_mlsses;
        next if scalar(@gdb_mlsses) == 0;

        my %rec = (
            'division' => $division,
            'release' => $release,
            'genome_name' => $gdb->name,
            'taxon_id' => $gdb->taxon_id,
        );
        foreach my $mlss (@gdb_mlsses) {
            my $method_type = $mlss->method->type;
            $method_type_set{$method_type} = 1;
            $rec{$method_type} += 1;
        }

        push(@recs, \%rec);
    }
}

my @out_col_names = ('division', 'release', 'genome_name', 'taxon_id', sort keys %method_type_set);
my $csv = Text::CSV->new({ sep_char => "\t", eol => "\n" });
open(my $fh, '>', $outfile) or throw("Failed to open output file [$outfile]");
$csv->say($fh, \@out_col_names);

foreach my $rec (@recs) {
    my @row = map { $rec->{$_} // 0 } @out_col_names;
    $csv->say($fh, \@row);
}

close($fh);
