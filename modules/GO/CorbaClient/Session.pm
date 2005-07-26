# $Id$
#
# This GO module is maintained by Chris Mungall <cjm@fruitfly.org>
#
# see also - http://www.geneontology.org
#          - http://www.fruitfly.org/annot/go
#
# You may distribute this module under the same terms as perl itself


=head1 NAME

  GO::CorbaClient::Session;

=head1 DESCRIPTION

  this is a simple wrapper to a corba Session object (see the
  interface Session in the idl); it passes requests to the object on
  the server, and translates the results into GO::Model::* objects

=cut

package GO::CorbaClient::Session;
use vars qw($AUTOLOAD @ISA);
use strict;

use Carp;
use GO::CorbaClient::Graph;
use GO::Utils qw(rearrange);
use GO::MiscUtils qw(dd);
use Error qw(:try);
use CORBA::ORBit;

use base qw(GO::AppHandle);


=head2 new

  Usage   - my $session = GO::CorbaClient::Session->new({ior_url=>$url});
  Returns - GO::CorbaClient::Session
  Args    - hashref - keys: ior_url, ior_file, idl_file

=cut

sub new {
    my $class = shift;
    my $self = {};
    bless $self, $class;
    $self->get_session(@_);
    return $self;
}

sub session {
    my $self = shift;
    $self->{_session} = shift if @_;
    return $self->{_session};
}

sub get_session {
    my $self = shift;
    my $conf = shift || {};
    CORBA::ORBit->import(idl => 
			 [ $conf->{idl_file} ||
			   ($ENV{GO_ROOT} ? "$ENV{GO_ROOT}/software/idl/go.idl": 'go.idl') ]);

    my $orb = CORBA::ORB_init("orbit-local-orb");

    my $ior_file = $conf->{ior_file} || "go_server.ior";
    # hacky fudge until we get nameservice
    if ($conf->{ior_url}) {
	$ior_file = "/tmp/$ENV{USER}-go-remote.ior";
	my $url = $conf->{ior_url};
	my $cmd = "wget -O $ior_file $url";
	`$cmd`;
    }

    open(F,"$ior_file") || die "Could not open $ior_file";
    my $ior = <F>;
    chomp $ior;
    close(F);
 
    my $mgr = $orb->string_to_object($ior);

    my $session = $mgr->initiate_Session([]);
    if (!$session) {confess;}
    print STDERR "got session:$session\n";
    $self->session($session);
}


=head2 get_graph_by_acc

  Usage   - my $graph = $session->get_graphy_by_acc(3677);
  Returns -
  Args    -

=cut

sub get_graph_by_acc {
    my $self = shift;
    my $graph_ptr = $self->session->get_graph_by_acc(@_);
    return GO::CorbaClient::Graph->new({stub=>$graph_ptr, apph=>$self});
}

sub get_graph {
    my $self = shift;
    return $self->get_graph_by_acc(@_);
}

sub get_associations {
    my $self = shift;
    my ($term, $template) =
      rearrange([qw(term template)], @_);
    
    my $ptr = $self->session->get_association_iterator($term->acc);
    my $n = $ptr->n_associations;
    my $assoc_str_l = $ptr->get_associations(0, $n);
    my @assocs =
      map {
	  $_->from_idl($_, $self->apph);
      } @$assoc_str_l;
    dd (\@assocs);
    return \@assocs;
}

=head2 get_association_iterator

  Usage   -
  Returns -
  Args    -

=cut

sub get_association_iterator {
    my $self = shift;
    my $ptr = $self->session->get_association_iterator(@_);
    return GO::CorbaClient::AssociationIterator->new($ptr);
}


=head2 get_graph_by_search

  Usage   -
  Returns -
  Args    -

=cut

sub get_graph_by_search {
    my $self = shift;
    my $graph_ptr = $self->session->get_graph_by_search(@_);
    GO::CorbaClient::Graph->new({stub=>$graph_ptr, apph=>$self});
}

=head2 get_parent_terms

  Usage   -
  Returns -
  Args    -

TO BE IMPLEMENTED

=cut

sub get_parent_terms {
    my $self = shift;
    warn("NOT IMPLEMENTED YET");
    return [];
}

1;

