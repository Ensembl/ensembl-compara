package Bio::EnsEMBL::Compara::RunnableDB::MemberDisplayLabelUpdater;

=pod

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::MemberDisplayLabelUpdater

=head1 SYNOPSIS

Normally it is used as a RunnableDB however you can run it using the non-hive
methods:

	my $u = Bio::EnsEMBL::Compara::RunnableDB::MemberDisplayLabelUpdater->new_without_hive(
	 -DB_ADAPTOR => $compara_dba,
	 -REPLACE => 0,
	 -DIE_IF_NO_CORE_ADAPTOR => 0,
	 -GENOME_DB_IDS => [90],
	 -DEBUG => 1 
	);
	$u->run_without_hive();
	
This would run an updater on the GenomeDB ID 90 (Homo sapiens normally) not
dying if it cannot find a core DBAdaptor & printing debug messages to STDOUT. 
By not specifying a GenomeDB ID you are asking to run this code over every
GenomeDB. 

Using it in the hive manner expects the above values (lowercased) filled in 
any of the fields ProcessWithParams can detect values in. The exception to 
this is db_adaptor which is created from the current Hive DBAdaptor instance.

=head1 DESCRIPTION

This module loops through the known GenomeDBs or the specified GenomeDB & 
attempts to update any gene or translation with the display identifier from 
the core database. This code uses direct SQL statements because of the
relationship between translations and their display labels being stored at the
transcript level. If the DB changes this will break.

The set of GenomeDBs are all Genome DBs with members.

=head1 AUTHOR

Andy Yates

=head1 MAINTANER

$Author$

=head1 VERSION

$Revision$

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with a _

=cut

use strict;
use warnings;

use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use Bio::EnsEMBL::Utils::Exception qw(throw);
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;

use base qw(Bio::EnsEMBL::Hive::ProcessWithParams);

#--- Non-hive methods
=head2 new_without_hive()

  Arg [DB_ADAPTOR]              : (DBAdaptor) Compara DBAdaptor to use
  Arg [REPLACE]                 : (Boolean)   Forces the code to replace display labels 
  Arg [DIE_IF_NO_CORE_ADAPTOR]  : (Boolean)   Kills the process if there is no core adaptor
  Arg [GENOME_DB_IDS]           : (ArrayRef)  GenomeDB IDs to run this process over
  Arg [DEBUG]                   : (Boolean)   Force debug output to STDOUT
  
  Example    : See synopsis
  Description: Non-hive version of the object construction to be used with scripts
  Returntype : Bio::EnsEMBL::Compara::RunnableDB::MemberDisplayIdUpdater
  Exceptions : if DB_ADAPTOR was not given and was not a valid object
  Caller     : general

=cut

sub new_without_hive {
  my ($class, @params) = @_;
  my $self = bless {}, $class;
  
  my ($db_adaptor, $replace, $die_if_no_core_adaptor, $genome_db_ids, $debug) = rearrange(
    [qw(db_adaptor replace die_if_no_core_adaptor genome_db_ids debug)], 
  @params);
  
  $self->db_adaptor($db_adaptor);
  $self->replace($replace) if defined $replace;
  $self->die_if_no_core_adaptor($die_if_no_core_adaptor) if defined $die_if_no_core_adaptor;
  $self->genome_db_ids($genome_db_ids) if defined $genome_db_ids;
  $self->debug($debug) if defined $debug;
  
  $self->_assert_state();
  
  return $self;
}

=head2 run_without_hive()

Performs the run() and write_output() calls in one method.

=cut

sub run_without_hive {
  my ($self) = @_;
  $self->run();
  $self->write_output();
  return;
}

#--- Hive methods

my @PARAMS = qw(db_adaptor replace die_if_no_core_adaptor genome_db_id);

=head2 fetch_input

    Title   :   fetch_input
    Usage   :   $self->fetch_input
    Function:   prepares global variables and DB connections
    Returns :   none
    Args    :   none

=cut

