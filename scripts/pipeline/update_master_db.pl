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

update_msater_db.pl

=head1 CONTACT

Please email comments or questions to the public Ensembl
developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

Questions may also be sent to the Ensembl help desk at
<http://www.ensembl.org/Help/Contact>.

=head1 DESCRIPTION

This script will check that all the species found in the Registry are
in the compara database, and with up-to-date meta-information (such as
the genebuild, etc).
By default, the script only does the comparison. You need to add --nodry-run
to allow it to update the master database to make it match the core databases.

=head1 SYNOPSIS

  perl update_master_db.pl --help

  perl update_master_db.pl
    --reg_conf registry_configuration_file
    --compara compara_db_name_or_alias
    [--division ensembl_genomes_division]
    [--[no]check_species_with_no_core] [--[no]check_species_missing_from_compara]
    [--[no]dry-run]

=head1 OPTIONS

=head2 GETTING HELP

=over

=item B<[--help]>

Prints help message and exits.

=back

=head2 DATABASE CONFIGURATION

=over

=item B<--reg_conf registry_configuration_file>

The Bio::EnsEMBL::Registry configuration file.

=item B<--compara compara_db_name_or_alias>

The compara database to update. You can use either the original name or any of the
aliases given in the registry_configuration_file

=item B<[--division ensembl_genomes_division]>

Restrict the search to a given division of Ensembl Genomes. You may consider
setting --check_species_with_no_core to 1 if your master database contains more
species than that division.

=back

=head2 REPORTING

=over

=item B<[--check_species_missing_from_compara]>

Boolean (default: true).
Reports all the species that have a core database but not a GenomeDB entry

=item B<[--check_species_with_no_core]>

Boolean (default: true).
Reports all the (current) GenomeDB entries that don't have a core database.

=item B<[--[no]dry-run]>

In dry-run mode (the default), the script does not write into the master
database (and would be happy with a read-only connection).

=back

=cut


use Getopt::Long;

use Bio::EnsEMBL::Registry;

my $help;
my $reg_conf;
my $compara;
my $force = 0;
my $dry_run = 1;
my $check_species_missing_from_compara = 1;
my $check_species_with_no_core = 1;
my $division = undef;

GetOptions(
    "help" => \$help,
    "reg_conf=s" => \$reg_conf,
    "compara=s" => \$compara,
    "division=s" => \$division,
    "dry_run|dry-run!" => \$dry_run,
    "check_species_missing_from_compara!" => \$check_species_missing_from_compara,
    "check_species_with_no_core!" => \$check_species_with_no_core,
  );

$| = 0;

# Print Help and exit if help is requested
if ($help or !$reg_conf or !$compara) {
    use Pod::Usage;
    pod2usage({-exitvalue => 0, -verbose => 2});
}

Bio::EnsEMBL::Registry->load_all($reg_conf, 0, 0, 0, "throw_if_missing");

my $compara_db = Bio::EnsEMBL::Registry->get_DBAdaptor($compara, "compara");
my $genome_db_adaptor = $compara_db->get_GenomeDBAdaptor();
my %found_genome_db_ids = ();

foreach my $db_adaptor (@{Bio::EnsEMBL::Registry->get_all_DBAdaptors(-GROUP => 'core')}) {

    next if $db_adaptor->dbc->dbname =~ /ensembl_ancestral/;

    eval {
        $db_adaptor->dbc->connect();
    };
    if ($@) {
        if ($@ =~ /DBI connect.*failed: Unknown database/) {
            warn sprintf("The database %s does not exist (yet ?). Skipping it.\n", $db_adaptor->dbc->locator);
            next;
        } else {
            die $@;
        }
    }

    # Get the production name and assembly to fetch our GenomeDBs
    my $mc = $db_adaptor->get_MetaContainer();
    next if $division and $mc->get_division and $mc->get_division ne $division;
    my $that_species = $mc->get_production_name();
    my $that_assembly = $db_adaptor->assembly_name();
    unless ($that_species) {
        warn sprintf("Skipping %s (no species name found: a compara_ancestral database ?).\n", $db_adaptor->dbc->locator);
        next;
    }
    my $master_genome_db = $genome_db_adaptor->fetch_by_name_assembly($that_species, $that_assembly);

    # Time to test !
    if ($master_genome_db) {
        $found_genome_db_ids{$master_genome_db->dbID} = 1;
        # Make a new one with the core db information
        my $proper_genome_db = Bio::EnsEMBL::Compara::GenomeDB->new_from_DBAdaptor( $db_adaptor );
        my $diffs = $proper_genome_db->_check_equals($master_genome_db);
        if ($diffs) {
            $proper_genome_db->first_release($master_genome_db->first_release);
            $proper_genome_db->adaptor($genome_db_adaptor);
            warn "> Differences for '$that_species' (assembly '$that_assembly')\n\t".($proper_genome_db->toString)."\n\t".($master_genome_db->toString)."\n$diffs\n";
            $proper_genome_db->dbID($master_genome_db->dbID);
            unless ($dry_run) {
                $genome_db_adaptor->update($proper_genome_db);
                warn "\t> Successfully updated the master database\n";
            }
        } elsif ($master_genome_db->is_current) {
            print "> '$that_species' (assembly '$that_assembly') OK\n";
        } else {
            warn "> '$that_species' (assembly '$that_assembly') is in the master database, but is not yet 'current' (i.e. first/last_release are not properly set). It should be fixed after running edit_collection.pl\n";
        }
    } elsif ($check_species_missing_from_compara) {
        warn "> Could not find the species '$that_species' (assembly '$that_assembly') in the genome_db table. You should probably add it.\n";
    }
    
    # Don't keep all the connections open
    $db_adaptor->dbc->disconnect_if_idle();
}

if ($check_species_with_no_core) {
    foreach my $master_genome_db (@{$genome_db_adaptor->fetch_all}) {
        next if $master_genome_db->name eq 'ancestral_sequences';
        if ($master_genome_db->is_current and not $found_genome_db_ids{$master_genome_db->dbID}) {
            if ($master_genome_db->locator) {
                warn "> The following genome_db entry has a locator in the master database. You should check that it really needs it.\n";
            } else {
                warn "> The following genome_db entry is set as current but cannot be found in the core databases.\n\t".($master_genome_db->toString)."\n";
            }
        }
    }
}


