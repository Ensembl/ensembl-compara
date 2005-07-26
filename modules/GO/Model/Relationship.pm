# $Id$
#
# This GO module is maintained by Chris Mungall <cjm@fruitfly.org>
#
# see also - http://www.geneontology.org
#          - http://www.fruitfly.org/annot/go
#
# You may distribute this module under the same terms as perl itself

package GO::Model::Relationship;

=head1 NAME

  GO::Model::Relationship

=head1 SYNOPSIS

=head1 DESCRIPTION

a relationship between two GO::Model::Terms

relationships can be thought of as B<statements> or sentences of the form

  SUBJECT-TERM PREDICATE OBJECT-TERM

for example,

  "dog" IS_A "animal"

  "G-Protein coupled receptor" IS_A "transmembrane receptor"

Statements have a B<subject> (i.e. the subject of the
sentence/statement), a predicate/relationship-type and an B<object>
(i.e. the object of the sentence/statement)

Relationships can also be seen as arcs in a directed graph, with the
subject being equivalent to the child, and the object equivalent to
the parent. The arc is labeled with the predicate/relationship-type.

A Relationship object currently does not contain an actual pointer to
a GO::Model::Term object. Instead it stores the ID of that term. This
is intended to be used in conjunction with the Graph object, or with
the database.

=cut


use Carp;
use Exporter;
use GO::Utils qw(rearrange);
use GO::Model::Root;
use strict;
use vars qw(@ISA);

@ISA = qw(GO::Model::Root Exporter);

=head2 subject_acc

 Title   : subject_acc
 Usage   : $obj->subject_acc($newid)
 Usage   : $currid = $obj->subject_acc()
 Synonyms: subj_acc, acc1, parent_acc
 Function: gets or sets the identifier for the parent/subject term
 Example : 
 Returns : value of subject_acc (string)
 Args    : on set, new value (string)

For example, in an "is_a" (inheritance/subsumption) relationship, the subject term of the statement below is 'dog':

  dog is_a animal

This can also be thought of as the child node of an arc in a graph

  animal
    ^
    |
    | [is_a]
    |
   dog
    ^
    |
    | [is_a]
    |
  chihuahua   

=cut

=head2 object_acc

 Title   : object_acc
 Usage   : $obj->object_acc($newid)
 Usage   : $currid = $obj->object_acc()
 Synonyms: obj_acc, acc1, parent_acc
 Function: gets or sets the identifier for the parent/object term
 Example : 
 Returns : value of object_acc (string)
 Args    : on set, new value (string)

For example, in an "is_a" (inheritance/subsumption) relationship, the object term of the statement below is 'animal':

  dog is_a animal

This can also be thought of as the parent node of an arc in a graph

  animal
    ^
    |
    | [is_a]
    |
   dog
    ^
    |
    | [is_a]
    |
  chihuahua   


=cut

=head2 type

 Title   : type
 Usage   : $obj->type($newval)
 Usage   : $currval = $obj->type()
 Synonyms: 
 Function: gets or sets the relationship type (a string)
 Example : 
 Returns : value of type (string)
 Args    : on set, new value (string)

Currently any string is allowed; in future the type string may be
constrained to come from a controlled vocabulary of relationship types

=cut



sub _initialize {
    my $self = shift;
    $self->SUPER::_initialize(@_);
}

sub types {
    qw(isa partof developsfrom);
}

sub _valid_params {
    return qw(acc1 acc2 is_inheritance type);
}


sub is_inheritance {
    my $self = shift;
    if (@_) {
	my $is = shift;
	$is && $self->type("isa");
	!$is && $self->type("partof");
    }
    return $self->type eq "isa";
}


sub is_partof {
    my $self = shift;
    if (@_) {
	warn("deprecated");
	my $is = shift;
	$is && $self->type("partof");
	!$is && $self->type("isa");
    }
    return $self->type eq "partof";
}


sub is_developsfrom {
    my $self = shift;
    if (@_) {
	warn("deprecated");
	my $is = shift;
	$is && $self->type("developsfrom");
	!$is && $self->type("isa");
    }
    return $self->type eq "developsfrom";
}

sub type {
    my $self = shift;
    if (@_) {
	my $type = shift;
	if ($type) {
#	    ($type) = grep { lc($_) eq $type } $self->types();
            $self->{type} = lc($type);
        }
    }
    return $self->{type} || "isa";
}




sub is_obsolete {
    my $self = shift;
    $self->{is_obsolete} = shift if @_;
    return $self->{is_obsolete} ? 1:0;
}

sub acc1 {
    my $self = shift;
    $self->{"acc1"} = shift if @_;
    return $self->{"acc1"};
}
*obj_acc = \&acc1;
*object_acc = \&acc1;
*parent_acc = \&acc1;

sub acc2 {
    my $self = shift;
    $self->{"acc2"} = shift if @_;
    return $self->{"acc2"};
}
*subj_acc = \&acc2;
*subject_acc = \&acc2;
*child_acc = \&acc2;


sub to_idl_struct {
    my $self = shift;
    return 
      {
       parent_acc=>$self->acc1,
       child_acc=>$self->acc2,
       rel_type=>($self->is_inheritance ? "ISA" : "PARTOF"),
      };
}

sub from_idl {
    my $class = shift;
    my $h = shift;
    my $rel = $class->new({"acc1"=>$h->{parent_acc},
			   "acc2"=>$h->{child_acc}});    
    return $rel;
}

sub as_str {
    my $self = shift;
    sprintf("%s:%s:%s", $self->type, $self->acc1, $self->acc2);
}



sub to_ptuples {
    my $self = shift;
    my ($th) =
      rearrange([qw(tuples)], @_);
    (["rel", $self->type, $self->acc1, $self->acc2]);
}


1;

