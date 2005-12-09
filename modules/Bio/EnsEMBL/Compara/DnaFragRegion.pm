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



=head1 DESCRIPTION

Describe the object here

=head1 CONTACT

Ensembl - ensembl-dev@ebi.ac.uk

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut


package Bio::EnsEMBL::Compara::DnaFragRegion;

use strict;
use Bio::EnsEMBL::Utils::Argument;
use Bio::EnsEMBL::Utils::Exception;

use Bio::EnsEMBL::Compara::NestedSet;
our @ISA = qw(Bio::EnsEMBL::Compara::NestedSet);

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

  Arg [1]    : hash reference $hashref
  Example    : none
  Description: This is an ultra fast constructor which requires knowledge of
               the objects internals to be used.
  Returntype :
  Exceptions : none
  Caller     :

=cut

sub new_fast {
  my ($class, $hashref) = @_;

  return bless $hashref, $class;
}


=head2 synteny_region_id

 Title   : synteny_region_id
 Usage   : $obj->synteny_region_id($newval)
 Function: 
 Returns : value of synteny_region_id
 Args    : newvalue (optional)


=cut

sub synteny_region_id{
   my $obj = shift;
   if( @_ ) {
      my $value = shift;
      $obj->{'synteny_region_id'} = $value;
    }
    return $obj->{'synteny_region_id'};

}

=head2 dnafrag_id

 Title   : dnafrag_id
 Usage   : $obj->dnafrag_id($newval)
 Function: 
 Returns : value of dnafrag_id
 Args    : newvalue (optional)


=cut

sub dnafrag_id{
  my $obj = shift;
  if( @_ ) {
    my $value = shift;
    $obj->{'dnafrag_id'} = $value;
  }
  return $obj->{'dnafrag_id'};
}

sub dnafrag_start{
  my $obj = shift;
  if( @_ ) {
    my $value = shift;
    $obj->{'dnafrag_start'} = $value;
  }
  return $obj->{'dnafrag_start'};
}

sub dnafrag_end{
  my $obj = shift;
  if( @_ ) {
    my $value = shift;
    $obj->{'dnafrag_end'} = $value;
  }
  return $obj->{'dnafrag_end'};
}

sub dnafrag_strand{
  my $obj = shift;
  if( @_ ) {
    my $value = shift;
    $obj->{'dnafrag_strand'} = $value;
  }
  return $obj->{'dnafrag_strand'};
}

=head2 adaptor

 Title   : adaptor
 Usage   : $obj->adaptor($newval)
 Function: 
 Returns : value of adaptor
 Args    : newvalue (optional)


=cut

sub adaptor{
   my $obj = shift;
   if( @_ ) {
      my $value = shift;
      $obj->{'adaptor'} = $value;
    }
    return $obj->{'adaptor'};

}

=head2 dnafrag

 Arg 1      : -none-
 Example    : $dnafrag = $dnafragregion->dnafrag;
 Description: Returns the Bio::EnsEMBL::Compara::DnaFrag object corresponding to this
              Bio::EnsEMBL::Compara::DnaFragRegion object.
 Returntype : Bio::EnsEMBL::Compara::Dnafrag object
 Exceptions : warns when the corresponding Bio::EnsEMBL::Compara::GenomeDB,
              coord_system_name, name or Bio::EnsEMBL::DBSQL::DBAdaptor
              cannot be retrieved and returns undef.
 Caller     : $object->methodname

=cut

sub dnafrag {
  my ($self) = @_;
  
  unless (defined $self->{'_slice'}) {
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

 Arg 1      : -none-
 Example    : $slice = $dnafragregion->slice;
 Description: Returns the Bio::EnsEMBL::Slice object corresponding to this
              Bio::EnsEMBL::Compara::DnaFrag object.
 Returntype : Bio::EnsEMBL::Slice object
 Exceptions : warns when the corresponding Bio::EnsEMBL::Compara::GenomeDB,
              coord_system_name, name or Bio::EnsEMBL::DBSQL::DBAdaptor
              cannot be retrieved and returns undef.
 Caller     : $object->methodname

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

1;
