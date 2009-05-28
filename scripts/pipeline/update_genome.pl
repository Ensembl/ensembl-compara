#!/usr/local/ensembl/bin/perl -w

use strict;

my $description = q{
###########################################################################
##
## PROGRAM update_genome.pl
##
## AUTHORS
##    Javier Herrero (jherrero@ebi.ac.uk)
##
## COPYRIGHT
##    This script is part of the Ensembl project http://www.ensembl.org
##
## DESCRIPTION
##    This script takes the new core DB and a compara DB in production fase
##    and updates it in several steps:
##
##      - It updates the genome_db table
##      - It updates all the dnafrags for the given genome_db
##
###########################################################################

};

=head1 NAME

update_genome.pl

=head1 AUTHORS

 Javier Herrero (jherrero@ebi.ac.uk)

=head1 COPYRIGHT

This script is part of the Ensembl project http://www.ensembl.org

=head1 DESCRIPTION

This script takes the new core DB and a compara DB in production fase and updates it in several steps:

 - It updates the genome_db table
 - It updates all the dnafrags for the given genome_db

=head1 SYNOPSIS

perl update_genome.pl --help

perl update_genome.pl
    [--reg_conf registry_configuration_file]
    --compara compara_db_name_or_alias
    --species new_species_db_name_or_alias
    [--species_name "Species name"]
        Set up the species name. This is needed when the core database
        misses this information
    [--taxon_id 1234]
        Set up the NCBI taxon ID. This is needed when the core database
        misses this information
    [--[no]force]
        This scripts fails if the genome_db table of the compara DB
        already matches the new species DB. This options allows you
        to overcome this. USE ONLY IF YOU REALLY KNOW WHAT YOU ARE
        DOING!
    [--offset 1000]
        This allows you to offset identifiers assigned to Genome DBs by a given
        amount. If not specified we assume we will use the autoincrement key
        offered by the Genome DB table. If given then IDs will start 
        from that number (and we will assign according to the current number
        of Genome DBs exceeding the offset). First ID will be equal to the 
        offset+1

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

=item B<[--species_name "Species name"]>

Set up the species name. This is needed when the core database
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

=back

=head1 INTERNAL METHODS

=cut

use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Utils::Exception qw(throw warning verbose);
use Getopt::Long;

my $usage = qq{
perl update_genome.pl
  
  Getting help:
    [--help]
  
  General configuration:
    [--reg_conf registry_configuration_file]
        the Bio::EnsEMBL::Registry configuration file. If none given,
        the one set in ENSEMBL_REGISTRY will be used if defined, if not
        ~/.ensembl_init will be used.
  Databases:
    --compara compara_db_name_or_alias
    --species new_species_db_name_or_alias

  Options:
    [--species_name "Species name"]
        Set up the species name. This is needed when the core database
        misses this information
    [--taxon_id 1234]
        Set up the NCBI taxon ID. This is needed when the core database
        misses this information
    [--[no]force]
        This scripts fails if the genome_db table of the compara DB
        already matches the new species DB. This options allows you
        to overcome this. USE ONLY IF YOU REALLY KNOW WHAT YOU ARE
        DOING!
    [--offset 1000]
        This allows you to offset identifiers assigned to Genome DBs by a given
        amount. If not specified we assume we will use the autoincrement key
        offered by the Genome DB table. If given then IDs will start 
        from that number (and we will assign according to the current number
        of Genome DBs exceeding the offset). First ID will be equal to the 
        offset+1
};

my $help;

my $reg_conf;
my $compara;
my $species;
my $species_name;
my $taxon_id;
my $force = 0;
my $offset = 0;

GetOptions(
    "help" => \$help,
    "reg_conf=s" => \$reg_conf,
    "compara=s" => \$compara,
    "species=s" => \$species,
    "species_name=s" => \$species_name,
    "taxon_id=i" => \$taxon_id,
    "force!" => \$force,
    'offset=i' => \$offset,
  );

$| = 0;

$species =~ s/\_/\ /;

# Print Help and exit if help is requested
if ($help or !$species or !$compara) {
  print $description, $usage;
  exit(0);
}

##
## Configure the Bio::EnsEMBL::Registry
## Uses $reg_conf if supplied. Uses ENV{ENSMEBL_REGISTRY} instead if defined. Uses
## ~/.ensembl_init if all the previous fail.
##
Bio::EnsEMBL::Registry->load_all($reg_conf);

