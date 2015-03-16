=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut


=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.

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

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut


# Let the code begin...


package Bio::EnsEMBL::Compara::DnaFrag;

use strict;
use warnings;

use Bio::EnsEMBL::Utils::Exception qw(deprecate throw);
use Bio::EnsEMBL::Utils::Argument;

use base ('Bio::EnsEMBL::Storable');        # inherit dbID(), adaptor() and new() methods


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

  my $self = $class->SUPER::new(@args);       # deal with Storable stuff

  my ($length, $name, $genome_db, $genome_db_id, $coord_system_name, $is_reference,
      ) =
    rearrange([qw(LENGTH NAME GENOME_DB GENOME_DB_ID COORD_SYSTEM_NAME IS_REFERENCE
        )],@args);

  $self->length($length) if (defined($length));
  $self->name($name) if (defined($name));
  $self->genome_db($genome_db) if (defined($genome_db));
  $self->genome_db_id($genome_db_id) if (defined($genome_db_id));
  $self->coord_system_name($coord_system_name) if (defined($coord_system_name));
  $self->is_reference($is_reference) if (defined($is_reference));

  return $self;
}


=head2 new_from_Slice

  Arg [1]    : Bio::EnsEMBL::Slice $slice
  Arg [2]    : Bio::EnsEMBL::Compara::GenomeDB $genome_db
  Description: Creates a new DnaFrag object using $slice (its underlying SeqRegion object)
               Note that the DnaFrag's GenomeDB is set with $genome_db
  Returntype : Bio::EnsEMBL::Compara::DnaFrag
  Exceptions : none
  Caller     : general
  Status     : Stable

=cut

sub new_from_Slice {
    my ($class, $slice, $genome_db) = @_;

    return $class->new(
        -NAME => $slice->seq_region_name(),
        -LENGTH => $slice->seq_region_length(),
        -COORD_SYSTEM_NAME => $slice->coord_system_name(),
        -IS_REFERENCE => $slice->is_reference(),
        -GENOME_DB => $genome_db,
    );
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
    $self->{'name'} = $name;
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


=head2 is_reference

 Arg [1]   : bool $is_reference
 Example   : $is_reference = $dnafrag->is_reference()
 Example   : $dnafrag->is_reference(1)
 Function  : get/set is_reference attribute. The default value
             is 1 (TRUE).
 Returns   : bool
 Exeption  : none
 Caller    : $object->is_reference
 Status    : Stable

=cut

sub is_reference {
  my ($self, $is_reference) = @_;

  if (defined($is_reference)) {
    $self->{'is_reference'} = $is_reference;
  }
  if (!defined($self->{'is_reference'})) {
    $self->{'is_reference'} = 1;
  }

  return $self->{'is_reference'};
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
    $dba->dbc->reconnect_when_lost(1);

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


=head2 isMT

  Args       : none
  Example    : my $isMT = $dnafrag->isMT;
  Description: returns true if this dnafrag has MT as a name or synonym, else returns false
  Returntype : boolean
  Exceptions : none
  Caller     : general
  Status     : Stable

=cut

sub isMT {
    my ($self) = @_;

    return 1 if ($self->name eq "MT");

    #Check synonyms
    my $slice = $self->slice;
    foreach my $synonym (@{$slice->get_all_synonyms}) {
        if ($synonym->name eq "MT") {
            return 1;
        }
    }
    return 0;
}

1;


