# $Id$
#
# This GO module is maintained by Chris Mungall <cjm@fruitfly.org>
#
# see also - http://www.geneontology.org
#          - http://www.fruitfly.org/annot/go
#
# You may distribute this module under the same terms as perl itself


=head1 NAME

  GO::CorbaClient::AssociationIterator;

=head1 SYNOPSIS

  you should not use this class directly

=head1 DESCRIPTION

  this is a simple wrapper to a corba AssociationIterator object (see
  the interface AssociationIterator in the idl); it passes requests to
  the object on the server, and translates the results into
  GO::Model::* objects

=cut

package GO::CorbaClient::AssociationIterator;
use vars qw($AUTOLOAD @ISA);
use strict;

use GO::MiscUtils qw(dd);
use Error qw(:try);
use CORBA::ORBit;

#@ISA = qw();

# shouldnt be called directly by api user
sub new {
    my $class = shift;
    my $self = {};
    bless $self, $class;
    $self->obj(@_);
    return $self;
}

sub obj {
    my $self = shift;
    $self->{_obj} = shift if @_;
    return $self->{_obj};
}


=head2 get_next_n_associations

  Usage   -
  Returns -
  Args    -

=cut

sub get_next_n_associations {
    my $self = shift;
    my $assocs = $self->obj->get_next_n_associations(@_);
    map {$_ = GO::Model::Association->from_idl($_)} @$assocs;
    return $assocs;
    
}


=head2 get_associations

  Usage   -
  Returns -
  Args    -

=cut

sub get_associations {
    my $self = shift;
    my $assocs = $self->obj->get_associations(@_);
    map {$_ = GO::Model::Association->from_idl($_)} @$assocs;
    return $assocs;
}


sub AUTOLOAD {
    
    my $self = shift;
 
    my $name = $AUTOLOAD;
    $name =~ s/.*://;   # strip fully-qualified portion

    if ($name eq "DESTROY") {
	# we dont want to propagate this!!
	return;
    }

    return $self->obj->$name(@_);
}


1;

