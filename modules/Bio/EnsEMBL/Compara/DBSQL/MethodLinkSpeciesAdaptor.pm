# Copyright EnsEMBL 2004
#
# Ensembl module for Bio::EnsEMBL::DBSQL::MethodLinkSpeciesAdaptor
# 
# POD documentation - main docs before the code
# 

=head1 NAME

Bio::EnsEMBL::DBSQL::MethodLinkSpeciesAdaptor

=head1 SYNOPSIS

  use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor; 
  my $db = new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor (
      -host => $host,
      -user => $dbuser,
      -pass => $dbpass,
      -port => $port,
      -dbname => $dbname,
      -conf_file => $conf_file);
  
  my $mlsa = $db->get_MethodLinkSpeciesAdaptor();

  $mlsa->store($method_link_species);

  my $method_link_species = $mlsa->fetch_all;
  
  my $method_link_species = $mlsa->fetch_by_dbID(1);
  
  my $method_link_species = $mlsa->fetch_all_by_method_link(3);
  my $method_link_species = $mlsa->fetch_all_by_method_link("BLASTZ_NET");
  my $method_link_species = $mlsa->fetch_all_by_method_link_id(3);
  my $method_link_species = $mlsa->fetch_all_by_method_link_type("BLASTZ_NET");
  
  my $method_link_species = $mlsa->fetch_all_by_genome_db_id(12);
  
  my $method_link_species = $mlsa->fetch_by_method_link_and_genome_db_ids(
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


package Bio::EnsEMBL::Compara::DBSQL::MethodLinkSpeciesAdaptor;
use vars qw(@ISA);
use strict;

use Bio::EnsEMBL::DBSQL::BaseAdaptor;
use Bio::EnsEMBL::Compara::MethodLinkSpecies;

@ISA = qw(Bio::EnsEMBL::DBSQL::BaseAdaptor  Bio::EnsEMBL::Compara::DBSQL::DBAdaptor);


sub new {
  my $class = shift;

  my $self = $class->SUPER::new(@_);

  return $self;
}


=head2 store

  Arg  1     : Bio::EnsEMBL::Compara::MethodLinkSpecies object
  Example    : $mlsa->store($method_link_species)
  Description: Stores a Bio::EnsEMBL::Compara::MethodLinkSpecies object into
               the database if it does not exist yet.
  Returntype : Bio::EnsEMBL::Compara::MethodLinkSpecies object
  Exceptions : Thrown if the argument is not a
               Bio::EnsEMBL::Compara::MethodLinkSpecies
  Caller     : 

=cut

sub store {
  my ($self, $method_link_species) = @_;
  my $sth;  

  $self->throw("method_link_species must be a Bio::EnsEMBL::Compara::MethodLinkSpecies\n")
    unless $method_link_species->isa("Bio::EnsEMBL::Compara::MethodLinkSpecies"); 
  
  my $method_link_sql = qq{SELECT 1 FROM method_link WHERE method_link_id = ?};
  
  my $method_link_species_sql = qq{
		INSERT INTO method_link_species (
			method_link_species_set,
			method_link_id,
			genome_db_id)
		VALUES (?, ?, ?)
	};

  my $method_link_id = $method_link_species->method_link_id;
  my $species_set = $method_link_species->species_set;
  my $method_link_species_set;

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

  ($method_link_species_set) = $sth->fetchrow_array();
  
  if (!$method_link_species_set) {
    $sth = $self->prepare($method_link_species_sql);
    foreach my $genome_db_id (@genome_db_ids) {
      $sth->execute($method_link_species_set, $method_link_id, $genome_db_id);
      $method_link_species_set = $sth->{'mysql_insertid'} if (!defined($method_link_species_set));
    }
  }
  $method_link_species->dbID($method_link_species_set);
  
  return $method_link_species;
}


=head2 fetch_all

  Arg  1     : none
  Example    : my $method_link_species = $mlsa->fetch_all
  Description: Retrieve all possible Bio::EnsEMBL::Compara::MethodLinkSpecies
               objects
  Returntype : listref of Bio::EnsEMBL::Compara::MethodLinkSpecies object
  Exceptions : none
  Caller     : 

=cut

sub fetch_all {
  my ($self) = @_;
  my $method_link_species = [];
  
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
    push(@{$all_method_link_species->{$method_link_species_set}->{'SPECIES_SET'}}, $gdba->fetch_by_dbID($genome_db_id));
  }
  
  foreach my $method_link_species_set (keys %$all_method_link_species) {
    my $this_method_link_species = new Bio::EnsEMBL::Compara::MethodLinkSpecies(
			-adaptor => $self,
			-dbID => $method_link_species_set,
			-method_link_id => $all_method_link_species->{$method_link_species_set}->{'METHOD_LINK_ID'},
			-method_link_type => $all_method_link_species->{$method_link_species_set}->{'METHOD_LINK_TYPE'},
			-species_set => $all_method_link_species->{$method_link_species_set}->{'SPECIES_SET'}
		);
    push(@$method_link_species, $this_method_link_species);
  }

  return $method_link_species;
}


