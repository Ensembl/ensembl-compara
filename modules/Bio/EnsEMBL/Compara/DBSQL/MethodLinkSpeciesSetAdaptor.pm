# Copyright EnsEMBL 2004
#
# Ensembl module for Bio::EnsEMBL::DBSQL::MethodLinkSpeciesAdaptor
# 
# POD documentation - main docs before the code
# 

=head1 NAME

Bio::EnsEMBL::DBSQL::MethodLinkSpeciesSetAdaptor

=head1 SYNOPSIS

  use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor; 
  my $db = new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor (
      -host => $host,
      -user => $dbuser,
      -pass => $dbpass,
      -port => $port,
      -dbname => $dbname,
      -conf_file => $conf_file);
  
  my $mlssa = $db->get_MethodLinkSpeciesSetAdaptor();

  $mlssa->store($method_link_species);

  my $method_link_species = $mlssa->fetch_all;
  
  my $method_link_species = $mlssa->fetch_by_dbID(1);
  
  my $method_link_species = $mlssa->fetch_all_by_method_link(3);
  my $method_link_species = $mlssa->fetch_all_by_method_link("BLASTZ_NET");
  my $method_link_species = $mlssa->fetch_all_by_method_link_id(3);
  my $method_link_species = $mlssa->fetch_all_by_method_link_type("BLASTZ_NET");
  
  my $method_link_species = $mlssa->fetch_all_by_genome_db_id(12);
  
  my $method_link_species = $mlssa->fetch_by_method_link_and_genome_db_ids(
        "MULTIZ", [$gdbid1, $gdbid2, $gdbid3]);
  
=head1 DESCRIPTION

Describe the object here

=head1 AUTHOR

Javier Herrero (jherrero@ebi.ac.uk)

This modules is part of the Ensembl project http://www.ensembl.org

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut


# Let the code begin...


package Bio::EnsEMBL::Compara::DBSQL::MethodLinkSpeciesSetAdaptor;
use vars qw(@ISA);
use strict;

use Bio::EnsEMBL::Compara::MethodLinkSpeciesSet;

@ISA = qw(Bio::EnsEMBL::DBSQL::BaseAdaptor Bio::EnsEMBL::Compara::DBSQL::DBAdaptor);


sub new {
  my $class = shift;

  my $self = $class->SUPER::new(@_);

  return $self;
}


=head2 store

  Arg  1     : Bio::EnsEMBL::Compara::MethodLinkSpeciesSet object
  Example    : $mlssa->store($method_link_species_set)
  Description: Stores a Bio::EnsEMBL::Compara::MethodLinkSpeciesSet object into
               the database if it does not exist yet.
  Returntype : Bio::EnsEMBL::Compara::MethodLinkSpeciesSet object
  Exception  : Thrown if the argument is not a
               Bio::EnsEMBL::Compara::MethodLinkSpeciesSet object
  Exception  : Thrown if the corresponding method_link is not in the 
               database
  Caller     : 

=cut

sub store {
  my ($self, $method_link_species_set) = @_;
  my $sth;  

  $self->throw("method_link_species_set must be a Bio::EnsEMBL::Compara::MethodLinkSpeciesSet\n")
    unless $method_link_species_set->isa("Bio::EnsEMBL::Compara::MethodLinkSpeciesSet");

  my $method_link_sql = qq{SELECT 1 FROM method_link WHERE method_link_id = ?};
  
  my $method_link_species_sql = qq{
		INSERT INTO method_link_species (
			method_link_species_set,
			method_link_id,
			genome_db_id)
		VALUES (?, ?, ?)
	};

  my $method_link_id = $method_link_species_set->method_link_id;
  my $species_set = $method_link_species_set->species_set;

  ## Checks if method_link_id already exists in the database
  $sth = $self->prepare($method_link_sql);
  $sth->execute($method_link_id);
  if (!$sth->fetchrow_array) {
    $self->throw("method_link_id $method_link_id is not in the database!\n");
  }

  ## Fetch genome_db_ids from Bio::EnsEMBL::Compara::GenomeDB objects
  my @genome_db_ids;
  foreach my $species (@$species_set) {
    push(@genome_db_ids, $species->dbID);
  }

  $sth = $self->prepare(qq{
		SELECT
		  method_link_species_set, COUNT(*) as count
		FROM
			method_link_species
		WHERE
			genome_db_id in (}.join(",", @genome_db_ids).qq{)
			AND method_link_id = $method_link_id
		GROUP BY method_link_species_set
		HAVING count = }.scalar(@genome_db_ids));
  $sth->execute();

  my ($dbID) = $sth->fetchrow_array();
  
  if (!$dbID) {
    $sth = $self->prepare($method_link_species_sql);
    foreach my $genome_db_id (@genome_db_ids) {
      $sth->execute("NULL", $method_link_id, $genome_db_id);
      $dbID = $sth->{'mysql_insertid'};
    }
  }
  $method_link_species_set->dbID($dbID);
  
  return $method_link_species_set;
}


