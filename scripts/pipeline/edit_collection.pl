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

This script's main purpose is to edit a "collection" species-set for a release.
It will prompt for GenomeDBs to add / remove from the current collection (if it
exists, otherwise it makes a new one) and store the selection.
first_release and last_release will be updated accordingly

=head1 SYNOPSIS

  perl edit_collection.pl --help

  perl edit_collection.pl
    [--reg_conf registry_configuration_file]
    --compara compara_db_name_or_url
    --collection collection_name

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

use Bio::EnsEMBL::ApiVersion;
use Bio::EnsEMBL::Utils::IO qw/:slurp/;

use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;

use Bio::EnsEMBL::Compara::Utils::CoreDBAdaptor;

use Getopt::Long;

my $help;
my $reg_conf;
my $compara;
my $collection_name;
my $dry_run = 1;
my $file;

GetOptions(
    "help" => \$help,
    "reg_conf=s" => \$reg_conf,
    "compara=s" => \$compara,
    'collection=s'  => \$collection_name,
    "dry_run|dry-run!" => \$dry_run,
    'file_of_production_names=s' => \$file,
  );

$| = 0;

# Print Help and exit if help is requested
if ($help or !$collection_name or !$compara) {
    use Pod::Usage;
    pod2usage({-exitvalue => 0, -verbose => 2});
}

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

warn "*** This script thinks that the Ensembl version is ".software_version().". Panic if it's wrong !\n";

my $collection_ss = $compara_dba->get_SpeciesSetAdaptor->fetch_collection_by_name($collection_name);
my $all_current_gdbs = [grep {($_->is_current or not $_->has_been_released) and ($_->name ne 'ancestral_sequences')} @{$compara_dba->get_GenomeDBAdaptor->fetch_all()}];
my @new_collection_gdbs = ();

my %preselection = ();
if ($file) {
  $preselection{$_} = 1 for @{ slurp_to_array($file, 1) };
}

if ($collection_ss) {
    ## Here we are in "update mode"
    warn "Found a collection named '$collection_name': species_set_id=".($collection_ss->dbID)."\n";

    my @gdbs_in_current_collection = @{$collection_ss->genome_dbs};
    my %collection_species_by_name = (map {$_->name => $_} @gdbs_in_current_collection);

    # new species
    my @new_species = grep {not exists $collection_species_by_name{$_->name}} @$all_current_gdbs;
    push @new_collection_gdbs, ask_for_genome_dbs('Select the new species to add to the collection', \@new_species);

    # forcedly-updated species
    my @forced_updated_species = grep {exists $collection_species_by_name{$_->name} and ($collection_species_by_name{$_->name}->dbID != $_->dbID) and $_->is_current} @$all_current_gdbs;
    push @new_collection_gdbs, ask_for_genome_dbs('Species that must be updated (because they are newer)', \@forced_updated_species, 1);

    # updated species: only show the more recent ones (i.e. higher genome_db_id)
    my @updated_species = grep {exists $collection_species_by_name{$_->name} and ($collection_species_by_name{$_->name}->dbID < $_->dbID) and not $_->is_current} @$all_current_gdbs;
    push @new_collection_gdbs, ask_for_genome_dbs('Select the species to update', \@updated_species);

    # Species to potentially remove
    my %confirmed_names = map {$_->name => 1} @new_collection_gdbs;
    my @unconfirmed_species= grep {not exists $confirmed_names{$_->name}} @gdbs_in_current_collection;
    if ($file) {
        my %new_preselection = map {$_->name => 1} grep {!$preselection{$_->name}} @unconfirmed_species;
        %preselection = %new_preselection;
    }
    my @to_delete_species = ask_for_genome_dbs('Select the species to remove', \@unconfirmed_species);
    my %deleted_names = map {$_->name => 1} @to_delete_species;
    push @new_collection_gdbs, grep {not exists $deleted_names{$_->name}} @unconfirmed_species;

    # Let's compute a summary of the differences
    print "\nSummary\n";
    my %new_collection_species_by_name = (map {$_->name => $_} @new_collection_gdbs);
    foreach my $name (sort keys %collection_species_by_name) {
        if ($new_collection_species_by_name{$name}) {
            if ($collection_species_by_name{$name}->assembly ne $new_collection_species_by_name{$name}->assembly) {
                print "Updated: $name: ", $collection_species_by_name{$name}->assembly, " -> ", $new_collection_species_by_name{$name}->assembly, "\n";
            }
        } else {
            print "Removed: $name (", $collection_species_by_name{$name}->assembly, ")\n";
        }
    }
    foreach my $name (sort keys %new_collection_species_by_name) {
        unless ($collection_species_by_name{$name}) {
            print "Added: $name (", $new_collection_species_by_name{$name}->assembly, ")\n";
        }
    }

} else {
    ## Here we create a new collection from scratch
    push @new_collection_gdbs, ask_for_genome_dbs('select the species in the collection', $all_current_gdbs);
}

# FIXME check if it deals correctly with polyploid genomes
warn "The new collection will be composed of ".scalar(@new_collection_gdbs)." GenomeDBs\n";
print "Press Enter to continue\n";
<>;

