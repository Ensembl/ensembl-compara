#
# Ensembl module for Bio::EnsEMBL::Compara::DBSQL::DnaFragAdaptor
#
# Cared for by Ewan Birney <birney@ebi.ac.uk>
#
# Copyright Ewan Birney
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

Bio::EnsEMBL::Compara::DBSQL::DnaFragAdaptor - DESCRIPTION of Object

=head1 SYNOPSIS

Give standard usage here

=head1 DESCRIPTION

Describe the object here

=head1 AUTHOR - Ewan Birney

This modules is part of the Ensembl project http://www.ensembl.org

Email birney@ebi.ac.uk

Describe contact details here

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut


# Let the code begin...


package Bio::EnsEMBL::Compara::DBSQL::DnaFragAdaptor;

use vars qw(@ISA);

use strict;
use Bio::EnsEMBL::DBSQL::BaseAdaptor;
use Bio::EnsEMBL::Compara::DnaFrag;
use Bio::EnsEMBL::Utils::Exception qw( throw warning verbose );

@ISA = qw(Bio::EnsEMBL::DBSQL::BaseAdaptor);


=head2 fetch_by_dbID

 Title   : fetch_by_dbID
 Usage   :
 Function:
 Example :
 Returns : 
 Args    :

=cut

sub fetch_by_dbID {
  my ($self,$dbid) = @_;

  if( !defined $dbid) {
    $self->throw("Must fetch by dbid");
  }

  $self->{'_dna_frag_id_cache'} ||= {};

  if($self->{'_dna_frag_id_cache'}->{$dbid}) {
    return $self->{'_dna_frag_id_cache'}->{$dbid};
  }

  my $sth = $self->prepare(qq{
          SELECT
            dnafrag_id,
            length,
            name,
            genome_db_id,
            coord_system_name
          FROM
            dnafrag
          WHERE
            dnafrag_id = ?
      });

  $sth->execute($dbid);

  my $dna_frags = $self->_objs_from_sth($sth);

  $self->throw("No dnafrag with this dbID $dbid") unless(@$dna_frags);

  $self->{'_dna_frag_id_cache'}->{$dbid} = $dna_frags->[0];

  return $dna_frags->[0];
}



=head2 fetch_by_GenomeDB_and_name

  Arg [1]    : integer $genome_db_id
                  - or -
               Bio::EnsEMBL::Compara::DBSQL::GenomeDB
  Arg [2]    : string $name
  Example    : my $dnafrag = $dnafrag_adaptor->fetch_by_GenomeDB_and_name($human_genome_db, 'X');
  Example    : my $dnafrag = $dnafrag_adaptor->fetch_by_GenomeDB_and_name(1, 'X');
  Description: Returns the Bio::EnsEMBL::Compara::DnaFrag obejct corresponding to the
               Bio::EnsEMBL::Compara::GenomeDB and name given.
  Returntype : Bio::EnsEMBL::Compara::DnaFrag
  Exceptions : throw when genome_db_id cannot be retrieved
  Caller     : $dnafrag_adaptor->fetch_by_GenomeDB_and_name

=cut

sub fetch_by_GenomeDB_and_name {
  my ($self, $genome_db, $name) = @_;
  my $dnafrag; # Returned value
  
  my $genome_db_id;
  if ($genome_db =~ /^\d+$/) {
    $genome_db_id = $genome_db;
  } elsif ($genome_db && ref $genome_db && 
      $genome_db->isa('Bio::EnsEMBL::Compara::GenomeDB')) {
    $genome_db_id = $genome_db->dbID;
    if (!$genome_db_id) {
      throw("[$genome_db] does not have a dbID");
    }
  } else {
    throw("[$genome_db] must be Bio::EnsEMBL::Compara::GenomeDB\n");
  }

  my $sql = qq{
          SELECT
            dnafrag_id,
            length,
            name,
            genome_db_id,
            coord_system_name
          FROM
            dnafrag
          WHERE
            genome_db_id = ?
            AND name = ?
      };

  my $sth = $self->prepare($sql);
  $sth->execute($genome_db_id, $name);

  return $self->_objs_from_sth($sth)->[0];
}


