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

=item B<[--collection collection_name]>

When --file_of_production_names is given, a collection species-set can be
created with all the species listed in the file.
When --file_of_production_names is not given, the species will be added to
the collection.

=item B<[--release]>

Mark all the GenomeDBs that are created (and the collection if --collection
is given) as "current", i.e. with a first_release and an undefined last_release

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
my $collection;
my $release;

GetOptions(
    "help" => \$help,
    "reg_conf=s" => \$reg_conf,
    "compara=s" => \$compara,
    "species=s" => \$species,
    "taxon_id=i" => \$taxon_id,
    "force!" => \$force,
    'offset=i' => \$offset,
    'file_of_production_names=s' => \$file,
    'collection=s' => \$collection,
    'release' => \$release,
  );

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

my $new_genome_dbs = [];

if ($species) {
    die "--species and --file_of_production_names cannot be given at the same time.\n" if $file;
    push @$new_genome_dbs, @{ process_species($species) };
} else {
    $taxon_id = undef;
    $species = undef;
    my $names = slurp_to_array($file, "chomp");
    foreach my $species (@$names) {
        #left and right trim for unwanted spaces
        $species =~ s/^\s+|\s+$//g;
        push @$new_genome_dbs, @{ process_species($species) };
    }
}

if ($collection) {
    my $ss_adaptor = $compara_dba->get_SpeciesSetAdaptor;
    my $ini_coll_ss = $ss_adaptor->fetch_collection_by_name($collection);
    if ($ini_coll_ss) {
        if ($species) {
            $species = $new_genome_dbs->[0]->name;  # In case the name given on the command line is not a production name
            # In "species" mode, update the species but keep the other ones
            push @$new_genome_dbs, grep {$_->name ne $species} @{$ini_coll_ss->genome_dbs};
        }
    } else {
        print "*** The collection '$collection' does not exist in the database. It will now be created.\n";
    }
    $compara_dba->dbc->sql_helper->transaction( -CALLBACK => sub {
        my $new_collection_ss = $ss_adaptor->update_collection($collection, $ini_coll_ss, $new_genome_dbs);
        # Enable the collection and all its GenomeDB. Also retire the superseded GenomeDBs and their SpeciesSets, including $old_ss. All magically :)
        $ss_adaptor->make_object_current($new_collection_ss) if $release;
    });
}

exit(0);


=head2 process_species

  Arg[1]      : string $string
  Description : Does everything for this species: create / update the GenomeDB entry, and load the DnaFrags
  Returntype  : arrayref of Bio::EnsEMBL::Compara::GenomeDB
  Exceptions  : none

=cut

sub process_species {
    my $species = shift;

    my $species_no_underscores = $species;
    $species_no_underscores =~ s/\_/\ /;

    my $species_db = Bio::EnsEMBL::Registry->get_DBAdaptor($species, "core");
    if(! $species_db) {
        $species_db = Bio::EnsEMBL::Registry->get_DBAdaptor($species_no_underscores, "core");
    }
    throw ("Cannot connect to database [${species_no_underscores} or ${species}]") if (!$species_db);

    my $gdbs = $compara_dba->dbc->sql_helper->transaction( -CALLBACK => sub {
        my $genome_db = update_genome_db($species_db, $compara_dba, $force);
        print "GenomeDB after update: ", $genome_db->toString, "\n\n";
        Bio::EnsEMBL::Compara::Utils::MasterDatabase::update_dnafrags($compara_dba, $genome_db, $species_db);
        my $component_genome_dbs = update_component_genome_dbs($genome_db, $species_db, $compara_dba);
        foreach my $component_gdb (@$component_genome_dbs) {
            Bio::EnsEMBL::Compara::Utils::MasterDatabase::update_dnafrags($compara_dba, $component_gdb, $species_db);
        }
        print_method_link_species_sets_to_update($compara_dba, $genome_db);
        return [$genome_db, @$component_genome_dbs];
    } );
    $species_db->dbc()->disconnect_if_idle();
    return $gdbs;
}


=head2 update_genome_db

  Arg[1]      : Bio::EnsEMBL::DBSQL::DBAdaptor $species_dba
  Arg[2]      : Bio::EnsEMBL::Compara::DBSQL::DBAdaptor $compara_dba
  Arg[3]      : bool $force
  Description : This method takes all the information needed from the
                species database in order to update the genome_db table
                of the compara database
  Returns     : The new Bio::EnsEMBL::Compara::GenomeDB object
  Exceptions  : throw if the genome_db table is up-to-date unless the
                --force option has been activated

