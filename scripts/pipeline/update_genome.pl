#!/usr/bin/env perl
# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2018] EMBL-European Bioinformatics Institute
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


use strict;
use warnings;

=head1 NAME

update_genome.pl

=head1 AUTHORS

 Javier Herrero et al.

=head1 CONTACT

Please email comments or questions to the public Ensembl
developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

Questions may also be sent to the Ensembl help desk at
<http://www.ensembl.org/Help/Contact>.

=head1 DESCRIPTION

This script's main purpose is to take the new core DB and a compara DB
in production phase and update it in several steps:
 - It updates the genome_db table
 - It updates all the dnafrags for the given genome_db

=head1 SYNOPSIS

  perl update_genome.pl --help

  perl update_genome.pl
    [--reg_conf registry_configuration_file]
    --compara compara_db_name_or_alias
    --species new_species_db_name_or_alias
    [--taxon_id 1234]
    [--[no]force]
    [--offset 1000]
    [--file_of_production_names path/to/file]

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
the one set in ENSEMBL_REGISTRY will be used if defined, if not
~/.ensembl_init will be used.

=back

=head2 DATABASES

=over

=item B<--compara compara_db_name_or_alias>

The compara database to update. You can use either the original name or any of the
aliases given in the registry_configuration_file

=item B<--species new_species_db_name_or_alias>

The core database of the species to update. You can use either the original name or
any of the aliases given in the registry_configuration_file

=back

=head2 OPTIONS

=over

=item B<[--taxon_id 1234]>

Set up the NCBI taxon ID. This is needed when the core database
misses this information

=item B<[--[no]force]>

This scripts fails if the genome_db table of the compara DB
already matches the new species DB. This options allows you
to overcome this. USE ONLY IF YOU REALLY KNOW WHAT YOU ARE
DOING!

=item B<[--offset 1000]>

This allows you to offset identifiers assigned to Genome DBs by a given
amount. If not specified we assume we will use the autoincrement key
offered by the Genome DB table. If given then IDs will start
from that number (and we will assign according to the current number
of Genome DBs exceeding the offset). First ID will be equal to the
offset+1

=item B<[--file_of_production_names path/to/file]>

File that contains the production names of all the species to import.
Mainly used by Ensembl Genomes, this allows a bulk import of many species.
In this mode, --species and --taxon_id are ignored.

=item B<[--release]>

Mark all the GenomeDBs that are created as "current", i.e. with a first_release 
and an undefined last_release. In cases of a new assembly, all species_sets, 
collections and method_link_species_sets associated with the old assembly will
be retired.

=back

=head1 INTERNAL METHODS

=cut

use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::ApiVersion;
use Bio::EnsEMBL::Utils::Exception qw(throw warning verbose);
use Bio::EnsEMBL::Utils::IO qw/:slurp/;

use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::Utils::CoreDBAdaptor;
use Bio::EnsEMBL::Compara::Utils::MasterDatabase;

use Getopt::Long;

my $help;
my $reg_conf;
my $compara;
my $species = "";
my $taxon_id;
my $force = 0;
my $offset = 0;
my $file;
my $release;
my $collection;

GetOptions(
    "help" => \$help,
    "reg_conf=s" => \$reg_conf,
    "compara=s" => \$compara,
    "species=s" => \$species,
    "taxon_id=i" => \$taxon_id,
    "force!" => \$force,
    'offset=i' => \$offset,
    'file|file_of_production_names=s' => \$file,
    'release' => \$release,
    'collection' => \$collection,
  );

die "The --collection flag has been deprecated. See here for more info:
https://www.ebi.ac.uk/seqdb/confluence/display/EnsCom/Updating+the+master+database\n" if $collection;

$| = 0;

# Print Help and exit if help is requested
if ($help or (!$species and !$file) or !$compara) {
    use Pod::Usage;
    pod2usage({-exitvalue => 0, -verbose => 2});
}

##
## Configure the Bio::EnsEMBL::Registry
## Uses $reg_conf if supplied. Uses ENV{ENSMEBL_REGISTRY} instead if defined. Uses
## ~/.ensembl_init if all the previous fail.
##
Bio::EnsEMBL::Registry->load_all($reg_conf, 0, 0, 0, "throw_if_missing");

my $compara_dba;
if ($compara =~ /mysql:\/\//) {
    $compara_dba = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(-url=>$compara);
} else {
    $compara_dba = Bio::EnsEMBL::Registry->get_DBAdaptor($compara, "compara");
}
throw ("Cannot connect to database [$compara]") if (!$compara_dba);
my $genome_db_adaptor = $compara_dba->get_GenomeDBAdaptor();


# create the list of species
my @species_list;
if ($species) {
    die "--species and --file_of_production_names cannot be given at the same time.\n" if $file;
    push @species_list, $species;
} else {
    $taxon_id = undef;
    my $names = slurp_to_array($file, "chomp");
    foreach my $species (@$names) {
        #left and right trim for unwanted spaces
        $species =~ s/^\s+|\s+$//g;
        push @species_list, $species;
    }
}


# run the update
my $new_genome_dbs = [];
foreach my $this_species ( @species_list ) {
    push @$new_genome_dbs, @{ Bio::EnsEMBL::Compara::Utils::MasterDatabase::update_genome($compara_dba, $this_species, -RELEASE => $release, -FORCE => $force, -TAXON_ID => $taxon_id, -OFFSET => $offset) };
}

exit(0);
