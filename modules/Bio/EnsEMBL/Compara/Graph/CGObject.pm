=head1 NAME

CGObject - DESCRIPTION of Object

=head1 SYNOPSIS

=head1 DESCRIPTION

Abstract superclass to mimic some of the functionality of Foundation/NSObject
Implements a 'reference count' system based on the OpenStep retain/release design. 
Implements a metadata tagging system.
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


##################################
#
# metadata tagging system
#
##################################

=head2 add_tag

  Description: adds metadata tags to a node.  Both tag and value are added
               as metdata with the added ability to retreive the value given
               the tag (like a perl hash). In case of one to many relation i.e.
               one tag and different values associated with it, the values are
               returned in a array reference.
  Arg [1]    : <string> tag
  Arg [2]    : (optional)<string> value
  Arg [3]    : (optional) <int> allows overloading the tag with different values
               default is 0 (no overloading allowed, one tag points to one value)
  Example    : $ns_node->add_tag('scientific name', 'Mammalia');
               $ns_node->add_tag('mammals_rosette');
  Returntype : none
  Exceptions : none
  Caller     : general

=cut

sub add_tag {
  my $self = shift;
  my $tag = shift;
  my $value = shift;
  my $allow_overloading = shift;
  
  unless (defined $allow_overloading) {
    $allow_overloading = 0;
  }
  unless(defined($self->{'_tags'})) { $self->{'_tags'} = {}; }
  return unless(defined($tag));
  
#  if(defined($value)) { $self->{'_tags'}->{$value} = '';}
#  else {$value='';}
  $value='' unless (defined $value);
  if ( ! defined $self->{'_tags'}->{$tag} || ! $allow_overloading ) {
    $self->{'_tags'}->{$tag} = $value;
  } elsif ( ref($self->{'_tags'}->{$tag}) eq 'ARRAY' ) {
    push @{$self->{'_tags'}->{$tag}}, $value;
  } else {
    $self->{'_tags'}->{$tag} = [ $self->{'_tags'}->{$tag}, $value ];
  }
}

sub store_tag {
  my $self = shift;
  my $tag = shift;
  my $value = shift;
  
  $self->add_tag($tag, $value);
  if($self->adaptor and $self->adaptor->can("_store_tagvalue")) {
    $self->adaptor->_store_tagvalue($self->node_id, $tag, $value);
  }
}


sub has_tag {
  my $self = shift;
  my $tag = shift;
  
  $self->_load_tags;
  return 1 if(defined($self->{'_tags'}->{$tag}));
  return 0
}

sub get_tagvalue {
  my $self = shift;
  my $tag = shift;
  
  return '' unless($self->has_tag($tag));
  return $self->{'_tags'}->{$tag};
}

sub get_all_tags {
  my $self = shift;
  
  $self->_load_tags;
  return keys(%{$self->{'_tags'}});
}

sub get_tagvalue_hash {
  my $self = shift;
  
  $self->_load_tags;
  return $self->{'_tags'};
}

sub _load_tags {
  my $self = shift;
  return if(defined($self->{'_tags'}));
  $self->{'_tags'} = {};
  if($self->adaptor and $self->adaptor->can("_load_tagvalues")) {
    $self->adaptor->_load_tagvalues($self);
  }
}

sub name {
  my $self = shift;
  my $value = shift;
  if(defined($value)) { $self->add_tag('name', $value); }
  else { $value = $self->get_tagvalue('name'); }
  return $value;
}

1;

