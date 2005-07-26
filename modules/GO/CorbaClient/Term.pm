# $Id$
#
# This GO module is maintained by Chris Mungall <cjm@fruitfly.org>
#
# see also - http://www.geneontology.org
#          - http://www.fruitfly.org/annot/go
#
# You may distribute this module under the same terms as perl itself


=head1 NAME

  GO::CorbaClient::Term;

=head1 DESCRIPTION

  simple wrapper to a Term object; mostly delegates calls to a
  GO::Model::Term object and queries additional data where required

=cut

package GO::CorbaClient::Term;
use vars qw($AUTOLOAD);
use strict;

use GO::Model::Term;
use GO::MiscUtils qw(dd);
use GO::Utils qw(rearrange);
use Error qw(:try);
use CORBA::ORBit;

# shouldnt be called directly by api user
sub new {
    my $class = shift;
    my $self = {};
    bless $self, $class;
    $self->model_obj(GO::Model::Term->new(@_));
    return $self;
}

sub model_obj {
    my $self = shift;
    $self->{_model_obj} = shift if @_;
    return $self->{_model_obj};
}

sub AUTOLOAD {
    
    my $self = shift;
 
    my $name = $AUTOLOAD;
    $name =~ s/.*://;   # strip fully-qualified portion

    if ($name eq "DESTROY") {
	# we dont want to propagate this!!
	return;
    }
    # this a slightly hacky way to intercept any calls
    # to association list / hash; this allows us to do
    # late binding of associations
    # TODO: fully expand this and not use autoload
    if ($name =~ /association/) {
	if (!$self->model_obj->association_list) {
	    print STDERR "Late binding of assoc list\n";
	}
    }

#    print STDERR "Autoloading $self $name\n";
    if ($self->model_obj->can($name)) {
	my $rv = $self->model_obj->$name(@_);
#	print $rv;
	return $rv;
    }
    else {
	confess($self->obj()." $name not implemented");
    }
}


1;