sub fetch_input {
  my ($self) = @_;
  
  #Defaults
  foreach my $param (@PARAMS) {
    my $value = $self->param($param);
    $self->can($param)->($self, $param);
  }
  
  #DBAdaptor
  my $dba = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(-DBCONN => $self->db()->dbc());
  $self->db_adaptor($dba);
  
  $self->_assert_state();
  $self->_print_params();
  
  return 1;
}

sub _print_params {
  my ($self) = @_;
  return unless $self->debug();
  foreach my $param (@PARAMS) {
    my $value = $self->can($param)->($self);
    print "$param : ".(defined $value ? q{} : $value), "\n"; 
  }
}

=head2 run

    Title   :   run
    Usage   :   $self->run
    Function:   Retrives the Members to update
    Returns :   none
    Args    :   none

=cut

sub run {
  my ($self) = @_;
  
  my $genome_dbs = $self->_genome_dbs_to_work_with();
  if($self->debug()) {
    my $names = join(q{, }, map { $_->name() } @{$genome_dbs});
    print "Working with: [${names}]\n";
  }
  
  foreach my $genome_db (@{$genome_dbs}) {
    my $output = $self->_process_genome_db($genome_db);
    $self->_add_to_process_list($genome_db, $output);
  }
  
  return 1;
}

=head2 write_output

    Title   :   write_output
    Usage   :   $self->write_output
    Function:   Writes the display labels/members back to the Compara DB
    Returns :   none
    Args    :   none

=cut

sub write_output {
  my ($self) = @_;
  
  my $genome_dbs = $self->_genome_dbs_to_work_with();
  foreach my $genome_db (@{$genome_dbs}) {
    $self->_update_genome_db($genome_db);
  }
  
  return 1;
}

#--- Generic accessors

=head2 db_adaptor()

The database adaptor for Compara. Must be given

=cut

sub db_adaptor {
  my ($self, $db_adaptor) = @_;
  $self->{db_adaptor} = $db_adaptor if defined $db_adaptor;
  return $self->{db_adaptor};
}

=head2 replace()

Normal logic says if there is already a display identifier for a member then
we do not update it. However if this is set to true then we will replace it.

=cut

sub replace {
  my ($self, $replace) = @_;
  $self->{replace} = $replace if defined $replace;
  return $self->{replace};
}

=head2 die_if_no_core_adaptor()

Set to true if you want the updater to die when we encounter a genome db with
no db_locator. This is a situation which we can find ourselves in if we are
working with externally donated comparas.

=cut

sub die_if_no_core_adaptor {
  my ($self, $die_if_no_core_adaptor) = @_;
  $self->{die_if_no_core_adaptor} = $die_if_no_core_adaptor if defined $die_if_no_core_adaptor;
  return $self->{die_if_no_core_adaptor};
}

=head2 genome_db_ids()

Will return the GenomeDB IDs we are using; can be left blank (which causes the
module to work over all GenomeDBs)

=cut

sub genome_db_ids {
  my ($self, $genome_db_ids) = @_;
  if(defined $genome_db_ids) {
    throw( 'Not an array or no data: ['.$genome_db_ids.']')
      unless ref($genome_db_ids) eq 'ARRAY' && @{$genome_db_ids};
    $self->{genome_db_ids} = $genome_db_ids;
  }
  return $self->{genome_db_ids};
}

sub _add_to_process_list {
  my ($self, $genome_db, $members) = @_;
  return unless defined $members && ref($members) eq 'ARRAY' && @{$members};
  my $id = $genome_db->dbID();
  throw('Already have data for GenomeDB '.$id) if exists $self->{_process_list}->{$id};
  $self->{_process_list}->{$id} = $members;
  return;
}

sub _process_list {
  my ($self, $genome_db) = @_;
  return $self->{_process_list}->{$genome_db->dbID()};
}

#--- Generic Logic

sub _assert_state {
  my ($self) = @_;
  my $dba = $self->db_adaptor();
  throw('A suitable Compara DBAdaptor was not found') 
    unless defined $dba;
  throw('Found DBAaptor is not a Bio::EnsEMBL::Compara::DBSQL::DBAdaptor') 
    unless $dba->isa('Bio::EnsEMBL::Compara::DBSQL::DBAdaptor');
  return;
}

