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

# Object preamble - inherits from Bio::Root::RootI

use Bio::EnsEMBL::DBSQL::BaseAdaptor;
use Bio::EnsEMBL::Compara::DnaFrag;

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

  my $sth = $self->prepare("
    SELECT genome_db_id, dnafrag_type, dnafrag_id,
           name, start, end
      FROM dnafrag
     WHERE dnafrag_id = ?
  ");

  $sth->execute($dbid);

  my $dna_frags = $self->_objs_from_sth($sth);

  $self->throw("No dnafrag with this dbID $dbid") unless(@$dna_frags);

  return $dna_frags->[0];
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
  my ($self, $genome_db, $dnafrag_type, $name, $start, $end) = @_;

  unless($genome_db && ref $genome_db && 
	 $genome_db->isa('Bio::EnsEMBL::Compara::GenomeDB')) {
    $self->throw("genome_db arg must be Bio::EnsEMBL::Compara::GenomeDB".
		 " not [$genome_db]\n")
  }

  my $gdb_id = $genome_db->dbID;

  unless($gdb_id) {
    $self->throw('GenomeDB does not have a dbID. Is it stored in the db?');
  }

  unless($dnafrag_type) {
    $self->throw('dnafrag_type argument must be defined');
  }

  my $sql = 'SELECT d.genome_db_id, d.dnafrag_type, d.dnafrag_id,
                    d.name, d.start, d.end
             FROM  dnafrag d
             WHERE d.dnafrag_type = ?
             AND   d.genome_db_id = ?';

  my @bind_values = ($dnafrag_type, $gdb_id);

  if(defined $name) {
    $sql .= ' AND d.name = ?';
    push @bind_values, "$name";
  }

  if(defined $start) {
    $sql .= ' AND d.end >= ?';
    push @bind_values, $start;
  }

  if(defined $end) {
    $sql .= ' AND d.start <= ?';
    push @bind_values, $end;
  }

  my $sth = $self->db->prepare($sql);
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

sub fetch_all{
   my ($self) = @_;
 
   my $sth = $self->prepare( "
     SELECT genome_db_id, dnafrag_type, dnafrag_id, 
            name, start, end
       FROM dnafrag
   " );

   $sth->execute;
   return _objs_from_sth( $sth );
}


sub _objs_from_sth {
  my ( $self, $sth ) = @_;

  my $result = [];

  my ( $dbID, $dnafrag_type, $name, $start, $end, $genome_db_id );
  $sth->bind_columns
    ( \$genome_db_id,  \$dnafrag_type, \$dbID,
      \$name, \$start, \$end,  );
  my $gda = $self->db->get_GenomeDBAdaptor();

  while( $sth->fetch() ) {

    my $dnafrag = Bio::EnsEMBL::Compara::DnaFrag->new();

    $dnafrag->dbID( $dbID );
    $dnafrag->name( $name );
    $dnafrag->type( $dnafrag_type);
    $dnafrag->start( $start );
    $dnafrag->end( $end );
    $dnafrag->genomedb( $gda->fetch_by_dbID( $genome_db_id ));

    push( @$result, $dnafrag );
  }

  return $result;
}



=head2 store

 Title   : store
 Usage   :
 Function:
 Example :
 Returns :
 Args    :

=cut

sub store{
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

   my $gdb = $dnafrag->genomedb();

   if( !defined $gdb || !ref $gdb || !$gdb->isa('Bio::EnsEMBL::Compara::GenomeDB') ) {
       $self->throw("Must have genomedb attached to the dnafrag to store the dnafrag [$gdb]");
   }

   if( !defined $gdb->dbID ) {
       $self->throw("genomedb must be stored (no dbID). Store genomedb first");
   }

  if( !defined $dnafrag->name ) {
       $self->throw("dnafrag must have a name");
   }

   my $name = $dnafrag->name;
   my $gid =  $gdb->dbID;
   my $type = 'NULL';
   $type = $dnafrag->type if (defined $dnafrag->type);

   my $sth = $self->prepare("
     INSERT INTO dnafrag ( genome_db_id, dnafrag_type,
                           name, start, end )
     VALUES (?,?,?,?,?)");

   $sth->execute($gid, $type, $name, $dnafrag->start(), $dnafrag->end() );

   $dnafrag->dbID( $sth->{'mysql_insertid'} );
   $dnafrag->adaptor($self);

   return $dnafrag->dbID;
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

   if( !defined $dnafrag ) {
       $self->throw("Must store $dnafrag object");
   }

   if( !defined $dnafrag || !ref $dnafrag || !$dnafrag->isa('Bio::EnsEMBL::Compara::DnaFrag') ) {
       $self->throw("Must have dnafrag arg [$dnafrag]");
   }

   if (defined $dnafrag->adaptor() && $dnafrag->adaptor() == $self) {
     return $dnafrag->dbID();
   }
   
   my $gdb = $dnafrag->genomedb();

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
         AND start = ?
         AND end = ?
   ");

   unless ($sth->execute( $name, $gid, $dnafrag->start(), $dnafrag->end())) {
     $self->throw("Failed execution of a select query");
   }

   my ($dnafrag_id) = $sth->fetchrow_array();

   if (defined $dnafrag_id) {
     # $dnafrag already stored
     $dnafrag->dbID($dnafrag_id);
     $dnafrag->adaptor( $self );
     return $dnafrag_id;
   } else {
     $self->store($dnafrag);
   }
}

1;
