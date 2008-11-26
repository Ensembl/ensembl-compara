
#
# Ensembl module for Bio::EnsEMBL::Compara::DnaFrag.pm
#
# Cared for by Ewan Birney <birney@ebi.ac.uk>
#
# Copyright Ewan Birney
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

Bio::EnsEMBL::Compara::DnaFrag - Defines the DNA sequences used in the database.

=head1 SYNOPSIS

  use Bio::EnsEMBL::Compara::DnaFrag; 
  my $dnafrag = new Bio::EnsEMBL::Compara::DnaFrag(
          -dbID => 1,
          -adaptor => $dnafrag_adaptor,
          -length => 256,
          -name => "19",
          -genome_db => $genome_db,
          -coord_system_name => "chromosome"
        );


SET VALUES
  $dnafrag->dbID(1);
  $dnafrag->adaptor($dnafrag_adaptor);
  $dnafrag->length(256);
  $dnafrag->genome_db($genome_db);
  $dnafrag->genome_db_id(123);
  $dnafrag->coord_system_name("chromosome");
  $dnafrag->name("19");

GET VALUES
  $dbID = $dnafrag->dbID;
  $dnafrag_adaptor = $dnafrag->adaptor;
  $length = $dnafrag->length;
  $genome_db = $dnafrag->genome_db;
  $genome_db_id = $dnafrag->genome_db_id;
  $coord_system_name = $dnafrag->coord_system_name;
  $name = $dnafrag->name;

=head1 DESCRIPTION
The DnaFrag object stores information on the toplevel sequences such as the name, coordinate system, length and species.

=head1 OBJECT ATTRIBUTES

=over

=item dbID

corresponds to dnafrag.dnafrag_id

=item adaptor

Bio::EnsEMBL::Compara::DBSQL::DnaFragAdaptor object to access DB

=item length

corresponds to dnafrag.length

=item genome_db_id

corresponds to dnafrag.genome_db_id

=item genome_db

Bio::EnsEMBL::Compara::GenomeDB object corresponding to genome_db_id

=item coord_system_name

corresponds to dnafrag.coord_system_name

=item name

corresponds to dnafrag.name

=back

=head1 AUTHOR

Javier Herrero (jherrero@ebi.ac.uk)

=head1 CONTACT

