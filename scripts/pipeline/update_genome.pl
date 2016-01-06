#!/usr/bin/env perl
# Copyright [1999-2016] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
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
    [--genome_db_name "Species name"]
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

=item B<[--genome_db_name "Species name"]>

Set up the GenomeDB name. This is needed when the core database
misses this information

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
In this mode, --species, --genome_db_name and --taxon_id are ignored.

=back

=head1 INTERNAL METHODS

=cut

use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::ApiVersion;
use Bio::EnsEMBL::Utils::Exception qw(throw warning verbose);
use Bio::EnsEMBL::Utils::IO qw/:slurp/;
use Bio::EnsEMBL::Utils::SqlHelper;

use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::Utils::CoreDBAdaptor;

use Getopt::Long;

my $help;
my $reg_conf;
my $compara;
my $species = "";
my $genome_db_name;
my $taxon_id;
my $force = 0;
my $offset = 0;
my $file;

GetOptions(
    "help" => \$help,
    "reg_conf=s" => \$reg_conf,
    "compara=s" => \$compara,
    "species=s" => \$species,
    "genome_db_name=s" => \$genome_db_name,
    "taxon_id=i" => \$taxon_id,
    "force!" => \$force,
    'offset=i' => \$offset,
    'file_of_production_names=s' => \$file,
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
Bio::EnsEMBL::Registry->load_all($reg_conf);

my $compara_dba;
if ($compara =~ /mysql:\/\//) {
    $compara_dba = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(-url=>$compara);
} else {
    $compara_dba = Bio::EnsEMBL::Registry->get_DBAdaptor($compara, "compara");
}
throw ("Cannot connect to database [$compara]") if (!$compara_dba);
my $helper = Bio::EnsEMBL::Utils::SqlHelper->new(-DB_CONNECTION => $compara_dba->dbc);

if ($species) {
    process_species($species);
} else {
    $taxon_id = undef;
    $genome_db_name = undef;
    $species = undef;
    my $names = slurp_to_array($file, 1);
    foreach my $species (@$names) {
        process_species($species);
    }
}

exit(0);


=head2 process_species

  Arg[1]      : string $string
  Description : Does everything for this species: create / update the GenomeDB entry, and load the DnaFrags
  Returntype  : none
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

    $helper->transaction( -CALLBACK => sub {
        my $genome_db = update_genome_db($species_db, $compara_dba, $force);
        update_dnafrags($compara_dba, $genome_db, $species_db);
        my $component_genome_dbs = update_component_genome_dbs($genome_db, $species_db, $compara_dba);
        foreach my $component_gdb (@$component_genome_dbs) {
            update_dnafrags($compara_dba, $component_gdb, $species_db);
        }
        print_method_link_species_sets_to_update($compara_dba, $genome_db);
    } );
    $species_db->dbc()->disconnect_if_idle();
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
  } elsif ($force) {
    print "GenomeDB with this name [$genome_db_name] and the correct assembly".
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

    print "GenomeDB after update: ", $genome_db->toString, "\n\n";

  }
  ## New genome or new assembly!!
  else {

    $genome_db = Bio::EnsEMBL::Compara::GenomeDB->new(
        -DB_ADAPTOR => $species_dba,

        -TAXON_ID   => $taxon_id,
        -NAME       => $genome_db_name,
    );

    if (!defined($genome_db->taxon_id)) {
      throw "Cannot find species.taxonomy_id in meta table for $genome_db_name.\n".
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
    print " -> Successfully stored with genome_db_id=".$genome_db->dbID."\n\n";
    printf("You can add a new 'ensembl alias name' entry in scripts/taxonomy/ensembl_aliases.sql to map the taxon_id %d to '%s'\n", $genome_db->taxon_id, $species_dba->get_MetaContainer->get_common_name());

  }
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


=head2 update_dnafrags

  Arg[1]      : Bio::EnsEMBL::Compara::DBSQL::DBAdaptor $compara_dba
  Arg[2]      : Bio::EnsEMBL::Compara::GenomeDB $genome_db
  Arg[3]      : Bio::EnsEMBL::DBSQL::DBAdaptor $species_dba
  Description : This method fetches all the dnafrag in the compara DB
                corresponding to the $genome_db. It also gets the list
                of top_level seq_regions from the species core DB and
                updates the list of dnafrags in the compara DB.
  Returns     : -none-
  Exceptions  :

=cut

sub update_dnafrags {
  my ($compara_dba, $genome_db, $species_dba) = @_;

  my $dnafrag_adaptor = $compara_dba->get_adaptor("DnaFrag");
  my $old_dnafrags = $dnafrag_adaptor->fetch_all_by_GenomeDB_region($genome_db);
  my $old_dnafrags_by_id;
  foreach my $old_dnafrag (@$old_dnafrags) {
    $old_dnafrags_by_id->{$old_dnafrag->dbID} = $old_dnafrag;
  }

  my $gdb_slices = $genome_db->genome_component
    ? $species_dba->get_SliceAdaptor->fetch_all_by_genome_component($genome_db->genome_component)
    : $species_dba->get_SliceAdaptor->fetch_all('toplevel', undef, 1, 1, 1);
  die "Could not fetch any toplevel slices from ".$genome_db->name() unless(scalar(@$gdb_slices));

  my $current_verbose = verbose();
  verbose('EXCEPTION');

  my $new_dnafrags_ids = 0;
  foreach my $slice (@$gdb_slices) {
    my $length = $slice->seq_region_length;
    my $name = $slice->seq_region_name;
    my $coordinate_system_name = $slice->coord_system_name;

    #Find out if region is_reference or not
    my $is_reference = $slice->is_reference;

    my $new_dnafrag = new Bio::EnsEMBL::Compara::DnaFrag(
            -genome_db => $genome_db,
            -coord_system_name => $coordinate_system_name,
            -name => $name,
            -length => $length,
            -is_reference => $is_reference
        );
    my $dnafrag_id = $dnafrag_adaptor->update($new_dnafrag);
    $new_dnafrags_ids++ if not exists $old_dnafrags_by_id->{$dnafrag_id};
    delete($old_dnafrags_by_id->{$dnafrag_id});
    throw() if ($old_dnafrags_by_id->{$dnafrag_id});
  }
  verbose($current_verbose);
  print "Inserted $new_dnafrags_ids new DnaFrags.\n";
  print "Now deleting ", scalar(keys %$old_dnafrags_by_id), " former DnaFrags...";
  foreach my $deprecated_dnafrag_id (keys %$old_dnafrags_by_id) {
    $compara_dba->dbc->do("DELETE FROM dnafrag WHERE dnafrag_id = ".$deprecated_dnafrag_id) ;
  }
  print "  ok!\n\n";
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
          {join("-", sort map {$_->name} @{$this_method_link_species_set->species_set_obj->genome_dbs})} = $this_method_link_species_set;
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