=head2 fetch_all

  Arg  1     : none
  Example    : my $method_link_species_sets = $mlssa->fetch_all
  Description: Retrieve all possible Bio::EnsEMBL::Compara::MethodLinkSpeciesSet
               objects
  Returntype : listref of Bio::EnsEMBL::Compara::MethodLinkSpeciesSet objects
  Exceptions : none
  Caller     : 

=cut

sub fetch_all {
  my ($self) = @_;
  my $method_link_species_sets = [];
  
  my $sql = qq{
		SELECT method_link_species_set, method_link_species.method_link_id, genome_db_id, type
		FROM method_link_species
		LEFT JOIN method_link USING (method_link_id)
	};

  my $sth = $self->prepare($sql);
  $sth->execute();
  my $all_method_link_species;
  my $gdba = $self->get_GenomeDBAdaptor;
  
  while (my ($method_link_species_set, $method_link_id, $genome_db_id, $type) = $sth->fetchrow_array()) {
    $all_method_link_species->{$method_link_species_set}->{'METHOD_LINK_ID'} = $method_link_id;
    $all_method_link_species->{$method_link_species_set}->{'METHOD_LINK_TYPE'} = $type;
    push(@{$all_method_link_species->{$method_link_species_set}->{'SPECIES_SET'}},
        $gdba->fetch_by_dbID($genome_db_id));
  }
  
  foreach my $method_link_species_set (keys %$all_method_link_species) {
    my $this_method_link_species = new Bio::EnsEMBL::Compara::MethodLinkSpeciesSet(
			-adaptor => $self,
			-dbID => $method_link_species_set,
			-method_link_id =>
                            $all_method_link_species->{$method_link_species_set}->{'METHOD_LINK_ID'},
			-method_link_type =>
                            $all_method_link_species->{$method_link_species_set}->{'METHOD_LINK_TYPE'},
			-species_set =>
                            $all_method_link_species->{$method_link_species_set}->{'SPECIES_SET'}
		);
    push(@$method_link_species_sets, $this_method_link_species);
  }

  return $method_link_species_sets;
}


=head2 fetch_by_dbID

  Arg  1     : integer $method_link_species_set
  Example    : my $method_link_species_set = $mlssa->fetch_by_dbID(1)
  Description: Retrieve the correspondig
               Bio::EnsEMBL::Compara::MethodLinkSpeciesSet object
  Returntype : Bio::EnsEMBL::Compara::MethodLinkSpeciesSet object
  Exceptions : Returns undef if no matching
               Bio::EnsEMBL::Compara::MethodLinkSpeciesSet object can be retrieved
  Caller     : none

=cut

sub fetch_by_dbID {
  my ($self, $dbID) = @_;
  my $method_link_species_set; # returned object
  
  my $gdba = $self->get_GenomeDBAdaptor;
  my $sql = qq{
		SELECT method_link_species_set, method_link_species.method_link_id, genome_db_id, type
		FROM method_link_species
		LEFT JOIN method_link USING (method_link_id)
		WHERE method_link_species_set = ?
	};

  my $sth = $self->prepare($sql);
  $sth->execute($dbID);
  
  my $this_method_link_species_set;
  
  ## Get all rows corresponding to this method_link_species_setmodules/Bio/EnsEMBL/Compara/DBSQL/MethodLinkSpeciesSetAdaptor.pm
  while (my ($method_link_species_set, $method_link_id, $genome_db_id, $type) = $sth->fetchrow_array()) {
    $this_method_link_species_set->{'METHOD_LINK_ID'} = $method_link_id;
    $this_method_link_species_set->{'METHOD_LINK_TYPE'} = $type;
    push(@{$this_method_link_species_set->{'SPECIES_SET'}}, $gdba->fetch_by_dbID($genome_db_id));
  }
  
  return undef if (!defined($this_method_link_species_set));
  
  ## Create the object
  $method_link_species_set = new Bio::EnsEMBL::Compara::MethodLinkSpeciesSet(
			-adaptor => $self,
			-dbID => $dbID,
			-method_link_id => $this_method_link_species_set->{'METHOD_LINK_ID'},
			-method_link_type => $this_method_link_species_set->{'METHOD_LINK_TYPE'},
			-species_set => $this_method_link_species_set->{'SPECIES_SET'}
		);

  return $method_link_species_set;
}


