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
  Arg [2]    : <string> value
  Arg [3]    : (optional) <int> allows overloading the tag with different values
               default is 0 (no overloading allowed, one tag points to one value)
  Example    : $ns_node->add_tag('scientific name', 'Mammalia');
               $ns_node->add_tag('lost_taxon_id', 9593, 1);
  Returntype : Boolean indicating if the tag could be stored
  Exceptions : none
  Caller     : general

=cut

sub add_tag {
    my $self = shift;
    my $tag = shift;
    my $value = shift;
    my $allow_overloading = shift;

    # Argument check
    return 0 unless (defined $tag);
    return 0 unless (defined $value);
    $allow_overloading = 0 unless (defined $allow_overloading);
    
    $self->_load_tags;
    $tag = lc($tag);

    return 0 if $allow_overloading and exists $self->{'_attr_list'} and exists $self->{'_attr_list'}->{$tag};

    # Stores the value in the PERL object
    if ( ! exists($self->{'_tags'}->{$tag}) || ! $allow_overloading ) {
        # No overloading or new tag: store the value
        $self->{'_tags'}->{$tag} = $value;

    } elsif ( ref($self->{'_tags'}->{$tag}) eq 'ARRAY' ) {
        # Several values were there: we add a new one
        push @{$self->{'_tags'}->{$tag}}, $value;

    } else {
        # One value was there, we make an array
        $self->{'_tags'}->{$tag} = [ $self->{'_tags'}->{$tag}, $value ];
    }
    return 1;
}


=head2 store_tag

  Description: calls add_tag and then stores the tag in the database. Has the
               exact same arguments as add_tag
  Arg [1]    : <string> tag
  Arg [2]    : <string> value
  Arg [3]    : (optional) <int> allows overloading the tag with different values
               default is 0 (no overloading allowed, one tag points to one value)
  Example    : $ns_node->store_tag('scientific name', 'Mammalia');
               $ns_node->store_tag('lost_taxon_id', 9593, 1);
  Returntype : 0 if the tag couldn't be stored,
               1 if it is only in the PERL object,
               2 if it is also stored in the database
  Exceptions : none
  Caller     : general

=cut

sub store_tag {
    my $self = shift;
    my $tag = shift;
    my $value = shift;
    my $allow_overloading = shift;

    if ($self->add_tag($tag, $value, $allow_overloading)) {
        if($self->adaptor and $self->adaptor->can("_store_tagvalue")) {
            $self->adaptor->_store_tagvalue($self->node_id, lc($tag), $value, $allow_overloading);
            return 2;
        } else {
            return 1;
        }
    } else {
        return 0;
    }
}


=head2 delete_tag

  Description: removes a tag from the metadata. If the value is provided, it tries
               to delete only it (if present). Otherwise, it just clears the tag,
               whatever value it was containing
  Arg [1]    : <string> tag
  Arg [2]    : (optional) <string> value
  Example    : $ns_node->remove_tag('scientific name', 'Mammalia');
               $ns_node->remove_tag('lost_taxon_id', 9593);
  Returntype : 0 if the tag couldn't be removed,
               1 if it is only in the PERL object,
               2 if it is also stored in the database
  Exceptions : none
  Caller     : general

=cut

sub delete_tag {
    my $self = shift;
    my $tag = shift;
    my $value = shift;

    # Arguments check
    return 0 unless (defined $tag);
    $tag = lc($tag);

    $self->_load_tags;
    return 0 unless exists($self->{'_tags'}->{$tag});

    # Updates the PERL object
    my $ret = 0;
    if (defined $value) {
        if ( ref($self->{'_tags'}->{$tag}) eq 'ARRAY' ) {
            my $arr = $self->{'_tags'}->{$tag};
            my $index = scalar(@$arr)-1;
            $index-- until ($index<0) or ($arr->[$index] eq $value);
            if ($index >= 0) {
                splice(@$arr, $index, 1);
                $ret = 1;
            }
        } else {
            if ($self->{'_tags'}->{$tag} eq $value) {
                delete $self->{'_tags'}->{$tag};
                $ret = 1;
            }
        }
    } else {
        delete $self->{'_tags'}->{$tag};
        $ret = 1;
    }

    # Update the database
    if ($ret) {
        if($self->adaptor and $self->adaptor->can("_delete_tagvalue")) {
            $self->adaptor->_delete_tagvalue($self->node_id, $tag, $value);
            return 2;
        } else {
            return 1;
        }
    } else {
        return 0;
    }
}


=head2 has_tag

  Description: indicates whether the tag exists in the metadata
  Arg [1]    : <string> tag
  Example    : $ns_node->has_tag('scientific name');
  Returntype : Boolean
  Exceptions : none
  Caller     : general

=cut

sub has_tag {
    my $self = shift;
    my $tag = shift;

    return 0 unless defined $tag;

    $self->_load_tags;
    return exists($self->{'_tags'}->{lc($tag)});
}


=head2 get_tagvalue

  Description: returns the value of the tag, or $default (undef
               if not provided) if the tag doesn't exist.
  Arg [1]    : <string> tag
  Arg [2]    : (optional) <string> default
  Example    : $ns_node->get_tagvalue('scientific name');
  Returntype : String
  Exceptions : none
  Caller     : general

=cut

sub get_tagvalue {
    my $self = shift;
    my $tag = shift;
    my $default = shift;

    return $default unless defined $tag;

    $tag = lc($tag);
    $self->_load_tags;
    return $default unless exists($self->{'_tags'}->{$tag});
    return $self->{'_tags'}->{$tag};
}


=head2 get_all_tags

  Description: returns an array of all the available tags
  Example    : $ns_node->get_all_tags();
  Returntype : Array
  Exceptions : none
  Caller     : general

=cut

sub get_all_tags {
    my $self = shift;

    $self->_load_tags;
    return keys(%{$self->{'_tags'}});
}


=head2 get_tagvalue_hash

  Description: returns the underlying hash that contains all
               the tags
  Example    : $ns_node->get_tagvalue_hash();
  Returntype : Hashref
  Exceptions : none
  Caller     : general

=cut

sub get_tagvalue_hash {
    my $self = shift;

    $self->_load_tags;
    return $self->{'_tags'};
}

=head2 _load_tags

  Description: loads all the tags (from the database) if possible.
               Otherwise, an empty hash is created
  Example    : $ns_node->_load_tags();
  Returntype : none
  Exceptions : none
  Caller     : internal

=cut

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

