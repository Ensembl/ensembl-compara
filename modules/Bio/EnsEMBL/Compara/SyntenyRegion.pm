#
# Ensembl module for Bio::EnsEMBL::Compara::SyntenyRegion
#
# Cared for by Ewan Birney <ensembl-dev@ebi.ac.uk>
#
# Copyright GRL and EBI
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

Bio::EnsEMBL::Compara::SyntenyRegion - Synteny region on one species

=head1 SYNOPSIS

  print $this_synteny_region->dbID;

  print $this_synteny_region->method_link_species_set_id;

  my $these_dnafrag_regions = $this_synteny_region->children();
  foreach my $this_dnafrag_region (@$these_dnafrag_regions) {
    print $this_dnafrag_region->dnafrag->genome_db->name, ": ", $this_dnafrag_region->slice->name, "\n";
  }

=head1 DESCRIPTION

Describe the object here

=head1 OBJECT ATTRIBUTES

=over

=item dbID

corresponds to synteny_region.synteny_region_id

=item adaptor

Bio::EnsEMBL::Compara::DBSQL::SyntenyRegionAdaptor object to access DB

=item method_link_species_set_id

corresponds to synteny_region.method_link_species_set_id

=back

=head1 CONTACT

Ensembl - ensembl-dev@ebi.ac.uk

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut


# Let the code begin...


package Bio::EnsEMBL::Compara::SyntenyRegion;

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
    my ($dbid, $stable_id, $method_link_species_set_id, $adaptor) = rearrange([qw(DBID STABLE_ID METHOD_LINK_SPECIES_SET_ID ADAPTOR)], @args);

    $dbid && $self->dbID($dbid);
    $stable_id && $self->stable_id($stable_id);
    $method_link_species_set_id && $self->method_link_species_set_id($method_link_species_set_id);
    $adaptor && $self->adaptor($adaptor);
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


=head2 stable_id

 Title   : stable_id
 Usage   : $obj->stable_id($newval)
 Function: 
 Returns : value of stable_id
 Args    : newvalue (optional)


=cut

sub stable_id{
   my $obj = shift;
   if( @_ ) {
      my $value = shift;
      $obj->{'stable_id'} = $value;
    }
    return $obj->{'stable_id'};

}


=head2 method_link_species_set_id

 Title   : method_link_species_set_id
 Usage   : $obj->method_link_species_set_id($newval)
 Function: 
 Returns : value of method_link_species_set_id
 Args    : newvalue (optional)


=cut

sub method_link_species_set_id{
  my $obj = shift;
  if( @_ ) {
    my $value = shift;
    $obj->{'method_link_species_set_id'} = $value;
  }
  return $obj->{'method_link_species_set_id'};
}

=head2 dbID

 Title   : dbID
 Usage   : $obj->dbID($newval)
 Function: 
 Returns : value of dbID
 Args    : newvalue (optional)


=cut

sub dbID{
   my $obj = shift;
   if( @_ ) {
      my $value = shift;
      $obj->{'dbID'} = $value;
    }
    return $obj->{'dbID'};

}


=head2 adaptor

 Title   : adaptor
 Usage   : $obj->adaptor($newval)
 Function: 
 Returns : value of adaptor
 Args    : newvalue (optional)


=cut

sub adaptor {
   my $obj = shift;
   if( @_ ) {
      my $value = shift;
      $obj->{'adaptor'} = $value;
    }
    return $obj->{'adaptor'};

}


=head2 get_all_DnaFragRegions

 Arg  1     : -none-
 Example    : my $all_dnafrag_regions = $obj->get_all_DnaFragRegions();
 Description: returns all the DnaFragRegion objects for this syntenic
              region
 Returntype : a ref. to an array of Bio::EnsEMBL::Compara::DnaFragRegion
              objects
 Exception  : 
 Caller     :
 Status     : Stable

=cut

sub get_all_DnaFragRegions {
  my $obj = shift;

  return $obj->children();
}

1;