=head2 fetch_all_by_method_link

  Arg  1     : string method_link_type
                       - or -
               integer method_link_id
  Example    : my $method_link_species_set = $mlssa->fetch_all_by_method_link(3)
  Example    : my $method_link_species_set =
                     $mlssa->fetch_all_by_method_link("BLASTZ_NET")
  Description: Retrieve all the Bio::EnsEMBL::Compara::MethodLinkSpeciesSet objects
               corresponding to the given method_link
  Returntype : listref of Bio::EnsEMBL::Compara::MethodLinkSpeciesSet objects
  Exceptions : none
  Caller     : 

=cut

sub fetch_all_by_method_link {
  my ($self, $method_link) = @_;

  if ($method_link =~ /^\d+$/) {
    return $self->fetch_all_by_method_link_id($method_link);
  } else {
    return $self->fetch_all_by_method_link_type($method_link);
  }
}


=head2 fetch_all_by_method_link_id

  Arg  1     : integer method_link_id
  Example    : my $method_link_species_set = $mlssa->fetch_all_by_method_link_id(3)
  Description: Retrieve all the Bio::EnsEMBL::Compara::MethodLinkSpeciesSet objects
               corresponding to the given method_link_id
  Returntype : listref of Bio::EnsEMBL::Compara::MethodLinkSpeciesSet objects
  Exceptions : none
  Caller     : 

=cut

sub fetch_all_by_method_link_id {
  my ($self, $method_link_id) = @_;
  my $method_link_species_sets = [];
  
  my $sql = qq{
		SELECT method_link_species_set, method_link_species.method_link_id, genome_db_id, type
		FROM method_link_species
		LEFT JOIN method_link USING (method_link_id)
		WHERE method_link.method_link_id = ?
	};

  my $sth = $self->prepare($sql);
  $sth->execute($method_link_id);
  my $all_method_link_species_sets;
  my $gdba = $self->get_GenomeDBAdaptor;
  
  while (my ($method_link_species_set, $method_link_id, $genome_db_id, $type) = $sth->fetchrow_array()) {
    $all_method_link_species_sets->{$method_link_species_set}->{'METHOD_LINK_ID'} = $method_link_id;
    $all_method_link_species_sets->{$method_link_species_set}->{'METHOD_LINK_TYPE'} = $type;
    push(@{$all_method_link_species_sets->{$method_link_species_set}->{'SPECIES_SET'}},
        $gdba->fetch_by_dbID($genome_db_id));
  }

  foreach my $method_link_species_set (keys %$all_method_link_species_sets) {
    my $this_method_link_species_set = new Bio::EnsEMBL::Compara::MethodLinkSpeciesSet(
			-adaptor => $self,
			-dbID => $method_link_species_set,
			-method_link_id =>
                            $all_method_link_species_sets->{$method_link_species_set}->{'METHOD_LINK_ID'},
			-method_link_type =>
                            $all_method_link_species_sets->{$method_link_species_set}->{'METHOD_LINK_TYPE'},
			-species_set =>
                            $all_method_link_species_sets->{$method_link_species_set}->{'SPECIES_SET'}
		);
    push(@$method_link_species_sets, $this_method_link_species_set);
  }

  return $method_link_species_sets;
}


=head2 fetch_all_by_method_link_type

  Arg  1     : string method_link_type
  Example    : my $method_link_species_sets =
                     $mlssa->fetch_all_by_method_link_type("BLASTZ_NET")
  Description: Retrieve all the Bio::EnsEMBL::Compara::MethodLinkSpeciesSet objects
               corresponding to the given method_link_type
  Returntype : listref of Bio::EnsEMBL::Compara::MethodLinkSpeciesSet objects
  Exceptions : none
  Caller     : 

=cut

sub fetch_all_by_method_link_type {
  my ($self, $method_link_type) = @_;
  my $method_link_species_sets = [];
  
  my $sql = qq{
		SELECT method_link_species_set, method_link_species.method_link_id, genome_db_id, type
		FROM method_link_species
		LEFT JOIN method_link USING (method_link_id)
		WHERE method_link.type = ?
	};

  my $sth = $self->prepare($sql);
  $sth->execute($method_link_type);
  my $all_method_link_species_sets;
  my $gdba = $self->get_GenomeDBAdaptor;
  
  while (my ($method_link_species_set, $method_link_id, $genome_db_id, $type) = $sth->fetchrow_array()) {
    $all_method_link_species_sets->{$method_link_species_set}->{'METHOD_LINK_ID'} = $method_link_id;
    $all_method_link_species_sets->{$method_link_species_set}->{'METHOD_LINK_TYPE'} = $type;
    push(@{$all_method_link_species_sets->{$method_link_species_set}->{'SPECIES_SET'}},
        $gdba->fetch_by_dbID($genome_db_id));
  }
  
  foreach my $method_link_species_set (keys %$all_method_link_species_sets) {
    my $this_method_link_species_set = new Bio::EnsEMBL::Compara::MethodLinkSpeciesSet(
			-adaptor => $self,
			-dbID => $method_link_species_set,
			-method_link_id =>
                            $all_method_link_species_sets->{$method_link_species_set}->{'METHOD_LINK_ID'},
			-method_link_type =>
                            $all_method_link_species_sets->{$method_link_species_set}->{'METHOD_LINK_TYPE'},
			-species_set =>
                            $all_method_link_species_sets->{$method_link_species_set}->{'SPECIES_SET'}
		);
    push(@$method_link_species_sets, $this_method_link_species_set);
  }

  return $method_link_species_sets;
}


