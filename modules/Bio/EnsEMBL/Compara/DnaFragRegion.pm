#
# Ensembl module for Bio::EnsEMBL::Compara::DnaFragRegion
#
# Cared for by Abel Ureta-Vidal <abel@ebi.ac.uk>
#
# Copyright GRL and EBI
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

Bio::EnsEMBL::Compara::DnaFragRegion - dnafrag region on one species

=head1 SYNOPSIS

  my $slice = $dnafrag_region->slice;
  my $dnafrag = $dnafrag_region->dnafrag;
  my $genome_db = $dnafrag_region->genome_db;
  my $dnafrag_start = $dnafrag_region->dnafrag_start;
  my $dnafrag_end = $dnafrag_region->dnafrag_end;
  my $dnafrag_strand = $dnafrag_region->dnafrag_strand;
  my $length = $dnafrag_region->length;

=head1 DESCRIPTION

DnaFragRegion are the objects underlying the SyntenyRegion objects. Each synteny is
represented as a Bio::EnsEMBL::Compara::SyntenyRegion object. Each of these objects
contain one Bio::EnsEMBL::Compara::DnaFragRegion object per region which defines the
synteny. For instance, for a syntenic region between human and mouse, there will be
one DnaFragRegion object for the human region and another one for the mouse one.

=head1 CONTACT

Ensembl - ensembl-dev@ebi.ac.uk

=head1 OBJECT ATTRIBUTES

=over

=item adaptor

Bio::EnsEMBL::Compara::DBSQL::DnaFragRegionAdaptor object to access DB

=item synteny_region_id

corresponds to dnafrag.synteny_region_id (external ref.)

=item dnafrag_id

corresponds to dnafrag.dnafrag_id (external ref.)

=item dnafrag

Bio::EnsEMBL::Compara::DnaFrag object corresponding to dnafrag_id

=item dnafrag_start

corresponds to dnafrag_region.dnafrag_start

=item dnafrag_end

corresponds to dnafrag_region.dnafrag_end

=item dnafrag_strand

corresponds to dnafrag_region.dnafrag_strand

=back

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut


package Bio::EnsEMBL::Compara::DnaFragRegion;

use strict;
use Bio::EnsEMBL::Utils::Argument;
use Bio::EnsEMBL::Utils::Exception;

use Bio::EnsEMBL::Compara::NestedSet;
our @ISA = qw(Bio::EnsEMBL::Compara::NestedSet);


=head2 new_fast

  Arg         : possible keys: ADAPTOR, SYNTENY_REGION_ID, DNAFRAG_ID,
                DNAFRAG_START, DNAFRAG_END, DNAFRAG_STRAND
                See also parent object: Bio::EnsEMBL::Compara::NestedSet
  Example     : none
  Description : Object constructor.
  Returntype  : Bio::EnsEMBL::Compara::DnaFragRegion object
  Exceptions  : none
  Caller      : general

=cut

sub new {
  my ($class, @args) = @_;
  my $self = $class->SUPER::new(@args);
#  my $self = bless {}, $class;
  
  if (scalar @args) {
    #do this explicitly.
    my ($adaptor, $synteny_region_id, $dnafrag_id, $dnafrag_start, $dnafrag_end, $dnafrag_strand) = rearrange([qw(ADAPTOR SYNTENY_REGION_ID DNAFRAG_ID DNAFRAG_START DNAFRAG_END DNAFRAG_STRAND)], @args);

    $adaptor && $self->adaptor($adaptor);
    $synteny_region_id && $self->synteny_region_id($synteny_region_id);
    $dnafrag_id && $self->dnafrag_id($dnafrag_id);
    $dnafrag_start && $self->dnafrag_start($dnafrag_start);
    $dnafrag_end && $self->dnafrag_end($dnafrag_end);
    $dnafrag_strand && $self->dnafrag_strand($dnafrag_strand);
  }

  return $self;
}