=head2 fetch_by_dbID

  Arg  1     : integer $method_link_species_set
  Example    : my $method_link_species = $mlsa->fetch_by_dbID(1)
  Description: Retrieve the correspondig
               Bio::EnsEMBL::Compara::MethodLinkSpecies object
  Returntype : Bio::EnsEMBL::Compara::MethodLinkSpecies object
  Exceptions : Returns undef if no matching
               Bio::EnsEMBL::Compara::MethodLinkSpecies object can be retrieved
  Caller     : none

=cut

sub fetch_by_dbID {
  my ($self, $dbID) = @_;
  my $method_link_species; # returned object
  
  my $gdba = $self->get_GenomeDBAdaptor;
  my $sql = qq{
		SELECT method_link_species_set, method_link_species.method_link_id, genome_db_id, type
		FROM method_link_species
		LEFT JOIN method_link USING (method_link_id)
		WHERE method_link_species_set = ?
	};

  my $sth = $self->prepare($sql);
  $sth->execute($dbID);
  
  my $this_method_link_species;
  
  ## Get all rows corresponding to this method_link_species_set
  while (my ($method_link_species_set, $method_link_id, $genome_db_id, $type) = $sth->fetchrow_array()) {
    $this_method_link_species->{'METHOD_LINK_ID'} = $method_link_id;
    $this_method_link_species->{'METHOD_LINK_TYPE'} = $type;
    push(@{$this_method_link_species->{'SPECIES_SET'}}, $gdba->fetch_by_dbID($genome_db_id));
  }
  
  return undef if (!defined($this_method_link_species));
  
  ## Create the object
  $method_link_species = new Bio::EnsEMBL::Compara::MethodLinkSpecies(
			-adaptor => $self,
			-dbID => $dbID,
			-method_link_id => $this_method_link_species->{'METHOD_LINK_ID'},
			-method_link_type => $this_method_link_species->{'METHOD_LINK_TYPE'},
			-species_set => $this_method_link_species->{'SPECIES_SET'}
		);

  return $method_link_species;
}


=head2 fetch_all_by_method_link

  Arg  1     : string method_link_type
                       - or -
               integer method_link_id
  Example    : my $method_link_species = $mlsa->fetch_all_by_method_link(3)
  Example    : my $method_link_species =
                     $mlsa->fetch_all_by_method_link("BLASTZ_NET")
  Description: Retrieve all the Bio::EnsEMBL::Compara::MethodLinkSpecies objects
               corresponding to the given method_link
  Returntype : listref of Bio::EnsEMBL::Compara::MethodLinkSpecies objects
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
  Example    : my $method_link_species = $mlsa->fetch_all_by_method_link_id(3)
  Description: Retrieve all the Bio::EnsEMBL::Compara::MethodLinkSpecies objects
               corresponding to the given method_link_id
  Returntype : listref of Bio::EnsEMBL::Compara::MethodLinkSpecies objects
  Exceptions : none
  Caller     : 