=head2 fetch_all_by_genome_db_id

  Arg  1     : integer $genome_db_id
  Example    : my $method_link_species_sets = $mlssa->fetch_all_by_genome_db_id(12)
  Description: Retrieve all the Bio::EnsEMBL::Compara::MethodLinkSpeciesSet objects
               which includes the genome defined by the genome_db_id in the
               species_set
  Returntype : listref of Bio::EnsEMBL::Compara::MethodLinkSpeciesSet objects
  Exceptions : none
  Caller     : 

=cut

sub fetch_all_by_genome_db_id {
  my ($self, $genome_db_id) = @_;
  my $method_link_species_sets = [];
   
  my $all_method_link_species_sets = $self->fetch_all;

  foreach my $this_method_link_species_set (@$all_method_link_species_sets) {
    foreach my $this_genome_db (@{$this_method_link_species_set->species_set}) {
      if ($this_genome_db->dbID == $genome_db_id) {
        push (@$method_link_species_sets, $this_method_link_species_set);
        last;
      }
    }
  }

  return $method_link_species_sets;
}


=head2 fetch_by_method_link_and_genome_db_ids

  Arg  1     : string $method_link_type
                       - or -
               integer $method_link_id
  Arg 2      : listref of integers [$gdbid1, $gdbid2, $gdbid3]
  Example    : my $method_link_species_set =
                   $mlssa->fetch_by_method_link_and_genome_db_ids("MULTIZ",
                       [1, 2, 3])
  Description: Retrieve the Bio::EnsEMBL::Compara::MethodLinkSpeciesSet object
               corresponding to the given method_link and the given set of
               genomes
  Returntype : Bio::EnsEMBL::Compara::MethodLinkSpeciesSet object
  Exceptions : Returns undef if no Bio::EnsEMBL::Compara::MethodLinkSpeciesSet
               object is found
  Caller     : 

=cut

sub fetch_by_method_link_and_genome_db_ids {
  my ($self, $method_link, $genome_db_ids) = @_;
  my $method_link_species_set;
   
  my $method_link_id;
  if ($method_link =~ /^\d+$/) {
    $method_link_id = $method_link;
  } else {
    $method_link_id = $self->_get_method_link_id_from_type($method_link);
  }
  
  my $sth = $self->prepare(qq{
		SELECT
		  method_link_species_set, COUNT(*) as count
		FROM
			method_link_species
		WHERE
			genome_db_id in (}.join(",", @$genome_db_ids).qq{)
			AND method_link_id = $method_link_id
		GROUP BY method_link_species_set
		HAVING count = }.scalar(@$genome_db_ids));
  $sth->execute();

  my ($dbID) = $sth->fetchrow_array();
  
  if ($dbID) {
    $method_link_species_set = $self->fetch_by_dbID($dbID);
  }

  return $method_link_species_set;
}


=head2 _get_method_link_type_from_id

  Arg  1     : none
  Example    : my $method_link_type = $mlssa->_get_method_link_type_from_id()
  Description: Retrieve method_link_type corresponding to the method_link_id
  Returntype : string $method_link_type
  Exceptions : none
  Caller     : 

=cut

sub _get_method_link_type_from_id {
  my ($self) = @_;
  my $type; # returned string
  
  my $sql = qq{
		SELECT type
		FROM method_link
		WHERE method_link_id = ?
	};

  my $sth = $self->prepare($sql);
  $sth->execute($self->method_link_id);
  
  $type = $sth->fetchrow_array();

  return $self->method_link_type($type);
}


=head2 _get_method_link_id_from_type

  Arg  1     : none
  Example    : my $method_link_id = $mlssa->_get_method_link_id_from_type()
  Description: Retrieve method_link_id corresponding to the method_link_type
  Returntype : integer $method_link_id
  Exceptions : none
  Caller     : 

=cut

sub _get_method_link_id_from_type {
  my ($self, $method_link_type) = @_;
  my $dbID; # returned integer
  
  my $sql = qq{
		SELECT method_link_id
		FROM method_link
		WHERE type = ?
	};

  my $sth = $self->prepare($sql);
  $sth->execute($method_link_type);
  
  $dbID = $sth->fetchrow_array();

  return $dbID;
}


1;