=cut

sub update_genome_db {
  my ($species_dba, $compara_dba, $force) = @_;

  my $genome_db_adaptor = $compara_dba->get_GenomeDBAdaptor();
  my $genome_db = eval {$genome_db_adaptor->fetch_by_core_DBAdaptor($species_dba)};

  if ($genome_db and $genome_db->dbID) {
    if (not $force) {
      my $species_production_name = $genome_db->name;
      my $this_assembly = $genome_db->assembly;
      throw "GenomeDB with this name [$species_production_name] and assembly".
        " [$this_assembly] is already in the compara DB [$compara]\n".
        "You can use the --force option IF YOU REALLY KNOW WHAT YOU ARE DOING!!";
    }
  } elsif ($force and $species) {
    print "GenomeDB with this name [$species] and the correct assembly".
        " is not in the compara DB [$compara]\n".
        "You don't need the --force option!!";
    print "Press [Enter] to continue or Ctrl+C to cancel...";
    <STDIN>;
  }


  if ($genome_db) {

    print "GenomeDB before update: ", $genome_db->toString, "\n";

    # Get fresher information from the core database
    $genome_db->db_adaptor($species_dba, 1);
    $genome_db->last_release(undef);

    # And store it back in Compara
    $genome_db_adaptor->update($genome_db);

  }
  ## New genome or new assembly!!
  else {

    $genome_db = Bio::EnsEMBL::Compara::GenomeDB->new_from_DBAdaptor($species_dba);
    $genome_db->taxon_id( $taxon_id ) if $taxon_id;

    if (!defined($genome_db->name)) {
      throw "Cannot find species.production_name in meta table for ".($species_dba->locator).".\n";
    }
    if (!defined($genome_db->taxon_id)) {
      throw "Cannot find species.taxonomy_id in meta table for ".($species_dba->locator).".\n".
          "   You can use the --taxon_id option";
    }
    print "New GenomeDB for Compara: ", $genome_db->toString, "\n";

    #New ID search if $offset is true

    if($offset) {
        my ($max_id) = $compara_dba->dbc->db_handle->selectrow_array('select max(genome_db_id) from genome_db where genome_db_id > ?', undef, $offset);
    	if(!$max_id) {
    		$max_id = $offset;
    	}
      $genome_db->dbID($max_id + 1);
    }

    $genome_db_adaptor->store($genome_db);

  }
  $genome_db_adaptor->make_object_current($genome_db) if $release;
  return $genome_db;
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
  Arg[2]      : Bio::EnsEMBL::Compara::GenomeDB $genome_db
  Description : This method prints all the genomic MethodLinkSpeciesSet
                that need to be updated (those which correspond to the
                $genome_db).
                NB: Only method_link with a dbID<200 || dbID>=500 are taken into
                account (they should be the genomic ones)
  Returns     : -none-
  Exceptions  :

=cut

sub print_method_link_species_sets_to_update {
  my ($compara_dba, $genome_db) = @_;

  my $method_link_species_set_adaptor = $compara_dba->get_adaptor("MethodLinkSpeciesSet");
  my $genome_db_adaptor = $compara_dba->get_adaptor("GenomeDB");

  my $method_link_species_sets;
  foreach my $this_genome_db (@{$genome_db_adaptor->fetch_all()}) {
    next if ($this_genome_db->name ne $genome_db->name);
    foreach my $this_method_link_species_set (@{$method_link_species_set_adaptor->fetch_all_by_GenomeDB($this_genome_db)}) {
      next unless $this_method_link_species_set->is_current;
      $method_link_species_sets->{$this_method_link_species_set->method->dbID}->
          {join("-", sort map {$_->name} @{$this_method_link_species_set->species_set->genome_dbs})} = $this_method_link_species_set;
    }
  }

  print "List of Bio::EnsEMBL::Compara::MethodLinkSpeciesSet to update:\n";
  foreach my $this_method_link_id (sort {$a <=> $b} keys %$method_link_species_sets) {
    next if ($this_method_link_id > 200) and ($this_method_link_id < 500); # Avoid non-genomic method_link_species_set
    foreach my $this_method_link_species_set (values %{$method_link_species_sets->{$this_method_link_id}}) {
      printf "%8d: ", $this_method_link_species_set->dbID,;
      print $this_method_link_species_set->method->type, " (", $this_method_link_species_set->name, ")\n";
    }
  }

}

