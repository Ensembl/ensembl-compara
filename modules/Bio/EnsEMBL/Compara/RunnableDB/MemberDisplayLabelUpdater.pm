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
any of the fields Process can detect values in. The exception to 
this is db_adaptor which is created from the current Hive DBAdaptor instance.

=head1 DESCRIPTION

When run in hive mode the module loops through all genome db ids given via
the parameter C<genome_db_ids> and attempts to update any gene/translation
with the display identifier from the core database.

When run in non-hive mode not specifying a set of genome db ids will cause
the code to work over all genome dbs with entries in the member table.

This code uses direct SQL statements because of the
relationship between translations and their display labels being stored at the
transcript level. If the DB changes this will break.

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
use Bio::EnsEMBL::Utils::Scalar qw(assert_ref check_ref);
use Bio::EnsEMBL::Utils::SqlHelper;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

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
  #Put in so we can have access to $self->param()
  my $job = Bio::EnsEMBL::Hive::AnalysisJob->new();
  $self->input_job($job);
  
  my ($db_adaptor, $replace, $die_if_no_core_adaptor, $genome_db_ids, $debug) = 
    rearrange(
      [qw(db_adaptor replace die_if_no_core_adaptor genome_db_ids debug)], 
      @params
  );
  
  $self->compara_dba($db_adaptor);
  $self->param('replace', $replace);
  $self->param('die_if_no_core_adaptor', $die_if_no_core_adaptor);
  $self->param('genome_db_ids', $genome_db_ids);
  $self->debug($debug);
  
  $self->_use_all_genomedbs() if ! check_ref($genome_db_ids, 'ARRAY');
  
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

#Set all IDs into the available ones to run over; only available through the 
#non-hive interface
sub _use_all_available_genomedbs {
  my ($self) = @_;
  my $h = Bio::EnsEMBL::Utils::SqlHelper->new(-DB_CONNECTION => $self->compara_dba()->dbc());
  my $sql = q{select distinct genome_db_id from member where genome_db_id is not null and genome_db_id <> 0};
  my $ids = $h->execute_simple( -SQL => $sql);
  $self->param('genome_db_ids', $ids);
  return;
}

#--- Hive methods

=head2 fetch_input

    Title   :   fetch_input
    Usage   :   $self->fetch_input
    Function:   prepares global variables and DB connections
    Returns :   none
    Args    :   none

=cut

sub fetch_input {
  my ($self) = @_;
  $self->_assert_state();
  $self->_print_params();
  return 1;
}