=head2 new_fast

  Arg 1       : hash reference $hashref
  Example     : none
  Description : This is an ultra fast constructor which requires knowledge of
                the objects internals to be used.
  Returntype  : Bio::EnsEMBL::Compara::DnaFragRegion object
  Exceptions  : none
  Caller      : general

=cut

sub new_fast {
  my ($class, $hashref) = @_;

  return bless $hashref, $class;
}


=head2 synteny_region_id

  Arg 1       : (optional) integer $synteny_region_id
  Example     : my $synteny_region_id = $dnafrag->synteny_region_id;
  Description : Getter/setter for the synteny_region_id attribute
  Returntype  : integer
  Exceptions  : none
  Caller      : general

=cut

sub synteny_region_id {
  my $obj = shift;

  if (@_) {
    my $value = shift;
    $obj->{'synteny_region_id'} = $value;
  }

  return $obj->{'synteny_region_id'};
}


=head2 dnafrag_id

  Arg 1       : (optional) integer $dnafrag_id
  Example     : my $dnafrag_id = $dnafrag->dnafrag_id;
  Description : Getter/setter for the dnafrag_id attribute
  Returntype  : integer
  Exceptions  : none
  Caller      : general

=cut

sub dnafrag_id {
  my $obj = shift;

  if (@_) {
    my $value = shift;
    $obj->{'dnafrag_id'} = $value;
  }

  return $obj->{'dnafrag_id'};
}


=head2 dnafrag_start

  Arg 1       : (optional) integer $dnafrag_start
  Example     : my $dnafrag_start = $dnafrag->dnafrag_start;
  Description : Getter/setter for the dnafrag_start attribute
  Returntype  : integer
  Exceptions  : none
  Caller      : general

=cut

sub dnafrag_start {
  my $obj = shift;

  if (@_) {
    my $value = shift;
    $obj->{'dnafrag_start'} = $value;
  }

  return $obj->{'dnafrag_start'};
}


=head2 dnafrag_end

  Arg 1       : (optional) integer $dnafrag_end
  Example     : my $dnafrag_end = $dnafrag->dnafrag_end;
  Description : Getter/setter for the dnafrag_end attribute
  Returntype  : integer
  Exceptions  : none
  Caller      : general

=cut

sub dnafrag_end {
  my $obj = shift;

  if (@_) {
    my $value = shift;
    $obj->{'dnafrag_end'} = $value;
  }

  return $obj->{'dnafrag_end'};
}


=head2 dnafrag_strand

  Arg 1       : (optional) integer $dnafrag_strand
  Example     : my $dnafrag_strand = $dnafrag->dnafrag_strand;
  Description : Getter/setter for the dnafrag_strand attribute
  Returntype  : integer (1 or -1)
  Exceptions  : none
  Caller      : general

=cut

sub dnafrag_strand {
  my $obj = shift;

  if (@_) {
    my $value = shift;
    $obj->{'dnafrag_strand'} = $value;
  }

  return $obj->{'dnafrag_strand'};
}


=head2 adaptor

  Arg 1       : (optional) Bio::EnsEMBL::Compara::DBSQL::DnaFragRegioAdaptor $adaptor
  Example     : my $adaptor = $dnafrag->adaptor;
  Description : Getter/setter for the corresponding
                Bio::EnsEMBL::Compara::DBSQL::DnaFragRegioAdaptor object
  Returntype  : Bio::EnsEMBL::Compara::DBSQL::DnaFragRegioAdaptor object
  Exceptions  : none
  Caller      : general

=cut

sub adaptor {
  my $obj = shift;

  if (@_) {
    my $value = shift;
    $obj->{'adaptor'} = $value;
  }

  return $obj->{'adaptor'};
}