my $species_db = Bio::EnsEMBL::Registry->get_DBAdaptor($species, "core");
throw ("Cannot connect to database [$species]") if (!$species_db);

my $compara_db = Bio::EnsEMBL::Registry->get_DBAdaptor($compara, "compara");
throw ("Cannot connect to database [$compara]") if (!$compara_db);

my $genome_db = update_genome_db($species_db, $compara_db, $force);
print "Bio::EnsEMBL::Compara::GenomeDB->dbID: ", $genome_db->dbID, "\n\n";

# delete_genomic_align_data($compara_db, $genome_db);

# delete_syntenic_data($compara_db, $genome_db);

update_dnafrags($compara_db, $genome_db, $species_db);

print_method_link_species_sets_to_update($compara_db, $genome_db);

exit(0);


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
  
  my $slice_adaptor = $species_dba->get_adaptor("Slice");
	my $genome_db_adaptor = $compara_dba->get_GenomeDBAdaptor();
  my $meta_container = $species_dba->get_MetaContainer;

  my $primary_species_binomial_name;
  if (defined($species_name)) {
    $primary_species_binomial_name = $species_name;
  } else {
    if (!$meta_container->get_Species()) {
      throw "Cannot get the species name from the database. Use the --species_name option";
    }
    $primary_species_binomial_name = $genome_db_adaptor->get_species_name_from_core_MetaContainer($meta_container);
  }
  my ($highest_cs) = @{$slice_adaptor->db->get_CoordSystemAdaptor->fetch_all()};
  my $primary_species_assembly = $highest_cs->version();
  my $genome_db = eval {$genome_db_adaptor->fetch_by_name_assembly(
          $primary_species_binomial_name,
          $primary_species_assembly
      )};
  if ($genome_db and $genome_db->dbID) {
    return $genome_db if ($force);
    throw "GenomeDB with this name [$primary_species_binomial_name] and assembly".
        " [$primary_species_assembly] is already in the compara DB [$compara]\n".
        "You can use the --force option IF YOU REALLY KNOW WHAT YOU ARE DOING!!";
  } elsif ($force) {
    print "GenomeDB with this name [$primary_species_binomial_name] and assembly".
        " [$primary_species_assembly] is not in the compara DB [$compara]\n".
        "You don't need the --force option!!";
    print "Press [Enter] to continue or Ctrl+C to cancel...";
    <STDIN>;
  }

	my ($assembly) = @{$meta_container->list_value_by_key('assembly.default')};
	if (!defined($assembly)) {
    warning "Cannot find assembly.default in meta table for $primary_species_binomial_name";
    $assembly = $primary_species_assembly;
	}
	my ($genebuild) = @{$meta_container->list_value_by_key('genebuild.version')};
	if (!defined($genebuild)) {
			warning "Cannot find genebuild.version in meta table for $primary_species_binomial_name";
			$genebuild = '';
	}

  print "New assembly and genebuild: ", join(" -- ", $assembly, $genebuild),"\n\n";

	#Have to define these since they were removed from the above meta queries
	#and the rest of the code expects them to be defined
  my $sql;
  my $sth;

  $genome_db = eval {
  	$genome_db_adaptor->fetch_by_name_assembly($primary_species_binomial_name,
  		$assembly)
  };
  
  ## New genebuild!
  if ($genome_db) {
  	$sth = $compara_dba->dbc()->prepare('UPDATE genome_db SET assembly =?, genebuild =?, WHERE genome_db_id =?');
  	$sth->execute($assembly, $genebuild, $genome_db->dbID());
  	$sth->finish();
  	
    $genome_db = $genome_db_adaptor->fetch_by_name_assembly(
            $primary_species_binomial_name,
            $assembly
        );

  } 
  ## New genome or new assembly!!
  else {
  	
    if (!defined($taxon_id)) {
      ($taxon_id) = @{$meta_container->list_value_by_key('species.taxonomy_id')};
    }
    if (!defined($taxon_id)) {
      throw "Cannot find species.taxonomy_id in meta table for $primary_species_binomial_name.\n".
          "   You can use the --taxon_id option";
    }
    print "New genome in compara. Taxon #$taxon_id; Name: $primary_species_binomial_name; Assembly $assembly\n\n";
    
    $sth = $compara_dba->dbc()->prepare('UPDATE genome_db SET assembly_default = 0 WHERE name =?');
    $sth->execute($primary_species_binomial_name);
    $sth->finish(); 
    
    #New ID search if $offset is true
    my @args = ($taxon_id, $primary_species_binomial_name, $assembly, $genebuild);
    if($offset) {
    	$sql = 'INSERT INTO genome_db (genome_db_id, taxon_id, name, assembly, genebuild) values (?,?,?,?,?)';
    	$sth = $compara_dba->dbc->prepare('select max(genome_db_id) from genome_db where genome_db_id > ?');
    	$sth->execute($offset);
    	my ($max_id) = $sth->fetchrow_array();
    	$sth->finish();
    	if(!$max_id) {
    		$max_id = $offset;
    	}
    	unshift(@args, $max_id+1);
    }
    else {
    	$sql = 'INSERT INTO genome_db (taxon_id, name, assembly, genebuild) values (?,?,?,?)';
    } 

    $sth = $compara_dba->dbc->prepare($sql);
    $sth->execute(@args);
    $sth->finish();
    $genome_db = $genome_db_adaptor->fetch_by_name_assembly(
         $primary_species_binomial_name,
         $assembly
    );
  }
  return $genome_db;
}

