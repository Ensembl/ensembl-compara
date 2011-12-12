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
  my $self = $class->alloc(@args);
  $self->init;  
  return $self;
}

sub alloc {
  my ($class, @args) = @_;
  my $self = {};
  bless $self,$class;
  #printf("%s   CREATE refcount:%d\n", $self->node_id, $self->refcount);  
  return $self;
}

sub init {
  my $self = shift;

  #internal variables minimal allocation
  $self->{'_node_id'} = undef;
  $self->{'_adaptor'} = undef;
  $self->{'_refcount'} = 0;

  return $self;
}

sub dealloc {
  my $self = shift;
  #printf("DEALLOC refcount:%d ", $self->refcount); $self->print_node;
}

sub DESTROY {
  my $self = shift;
  if(defined($self->{'_refcount'}) and $self->{'_refcount'}>0) {
    printf("WARNING DESTROY refcount:%d  (%s)%s %s\n", 
       $self->refcount, $self->node_id, $self->get_tagvalue('name'), $self);
  }    
  $self->SUPER::DESTROY if $self->can("SUPER::DESTROY");
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

  if($self->{'_tags'}) {
    %{$mycopy->{'_tags'}} = %{$self->{'_tags'}};
  }
  
  return $mycopy;
}

#######################################
# reference counting system
# DO NOT OVERRIDE
#######################################

sub retain {
  my $self = shift;
  return $self;
  $self->{'_refcount'}=0 unless(defined($self->{'_refcount'}));
  $self->{'_refcount'}++;
  #printf("RETAIN  refcount:%d (%s)%s %s\n", 
  #     $self->refcount, $self->obj_id, $self->get_tagvalue('name'), $self);
  return $self;
}

sub release {
  my $self = shift;
  $self->dealloc;
  return $self;
  throw("calling release on object which hasn't been retained") 
    unless(defined($self->{'_refcount'}));
  $self->{'_refcount'}--;
  #printf("RELEASE refcount:%d (%s)%s %s\n", 
  #     $self->refcount, $self->obj_id, $self->get_tagvalue('name'), $self);
  return $self if($self->refcount > 0);
  $self->dealloc;
  return undef;
}

sub refcount {
  my $self = shift;
  return $self->{'_refcount'};
}

#################################################
#
# get/set variable methods
#
#################################################

=head2 obj_id

  Example    : my $nsetID = $object->obj_id();
  Description: returns the unique identifier of this object.  
  Returntype : <string> uuid
  Exceptions : none
  Caller     : general

=cut

sub obj_id {
  my $self = shift;
  return $self;
  unless(defined($self->{'_cgobject_id'})) {
    $self->{'_cgobject_id'} = $self;
  }
  return $self->{'_cgobject_id'};
}


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

