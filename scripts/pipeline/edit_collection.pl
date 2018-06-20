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

edit_collection.pl

=head1 CONTACT

Please email comments or questions to the public Ensembl
developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

Questions may also be sent to the Ensembl help desk at
<http://www.ensembl.org/Help/Contact>.

=head1 DESCRIPTION

This script's main purpose is to edit a "collection" species-set for a release, given
a file of species names (--file).

It has two modes, --new and --update:
  --new    : create a new collection containing only the species listed in the input file
  --update : add the species to an existing collection

first_release and last_release will be updated accordingly

=head1 SYNOPSIS

  perl edit_collection.pl --help

  perl edit_collection.pl
    [--reg_conf registry_configuration_file]
    --compara compara_db_name_or_url
    --collection collection_name
    --file|file_of_production_names file listing species production names (1 per line)
    --new|--update

=head1 OPTIONS

=head2 GETTING HELP

=over

=item B<[--help]>

Prints help message and exits.

=back

=head2 GENERAL CONFIGURATION

=over

=item B<--collection collection_name>

The name of the collection to edit

=item B<--compara compara_db_name_or_alias>

The compara database to update. You can use either a Registry name or a URL

=item B<--new>

Create a new collection containing ONLY the species in the file

=item B<--update>

Update an existing collection with the species in the file. Note: this will
result in old assemblies being replaced with their newer counterparts


=item B<[--reg_conf registry_configuration_file]>

The Bio::EnsEMBL::Registry configuration file. If none given,
the one set in ENSEMBL_REGISTRY will be used if defined, if not
~/.ensembl_init will be used.

=item B<[--file_of_production_names path/to/file]>

File that contains the production names of all the species to import.
Mainly used by Ensembl Genomes, this allows a bulk import of many species.
In this mode, the species listed in the file are pre-selected. The script
will still ask the uer to confirm the selection.

=back

=head2 OPTIONS

=over

=item B<[--[no]dry-run]>

In dry-run mode (the default), the script does not write into the master
database (and would be happy with a read-only connection).

=back

=head1 INTERNAL METHODS

=cut

use Pod::Usage;
use Bio::EnsEMBL::ApiVersion;
use Bio::EnsEMBL::Utils::IO qw/:slurp/;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::Utils::CoreDBAdaptor;
use Bio::EnsEMBL::Compara::Utils::MasterDatabase;

use Getopt::Long;

use Data::Dumper;
$Data::Dumper::Maxdepth=3;


my $help;
my $reg_conf;
my $compara;
my $collection_name;
my $dry_run = 0;
my $file;
my ( $new, $update );

GetOptions(
    "help!"                      => \$help,
    "reg_conf=s"                 => \$reg_conf,
    "compara=s"                  => \$compara,
    'collection=s'               => \$collection_name,
    "dry_run|dry-run!"           => \$dry_run,
    'file|file_of_production_names=s' => \$file,
    'new!'                       => \$new,
    'update!'                    => \$update,
  );

$| = 0;

# Print Help and exit if help is requested
pod2usage({-exitvalue => 0, -verbose => 2}) if ($help || !$collection_name || !$compara || !$file);

die "Unknown action! Please specify the --new or --update flag\n\n\n" unless ( $new || $update );

# Find the Compara databae
my $compara_dba;
if ($compara =~ /mysql:\/\//) {
    $compara_dba = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(-url=>$compara);
} else {
    ##
    ## Configure the Bio::EnsEMBL::Registry
    ## Uses $reg_conf if supplied. Uses ENV{ENSMEBL_REGISTRY} instead if defined. Uses
    ## ~/.ensembl_init if all the previous fail.
    ##
    require Bio::EnsEMBL::Registry;
    Bio::EnsEMBL::Registry->load_all($reg_conf, 0, 0, 0, "throw_if_missing");
    $compara_dba = Bio::EnsEMBL::Registry->get_DBAdaptor($compara, "compara");
}
die "Cannot connect to database [$compara]" if (!$compara_dba);

# parse input file
open(my $species_fh, '<', $file) or die "Cannot open file '$file'\n";
my @requested_species_names = <$species_fh>;
chomp @requested_species_names;

Bio::EnsEMBL::Compara::Utils::MasterDatabase::update_collection( $compara_dba, $collection_name, \@requested_species_names, $dry_run ) if ($update);
Bio::EnsEMBL::Compara::Utils::MasterDatabase::new_collection( $compara_dba, $collection_name, \@requested_species_names, $dry_run ) if ($new);

exit(0);