sub _genome_dbs_to_work_with {
	my ($self) = @_;
	my @ids;
	if(defined $self->genome_db_ids()) {
	  @ids = @{$self->genome_db_ids()};
	}
	else {
    my $sql = q{select distinct genome_db_id from member where genome_db_id is not null and genome_db_id <> 0};
    @ids = map {$_->[0]} @{$self->_compara_execute_to_array($sql)};
	}
  my $gdba = $self->db_adaptor()->get_GenomeDBAdaptor();  
  my @genome_dbs = map { $gdba->fetch_by_dbID($_) } @ids;
	return \@genome_dbs;
}

sub _process_genome_db {
	my ($self, $genome_db) = @_;
	
	my $name = $genome_db->name();
	
	print "Processing ${name}\n" if $self->debug();
	
	if(!$genome_db->db_adaptor()) {
		throw('Cannot get an adaptor for GenomeDB '.$name) if $self->die_if_no_adaptor();
		return;
	}
	
	my $dispatch = {
	  'ENSEMBLGENE'  => sub {
	    return $self->_get_genes($genome_db);
	  },
	  'ENSEMBLPEP'   => sub {
	    return $self->_get_translations($genome_db);
	  } 
	};
	
	my @members_to_update;
	foreach my $source (keys %{$dispatch}) {
	  print "Working with ${source}\n" if $self->debug();
	  my $subroutine = $dispatch->{$source};
	  if(!$self->_need_to_process_genome_db_source($genome_db, $source) && !$self->replace()) {
	    if($self->debug()) {
	      print "No need to update as all members for ${name} and source ${source} have display labels\n";
	    }
	    next;
	  }
	  my $results = $self->_process($genome_db, $source, $subroutine);
	  push(@members_to_update, @{$results});
	}
	
	return \@members_to_update;
}

sub _process {
  my ($self, $genome_db, $source, $subroutine) = @_;
  
  my @members_to_update;
  
  my $core_labels = $subroutine->();
  my $members = $self->_get_members_by_source($genome_db, $source);
  
  if(%{$members}) {
    foreach my $stable_id (keys %{$members}) {
      my $member = $members->{$stable_id};
      
      #Skip if it's already got a label & we are not replacing things
      next if defined $member->display_label() && !$self->replace();
      
      my $display_label = $core_labels->{$stable_id};
      #Next if there was no core object for the stable ID
      next if ! defined $display_label;
      $member->display_label($display_label);
      push(@members_to_update, $member);
    }
  }
  else {
    my $name = $genome_db->name();
    print "No members found for ${name} and ${source}\n" if $self->debug();
  }
	
	return \@members_to_update;
}

sub _need_to_process_genome_db_source {
	my ($self, $genome_db, $source) = @_;
	my $sql = q{select count(*) from member where genome_db_id =? and display_label is null and source_name =?};
	my $results = $self->_compara_execute_to_array($sql, $genome_db->dbID(), $source);
	return $results->[0] if @{$results};
	return 0;
}

sub _get_members_by_source {
	my ($self, $genome_db, $source) = @_;
	my $member_a = $self->db_adaptor()->get_MemberAdaptor();
	my $gdb_id = $genome_db->dbID();
	my $constraint = qq(m.source_name = '${source}' and m.genome_db_id = ${gdb_id});
	my $members = $member_a->_generic_fetch($constraint);
	my $members_hash = {};
	foreach my $member (@{$members}) {
		$members_hash->{$member->stable_id()} = $member;
	}
	return $members_hash;
}

sub _get_genes {
  my ($self, $genome_db) = @_;
  
  my $sql = q{select gsi.stable_id, x.display_label 
from gene_stable_id gsi 
join gene g using (gene_id)  
join xref x on (g.display_xref_id = x.xref_id) 
join seq_region sr on (g.seq_region_id = sr.seq_region_id) 
join coord_system cs using (coord_system_id) 
where cs.species_id =?};

  return $self->_run_mapper_sql($genome_db, $sql);
}

