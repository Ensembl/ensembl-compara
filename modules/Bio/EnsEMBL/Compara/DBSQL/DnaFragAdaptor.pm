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
  my $dnafrag = $self->_objs_from_sth( $sth )->[0];
  
  if( !defined $dnafrag ) {
    $self->throw("No dnafrag with this dbID $dbid");
  }

  return $dnafrag;
}




=head2 _dna_frag_types

  Arg [1]    : none
  Example    : if($self->_dna_frag_types->{$type}) { do something }
  Description: returns a hashreference containing valid dna_frag types as keys
               and true values;
  Returntype : hasref
  Exceptions : none
  Caller     : general

=cut

sub _dna_frag_types {
  return {'RawContig'     => 1, 
	  'VirtualContig' => 1,
	  'Chromosome'    => 1};
}



=head2 fetch_all_by_GenomeDB_region

  Arg [1]    : Bio::EnsEMBL::Compara::GenomeDB $genome_db
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
  my ($self, $genome_db, $dna_frag_type, $name, $start, $end) = @_;
  
  unless($genome_db && ref $genome_db 
	 && $genome_db->isa('Bio::EnsEMBL::Compara::GenomeDB')) {
    $self->throw("fetch_all_by_species_region requires genome_db arg not ".
		 "[$genome_db]");
  }
  
  return 
    $self->fetch_all_by_species_region($self, $genome_db->species, 
				       $dna_frag_type, $name, $start, $end);
}



=head2 fetch_all_by_GenomeDB_region

  Arg [1]    : Bio::EnsEMBL::Compara::GenomeDB $genome_db
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

sub fetch_all_by_species_region {
  my ($self, $species, $dnafrag_type, $name, $start, $end) = @_;
 
  unless($species) {
    $self->throw("fetch_all_by_species_region requires species name argument");
  }

  $dnafrag_type = 'Chromosome' unless $dnafrag_type;

  unless($self->_dna_frag_types()->{$dnafrag_type}) {
    $self->throw("[$dnafrag_type] is not a valid dna_frag_type." .
		 "Valid types are:["
		 .join(', ', keys(%{$self->_dna_frag_types}))."]\n");
  }
 
  my $sql = 'SELECT d.genome_db_id, d.dnafrag_type, d.dnafrag_id, 
                    d.name, d.start, d.end
             FROM  dnafrag d, genome_db g
             WHERE d.type = ?
             AND   g.name = ?
             AND   d.genome_db_id = g.genome_db_id';

  my @bind_values = ($dnafrag_type, $species);

  if(defined $name) {
    $sql .= ' AND d.name = ?';
    push @bind_values, "$name";
  }

  if(defined $start) {
    $sql .= ' AND d.end >= ?';
    push @bind_values, $end;
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

   if( $dnafrag->adaptor() == $self ) {
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

   $sth->execute($gid, $type. $name, $dnafrag->start(), $dnafrag->end() );

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

   if( $dnafrag->adaptor() == $self ) {
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



####################################DEPRECATED#################################
####################################DEPRECATED#################################

=head2 fetch_by_species_chr_start_end

  Arg [1]    : none
  Example    : none
  Description: DEPRECATED use fetch_all_by_species_region instead
  Returntype : none
  Exceptions : none
  Caller     : none

=cut

sub fetch_by_species_chr_start_end {
  my ($self, @args) = @_;

  my ($f, $p, $l) = caller;
  $self->warn("fetch_by_species_chr_start_end is replaced with " .
              "fetch_all_by_species_region: $f,$p: $l\n");

  return $self->fetch_all_by_species_region(@args);
}




sub fetch_by_name_genomedb_id{
  my ($self,$name,$genomedb_id) = @_;
  
  if( !defined $name) {
    $self->throw("fetch_by_name_genomedb_id requires dnafrag name");
  }
  
  if( !defined $genomedb_id) {
    $self->throw("fetch_by_name_genomedb_id requires genomedb_id");
  }
  
  my $sth = $self->prepare("
   SELECT genome_db_id, dnafrag_type, dnafrag_id, 
          name, start, end
     FROM dnafrag 
    WHERE name = ? 
      AND genome_db_id = ?
  ");

  $sth->execute($name,$genomedb_id);
  my $dnafrag = $self->_objs_from_sth( $sth )->[0];
  
  if( !defined $dnafrag ) {
    $self->throw("No dnafrag with this name $name and genomedb $genomedb_id");
  }

  return $dnafrag;
}




sub fetch_all_by_genomedb_position {
  my ( $self, $genome_db, $name, $start, $end ) = @_;

  my ($f, $p, $l) = caller;
  $self->warn("fetch_all_by_genomedb_position:" . 
       "use fetch_all_by_GenomeDB_region instead caller=$f, $p, $l\n");
  
  my $sql = "
   SELECT genome_db_id, dnafrag_type, dnafrag_id, 
          name, start, end
     FROM dnafrag 
    WHERE name = ? 
      AND genome_db_id = ?
  ";

  if( defined $end ) {
    $sql .= "
      AND end >= ?
      AND start <= ?
    ";
  }

  my $sth = $self->prepare( $sql );
  if( defined $end ) {
    $sth->execute( $name, $genome_db->dbID(), $start, $end );
  } else {
    $sth->execute(  $name, $genome_db->dbID() );
  }

  $self->_objs_from_sth( $sth );
}


1;