=head2 fetch_all_by_GenomeDB_region

  Arg [1]    : Bio::EnsEMBL::Compara::DBSQL::GenomeDB
  Arg [2]    : (optional) string $dna_frag_type
  Arg [3]    : (optional) string $name
  Arg [4]    : (optional) int $start
  Arg [5]    : (optional) int $end
  Example    : 
  Description: 
  Returntype : 
  Exceptions : 
  Caller     : 

=cut

sub fetch_all_by_GenomeDB_region {
  my ($self, $genome_db, $coord_system_name, $name) = @_;

  unless($genome_db && ref $genome_db && 
	 $genome_db->isa('Bio::EnsEMBL::Compara::GenomeDB')) {
    $self->throw("genome_db arg must be Bio::EnsEMBL::Compara::GenomeDB".
		 " not [$genome_db]\n")
  }

  my $gdb_id = $genome_db->dbID;

  unless($gdb_id) {
    $self->throw('GenomeDB does not have a dbID. Is it stored in the db?');
  }

#  unless($dnafrag_type) {
#    $self->throw('dnafrag_type argument must be defined');
#  }

  my $sql = qq{
          SELECT
            dnafrag_id,
            length,
            name,
            genome_db_id,
            coord_system_name
          FROM
            dnafrag d
          WHERE
            genome_db_id = ?
      };

  my @bind_values = ($gdb_id);

  if(defined $coord_system_name) {
    $sql .= ' AND coord_system_name = ?';
    push @bind_values, "$coord_system_name";
  }

  if(defined $name) {
    $sql .= ' AND d.name = ?';
    push @bind_values, "$name";
  }

  my $sth = $self->prepare($sql);
  $sth->execute(@bind_values);

  return $self->_objs_from_sth($sth);
}


=head2 fetch_all

 Title   : fetch_all
 Usage   :
 Function:
 Example :
 Returns : 
 Args    :

=cut

sub fetch_all {
  my ($self) = @_;

  my $sth = $self->prepare(qq{
          SELECT
            dnafrag_id,
            length,
            name,
            genome_db_id,
            coord_system_name
          FROM
            dnafrag
      });

   $sth->execute;
   return $self->_objs_from_sth( $sth );
}


sub _objs_from_sth {
  my ($self, $sth) = @_;

  throw if (!$sth);

  my $these_dnafrags = [];

  my ($dbID, $length, $name, $genome_db_id, $coord_system_name);
  $sth->bind_columns(
          \$dbID,
          \$length,
          \$name,
          \$genome_db_id,
          \$coord_system_name
      );

  my $gda = $self->db->get_GenomeDBAdaptor();

  while ($sth->fetch()) {

    my $this_dnafrag = Bio::EnsEMBL::Compara::DnaFrag->new(
            -dbID => $dbID,
            -adaptor => $self,
            -length => $length,
            -name => $name,
            -genome_db_id => $genome_db_id,
            -coord_system_name => $coord_system_name
        );


    push(@$these_dnafrags, $this_dnafrag);
  }

  return $these_dnafrags;
}



=head2 store

 Arg [1]     : Bio::EnsEMBL::Compara::DnaFrag $new_dnafrag
 Example     : $dnafrag_adaptor->store($new_dnafrag)
 Description : Stores a Bio::EnsEMBL::Compara::DnaFrag object
               in the DB-
 ReturnType  : integer new_dnafrag_id
 Exceptions  : throw if $new_dnafrag is not a
               Bio::EnsEMBL::Compara::DnaFrag object
 Exceptions  : does not store anything if $new_dnafrag->adaptor is
               already defined and is equal to this adaptor
 Exceptions  : throw if $new_dnafrag->genome_db is not defined or has
               no dbID.
 Exceptions  : throw if $new_dnafrag has no name
 Caller      : $object->methodname

=cut

