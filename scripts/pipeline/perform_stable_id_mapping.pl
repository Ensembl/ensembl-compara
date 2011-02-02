#!/usr/bin/env perl

use strict;
use warnings;

use Bio::EnsEMBL::Registry;
use Getopt::Long;
use Pod::Usage;
use Bio::EnsEMBL::Compara::RunnableDB::StableIdMapper;

my $OPTIONS = options();
run();

sub options {
  my $opts = {};
  my @flags = qw(
    reg_conf=s database=s previous_database=s master=s release=i 
    previous_release=i type=s help man
  );
  GetOptions($opts, @flags) or pod2usage(1);
  
  _exit( undef, 0, 1) if $opts->{help};
	_exit( undef, 0, 2) if $opts->{man};
	
	_exit('No -database given', 1, 1) unless $opts->{database};
  _exit('No -reg_conf given', 1, 1) unless $opts->{reg_conf};
  _exit('No -previous_database given', 1, 1) unless $opts->{previous_database};
  _exit('No -release given', 1, 1) unless $opts->{release};
  _exit('No -previous_release given', 1, 1) unless $opts->{previous_release};
  _exit('No -type given', 1, 1) unless $opts->{type};
  
  if(! $opts->{master}) {
    $opts->{master} = 'compara-master';
  }
  
  #Loading the registry finally
  if(! -f $opts->{reg_conf}) {
    die 'Cannot find the given -reg_conf location '.$opts->{reg_conf};
  }
  Bio::EnsEMBL::Registry->load_all($opts->{reg_conf});
	
  return $opts;
}

sub run {
  my $r = _build_runnable();
  $r->run_without_hive();
  return;
}

sub _build_runnable {
  my $r = Bio::EnsEMBL::Compara::RunnableDB::StableIdMapper->new_without_hive(
    -DB_ADAPTOR => _get_dba($OPTIONS->{database}, 'compara'),
    -TYPE => $OPTIONS->{type},
    -RELEASE => $OPTIONS->{release},
    -PREV_RELEASE => $OPTIONS->{previous_release},
    -PREV_RELEASE_DB => _get_dba($OPTIONS->{previous_database}, 'compara'),
    -MASTER_DB => _get_dba($OPTIONS->{master}, 'compara')
  );
  
  return $r;
}

sub _get_dba {
  my ($species, $group) = @_;
  my $dba = Bio::EnsEMBL::Registry->get_DBAdaptor($species, $group);
  if(! defined $dba) {
    _exit("No database found in the registry for ${species} and ${group}", 2, 1);
  }
  return $dba;
}

sub _exit {
  my ($msg, $status, $verbose) = @_;
  print STDERR $msg, "\n" if defined $msg;
  pod2usage( -exitstatus => $status, -verbose => $verbose );
}

1;
__END__

=pod

=head1 NAME

perform_stable_id_mapping.pl

=head1 SYNOPSIS

  ./perform_stable_id_mapping.pl -reg_conf REG -database DB -release REL -previous_database DB -previous_release PREV_REL -type TYPE [-master MASTER] [-help | -man]
  
=head1 DESCRIPTION

This module provides a very thin wrapper around the runnables provided by
Ensembl for mapping releases of GeneTrees between releases. This
version requires a registry which has the current database, previous database
and the master database registered.

=head1 OPTIONS

=over 8

=item B<--reg_conf>

The registry file to use 

=item B<--database>

The database with the next release in

=item B<--release>

The release number for this propagation

=item B<--previous_database>

The source of identifiers for this session

=item B<--previous_release>

The release number for the source of the identifiers

=item B<--type>

The type of mapping to perform. Must be set to f (for Family) or t (for
GeneTrees).

=item B<--master>

The master database name; will default to compara-master if not given

=item B<--help>

This help message

=item B<--manual>

The manual page

=back 

=head1 AUTHOR

Andrew Yates

=head1 MAINTAINER

$Author$

=head1 VERSION

$Revision$

=cut