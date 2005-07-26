# $Id$
#
# This GO module is maintained by Chris Mungall <cjm@fruitfly.org>
#
# see also - http://www.geneontology.org
#          - http://www.fruitfly.org/annot/go
#
# You may distribute this module under the same terms as perl itself


=head1 NAME

GO::CorbaServer::Config

=head1 SYNOPSIS

=head1 DESCRIPTION

Configurations object

When this  object   is instantiated, it  will   set up  various config
settings, described below

the order of precedence is:

1 - config file - usually ./go_server.config, but the config file
can be overridden with env var GOSERVER_CONFFILE

the config file is a list of settings, one per line, eg

xmlbasedir /users/me/data
xmlreldir  go-data
dbname     go

2 - environment variables

all these are preceeded by GOSERVER_ and are in caps; eg

GOSERVER_DBNAME
GOSERVER_SERVERLOG

3 - default values

see the code for defaults

//////

any setting can be overridden any time during the config objects lifecycle

config objects can be duplicated and bassed to other configurable
objects throughout a process lifetime


=head1 FEEDBACK

=head1 AUTHOR - Chris Mungall

Email: cjm@fruitfly.org

=head1 APPENDIX

The rest of the documentation details each of the object
methods. Internal methods are usually preceded with a _

=cut

package GO::CorbaServer::Config;
use FileHandle;
use Carp;
use vars qw($AUTOLOAD @ISA);
use strict;

sub new {
    my $class = shift;
    my $h = shift ||{};
    my $self = {};
    bless $self,$class;
    if (!$h->{empty}) {
	$self->_set_defaults();
    }
    return $self;
}


sub can_write_to_db {
    my $self = shift;
    my $dbh = $self->dbh;
    warn("Deprecated");
    if (!$dbh) {
	throw GO::ProcessError(reason=>"not connected");
    }
    if ($dbh->{private_database_name} =~ /test/) {
	return 1;
    }
    else {
	return 0;
    }
}

sub apph_params {
    qw(dbname dbiproxy serverlog);
}

sub _set_defaults {
    my $self = shift;
    my $conffile = $ENV{GOSERVER_CONFFILE} || "./go_server.config";
    
    my @conf = ();
    if (-f $conffile) {
	my $fh = FileHandle->new($conffile);
	if (!$fh) {
	    warn("Can't open $conffile; using defaults");
	}
	else {
	    while (<$fh>) {
		chomp;
		my ($k, @v) = split(' ', $_);
		if (grep {$k eq $_} $self->apph_params) {
		    push(@conf, "-$k"=>(join(" ", @v)));
		}
	    }
	    $fh->close;
	}
    }
    require GO::AppHandle;
    $self->apph(GO::AppHandle->connect(\@conf));
    my %h = @conf;
    $self->serverlog($ENV{GO_SERVERLOG} || 
		     $h{"-serverlog"} || "go_server.log");
}


=head2 apph

  Usage   -
  Returns -
  Args    -

=cut

sub apph {
    my $self = shift;
    $self->{apph} = shift if @_;
    return $self->{apph};
}


sub dbh {
    my $self = shift;
    return $self->apph->dbh;
}


=head2 obj_cache

  Usage   -
  Returns -
  Args    -

=cut

sub obj_cache {
    my $self = shift;
    warn("deprecated");
    $self->{_obj_cache} = shift if @_;
    return $self->{_obj_cache};
}


=head2 serverlog

  Usage   -
  Returns -
  Args    -

=cut

sub serverlog {
    my $self = shift;
    $self->{_serverlog} = shift if @_;
    return $self->{_serverlog};
}


=head2 serverlog_fh

  Usage   -
  Returns -
  Args    -

=cut

sub serverlog_fh {
    my $self = shift;
    if (!$self->{_serverlog_fh}) {
	$self->{_serverlog_fh} = 
	  FileHandle->new(">".$self->serverlog) || 
	    confess("Can't open log ".$self->serverlog);
    }
    return $self->{_serverlog_fh};
}



=head2 duplicate

  Usage   -
  Returns -
  Args    -

currently does shallow copy only

=cut

# need to use data dumper for deep copies if we introduce refs
sub duplicate {
    my $self = shift;
    my %h = %{$self};
    my $dupl = ref($self)->new({empty=>1});
    %{$dupl} =%h;
    return $dupl;
}




1;

