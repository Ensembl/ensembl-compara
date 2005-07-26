# $Id$
#
# This GO module is maintained by Chris Mungall <cjm@fruitfly.org>
#
# see also - http://www.geneontology.org
#          - http://www.fruitfly.org/annot/go
#
# You may distribute this module under the same terms as perl itself


=head1 NAME

  GO::CorbaClient::Graph;

=head1 DESCRIPTION

  this is a simple wrapper to a corba Graph object (see the
  interface Graph in the idl); it passes requests to the object on
  the server, and translates the results into GO::Model::* objects

=cut

package GO::CorbaClient::Graph;
use vars qw($AUTOLOAD @ISA);
use strict;

use GO::Model::Term;
use GO::CorbaClient::AssociationIterator;
use GO::MiscUtils qw(dd);
use GO::Utils qw(rearrange);
use Error qw(:try);
use CORBA::ORBit;

#@ISA = qw();

# shouldnt be called directly by api user
sub new {
    my $class = shift;
    my $h = shift;
    my $self = {};
    bless $self, $class;
    $self->obj($h->{stub});
    $self->apph($h->{apph});
    return $self;
}

# CORBA stub object
sub obj {
    my $self = shift;
    $self->{_obj} = shift if @_;
    return $self->{_obj};
}

# application handle obj
sub apph {
    my $self = shift;
    $self->{_apph} = shift if @_;
    return $self->{_apph};
}


=head2 get_top_nodes

  Usage   - my $nodes = $graph->get_top_nodes
  Returns - arrayref of GO::Model::Term objects
  Args    - none

=cut

sub get_top_nodes {
    my $self = shift;
    my $nodes = $self->obj->get_top_nodes();
    return [map {$self->create_term_from_idl($_)} @$nodes];
}

=head2 get_all_nodes

  Usage   - my $nodes = $graph->get_all_nodes
  Returns - arrayref of GO::Model::Term objects
  Args    - none

=cut

sub get_all_nodes {
    my $self = shift;
    my $nodes = $self->obj->get_all_nodes();
    return [map {$self->create_term_from_idl($_)} @$nodes];
}

=head2 get_child_terms

=cut

sub get_child_terms {
    my $self = shift;
    my ($acc, $template) =
      rearrange([qw(acc template)], @_);
    if (!$template || $template eq "shallow") {
	# shallow template, just get term attributes, no other
	# structs
	require GO::Model::Term;
	$template = GO::Model::Term->get_template($template);
    }
    my $nodes = $self->obj->get_child_terms($acc, $template->to_idl_struct);
    return [map {$self->create_term_from_idl($_)} @$nodes];
}

=head2 get_child_relationships

=cut

sub get_child_relationships {
    my $self = shift;
    my $rels = $self->obj->get_child_relationships(@_);
    return [map {GO::Model::Relationship->from_idl($_)} @$rels];
}

=head2 get_parent_relationships

=cut

sub get_parent_relationships {
    my $self = shift;
    my $rels = $self->obj->get_parent_relationships(@_);
    return [map {GO::Model::Relationship->from_idl($_)} @$rels];
}

=head2 get_term

  Usage   - my $term = $graph->get_term(3677)
  Returns - GO::Model::Term object
  Args    - accession [as int]

=cut

sub get_term {
    my $self = shift;
    my ($acc, $template) =
      rearrange([qw(acc template)], @_);
    if (!$template || $template eq "shallow") {
	# shallow template, just get term attributes, no other
	# structs
	require GO::Model::Term;
	$template = GO::Model::Term->get_template($template);
    }
    my $obj = $self->obj;
    my $t_struct = $template->to_idl_struct;
    my $termh = 
      $obj->get_term($acc, $t_struct);
    return $self->create_term_from_idl($termh);
}

sub get_associations {
    my $self = shift;
    my ($term, $template) =
      rearrange([qw(term template)], @_);
    
    my $ptr = $self->obj->get_association_iterator($term->acc);
    my $n = $ptr->n_associations;
    my $assoc_str_l = $ptr->get_next_n_associations;
    my @assocs =
      map {
	  $_->from_idl($_, $self->apph);
      } @$assoc_str_l;
    return \@assocs;
}

=head2 get_association_iterator

  Usage   -
  Returns -
  Args    -

=cut

sub get_association_iterator {
    my $self = shift;
    my $ptr = $self->obj->get_association_iterator(@_);
    return GO::CorbaClient::AssociationIterator->new($ptr);
}

sub create_term_from_idl {
    my $self = shift;
    my $struct = shift;
    my $term = GO::Model::Term->from_idl($struct);
    $term->apph($self->apph);
    return $term;
}


sub AUTOLOAD {
    
    my $self = shift;
 
    my $name = $AUTOLOAD;
    $name =~ s/.*://;   # strip fully-qualified portion

    if ($name eq "DESTROY") {
	# we dont want to propagate this!!
	return;
    }


#    print STDERR "Autoloading $self $name\n";
    if ($self->obj->can($name)) {
	my $rv = $self->obj->$name(@_);
#	print $rv;
	return $rv;
    }
    else {
	confess($self->obj()." $name not implemented");
    }
}


1;

