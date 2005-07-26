# $Id$
#
# This GO module is maintained by Chris Mungall <cjm@fruitfly.org>
#
# see also - http://www.geneontology.org
#          - http://www.fruitfly.org/annot/go
#
# You may distribute this module under the same terms as perl itself

#!perl -w 
#
# DebugUtils.pm
# Copyright Berkeley Drosophila Genome Project 1999
#
# Miscellaneous debugging utilities
#

package GO::DebugUtils;

=head1 NAME

GO::DebugUtils

=head1 DESCRIPTION

Miscellaneous debugging utilities


=cut

use Exporter;

@EXPORT_OK = qw(printErrorLine printDebugLine 
		sqllog dblog msglog setsqllog setdblog setlog);
%EXPORT_TAGS  = 
  (all=> [qw(printErrorLine printDebugLine 
		sqllog dblog msglog setsqllog setdblog setlog)],
   sql=> [qw(sqllog setsqllog)],
   db=>  [qw(dblog setdblog)],
   general=> [qw(msglog setlog)]);

@GO::DebugUtils::ISA = qw (Exporter);

# Behavior Constants - public

$::DEBUG = 0;
$::VERBOSE = 0;
$::STDERR_TO_STDOUT = 0;


use strict;

# - - - - - - - - - - - PROGRAM FLOW - - - - - - - - - - - - 


*GO::DebugUtils::LOGF = *STDERR;
*GO::DebugUtils::DBLOGF = *STDERR;
*GO::DebugUtils::SQLLOGF = *STDERR;

=head1 FUNCTIONS

=head2 setsqllog

 usage:

  use GO::DebugUtils qw(:sql);
  open(MYLOGFILE, ">x.log");
  $ENV{SQL_TRACE} = 1;
  setdblog(\*MYLOGFILE);
  # ... main code here
  close(MYLOGFILE);

  defaults to STDERR

=cut

sub setsqllog {
    *SQLLOGF = shift;
}

=head2 setdblog

 usage:

  use GO::DebugUtils qw(:db);
  open(MYLOGFILE, ">x.log");
  $ENV{DBLOGGING} = 1;
  setdblog(\*MYLOGFILE);
  # ... main code here
  close(MYLOGFILE);

  defaults to STDERR

=cut

sub setdblog {
    *DBLOGF = shift;
}

=head2 setlog

 usage:

  use GO::DebugUtils qw(:general);
  open(MYLOGFILE, ">x.log");
  $ENV{MSGLOGGING} = 1;
  setdblog(\*MYLOGFILE);
  # ... main code here
  close(MYLOGFILE);

  defaults to STDERR

=cut

sub setlog {
    *LOGF = shift;
}

=head2 msglog

outputs a log message. if the environment variable MSGLOGGING is not
set, this function will do nothing.

use the function L<setlog> to set a logging file; otherwise output will
default to STDERR

this is for general logging messages

usage:

  msglog("logging message");


=cut

sub msglog {
    if ($ENV{MSGLOGGING}) {
	my $string = shift;
	print LOGF "$string.\n";
    }
}

=head2 dblog

outputs a db log message. if the environment variable DBLOGGING is not
set, this function will do nothing.

use the function L<setdblog> to set a logging file; otherwise output will
default to STDERR

for consistency, this should be used to a produce a high level
description of operations performed to modify the database

usage:

  dblog("add the clone and associated data");


=cut

sub dblog {
    if ($ENV{DBLOGGING}) {
	my $string = shift;
	print DBLOGF "DBLOG:$string.\n";
    }
}

=head2 sqllog

outputs an sql log message. if the environment variable SQL_TRACE is
not set, this function will do nothing.

use the function L<setsqllog> to set a logging file; otherwise output will
default to STDERR

this should be used to produce an output of SQL commands executed

usage:

  sqllog("$sql_command");


=cut

sub sqllog {
    my $string = shift;
    if ($ENV{SQL_TRACE}) {
	print SQLLOGF "SQL:$string\n";
    }
#    print "<pre>SQL is $string</pre>";
}

sub printDebugLine
  {
    my ($string, $verbose_only) = @_;
    
    if ($::DEBUG || $ENV{DEBUG})
      {
	if ($verbose_only && (!$::VERBOSE && !$ENV{VERBOSE}))
	  {
	  }
	else
	  {
	    if ($::STDERR_TO_STDOUT)
	      {
		print "${string}\n";
	      }
	    else
	      {
		print STDERR "${string}\n";
	      }
	  }
      }
  }


sub printErrorLine
  {
    my ($string, $verbose_only) = @_;
    
    if ($::STDERR_TO_STDOUT)
      {
	print "${string}\n";
      }
    else
      {
	print STDERR "${string}\n";
      }
  }



1;