=cut

sub fetch_all_by_method_link_id {
  my ($self, $method_link_id) = @_;
  my $method_link_species = [];
  
  my $sql = qq{
		SELECT method_link_species_set, method_link_species.method_link_id, genome_db_id, type
		FROM method_link_species
		LEFT JOIN method_link USING (method_link_id)
		WHERE method_link.method_link_id = ?
	};

  my $sth = $self->prepare($sql);
  $sth->execute($method_link_id);
  my $all_method_link_species;
  my $gdba = $self->get_GenomeDBAdaptor;
  
  while (my ($method_link_species_set, $method_link_id, $genome_db_id, $type) = $sth->fetchrow_array()) {
    $all_method_link_species->{$method_link_species_set}->{'METHOD_LINK_ID'} = $method_link_id;
    $all_method_link_species->{$method_link_species_set}->{'METHOD_LINK_TYPE'} = $type;
    push(@{$all_method_link_species->{$method_link_species_set}->{'SPECIES_SET'}}, $gdba->fetch_by_dbID($genome_db_id));
  }
  
  foreach my $method_link_species_set (keys %$all_method_link_species) {
    my $this_method_link_species = new Bio::EnsEMBL::Compara::MethodLinkSpecies(
			-adaptor => $self,
			-dbID => $method_link_species_set,
			-method_link_id => $all_method_link_species->{$method_link_species_set}->{'METHOD_LINK_ID'},
			-method_link_type => $all_method_link_species->{$method_link_species_set}->{'METHOD_LINK_TYPE'},
			-species_set => $all_method_link_species->{$method_link_species_set}->{'SPECIES_SET'}
		);
    push(@$method_link_species, $this_method_link_species);
  }

  return $method_link_species;
}


=head2 fetch_all_by_method_link_type

  Arg  1     : string method_link_type
  Example    : my $method_link_species =
                     $mlsa->fetch_all_by_method_link_type("BLASTZ_NET")
  Description: Retrieve all the Bio::EnsEMBL::Compara::MethodLinkSpecies objects
               corresponding to the given method_link_type
  Returntype : listref of Bio::EnsEMBL::Compara::MethodLinkSpecies objects
  Exceptions : none
  Caller     : 

=cut

sub fetch_all_by_method_link_type {
  my ($self, $method_link_type) = @_;
  my $method_link_species = [];
  
  my $sql = qq{
		SELECT method_link_species_set, method_link_species.method_link_id, genome_db_id, type
		FROM method_link_species
		LEFT JOIN method_link USING (method_link_id)
		WHERE method_link.type = ?
	};

  my $sth = $self->prepare($sql);
  $sth->execute($method_link_type);
  my $all_method_link_species;
  my $gdba = $self->get_GenomeDBAdaptor;
  
  while (my ($method_link_species_set, $method_link_id, $genome_db_id, $type) = $sth->fetchrow_array()) {
    $all_method_link_species->{$method_link_species_set}->{'METHOD_LINK_ID'} = $method_link_id;
    $all_method_link_species->{$method_link_species_set}->{'METHOD_LINK_TYPE'} = $type;
    push(@{$all_method_link_species->{$method_link_species_set}->{'SPECIES_SET'}}, $gdba->fetch_by_dbID($genome_db_id));
  }
  
  foreach my $method_link_species_set (keys %$all_method_link_species) {
    my $this_method_link_species = new Bio::EnsEMBL::Compara::MethodLinkSpecies(
			-adaptor => $self,
			-dbID => $method_link_species_set,
			-method_link_id => $all_method_link_species->{$method_link_species_set}->{'METHOD_LINK_ID'},
			-method_link_type => $all_method_link_species->{$method_link_species_set}->{'METHOD_LINK_TYPE'},
			-species_set => $all_method_link_species->{$method_link_species_set}->{'SPECIES_SET'}
		);
    push(@$method_link_species, $this_method_link_species);
  }

  return $method_link_species;
}


