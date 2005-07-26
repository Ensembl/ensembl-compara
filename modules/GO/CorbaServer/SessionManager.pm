# $Id$
#
# This GO module is maintained by Chris Mungall <cjm@fruitfly.org>
#
# see also - http://www.geneontology.org
#          - http://www.fruitfly.org/annot/go
#
# You may distribute this module under the same terms as perl itself


=head1 NAME

GO::CorbaServer::SessionManager

=head1 SYNOPSIS

=head1 DESCRIPTION

corba servant class implementing SessionManager interface

=head1 FEEDBACK

=head2 Mailing Lists

gofriends@geneontology.org

=head1 AUTHOR - Chris Mungall

Email: cjm@fruitfly.org

=head1 APPENDIX

The rest of the documentation details each of the object
methods. Internal methods are usually preceded with a _

=cut


package GO::CorbaServer::SessionManager;
use vars qw($AUTOLOAD @ISA);
use strict;

#use GO::ObjCache;
use GO::CorbaServer::Base;
use GO::CorbaServer::Session;
use GO::CorbaServer::Config;

@ISA = qw( GO::CorbaServer::Base POA_GO::SessionManager);

sub initiate_Session {
    my $self = shift;
    my $param_list = shift;
    my $config = $self->config;

#    $self->connect_to_db;
    my $servant = GO::CorbaServer::Session->new($self->poa, 
						{config=>$config});
    $self->log("Got a ".ref($servant)."... about to activate...");
    my $id = $self->poa->activate_object ($servant);                         
    # seg faults if I don't touch id. Yikes
    my $other = $id;
    my $temp = $self->poa->id_to_reference($id);
    return $temp;
}

sub _initialize {
    my $self = shift;
    $self->SUPER::_initialize(@_);
    my $paramh = shift;
    $self->config(GO::CorbaServer::Config->new());
#DEPRECATED    $self->config->obj_cache(GO::ObjCache->new);
}


sub connect_to_db {
    my $self = shift;
    my $config = $self->config;
#    $config->obj_cache->apph($config->apph);
}


1;

