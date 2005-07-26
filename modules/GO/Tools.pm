# $Id$
#
# This GO module is maintained by Chris Mungall <cjm@fruitfly.org>
#
# see also - http://www.geneontology.org
#          - http://www.fruitfly.org/annot/go
#
# You may distribute this module under the same terms as perl itself


package GO::Tools;

=head1 NAME

GO::Tools

=head1 SYNOPSIS

DO NOT USE THIS METHOD DIRECTLY; use GO::AppHandle instead

=head1 DESCRIPTION

procedural wrapper to a go relational database. at some point this
module may be deprecated, and folded into GO::AppHandleSqlImpl. but
this should worry you, as you are now using GO::AppHandle, right?

=head1 FEEDBACK

Email cjm@fruitfly.berkeley.edu

=head1 INHERITED METHODS

=cut

use strict;
use GO::Utils qw(rearrange pset2hash dd);
use GO::Model::Xref;
use GO::Model::Term;
use GO::Model::Association;
use GO::Model::GeneProduct;
use GO::Model::Relationship;
use GO::Model::Graph;
use FileHandle;
use Carp;
use DBI;
use Exporter;
use vars qw(@ISA @EXPORT_OK %EXPORT_TAGS);
use GO::SqlWrapper qw(:all);

@ISA = qw(Exporter);
@EXPORT_OK = qw(get_handle add_term get_term add_relation retire_term
		undo_changes undo replace_term get_relationships
		generate_goid add_dbxref);
%EXPORT_TAGS = (all=> [@EXPORT_OK]);

=head1 PUBLIC METHODS

=cut

=head2 get_handle

=cut

sub get_handle {
    my $database_name = shift || confess("You must specify db name");

    warn("DEPRECATED! use GO::AppHandle->connect(-dbname=>$database_name)");
    my $dbms = $ENV{DBMS} || "Informix"; 
    my $dsn;
    $dsn = "dbi:$dbms:$database_name";
    if ($database_name =~ /\@/) {
      my ($dbn,$host) = split(/\@/, $database_name);
      $dsn = "dbi:$dbms:database=$dbn:host=$host";
    }
    if ($ENV{DBI_PROXY}) {
	$dsn = "$ENV{DBI_PROXY};dsn=$dsn";
    }
    #print "$dsn\n";
    my $dbh = DBI->connect($dsn, "root");
##    my $dbh = DBI->connect($dsn);
##    $dbh->{RaiseError} = 1;
    $dbh->{private_database_name} = $database_name;
    eval {$dbh->{AutoCommit} = 0};

    # default behaviour should be to chop trailing blanks;
    # this behaviour is preferable as it makes the semantics free
    # of physical modelling issues
    # e.g. if we have some code that compares a user supplied string
    # with a database varchar, this code will break if the varchar
    # is changed to a char, unless we chop trailing blanks
    $dbh->{ChopBlanks} = 1;
    return $dbh;
}



1;

confess "DEPRECATED";