=head2 fetch_all_by_genome_db_id

  Arg  1     : integer $genome_db_id
  Example    : my $method_link_species = $mlsa->fetch_all_by_genome_db_id(12)
  Description: Retrieve all the Bio::EnsEMBL::Compara::MethodLinkSpecies objects
               which includes the genome defined by the genome_db_id in the
               species_set
  Returntype : listref of Bio::EnsEMBL::Compara::MethodLinkSpecies objects
  Exceptions : none
  Caller     : 

=cut

sub fetch_all_by_genome_db_id {
  my ($self, $genome_db_id) = @_;
  my $method_link_species = [];
   
  my $all_method_link_species = $self->fetch_all;

  foreach my $this_method_link_species (@$all_method_link_species) {
    foreach my $this_genome_db (@{$this_method_link_species->species_set}) {
      if ($this_genome_db->dbID == $genome_db_id) {
        push (@$method_link_species, $this_method_link_species);
        last;
      }
    }
  }

  return $method_link_species;
}


=head2 fetch_by_method_link_and_genome_db_ids

  Arg  1     : string $method_link_type
                       - or -
               integer $method_link_id
  Arg 2      : listref of integers [$gdbid1, $gdbid2, $gdbid3]
  Example    : my $method_link_species =
                   $mlsa->fetch_by_method_link_and_genome_db_ids("MULTIZ",
                       [1, 2, 3])
  Description: Retrieve the Bio::EnsEMBL::Compara::MethodLinkSpecies object
               corresponding to the given method_link and the given set of
               genomes
  Returntype : Bio::EnsEMBL::Compara::MethodLinkSpecies object
  Exceptions : Returns undef if no Bio::EnsEMBL::Compara::MethodLinkSpecies
               object is found
  Caller     : 

=cut

sub fetch_by_method_link_and_genome_db_ids {
  my ($self, $method_link, $genome_db_ids) = @_;
  my @genome_db_ids = sort {$a <=> $b} @$genome_db_ids; # sort all genome_db_ids
  my $method_link_species;
   
  my $all_method_link_species = $self->fetch_all_by_method_link($method_link);

  foreach my $this_method_link_species (@$all_method_link_species) {
    my $is_equal = 1;
    
    ## Retrieve all the genome_db_ids and sort them
    my @those_genome_db_ids;
    foreach my $this_genome_db (@{$this_method_link_species->species_set}) {
      push(@those_genome_db_ids, $this_genome_db->dbID);
    }
    @those_genome_db_ids = sort(@those_genome_db_ids);

    ## Compare size of sets
    if (scalar(@those_genome_db_ids) != scalar(@genome_db_ids)) {
      $is_equal = 0;
    
    ## Compare all genome_db_ids
    } else {
      for (my $i=0; $i<@genome_db_ids; $i++) {
        if ($those_genome_db_ids[$i] != $genome_db_ids[$i] ) {
          $is_equal = 0;
	  last;
	}
      }
    }
  
    if ($is_equal) {
      return $this_method_link_species;
    }
  }

  return undef;
}


=head2 _get_method_link_type_from_id

  Arg  1     : none
  Example    : my $method_link_type =
                     $meth_lnk_spc->_get_method_link_type_from_id()
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
  Example    : my $method_link_id =
                     $meth_lnk_spc->_get_method_link_id_from_type()
  Description: Retrieve method_link_id corresponding to the method_link_type
  Returntype : integer $method_link_id
  Exceptions : none
  Caller     : 

=cut

sub _get_method_link_id_from_type {
  my ($self) = @_;
  my $dbID; # returned integer
  
  my $sql = qq{
		SELECT method_link_id
		FROM method_link
		WHERE type = ?
	};

  my $sth = $self->prepare($sql);
  $sth->execute($self->method_link_type);
  
  $dbID = $sth->fetchrow_array();

  return $self->method_link_id($dbID);
}


1;
