# $Id$
#
# This GO module is maintained by Chris Mungall <cjm@fruitfly.org>
#
# see also - http://www.geneontology.org
#          - http://www.fruitfly.org/annot/go
#
# You may distribute this module under the same terms as perl itself



=head1 NAME

GO::CorbaServer::AssociationIterator

=head1 SYNOPSIS

=head1 DESCRIPTION

corba servant class implementing AssociationIterator interface

this class is pure implementation: the interface is the IDL interface
itself! see go.idl

=head1 FEEDBACK

=head2 Mailing Lists

gofriends@geneontology.org

=head1 AUTHOR - Chris Mungall

Email: cjm@fruitfly.org

=head1 APPENDIX

The rest of the documentation details each of the object
methods. Internal methods are usually preceded with a _

=cut



package GO::CorbaServer::AssociationIterator;
use vars qw($AUTOLOAD @ISA);
use strict;

use GO::CorbaServer::Base;
use GO::Model::Graph;
use GO::MiscUtils qw(dd);
use Error;

@ISA = qw( GO::CorbaServer::Base POA_GO::AssociationIterator);

sub _initialize {
    my $self = shift;
    $self->SUPER::_initialize(@_);
    $self->idx(0);
}

sub term {
    my $self = shift;
    $self->{term} = shift if @_;
    return $self->{term};
}

sub graph {
    my $self = shift;
    $self->{graph} = shift if @_;
    return $self->{graph};
}


# cursor index
sub idx {
    my $self = shift;
    $self->{idx} = shift if @_;
    return $self->{idx};
}

sub term_acc {
    my $self = shift;
    return $self->term->acc;
}

sub set_index {
    my $self = shift;
    $self->idx(@_);
}

sub get_index {
    my $self = shift;
    return $self->idx();
}

sub n_associations {
    my $self = shift;
    return scalar(@{$self->deep_association_list});

}

sub get_next_n_associations {
    my $self = shift;
    my $n = shift;
    my ($from, $to) = ($self->idx(), $n);
    $self->idx($to + $self->idx);
    return $self->return_assocs($from, $n);
}

sub get_associations {
    my $self = shift;
    my ($from, $n) = @_;
    $self->idx($from + $n);
    return $self->return_assocs($from, $n);
}

sub return_assocs {
    my $self = shift;
    my ($from, $n) = @_;
    my @assocs = @{$self->deep_association_list || []};
    my @list =
      splice(@assocs,
	     $from,
	     $n);
    dd \@list;
    my @structs = 
      map{
	  $_->to_idl_struct;
      } @list;

    return \@structs;
}

sub association_list {
    my $self = shift;
    return $self->term->association_list;
}

sub deep_association_list {
    my $self = shift;
    my $term = shift;
    return $self->graph->deep_association_list($self->term->acc);
}

1;