sub _print_params {
  my ($self) = @_;
  return unless $self->debug();
  my @params = qw(replace die_if_no_core_adaptor genome_db_id);
  foreach my $param (@params) {
    my $value = $self->param($param);
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
  
  my $genome_dbs = $self->_genome_dbs();
  if($self->debug()) {
    my $names = join(q{, }, map { $_->name() } @{$genome_dbs});
    print "Working with: [${names}]\n";
  }
  
  my $results = $self->param('results', {});
  
  foreach my $genome_db (@{$genome_dbs}) {
    my $output = $self->_process_genome_db($genome_db);
    $results->{$genome_db->dbID()} = $output;
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
  
  my $genome_dbs = $self->_genome_dbs();
  foreach my $genome_db (@{$genome_dbs}) {
    $self->_update_display_labels($genome_db);
  }
  
  return 1;
}

#--- Generic Logic

sub _assert_state {
  my ($self) = @_;
  
  my $dba = $self->compara_dba();
  throw('A suitable Compara DBAdaptor was not found') unless defined $dba;
  assert_ref($dba, 'Bio::EnsEMBL::Compara::DBSQL::DBAdaptor');
  
  #Checking we have some genome dbs to work on
  my $genome_db_ids = $self->param('genome_db_ids');
  throw 'GenomeDB IDs array was not defined' if(! defined $genome_db_ids);
  assert_ref($genome_db_ids, 'ARRAY');
  throw 'GenomeDB IDs array was empty' if(! @{$genome_db_ids});
  
  return;
}

sub _genome_dbs {
	my ($self) = @_;
	my $ids = $self->param('genome_db_ids');
  my $gdba = $self->compara_dba()->get_GenomeDBAdaptor();  
  return [ map { $gdba->fetch_by_dbID($_) } @{$ids} ];
}

sub _process_genome_db {
	my ($self, $genome_db) = @_;
	
	my $name = $genome_db->name();
	my $replace = $self->param('replace');
	
	print "Processing ${name}\n" if $self->debug();
	
	if(!$genome_db->db_adaptor()) {
		throw('Cannot get an adaptor for GenomeDB '.$name) if $self->param('die_if_no_core_adaptor');
		return;
	}

	my @members_to_update;
	my @sources = qw(ENSEMBLGENE ENSEMBLPEP);
	foreach my $source_name (@sources) {
	  print "Working with ${source_name}\n" if $self->debug();
	  if(!$self->_need_to_process_genome_db_source($genome_db, $source_name) && !$replace) {
	    if($self->debug()) {
	      print "No need to update as all members for ${name} and source ${source_name} have display labels\n";
	    }
	    next;
	  }
	  my $results = $self->_process($genome_db, $source_name);
	  push(@members_to_update, @{$results});
	}
	
	return \@members_to_update;
}

sub _process {
  my ($self, $genome_db, $source_name) = @_;
  
  my @members_to_update;
  
  my $core_labels = $self->_get_display_label_lookup($genome_db, $source_name);
  my $members = $self->_get_members_by_source($genome_db, $source_name);
  
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
    print "No members found for ${name} and ${source_name}\n" if $self->debug();
  }
	
	return \@members_to_update;
}

sub _need_to_process_genome_db_source {
	my ($self, $genome_db, $source_name) = @_;
	my $h = Bio::EnsEMBL::Utils::SqlHelper->new(-DB_CONNECTION => $self->compara_dba()->dbc());
	my $sql = q{select count(*) from member 
where genome_db_id =? and display_label is null and source_name =?};
  my $params = [$genome_db->dbID(), $source_name];
	return $h->execute_single_result( -SQL => $sql, -PARAMS => $params);
}

sub _get_members_by_source {
	my ($self, $genome_db, $source_name) = @_;
	my $member_a = $self->compara_dba()->get_MemberAdaptor();
	my $gdb_id = $genome_db->dbID();
	my $constraint = qq(m.source_name = '${source_name}' and m.genome_db_id = ${gdb_id});
	my $members = $member_a->_generic_fetch($constraint);
	my $members_hash = {};
	foreach my $member (@{$members}) {
		$members_hash->{$member->stable_id()} = $member;
	}
	return $members_hash;
}

sub _get_display_label_lookup {
  my ($self, $genome_db, $source_name) = @_;
  	
  my $sql_lookup = {
	  'ENSEMBLGENE'  => q{select gsi.stable_id, x.display_label 
from gene_stable_id gsi 
join gene g using (gene_id)  
join xref x on (g.display_xref_id = x.xref_id) 
join seq_region sr on (g.seq_region_id = sr.seq_region_id) 
join coord_system cs using (coord_system_id) 
where cs.species_id =?},
	  'ENSEMBLPEP'   => q{select tsi.stable_id, x.display_label 
from translation_stable_id tsi 
join translation tr using (translation_id) 
join transcript t using (transcript_id) 
join xref x on (t.display_xref_id = x.xref_id) 
join seq_region sr on (t.seq_region_id = sr.seq_region_id) 
join coord_system cs using (coord_system_id) 
where cs.species_id =?}
	};
	
	my $sql = $sql_lookup->{$source_name};
	
	my $dba = $genome_db->db_adaptor();
  my $h = Bio::EnsEMBL::Utils::SqlHelper->new(-DB_CONNECTION => $dba->dbc());
  my $hash = $h->execute_into_hash( -SQL => $sql );
  return $hash;
}

sub _update_display_labels {
	my ($self, $genome_db) = @_;
	
	my $name = $genome_db->name();
	my $members = $self->param('results')->{$genome_db->dbID()};
	
	if(! defined $members || scalar(@{$members}) == 0) {
	  print "No members to write back for ${name}\n" if $self->debug();
	  return;
	}
	
  print "Writing members out for ${name}\n" if $self->debug();
	
	my $total = 0;
	
	my $h = Bio::EnsEMBL::Utils::SqlHelper->new(-DB_CONNECTION => $self->compara_dba()->dbc());
	 
	$h->transaction( -CALLBACK => sub {
	  my $sql = 'update member set display_label =? where member_id =?';
	  $h->batch(
	   -SQL => $sql,
	   -CALLBACK => sub {
	     my ($sth) = @_;
	     foreach my $member (@{$members}) {
	       my $updated = $sth->execute($member->display_label(), $member->dbID());
	       $total += $updated;
	     }
	     return;
	   }
	  );
	});

	print "Inserted ${total} member(s) for ${name}\n" if $self->debug();
	
	return $total;
}

1;
