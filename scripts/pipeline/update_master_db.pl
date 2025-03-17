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


use strict;
use warnings;

=head1 NAME

update_msater_db.pl

=head1 DESCRIPTION

This script will check that all the species found in the compara database are in the Registry
and with up-to-date meta-information (such as the genebuild, etc).
You probably want to run this script first with the --dry-run option to
see the differences, and then remove --dry-run to actually perform the
update.

=head1 SYNOPSIS

  perl update_master_db.pl --help

  perl update_master_db.pl
    --reg_conf registry_configuration_file
    --compara compara_db_name_or_alias
    [--[no]check_species_with_no_core] [--[no]check_species_missing_from_compara]
    [--dry-run]

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

=back

=head2 REPORTING

=over

=item B<[--check_species_missing_from_compara]>

Boolean (default: false).
Reports all the species that have a core database but not a GenomeDB entry.

=item B<[--check_species_with_no_core]>

Boolean (default: true).
Reports all the (current) GenomeDB entries that don't have a core database.

=item B<[--dry-run]>

In dry-run mode, the script does not write into the master
database (and would be happy with a read-only connection).

=back

=cut


use Getopt::Long;

use Bio::EnsEMBL::Registry;

my $help;
my $reg_conf;
my $compara;
my $force = 0;
my $dry_run;
my $check_species_missing_from_compara = 0;
my $check_species_with_no_core = 1;

GetOptions(
    "help" => \$help,
    "reg_conf=s" => \$reg_conf,
    "compara=s" => \$compara,
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
my $has_errors = 0;

my %genome_db_names = map {$_->name => 1} @{$genome_db_adaptor->fetch_all_current()};

foreach my $db_adaptor (@{Bio::EnsEMBL::Registry->get_all_DBAdaptors(-GROUP => 'core')}) {

    next if $db_adaptor->dbc->dbname =~ /^ensembl_ancestral_/;
    next if $db_adaptor->dbc->dbname =~ /_ancestral_core_/;

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
    my $that_species = $mc->get_production_name();
    if (!$genome_db_names{$that_species}) {
        $db_adaptor->dbc->disconnect_if_idle();
        next;
    }
    my $that_assembly = $db_adaptor->assembly_name();
    unless ($that_species) {
        warn sprintf("Skipping %s (no species name found: a compara_ancestral database ?).\n", $db_adaptor->dbc->locator);
        next;
    }

    # Genome components loop
    foreach my $c (undef, @{$db_adaptor->get_GenomeContainer->get_genome_components}) {

    my $master_genome_db = $genome_db_adaptor->fetch_by_name_assembly($that_species, $that_assembly, $c);

    my $that_genome_name = defined $c
                         ? "'$that_species' (assembly '$that_assembly', component '$c')"
                         : "'$that_species' (assembly '$that_assembly')"
                         ;

    # Time to test !
    if ($master_genome_db) {
        $found_genome_db_ids{$master_genome_db->dbID} = 1;
        # Make a new one with the core db information
        my $proper_genome_db = Bio::EnsEMBL::Compara::GenomeDB->new_from_DBAdaptor( $db_adaptor, $c );
        my $diffs = $proper_genome_db->_check_equals($master_genome_db);
        if ($diffs) {
            # Need to copy all the fields that don't come from the Core database
            $proper_genome_db->first_release($master_genome_db->first_release);
            $proper_genome_db->is_good_for_alignment($master_genome_db->is_good_for_alignment);
            $proper_genome_db->adaptor($genome_db_adaptor);
            warn "> Differences for $that_genome_name\n\t".($proper_genome_db->toString)."\n\t".($master_genome_db->toString)."\n$diffs\n";
            $proper_genome_db->dbID($master_genome_db->dbID);
            if ($dry_run) {
                $has_errors = 1;
            } else {
                $genome_db_adaptor->update($proper_genome_db);
                warn "\t> Successfully updated the master database\n";
            }
        } elsif ($master_genome_db->is_current) {
            print "> $that_genome_name OK\n";
        } else {
            warn "> $that_genome_name is in the master database, but is not yet 'current' (i.e. first/last_release are not properly set). It should be fixed after running edit_collection.pl\n";
        }
    } elsif ($check_species_missing_from_compara) {
        $has_errors = 1;
        warn "> Could not find the species $that_genome_name in the genome_db table. You should probably add it.\n";
    }

    # Genome components loop
    }
    
    # Don't keep all the connections open
    $db_adaptor->dbc->disconnect_if_idle();
}

if ($check_species_with_no_core) {
    foreach my $master_genome_db (@{$genome_db_adaptor->fetch_all_current()}) {
        # the ancestral database is only ready towards the end of the release
        next if $master_genome_db->name eq 'ancestral_sequences';
        if ($master_genome_db->is_current and not $found_genome_db_ids{$master_genome_db->dbID}) {
            $has_errors = 1;
            if ($master_genome_db->locator) {
                warn "> The following genome_db entry has a locator in the master database. You should check that it really needs it.\n";
            } else {
                warn "> The following genome_db entry is set as current but cannot be found in the core databases.\n\t".($master_genome_db->toString)."\n";
            }
        }
    }
}

exit $has_errors;