$compara_dba->dbc->sql_helper->transaction( -CALLBACK => sub {
    my $new_collection_ss = $compara_dba->get_SpeciesSetAdaptor->update_collection($collection_name, $collection_ss, \@new_collection_gdbs);
    # Enable the collection and all its GenomeDB. Also retire the superseded GenomeDBs and their SpeciesSets, including $old_ss. All magically :)
    $compara_dba->get_SpeciesSetAdaptor->make_object_current($new_collection_ss);
    print_method_link_species_sets_to_update($compara_dba, $collection_ss) if $collection_ss;
    die "Dry-run mode required. Now aborting the transaction. Review the above-mentionned changes and re-run with the --nodry-run option\n" if $dry_run;
} );

exit(0);


sub ask_for_genome_dbs {
    my $title = shift;
    my $all_genome_dbs = shift;
    my $should_select_all = shift;
    return () unless scalar(@$all_genome_dbs);

    my $genome_dbs_hash = {map {$_->dbID => $_} @{$all_genome_dbs}};
    my $genome_dbs_in = {map {$_->dbID => $_} grep {$preselection{$_->name}} @{$all_genome_dbs}};
    $genome_dbs_in = $genome_dbs_hash if $should_select_all and !$file;
    my $dont_ask = ($file or $should_select_all);

    while (1) {
        print "Selection of species:\n";

        foreach my $this_genome_db (sort {
            ($a->is_current <=> $b->is_current)
                or
            ($a->name cmp $b->name)} @{$all_genome_dbs}) {
            my $dbID = $this_genome_db->dbID;
            my $name = $this_genome_db->name;
            my $assembly = $this_genome_db->assembly;
            my $state = $genome_dbs_in->{$this_genome_db->dbID} ? ' [SELECTED]' : '';
            if ($this_genome_db->is_current) {
                printf " %5d.$state $name $assembly\n", $dbID;
            } else {
                printf " %5d.$state ($name $assembly)\n", $dbID;
            }
        }

        if ($dont_ask) {
            print "Nothing to edit.\n";
            last;
        }

        print "$title\nAdd or remove a GenomeDB by typing its dbID. Type 'all' to select all, or 'none' to clear the selection. Press enter to finish.   ";
        my $answer;
        chomp ($answer = <>);
        if ($answer) {
            if ($answer eq 'all') {
                $genome_dbs_in = {%$genome_dbs_hash};
            } elsif ($answer eq 'none') {
                $genome_dbs_in = {};
            } elsif (not $answer =~ /^\d+$/) {
                print "\nERROR: '$answer' is not a number, try again\n";
            } elsif (not exists $genome_dbs_hash->{$answer}) {
                print "\nERROR: '$answer' is not a valid GenomeDB ID, try again\n";
            } else {
                if (exists $genome_dbs_in->{$answer}) {
                    delete $genome_dbs_in->{$answer};
                } else {
                    $genome_dbs_in->{$answer} = $genome_dbs_hash->{$answer};
                }
            }
        } else {
            last;
        }
    }
    return values %$genome_dbs_in;
}

=head2 update_component_genome_dbs

  Description : Updates all the genome components (only for polyploid genomes)
  Returns     : -none-
  Exceptions  : none

=cut

sub update_component_genome_dbs {
    my ($principal_genome_db, $species_dba, $compara_dba) = @_;

    my @gdbs = ();
    my $genome_db_adaptor = $compara_dba->get_GenomeDBAdaptor();
    foreach my $c (@{$species_dba->get_GenomeContainer->get_genome_components}) {
        my $copy_genome_db = $principal_genome_db->make_component_copy($c);
        $genome_db_adaptor->store($copy_genome_db);
        push @gdbs, $copy_genome_db;
        print "Component '$c' genome_db: ", $copy_genome_db->toString(), "\n";
    }
    return \@gdbs;
}



=head2 print_method_link_species_sets_to_update

  Arg[1]      : Bio::EnsEMBL::Compara::DBSQL::DBAdaptor $compara_dba
  Arg[2]      : Bio::EnsEMBL::Compara::SpeciesSet $collection_ss
  Description : This method prints all the genomic MethodLinkSpeciesSet
                that need to be updated (those which correspond to the
                $collection_ss species-set).
  Returns     : -none-
  Exceptions  :

=cut

sub print_method_link_species_sets_to_update {
    my ($compara_dba, $collection_ss) = @_;

    my $method_link_species_sets = $compara_dba->get_MethodLinkSpeciesSetAdaptor->fetch_all_by_species_set_id($collection_ss->dbID);

    print "List of Bio::EnsEMBL::Compara::MethodLinkSpeciesSet to update:\n";
    foreach my $this_method_link_species_set (sort {$a->dbID <=> $b->dbID} @$method_link_species_sets) {
        printf "%8d: ", $this_method_link_species_set->dbID,;
        print $this_method_link_species_set->method->type, " (", $this_method_link_species_set->name, ")\n";
        if ($this_method_link_species_set->url) {
            $this_method_link_species_set->url('');
            $compara_dba->dbc->do('UPDATE method_link_species_set SET url = "" WHERE method_link_species_set_id = ?', undef, $this_method_link_species_set->dbID);
        }
    }
    print "  NONE\n" unless scalar(@$method_link_species_sets);

}

