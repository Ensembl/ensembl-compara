# $Id$
#
# This GO module is maintained by Chris Mungall <cjm@fruitfly.org>
#
# see also - http://www.geneontology.org
#          - http://www.fruitfly.org/annot/go
#
# You may distribute this module under the same terms as perl itself


package GO::CorbaServer::Session;
use vars qw($AUTOLOAD @ISA);
use strict;

use GO::CorbaServer::Base;
use GO::CorbaServer::Graph;
use GO::CorbaServer::AssociationIterator;
use GO::MiscUtils qw(dd);
use Error;

@ISA = qw( GO::CorbaServer::Base POA_GO::Session);

sub _initialize {
    my $self = shift;
    $self->SUPER::_initialize(@_);

}

sub apph {
    my $self = shift;
    $self->config->apph(@_);
}

sub get_graph_by_acc {
    my $self = shift;
    my $acc=shift;
    my $depth=shift;

    my $servant = GO::CorbaServer::Graph->new($self->poa, 
					      {config=>$self->config});
    $servant->extend_by_acc($acc, $depth);
    $self->log("Got a ".ref($servant)."... about to activate...");
    my $id = $self->poa->activate_object ($servant); 
    my $other = $id;
    my $temp = $self->poa->id_to_reference($id);
    return $temp;
}

sub get_stats {
    my $self = shift;
    require GO::Stats;

    my $stats = GO::Stats->new($self->dbh);
    my @tags = @{$stats->get_tags};
    my @plist = ();
    for (my $i=0; $i < @tags; $i+=2) {
	push(@plist, {name=>$tags[$i], value=>$tags[$i+1]});
    }
    return \@plist;
}

sub get_graph_by_search {
    my $self = shift;

    my $servant = GO::CorbaServer::Graph->new($self->poa, 
					      {config=>$self->config});
    $self->log("Got a ".ref($servant)."... about to activate...");
    my $id = $self->poa->activate_object ($servant);  
    my $other = $id;
    my $temp = $self->poa->id_to_reference($id);
    $servant->extend_by_search(@_);
    return $temp;
}

sub deep_association_list {
    my $self = shift;
    my $acc = shift;
    $self->config->obj_cache->deep_association_list($acc);
}

sub get_association_iterator {
    my $self = shift;
    my $acc = shift;
    my $term = $self->config->obj_cache->get_term($acc);

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

    print STDERR "autoloading $name\n";
    my $apph=$self->apph;
    if ($apph->can($name)) {
	
	my $rv;
	eval {
	    no strict qw (refs);
	    $rv= $apph->$name($self->dbh, @_);
#	    dd($rv);
	};
	if ($@) {
	    throw GO::ProcessError(reason=>"err:$@");
	}
	if (ref($rv)) {
	    if (ref($rv) eq "ARRAY") {
		return [map {$_->to_idl_struct} @$rv];
	    }
	    else {
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