sub store {
   my ($self, $dnafrag) = @_;

   if( !defined $dnafrag ) {
       throw("Must store $dnafrag object");
   }

   if( !ref $dnafrag || !$dnafrag->isa('Bio::EnsEMBL::Compara::DnaFrag') ) {
       throw("Must have dnafrag arg [$dnafrag]");
   }

   if (defined $dnafrag->adaptor() && $dnafrag->adaptor() == $self) {
     return $dnafrag->dbID();
   }

   my $gdb = $dnafrag->genome_db();

   if( !defined $gdb || !ref $gdb || !$gdb->isa('Bio::EnsEMBL::Compara::GenomeDB') ) {
       $self->throw("Must have genomedb attached to the dnafrag to store the dnafrag [$gdb]");
   }

   if( !defined $gdb->dbID ) {
       throw("genomedb must be stored (no dbID). Store genomedb first");
   }

  if( !defined $dnafrag->name ) {
       throw("dnafrag must have a name");
   }

   my $name = $dnafrag->name;
   my $gid =  $gdb->dbID;
   my $type = $dnafrag->coord_system_name;

   my $sth = $self->prepare("
     INSERT INTO dnafrag ( genome_db_id, coord_system_name,
                           name, length )
     VALUES (?,?,?,?)");

   $sth->execute($gid, $type, $name, $dnafrag->length);

   $dnafrag->dbID( $sth->{'mysql_insertid'} );
   $dnafrag->adaptor($self);

   return $dnafrag->dbID;
}

=head2 is_already_stored

 Title   : is_already_stored
 Usage   : $self->is_already_stored($dnafrag)
 Function: checks if already stored by querying database
 Example :
 Returns : $dnafrag->dbID if stored and 0 if not stored
 Args    : Bio::EnsEMBL::Compara::DnaFrag object


=cut

sub is_already_stored {
   my ($self,$dnafrag) = @_;

   if( !defined $dnafrag ) {
       $self->throw("Must store $dnafrag object");
   }

   if( !defined $dnafrag || !ref $dnafrag || !$dnafrag->isa('Bio::EnsEMBL::Compara::DnaFrag') ) {
       $self->throw("Must have dnafrag arg [$dnafrag]");
   }

   if (defined $dnafrag->adaptor() && $dnafrag->adaptor() == $self) {
     return $dnafrag->dbID();
   }
   
   my $gdb = $dnafrag->genome_db();

   if( !defined $gdb || !ref $gdb || !$gdb->isa('Bio::EnsEMBL::Compara::GenomeDB') ) {
       $self->throw("Must have genomedb attached to the dnafrag to store the dnafrag [$gdb]");
   }


   if( !defined $gdb->dbID ) {
       $self->throw("genomedb must be stored (no dbID). Store genomedb first");
   }

   if( !defined $dnafrag->name ) {
       $self->throw("dna frag must have a name");
   }
   
   my $name = $dnafrag->name;
   my $gid =  $gdb->dbID;
   my $sth = $self->prepare("
      SELECT dnafrag_id 
        FROM dnafrag 
       WHERE name= ?
         AND genome_db_id= ?
   ");

   unless ($sth->execute( "$name", $gid )) {
     $self->throw("Failed execution of a select query");
   }

   my ($dnafrag_id) = $sth->fetchrow_array();

   if (defined $dnafrag_id) {
     # $dnafrag already stored
     $dnafrag->dbID($dnafrag_id);
     $dnafrag->adaptor( $self );
     return $dnafrag_id;
   } 
  return 0;
} 
   

=head2 store_if_needed

 Title   : store_if_needed
 Usage   : $self->store_if_needed($dnafrag)
 Function: store instance in the defined database if NOT
           already present.
 Example :
 Returns : $dnafrag->dbID
 Args    : Bio::EnsEMBL::Compara::DnaFrag object


=cut


sub store_if_needed {

   my ($self,$dnafrag) = @_;

   $self->store($dnafrag) unless($self->is_already_stored($dnafrag));
   return $dnafrag->dbID;
}

1;