=head2 delete_genomic_align_data

  Arg[1]      : Bio::EnsEMBL::Compara::DBSQL::DBAdaptor $compara_dba
  Arg[2]      : Bio::EnsEMBL::Compara::GenomeDB $genome_db
  Description : This method deletes from the genomic_align,
                genomic_align_block and genomic_align_group tables
                all the rows that refer to the species identified
                by the $genome_db_id
  Returns     : -none-
  Exceptions  : throw if any SQL statment fails

=cut

sub delete_genomic_align_data {
  my ($compara_dba, $genome_db) = @_;

  print "Getting the list of genomic_align_block_id to remove... ";
  my $rows = $compara_dba->dbc->do(qq{
      CREATE TABLE list AS
          SELECT genomic_align_block_id
          FROM genomic_align_block, method_link_species_set
          WHERE genomic_align_block.method_link_species_set_id = method_link_species_set.method_link_species_set_id
          AND genome_db_id = $genome_db->{dbID}
    });
  throw $compara_dba->dbc->errstr if (!$rows);
  print "$rows elements found.\n";

  print "Deleting corresponding genomic_align, genomic_align_block and genomic_align_group rows...";
  $rows = $compara_dba->dbc->do(qq{
      DELETE
        genomic_align, genomic_align_block, genomic_align_group
      FROM
        list
        LEFT JOIN genomic_align_block USING (genomic_align_block_id)
        LEFT JOIN genomic_align USING (genomic_align_block_id)
        LEFT JOIN genomic_align_group USING (genomic_align_id)
      WHERE
        list.genomic_align_block_id = genomic_align.genomic_align_block_id
    });
  throw $compara_dba->dbc->errstr if (!$rows);
  print " ok!\n";

  print "Droping the list of genomic_align_block_ids...";
  $rows = $compara_dba->dbc->do(qq{DROP TABLE list});
  throw $compara_dba->dbc->errstr if (!$rows);
  print " ok!\n\n";
}

=head2 delete_syntenic_data

  Arg[1]      : Bio::EnsEMBL::Compara::DBSQL::DBAdaptor $compara_dba
  Arg[2]      : Bio::EnsEMBL::Compara::GenomeDB $genome_db
  Description : This method deletes from the dnafrag_region
                and synteny_region tables all the rows that refer
                to the species identified by the $genome_db_id
  Returns     : -none-
  Exceptions  : throw if any SQL statment fails

=cut

