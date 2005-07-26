# $Id$
#
# This GO module is maintained by Chris Mungall <cjm@fruitfly.org>
#
# see also - http://www.geneontology.org
#          - http://www.fruitfly.org/annot/go
#
# You may distribute this module under the same terms as perl itself



=head1 NAME

GO::CorbaServer::Graph

=head1 SYNOPSIS

=head1 DESCRIPTION

corba servant class implementing Graph interface

this class is pure implementation: the interface is the IDL interface
itself! see go.idl

  this is basically a delegation class that delegates to a
  GO::Model::Graph object

=head1 FEEDBACK

=head2 Mailing Lists

gofriends@geneontology.org

=head1 AUTHOR - Chris Mungall

Email: cjm@fruitfly.org

=head1 APPENDIX

The rest of the documentation details each of the object
methods. Internal methods are usually preceded with a _

=cut


package GO::CorbaServer::Graph;
use vars qw($AUTOLOAD @ISA);
use strict;

use GO::CorbaServer::Base;
use GO::CorbaServer::AssociationIterator;
use GO::Model::Graph;
use GO::MiscUtils qw(dd);
use Error;

@ISA = qw( GO::CorbaServer::Base POA_GO::Graph);

sub _initialize {
    my $self = shift;
    $self->SUPER::_initialize(@_);
    $self->model_obj(GO::Model::Graph->new);
}

# the actual Graph object
sub model_obj {
    my $self = shift;
    $self->{model_obj} = shift if @_;
    return $self->{model_obj};
}

sub get_child_terms {
    my $self = shift;
    my ($acc, $template) = @_;
    my $nodes = $self->model_obj->get_child_terms($acc);
    return [map {$_->to_idl_struct($template)} @$nodes];
}

sub get_term {
    my $self = shift;
    my ($acc, $template) = @_;
    my $term = $self->model_obj->get_term($acc);
    if (!$term) {
	throw GO::NoSuchEntity();
    }
    return $term->to_idl_struct($template);
}

sub extend_by_acc {
    my $self = shift;
    my ($acc,$depth) = shift;
    
    my $obj_cache = $self->config->obj_cache;
    $obj_cache->extend_graph_by_acc($self->model_obj, $acc,$depth);
}

sub extend_by_search {
    my $self = shift;
    my ($search ,$depth) = shift;
    
    my $obj_cache = $self->config->obj_cache;
    $obj_cache->extend_graph_by_search($self->model_obj, $search, $depth);
}

sub deep_association_list {
    my $self = shift;
    my $acc = shift;
    $self->config->obj_cache->deep_association_list($acc);
}

sub get_association_iterator {
    my $self = shift;
    my $acc = shift;
    my $term = $self->model_obj->get_term($acc);

    if (!$term) {
	print STDERR "WARNING! no term for $acc\n";
	return;
    }

    my $servant = GO::CorbaServer::AssociationIterator->new($self->poa);
    $servant->term($term);
    $servant->graph($self);
    $self->log("Got a ".ref($servant)."... about to activate...");
    my $id = $self->poa->activate_object ($servant); 
    my $other = $id;
    my $temp = $self->poa->id_to_reference($id);
    return $temp;
}

sub AUTOLOAD {
    
    my $self = shift;
 
    my $name = $AUTOLOAD;
    $name =~ s/.*://;   # strip fully-qualified portion

    if ($name eq "DESTROY") {
	# we dont want to propagate this!!
	return;
    }

    my $obj = $self->model_obj;

    print STDERR "autoloading $name\n";
    if ($obj->can($name)) {
	
	my $rv;
	eval {
	    no strict qw (refs);
	    $rv= $obj->$name(@_);
#	    dd($rv);
	};
	if ($@) {
	    dd($@);
	    throw GO::ProcessError(reason=>"err:$@");
	}
	if (ref($rv)) {
	    if (ref($rv) eq "ARRAY") {
		return [map {$_->to_idl_struct} @$rv];
	    }
	    else {
#		dd ($rv->to_idl_struct);
		return $rv->to_idl_struct;
	    }
	}
	else {
	    return $rv;
	}
    }
    else {
	confess("can't do $name");
    }
    
}


1;

