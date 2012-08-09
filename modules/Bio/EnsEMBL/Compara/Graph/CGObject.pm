=head1 NAME

CGObject - DESCRIPTION of Object

=head1 SYNOPSIS

=head1 DESCRIPTION

Abstract superclass to mimic some of the functionality of Foundation/NSObject
Implements a 'reference count' system based on the OpenStep retain/release design. 
Is used as the Root class for the Compara::Graph system (Node and Link) which is 
the foundation on which Compara::Graph (Node/Link) and Compara::NestedSet are built 

=head1 CONTACT

  Contact Jessica Severin on implemetation/design detail: jessica@ebi.ac.uk
  Contact Ewan Birney on EnsEMBL in general: birney@sanger.ac.uk

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut



package Bio::EnsEMBL::Compara::Graph::CGObject;

use strict;
use Bio::EnsEMBL::Utils::Exception;
use Bio::EnsEMBL::Utils::Argument;

use base ('Bio::EnsEMBL::Compara::Taggable');

#################################################
# Factory methods
#################################################

sub new {
  my ($class, @args) = @_;
  ## Allows to create a new object from an existing one with $object->new
  $class = ref($class) if (ref($class));
  my $self = {};
  bless $self,$class;
  $self->init;  
  return $self;
}

sub init {
  my $self = shift;

  #internal variables minimal allocation
  $self->{'_node_id'} = undef;
  $self->{'_adaptor'} = undef;

  return $self;
}

=head2 copy

  Overview   : copies object content but not identity
               copies tags, but not objc_id and adaptor
  Example    : my $clone = $self->copy;
  Returntype : Bio::EnsEMBL::Compara::Graph::CGObject
  Exceptions : none
  Caller     : general

=cut

sub copy {
  my $self = shift;
  
  my $mycopy = new Bio::EnsEMBL::Compara::Graph::CGObject;
  bless

  if($self->{'_tags'}) {
    %{$mycopy->{'_tags'}} = %{$self->{'_tags'}};
  }
  
  return $mycopy;
}

#################################################
#
# get/set variable methods
#
#################################################

=head2 adaptor

  Arg [1]    : (opt.) subcalss of Bio::EnsEMBL::DBSQL::BaseAdaptor
  Example    : my $object_adaptor = $object->adaptor();
  Example    : $object->adaptor($object_adaptor);
  Description: Getter/Setter for the adaptor this object uses for database
               interaction.
  Returntype : subclass of Bio::EnsEMBL::DBSQL::BaseAdaptor
  Exceptions : none
  Caller     : general

=cut

sub adaptor {
  my $self = shift;
  $self->{'_adaptor'} = shift if(@_);
  return $self->{'_adaptor'};
}


sub store {
  my $self = shift;
  throw("adaptor must be defined") unless($self->adaptor);
  $self->adaptor->store($self) if $self->adaptor->can("store");
}


sub name {
  my $self = shift;
  my $value = shift;
  if(defined($value)) { $self->add_tag('name', $value); }
  else { $value = $self->get_tagvalue('name'); }
  return $value;
}

1;