This modules is part of the EnsEMBL project (http://www.ensembl.org)

Questions can be posted to the ensembl-dev mailing list:
ensembl-dev@ebi.ac.uk

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut


# Let the code begin...


package Bio::EnsEMBL::Compara::DnaFrag;

use strict;
use Bio::EnsEMBL::Utils::Exception qw(deprecate throw);
use Bio::EnsEMBL::Utils::Argument;

=head2 new

  Arg [-DBID] : (opt.) int $dbID (the database internal ID for this object)
  Arg [-ADAPTOR]
              : (opt.) Bio::EnsEMBL::Compara::DBSQL::DnaFragAdaptor $adaptor
                (the adaptor for connecting to the database)
  Arg [-LENGTH]:(opt.) int $length (the length of this dnafrag)
  Arg [-NAME]:  (opt.) string $name (the name of this dnafrag)
  Arg [-GENOME_DB]
               :(opt.) Bio::EnsEMBL::Compara::GenomeDB $genome_db (the 
                genome_db object representing the species of this dnafrag)
  Arg [-GENOME_DB_ID]
               :(opt.) int $genome_db_id (the database internal for the 
                 genome_db)
  Arg [-COORD_SYSTEM_NAME]
               :(opt.) string $coord_system_name (the name of the toplevel
                 coordinate system of the dnafrag eg 'chromosome', 'scaffold')
  Example : my $dnafrag = new Bio::EnsEMBL::Compara::DnaFrag(
                      -length 247249719,
                      -name "1",
                      -genome_db $genome_db,
                      -coord_system_name "chromosome");
  Example : my $dnafrag = new Bio::EnsEMBL::Compara::DnaFrag(
                      -length 247249719,
                      -name "1",
                      -genome_db_id 22,
                      -coord_system_name "chromosome");
  Description: Creates a new DnaFrag object
  Returntype : Bio::EnsEMBL::Compara::DnaFrag
  Exceptions : none
  Caller     : general
  Status     : Stable

=cut


sub new {
  my($class,@args) = @_;

  my $self = {};

  bless $self,$class;

#   my ($name,$contig,$genomedb,$type,$adaptor,$dbID) =
#     rearrange([qw(NAME CONTIG GENOMEDB TYPE ADAPTOR DBID)],@args);
#    if ( defined $contig) {
#      $self->contig($contig);
#    }

  my ($dbID, $adaptor, $length, $name, $genome_db, $genome_db_id, $coord_system_name,
          $start, $end, $genomedb, $type
      ) =
    rearrange([qw(DBID ADAPTOR LENGTH NAME GENOME_DB GENOME_DB_ID COORD_SYSTEM_NAME
            START END GENOMEDB TYPE
        )],@args);

  $self->dbID($dbID) if (defined($dbID));
  $self->adaptor($adaptor) if (defined($adaptor));
  $self->length($length) if (defined($length));
  $self->name($name) if (defined($name));
  $self->genome_db($genome_db) if (defined($genome_db));
  $self->genome_db_id($genome_db_id) if (defined($genome_db_id));
  $self->coord_system_name($coord_system_name) if (defined($coord_system_name));

  ###################################################################
  ## Support for backwards compatibility
  $self->start($start) if (defined($start));
  $self->end($end) if (defined($end));
  $self->genomedb($genomedb) if (defined($genomedb));
  $self->type($type) if (defined($type));
  ##
  ###################################################################

  return $self;
}

=head2 new_fast

  Arg [1]    : hash reference $hashref
  Example    : none
  Description: This is an ultra fast constructor which requires knowledge of
               the objects internals to be used.
  Returntype :
  Exceptions : none
  Caller     :
  Status     : Stable

=cut

sub new_fast {
  my $class = shift;
  my $hashref = shift;

  return bless $hashref, $class;
}

=head2 dbID

 Arg [1]   : int $dbID
 Example   : $dbID = $dnafrag->dbID()
 Example   : $dnafrag->dbID(1)
 Function  : get/set dbID attribute.
 Returns   : integer
 Exeption  : none
 Caller    : $object->dbID
 Status    : Stable

=cut

sub dbID {
  my ($self, $dbID) = @_;
   
  if (defined($dbID)) {
    $self->{'dbID'} = $dbID;
  }

  return $self->{'dbID'};
}


=head2 adpator

 Arg [1]   : Bio::EnsEMBL::Compara::DBSQL::DnaFragAdaptor $dnafrag_adaptor
 Example   : $dnafrag_adaptor = $dnafrag->adaptor()
 Example   : $dnafrag->adaptor($dnafrag_adaptor)
 Function  : get/set adaptor attribute.
 Returns   : Bio::EnsEMBL::Compara::DBSQL::DnaFragAdaptor object
 Exeption  : thrown if argument is not a Bio::EnsEMBL::Compara::DBSQL::DnaFragAdaptor
             object
 Caller    : $object->adaptor
 Status    : Stable

=cut

sub adaptor {
  my ($self, $adaptor) = @_;
   
  if (defined($adaptor)) {
    throw("[$adaptor] must be a Bio::EnsEMBL::Compara::DBSQL::DnaFragAdaptor object")
      unless ($adaptor->isa("Bio::EnsEMBL::Compara::DBSQL::DnaFragAdaptor"));
    $self->{'adaptor'} = $adaptor;
  }

  return $self->{'adaptor'};
}


=head2 length

 Arg [1]   : int $length
 Example   : $length = $dnafrag->length()
 Example   : $dnafrag->length(256)
 Function  : get/set length attribute. Use 0 as argument to reset this attribute.
 Returns   : integer
 Exeption  : none
 Caller    : $object->length
 Status    : Stable

=cut

sub length {
  my ($self, $length) = @_;
   
  if (defined($length)) {
    $self->{'length'} = ($length or undef);
  }

  return $self->{'length'};
}


=head2 name

 Arg [1]   : string $name
 Example   : $name = $dnafrag->name()
 Example   : $dnafrag->name("19")
 Function  : get/set name attribute. Use "" as argument to reset this attribute.
 Returns   : string
 Exeption  : none
 Caller    : $object->name
 Status    : Stable

=cut

sub name {
  my ($self, $name) = @_;
   
  if (defined($name)) {
    $self->{'name'} = ($name or undef);
  }

  return $self->{'name'};
}


=head2 genome_db

 Arg [1]   : Bio::EnsEMBL::Compara::GenomeDB $genome_db
 Example   : $genome_db = $dnafrag->genome_db()
 Example   : $dnafrag->genome_db($genome_db)
 Function  : get/set genome_db attribute. If no argument is given and the genome_db
             is not defined, it tries to get the data from other sources like the
             database using the genome_db_id.
 Returns   : Bio::EnsEMBL::Compara::GenomeDB object
 Exeption  : thrown if argument is not a Bio::EnsEMBL::Compara::GenomeDB
             object
 Caller    : $object->genome_db
 Status    : Stable

=cut

sub genome_db {
  my ($self, $genome_db) = @_;
   
  if (defined($genome_db)) {
    throw("[$genome_db] must be a Bio::EnsEMBL::Compara::GenomeDB object")
      unless ($genome_db and $genome_db->isa("Bio::EnsEMBL::Compara::GenomeDB"));
    if ($genome_db->dbID and defined($self->genome_db_id)) {
      throw("dbID of genome_db object does not match previously defined".
            " genome_db_id. If you want to override this".
            " Bio::EnsEMBL::Compara::GenomeDB object, you can reset the ".
            "genome_db_id using \$dnafrag->genome_db_id(0)")
          unless ($genome_db->dbID == $self->genome_db_id);
    }
    $self->{'genome_db'} = $genome_db;
  
  } elsif (!defined($self->{'genome_db'})) {
    # Try to get data from other sources
    if (defined($self->{'genome_db_id'}) and defined($self->{'adaptor'})) {
      $self->{'genome_db'} =
          $self->{'adaptor'}->db->get_GenomeDBAdaptor->fetch_by_dbID($self->{'genome_db_id'});
    }
  }

  return $self->{'genome_db'};
}


=head2 genome_db_id

 Arg [1]   : int $genome_db_id
 Example   : $genome_db_id = $dnafrag->genome_db_id()
 Example   : $dnafrag->genome_db_id(123)
 Function  : get/set genome_db_id attribute. If no argument is given and the genome_db_id
             is not defined, it tries to get the data from other sources like the
             corresponding Bio::EnsEMBL::Compara::GenomeDB object. Use 0 as argument to
             clear this attribute.
 Returns   : integer
 Exeption  : none
 Caller    : $object->genome_db_id
 Status    : Stable

=cut

sub genome_db_id {
  my ($self, $genome_db_id) = @_;
   
  if (defined($genome_db_id)) {
    if (defined($self->genome_db) and $genome_db_id) {
      if (defined($self->genome_db->dbID)) {
        throw("genome_db_id does not match previously defined".
              " dbID of genome_db object.")
            unless ($genome_db_id == $self->genome_db->dbID);
      } else {
        $self->genome_db->dbID($genome_db_id);
      }
    }
    $self->{'genome_db_id'} = ($genome_db_id or undef);
  
  } elsif (!defined($self->{'genome_db_id'})) {
    # Try to get data from other sources
    if (defined($self->{'genome_db'})) {
      # From the dbID of the corresponding Bio::EnsEMBL::Compara::GenomeDB object
      $self->{'genome_db_id'} = $self->{'genome_db'}->dbID;
    }
  }

  return $self->{'genome_db_id'};
}


=head2 coord_system_name

 Arg [1]   : string $coord_system_name
 Example   : $coord_system_name = $dnafrag->coord_system_name()
 Example   : $dnafrag->coord_system_name("chromosome")
 Function  : get/set coord_system_name attribute. Use "" or 0 as argument to
             clear this attribute.
 Returns   : string
 Exeption  : none
 Caller    : $object->coord_system_name
 Status    : Stable

=cut

sub coord_system_name {
  my ($self, $coord_system_name) = @_;

  if (defined($coord_system_name)) {
    $self->{'coord_system_name'} = ($coord_system_name or undef);
  }

  return $self->{'coord_system_name'};
}


=head2 slice

 Arg 1      : -none-
 Example    : $slice = $dnafrag->slice;
 Description: Returns the Bio::EnsEMBL::Slice object corresponding to this
              Bio::EnsEMBL::Compara::DnaFrag object.
 Returntype : Bio::EnsEMBL::Slice object
 Exceptions : warns when the corresponding Bio::EnsEMBL::Compara::GenomeDB,
              coord_system_name, name or Bio::EnsEMBL::DBSQL::DBAdaptor
              cannot be retrieved and returns undef.
 Caller     : $object->methodname
 Status     : Stable

=cut

sub slice {
  my ($self) = @_;
  
  unless (defined $self->{'_slice'}) {
    if (!defined($self->genome_db)) {
      warn "Cannot get the Bio::EnsEMBL::Compara::GenomeDB object corresponding to [".$self."]";
      return undef;
    }
    if (!defined($self->coord_system_name)) {
      warn "Cannot get the coord_system_name corresponding to [".$self."]";
      return undef;
    }
    if (!defined($self->name)) {
      warn "Cannot get the name corresponding to [".$self."]";
      return undef;
    }
    my $dba = $self->genome_db->db_adaptor;
    if (!defined($dba)) {
      warn "Cannot get the Bio::EnsEMBL::DBSQL::DBAdaptor corresponding to [".$self->genome_db->name."]";
      return undef;
    }

    $self->{'_slice'} = $dba->get_SliceAdaptor->fetch_by_region($self->coord_system_name, $self->name);
  }

  return $self->{'_slice'};
}


=head2 display_id

  Args       : none
  Example    : my $id = $dnafrag->display_id;
  Description: returns string describing this chunk which can be used
               as display_id of a Bio::Seq object or in a fasta file.
               Uses dnafrag information in addition to start and end.
  Returntype : string
  Exceptions : none
  Caller     : general
  Status     : Stable

=cut

sub display_id {
  my $self = shift;

  return "" unless($self->genome_db);
  my $id = $self->genome_db->taxon_id. ".".
           $self->genome_db->dbID. ":".
           $self->coord_system_name.":".
           $self->name;
  return $id;
}


#####################################################################
#####################################################################

=head1 DEPRECATED METHODS

Bio::EnsEMBL::Compara::DnaFrag::start and Bio::EnsEMBL::Compara::DnaFrag::end
methods are no longer used. All Bio::EnsEMBL::Compara::DnaFrag objects start
in 1. Start and end coordinates have been replaced by length attribute. Please,
use Bio::EnsEMBL::Compara::DnaFrag::length method to access it.

Bio::EnsEMBL::Compara::DnaFrag::genomedb has been renamed
Bio::EnsEMBL::Compara::DnaFrag::genome_db.

Bio::EnsEMBL::Compara::DnaFrag::type has been renamed
Bio::EnsEMBL::Compara::DnaFrag::coord_system_name.

=cut

#####################################################################
#####################################################################




=head2 start [DEPRECATED]
 
  DEPRECATED! All Bio::EnsEMBL::Compara::DnaFrag objects start in 1
  
  Arg [1]    : int
  Example    : $dnafrag->start(1);
  Description: Getter/Setter for the start attribute
  Returntype : int
  Exceptions : thrown when trying to set a starting position different from 1
  Caller     : general

=cut
 
sub start {
  my ($self,$value) = @_;

  deprecate("All Bio::EnsEMBL::Compara::DnaFrag objects start in 1");
  if (defined($value) and ($value != 1)) {
    throw("Trying to set a start value different from 1!\n".
        "All Bio::EnsEMBL::Compara::DnaFrag objects start in 1");
  }

  return 1;
}



=head2 end [DEPRECATED]
 
  DEPRECATED! Use Bio::EnsEMBL::Compara::DnaFrag->length() method instead

  Arg [1]    : int $end
  Example    : $dnafrag->end(42);
  Description: Getter/Setter for the start attribute
  Returntype : int
  Exceptions : none
  Caller     : general
 
=cut

sub end {
  my ($self, $end) = @_;
  deprecate("Use Bio::EnsEMBL::Compara::DnaFrag->length() method instead");

  return $self->length($end);
}


=head2 genomedb [DEPRECATED]

 DEPRECATD! Use Bio::EnsEMBL::Compara::DnaFrag->genome_db() method instead

 Title   : genomedb
 Usage   : $obj->genomedb($newval)
 Function: 
 Example : 
 Returns : value of genomedb
 Args    : newvalue (optional)

=cut

sub genomedb {
  my ($self, @args) = @_;
  deprecate("Calling Bio::EnsEMBL::Compara::DnaFrag::genome_db method instead");
  return $self->genome_db(@args);
}


=head2 type [DEPRECATED]

 DEPRECATED! Use Bio::EnsEMBL::Compara::DnaFrag->coord_system_name() method instead

 Title   : type
 Usage   : $obj->type($newval)
 Function: 
 Example : 
 Returns : value of coord_system_name (former type)
 Args    : newvalue (optional)

=cut

sub type {
  my ($self, @args) = @_;
  deprecate("Calling Bio::EnsEMBL::Compara::DnaFrag::coord_system_name method instead");
  return $self->coord_system_name(@args);
}


=head2 contig [DEPRECATED]

 DEPRECATED! Use Bio::EnsEMBL::Compara::DnaFrag->slice() method instead

=cut

sub contig {
  my ($self, @args) = @_;

  deprecated("Calling Bio::EnsEMBL::Compara::DnaFrag::slice method instead");
   
  return $self->slice(@args);
}


1;