sub delete_syntenic_data {
  my ($compara_dba, $genome_db) = @_;

  print "Deleting dnafrag_region and synteny_region rows...";
  my $rows = $compara_dba->dbc->do(qq{
      DELETE
        dnafrag_region, synteny_region
      FROM
        dnafrag_region
        LEFT JOIN synteny_region USING (synteny_region_id)
        LEFT JOIN method_link_species_set USING (method_link_species_set_id)
      WHERE genome_db_id = $genome_db->{dbID}
    });
  throw $compara_dba->dbc->errstr if (!$rows);
  print " ok!\n\n";
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

  my $sql1 = qq{
      SELECT
        cs.name,
        sr.name,
        sr.length
      FROM
        coord_system cs,
        seq_region sr,
        seq_region_attrib sra,
        attrib_type at
      WHERE
        sra.attrib_type_id = at.attrib_type_id
        AND at.code = 'toplevel'
        AND sr.seq_region_id = sra.seq_region_id
        AND sr.coord_system_id = cs.coord_system_id
        AND cs.species_id =?
    };
  my $sth1 = $species_dba->dbc->prepare($sql1);
  $sth1->execute($species_dba->species_id());
  my $current_verbose = verbose();
  verbose('EXCEPTION');
  while (my ($coordinate_system_name, $name, $length) = $sth1->fetchrow_array) {
    my $new_dnafrag = new Bio::EnsEMBL::Compara::DnaFrag(
            -genome_db => $genome_db,
            -coord_system_name => $coordinate_system_name,
            -name => $name,
            -length => $length
        );
    my $dnafrag_id = $dnafrag_adaptor->update($new_dnafrag);
    delete($old_dnafrags_by_id->{$dnafrag_id});
    throw() if ($old_dnafrags_by_id->{$dnafrag_id});
  }
  verbose($current_verbose);
  print "Deleting ", scalar(keys %$old_dnafrags_by_id), " former DnaFrags...";
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
                NB: Only method_link with a dbID <200 are taken into
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
      $method_link_species_sets->{$this_method_link_species_set->method_link_id}->
          {join("-", sort map {$_->name} @{$this_method_link_species_set->species_set})} = $this_method_link_species_set;
    }
  }

  print "List of Bio::EnsEMBL::Compara::MethodLinkSpeciesSet to update:\n";
  foreach my $this_method_link_id (sort {$a <=> $b} keys %$method_link_species_sets) {
    last if ($this_method_link_id > 200); # Avoid non-genomic method_link_species_set
    foreach my $this_method_link_species_set (values %{$method_link_species_sets->{$this_method_link_id}}) {
      printf "%8d: ", $this_method_link_species_set->dbID,;
      print $this_method_link_species_set->method_link_type, " (",
          join(",", map {$_->name} @{$this_method_link_species_set->species_set}), ")\n";
    }
  }

}

=head2 create_new_method_link_species_sets

  Arg[1]      : Bio::EnsEMBL::Compara::DBSQL::DBAdaptor $compara_dba
  Arg[2]      : Bio::EnsEMBL::Compara::GenomeDB $genome_db
  Description : This method creates all the genomic MethodLinkSpeciesSet
                that are needed for the new assembly.
                NB: Only method_link with a dbID <200 are taken into
                account (they should be the genomic ones)
  Returns     : -none-
  Exceptions  :

=cut

sub create_new_method_link_species_sets {
  my ($compara_dba, $genome_db) = @_;

  my $method_link_species_set_adaptor = $compara_dba->get_adaptor("MethodLinkSpeciesSet");
  my $genome_db_adaptor = $compara_dba->get_adaptor("GenomeDB");

  my $method_link_species_sets;
  my $all_genome_dbs = $genome_db_adaptor->fetch_all();
  foreach my $this_genome_db (@$all_genome_dbs) {
    next if ($this_genome_db->name ne $genome_db->name);
    foreach my $this_method_link_species_set (@{$method_link_species_set_adaptor->fetch_all_by_GenomeDB($this_genome_db)}) {
      $method_link_species_sets->{$this_method_link_species_set->method_link_id}->
          {join("-", sort map {$_->name} @{$this_method_link_species_set->species_set})} = $this_method_link_species_set;
    }
  }

  print "List of Bio::EnsEMBL::Compara::MethodLinkSpeciesSet to update:\n";
  foreach my $this_method_link_id (sort {$a <=> $b} keys %$method_link_species_sets) {
    last if ($this_method_link_id > 200); # Avoid non-genomic method_link_species_set
    foreach my $this_method_link_species_set (values %{$method_link_species_sets->{$this_method_link_id}}) {
      printf "%8d: ", $this_method_link_species_set->dbID,;
      print $this_method_link_species_set->method_link_type, " (",
          join(",", map {$_->name} @{$this_method_link_species_set->species_set}), ")\n";
    }
  }

}