sub _get_translations {
  my ($self, $genome_db) = @_;
  
  my $sql = q{select tsi.stable_id, x.display_label 
from translation_stable_id tsi 
join translation tr using (translation_id) 
join transcript t using (transcript_id) 
join xref x on (t.display_xref_id = x.xref_id) 
join seq_region sr on (t.seq_region_id = sr.seq_region_id) 
join coord_system cs using (coord_system_id) 
where cs.species_id =?};

  return $self->_run_mapper_sql($genome_db, $sql);
}

sub _run_mapper_sql {
  my ($self, $genome_db, $sql) = @_;
  my $dba = $genome_db->db_adaptor();
	my $original_dwi = $dba->dbc()->disconnect_when_inactive();
  $dba->dbc()->disconnect_when_inactive(0);
  my $hash = $self->_execute_to_hash($dba, $sql, $dba->species_id());
  $genome_db->db_adaptor()->dbc()->disconnect_if_idle();
	$dba->dbc()->disconnect_when_inactive($original_dwi);
	return $hash;
}

sub _set_into_hash {
  my ($self, $hash, $stable_id, $core_object) = @_;
  my $display_xref = $core_object->display_xref();
  if(defined $display_xref) {
    $hash->{$stable_id} = $display_xref->display_id();
  }
  return;
}

sub _update_genome_db {
	my ($self, $genome_db) = @_;
	
	my $members = $self->_process_list($genome_db);
	my $name = $genome_db->name();
	
	if(! defined $members) {
	  print "No members to write back for ${name}\n" if $self->debug();
	  return;
	}
	
  print "Writing members out for ${name}\n" if $self->debug();
	
	my $total = 0;
	my $dbc = $self->db_adaptor()->dbc();
	my $handle = $dbc->db_handle();
	
	#Forcing the code to prevent early connection termination & turn on transactions (InnoDB only affected)
  my $original_dwi = $dbc->disconnect_when_inactive();
  $dbc->disconnect_when_inactive(0);
	my $ac = $handle->{'AutoCommit'};
  $handle->{'AutoCommit'} = 0;
  
	my $sql = 'update member set display_label =? where member_id =?';
	my $sth;
	my $last_member;
	eval {
	 $sth = $dbc->prepare($sql);
	 foreach my $member (@{$members}) {
	   $last_member = $member;
	   my $rows_affected = $sth->execute($member->display_label(), $member->dbID());
	   $total += $rows_affected;
	 }
	 $handle->commit();
	};
	
	#Cleanup statement, rollback, reset AC and DWI
	my $error = $@;
	eval { $sth->finish() if defined $sth; };
	eval { $handle->rollback() if $error; };
	$handle->{'AutoCommit'} = $ac;
	$dbc->disconnect_when_inactive($original_dwi);
	
	if($error) {
	  throw('Cannot insert member '.$last_member->stable_id().' because of error raised during insertion: '.$error);
	}
	
	print "Inserted ${total} member(s) for ${name}\n" if $self->debug();
	
	return $total;
}

sub _compara_execute_to_array {
  my ($self, $sql, @params) = @_;
  return $self->_execute_to_array($self->db_adaptor(), $sql, @params);
}

sub _execute_to_array {
  my ($self, $db_adaptor, $sql, @params) = @_;
  my $dbc = $db_adaptor->dbc();
  my @res;
  my $sth;
  eval {
    $sth = $dbc->prepare($sql);
    $sth->execute(@params);
  };
  my $error= $@;
  
  if(! $error) {
    while(my $row = $sth->fetchrow_arrayref()) {
      push(@res, [@{$row}]);
    }
  }
  eval { $sth->finish(); };
  
  throw("Error when executing '${sql}' with params [@params]: $error") if $error;
  
  return \@res;
}

sub _execute_to_hash {
  my ($self, $db_adaptor, $sql, @params) = @_;
  my $results = $self->_execute_to_array($db_adaptor, $sql, @params);
  my %hash = map { @{$_} } @{$results};
  return \%hash;
}

1;