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


use warnings;
use strict;

=head1 NAME

sample_genomic_regions.pl

=head1 DESCRIPTION

This script samples genomic regions of given size and number from each of the genomes of an MLSS or species set.
The dnafrags of the regions are sampled in proportion to their lengths. The output is a TSV with the production name,
dnafrag name, start and end.

=head1 SYNOPSIS

    sample_genomic_regions.pl --mlss 312167 --size 4000 --nr 4

    sample_genomic_regions.pl --ssid 612680 --size 6000 --nr 10

=head1 OPTIONS

=head2 GETTING HELP

=over

=item B<[--help]>

Prints help message and exits.

=back

=head2 GENERAL CONFIGURATION

=over

=item B<[--reg_conf registry_configuration_file]>

The Bio::EnsEMBL::Registry configuration file. If none given,
the L<--compara> option must be a URL or the COMPARA_REG_PATH
environmental variable must be set.

=item B<[--compara compara_db_name_or_alias]>

The compara database to use. You can use either the original name or any of the
aliases given in the registry_configuration_file. DEFAULT VALUE: compara_curr
(assumes the registry information is given).

=item B<--mlss method_link_species_set_id>

A MethodLinkSpeciesSet identifier.

=item B<--ssid species_set_id>

A species set identifier.

=item B<[--size region_size]>

Size of the regions to sample.

=item B<[--nr nr_regions]>

Number of regions to sample per genome.

=back

=cut

use Getopt::Long;
use List::Util qw(sum first);

use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;

my $help;
my $reg_conf;
my $compara     = 'compara_curr';
my $mlss_id;
my $ss_id;
my $size        = 5000;
my $nr          = 3;

GetOptions(
    'help'          => \$help,
    'reg_conf=s'    => \$reg_conf,
    'compara=s'     => \$compara,
    'mlss=i'        => \$mlss_id,
    'ssid=i'        => \$ss_id,
    'size=i'        => \$size,
    'nr=i'          => \$nr,
);

# Print Help and exit if help is requested
if ($help) {
    use Pod::Usage;
    pod2usage({-exitvalue => 0, -verbose => 2});
}

# Process command line parameters:
die("Either MLSS or species set ID must be specified!") if !$mlss_id && !$ss_id;
die("Either MLSS or species set ID must be specified!") if $mlss_id && $ss_id;

$reg_conf = $ENV{COMPARA_REG_PATH} if !$reg_conf;

#################################################
## Get the adaptors from the Registry
Bio::EnsEMBL::Registry->load_all($reg_conf, 0, 0, 0, 'throw_if_missing') if $reg_conf;

my $compara_dba;
if ($compara =~ /mysql:\/\//) {
    $compara_dba = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(-url=>$compara);
} else {
    $compara_dba = Bio::EnsEMBL::Registry->get_DBAdaptor($compara, 'compara');
}
if (!$compara_dba) {
  die "Cannot connect to compara database <$compara>.";
}
my $genome_dba      = $compara_dba->get_GenomeDBAdaptor;
my $dnafrag_adaptor = $compara_dba->get_DnaFragAdaptor();

# Fetch the species set and genome DBs:
my $species_set;
if ($mlss_id) {
my $mlss_adaptor    = $compara_dba->get_MethodLinkSpeciesSetAdaptor();
my $cactus_mlss = $mlss_adaptor->fetch_by_dbID($mlss_id);
    $species_set = $cactus_mlss->species_set();
} else {
    my $ss_adaptor    = $compara_dba->get_SpeciesSetAdaptor();
    $species_set = $ss_adaptor->fetch_by_dbID($ss_id);
}
my $genome_dbs  = $species_set->genome_dbs();

# Subroutine to sample from a hash in proportion to its values:
sub prob_choice {
    my %probs = @_;
    my ($csum, @tmp) = 0, ();
    foreach my $k (keys %probs) { 
      $csum += $probs{$k};
      push @tmp, [$csum, $k];
    }
  my $r = rand;
  return ( first {$r <= $_->[0]} @tmp )->[1];
}

# Sample a random region of given size from a genome:
sub get_random_region {
    my $gdb     = shift;
    my $size    = shift;
    my $frags   = shift;
    my $probs   = shift;
    
    my $frag    = prob_choice(%$probs);
    my $start   = int(rand($frags->{$frag} - $size)) + 1; # Use one-based coordinates.
    my $end     = $start + $size - 1;
    return [$gdb->name, $frag, $start, $end];
}

# Sample multiple regions from a genome:
sub get_random_regions {
    my $gdb     = shift;
    my $size    = shift;
    my $nr      = shift;

    # Filter for all dnafrags of suitable size:
    my $all_dnafrags = [ grep {$_->length >= $size} @{$dnafrag_adaptor->fetch_all_by_GenomeDB($gdb)} ];
    # Calculate the total length:
    my $sum = sum( map {$_->length} @$all_dnafrags );
    # Build a hash of normalised dnafrag lengths/probabilities:
    my %probs = ( map { $_->name, $_->length/$sum} @$all_dnafrags );
    # Build a hash of dnafrag lengths:
    my %frags = ( map { $_->name, $_->length} @$all_dnafrags );

    my $regions = [ map { get_random_region($gdb, $size, \%frags, \%probs) } (1..$nr) ];
}

# Print out regions:
sub print_regions {
    my $regions = shift;
    for my $reg (@$regions) {
        print "$reg->[0]\t$reg->[1]\t$reg->[2]\t$reg->[3]\n";
    }
}

# Print out header:
print "Species\tDnaFrag\tStart\tEnd\n";

# Generate all regions:
for my $gdb (@$genome_dbs) {
    my $regions = get_random_regions($gdb, $size, $nr);
    print_regions($regions);
}
