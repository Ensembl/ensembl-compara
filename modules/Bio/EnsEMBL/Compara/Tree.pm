=head1 NAME

Tree - DESCRIPTION of Object

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 CONTACT

  Contact Jessica Severin on implemetation/design detail: jessica@ebi.ac.uk
  Contact Ewan Birney on EnsEMBL in general: birney@sanger.ac.uk

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::Tree;

use strict;
use Bio::Species;
use Bio::EnsEMBL::Utils::Exception;
use Bio::EnsEMBL::Utils::Argument;
use Bio::EnsEMBL::Compara::TreeNode;

sub new {
  my ($class, @args) = @_;
  my $self = {};

  bless $self,$class;

  if (scalar @args) {
    #do this explicitly.
    my ($dbid, $description, $adaptor) = rearrange([qw(DBID NAME ADAPTOR)], @args);

    $self->dbID($dbid)               if($dbid);
    $self->description($description) if($description);
    $self->adaptor($adaptor)         if($adaptor);
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

=head2 adaptor

 Title   : adaptor
 Usage   :
 Function: give the adaptor if known
 Example :
 Returns :
 Args    :

=cut

sub adaptor {
  my $self = shift;
  $self->{'_adaptor'} = shift if(@_);
  return $self->{'_adaptor'};
}

=head2 dbID

  Arg [1]    : int $dbID (optional)
  Example    :
  Description:
  Returntype :
  Exceptions :
  Caller     :

=cut

sub dbID {
  my $self = shift;
  $self->{'_dbID'} = shift if(@_);
  return $self->{'_dbID'};
}

=head2 description

  Arg [1]    : string $description (optional)
  Example    :
  Description:
  Returntype : string
  Exceptions :
  Caller     :

=cut

sub description {
  my $self = shift;
  $self->{'_description'} = shift if(@_);
  $self->{'_description'} = '' unless(defined($self->{'_description'}));
  return $self->{'_description'};
}

=head2 method_link_species_set_id

  Arg [1]    : int $methodLinkSpeciesSet->dbID (optional)
  Example    :
  Description:
  Returntype : string
  Exceptions :
  Caller     :

=cut

sub method_link_species_set_id {
  my $self = shift;
  $self->{'_method_link_species_set_id'} = shift if(@_);
  return $self->{'_method_link_species_set_id'};
}

=head2 method_link_species_set

  Arg [1]    : MethodLinkSpeciesSet object (optional)
  Example    : 
  Description: getter/setter method for the MethodLinkSpeciesSet for this relation
  Returntype : Bio::EnsEMBL::Compara::MethodLinkSpeciesSet
  Exceptions : 
  Caller     : 

=cut

sub method_link_species_set {
  my $self = shift;

  if(@_) {
    my $mlss = shift;
    unless ($mlss->isa('Bio::EnsEMBL::Compara::MethodLinkSpeciesSet')) {
      throw("Need to add a Bio::EnsEMBL::Compara::MethodLinkSpeciesSet, not a $mlss\n");
    }
    $self->{'_method_link_species_set'} = $mlss;
    $self->{'_method_link_species_set_id'} = $mlss->dbID;
  }

  #lazy load from method_link_species_set_id
  if ( ! defined $self->{'_method_link_species_set'} && defined $self->method_link_species_set_id) {
    my $mlssa = $self->adaptor->db->get_MethodLinkSpeciesSetAdaptor;
    my $mlss = $mlssa->fetch_by_dbID($self->method_link_species_set_id);
    $self->{'_method_link_species_set'} = $mlss;
  }

  return $self->{'_method_link_species_set'};
}


=head2 root_node

  Arg [1]    : Bio::EnsEMBL::Compara::TreeNode object (optional)
  Example    :
  Description: Getter/setter method to set the root of the tree 
  Returntype : Bio::EnsEMBL::Compara::TreeNode object root of a tree
  Exceptions :
  Caller     :

=cut

sub root_node {
  my ($self,$arg) = @_;

  if (defined($arg)) {
    throw("arg must be a [Bio::EnsEMBL::Compara::TreeNode] not a [$arg]")
        unless($arg->isa('Bio::EnsEMBL::Compara::TreeNode'));
    $self->{'_root_node'} = $arg;
  }
  return $self->{'_root_node'};
}

1;