=head2 dnafrag

  Arg 1       : (optional) Bio::EnsEMBL::Compara::DnaFrag object
  Example     : $dnafrag = $dnafragregion->dnafrag;
  Description : Getter/setter for the Bio::EnsEMBL::Compara::DnaFrag object corresponding to this
                Bio::EnsEMBL::Compara::DnaFragRegion object.
  Returntype  : Bio::EnsEMBL::Compara::Dnafrag object
  Exceptions  : warns when the corresponding Bio::EnsEMBL::Compara::GenomeDB,
                coord_system_name, name or Bio::EnsEMBL::DBSQL::DBAdaptor
                cannot be retrieved and returns undef.
  Caller      : $object->methodname

=cut

sub dnafrag {
  my ($self) = shift @_;

  if (@_) {
    $self->{'_dnafrag'} = shift @_;
  } elsif (!defined $self->{'_dnafrag'}) {
    if (!defined($self->dnafrag_id)) {
      warn "Cannot get the Bio::EnsEMBL::Compara::DnaFrag object without dbID";
      return undef;
    }
    my $dfa = $self->adaptor->db->get_DnaFragAdaptor;
    if (!defined($dfa)) {
      warn "Cannot get the Bio::EnsEMBL::Compara::DBSQL::DnaFragAdaptor";
      return undef;
    }
    $self->{'_dnafrag'} = $dfa->fetch_by_dbID($self->dnafrag_id);
  }
  return $self->{'_dnafrag'};
}


=head2 slice

  Arg 1       : -none-
  Example     : $slice = $dnafragregion->slice;
  Description : Returns the Bio::EnsEMBL::Slice object corresponding to this
                Bio::EnsEMBL::Compara::DnaFrag object.
  Returntype  : Bio::EnsEMBL::Slice object
  Exceptions  : warns when the corresponding Bio::EnsEMBL::Compara::GenomeDB,
                coord_system_name, name or Bio::EnsEMBL::DBSQL::DBAdaptor
                cannot be retrieved and returns undef.
  Caller      : $object->methodname

=cut

sub slice {
  my ($self) = @_;
  
  unless (defined $self->{'_slice'}) {
    if (!defined($self->dnafrag->genome_db)) {
      warn "Cannot get the Bio::EnsEMBL::Compara::GenomeDB object corresponding to [".$self."]";
      return undef;
    }
    if (!defined($self->dnafrag->coord_system_name)) {
      warn "Cannot get the coord_system_name corresponding to [".$self."]";
      return undef;
    }
    if (!defined($self->dnafrag->name)) {
      warn "Cannot get the name corresponding to [".$self."]";
      return undef;
    }
    my $dba = $self->dnafrag->genome_db->db_adaptor;
    if (!defined($dba)) {
      warn "Cannot get the Bio::EnsEMBL::DBSQL::DBAdaptor corresponding to [".$self->dnafrag->genome_db."]";
      return undef;
    }
    $self->{'_slice'} = $dba->get_SliceAdaptor->fetch_by_region($self->dnafrag->coord_system_name, $self->dnafrag->name,$self->dnafrag_start, $self->dnafrag_end, $self->dnafrag_strand);
  }

  return $self->{'_slice'};
}


=head2 genome_db

  Arg 1       : -none-
  Example     : $genome_db = $dnafragregion->genome_db;
  Description : Returns the Bio::EnsEMBL::Compara::GenomeDB object corresponding to this
                Bio::EnsEMBL::Compara::DnaFragRegion object. This method is a shortcut
                for $dnafragregion->dnafrag->genome_db
  Returntype  : Bio::EnsEMBL::Compara::GenomeDB object
  Exceptions  : return undef if no dnafrag can be found for this DnaFragRegion object.
                See dnafrag method elsewhere in this document.
  Caller      : $object->methodname

=cut

sub genome_db {
  my ($self) = @_;

  if ($self->dnafrag) {
    return $self->dnafrag->genome_db;
  }

  return undef;
}


=head2 length

  Arg 1       : -none-
  Example     : $length = $dnafragregion->length;
  Description : Returns the lenght of this DnaFragRegion
  Returntype  : integer
  Exceptions  :
  Caller      : $object->methodname

=cut

sub length {
  my ($self) = @_;

  return $self->dnafrag_end - $self->dnafrag_start + 1;
}

1;
