package Bio::EnsEMBL::Compara::RunnableDB::MemberDisplayLabelUpdater;

=pod

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::MemberDisplayLabelUpdater

=head1 SYNOPSIS

This runnable can be used both as a Hive pipeline component or run in standalone mode.
At the moment Compara runs it standalone, EnsEMBL Genomes runs it in both modes.

In standalone mode you will need to set --reg_conf to your registry configuration file in order to access the core databases.
You will have to refer to your compara database either via the full URL or (if you have a corresponding registry entry) via registry.
Here are both examples:

    standaloneJob.pl Bio::EnsEMBL::Compara::RunnableDB::MemberDisplayLabelUpdater --reg_conf $ENSEMBL_CVS_ROOT_DIR/ensembl-compara/scripts/pipeline/production_reg_conf.pl --compara_db compara_homology_merged --debug 1

    standaloneJob.pl Bio::EnsEMBL::Compara::RunnableDB::MemberDisplayLabelUpdater --reg_conf $ENSEMBL_CVS_ROOT_DIR/ensembl-compara/scripts/pipeline/production_reg_conf.pl --compara_db mysql://ensadmin:${ENSADMIN_PSW}@compara3:3306/lg4_compara_homology_merged_64 --debug 1

You should be able to limit the set of species being updated by adding --species "[ 90, 3 ]" or --species "[ 'human', 'rat' ]"

=head1 DESCRIPTION

The module loops through all genome_dbs given via the parameter C<species> and attempts to update any gene/translation with the display identifier from the core database.
If the list of genome_dbs is not specified, it will attempt all genome_dbs with entries in the member table.

This code uses direct SQL statements because of the relationship between translations and their display labels
being stored at the transcript level. If the DB changes this will break.

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

use Scalar::Util qw(looks_like_number);
use Bio::EnsEMBL::Utils::SqlHelper;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


=head2 fetch_input

    Title   :   fetch_input
    Usage   :   $self->fetch_input
    Function:   prepares global variables and DB connections
    Returns :   none
    Args    :   none

=cut

sub fetch_input {
  my ($self) = @_;

  my $species_list = $self->param('species') || $self->param('genome_db_ids');

  unless( $species_list ) {
      my $h = Bio::EnsEMBL::Utils::SqlHelper->new(-DB_CONNECTION => $self->compara_dba()->dbc());
      my $sql = q{SELECT DISTINCT genome_db_id FROM member WHERE genome_db_id IS NOT NULL AND genome_db_id <> 0};
      $species_list = $h->execute_simple( -SQL => $sql);
  }

  my $genome_db_adaptor = $self->compara_dba()->get_GenomeDBAdaptor();  

  my @genome_dbs = ();
  foreach my $species (@$species_list) {
    my $genome_db = ( looks_like_number( $species )
        ? $genome_db_adaptor->fetch_by_dbID( $species )
        : $genome_db_adaptor->fetch_by_registry_name( $species ) )
    or die "Could not fetch genome_db object given '$species'";

    push @genome_dbs, $genome_db;
  }
  $self->param('genome_dbs', \@genome_dbs);
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
  
  my $genome_dbs = $self->param('genome_dbs');
  if($self->debug()) {
    my $names = join(q{, }, map { $_->name() } @$genome_dbs);
    print "Working with: [${names}]\n";
  }
  
  my $results = $self->param('results', {});
  
  foreach my $genome_db (@$genome_dbs) {
    my $output = $self->_process_genome_db($genome_db);
    $results->{$genome_db->dbID()} = $output;
  }
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
  
  my $genome_dbs = $self->param('genome_dbs');
  foreach my $genome_db (@$genome_dbs) {
    $self->_update_display_labels($genome_db);
  }
}


#--- Generic Logic


sub _process_genome_db {
	my ($self, $genome_db) = @_;
	
	my $name = $genome_db->name();
	my $replace = $self->param('replace');
	
	print "Processing ${name}\n" if $self->debug();
	
	if(!$genome_db->db_adaptor()) {
		die 'Cannot get an adaptor for GenomeDB '.$name if $self->param('die_if_no_core_adaptor');
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
  my $replace = $self->param('replace');
  
  my $members = $self->_get_members_by_source($genome_db, $source_name);
  
  if(%{$members}) {
    my $core_labels = $self->_get_display_label_lookup($genome_db, $source_name);

    foreach my $stable_id (keys %{$members}) {
      my $member = $members->{$stable_id};
      
      #Skip if it's already got a label & we are not replacing things
      next if defined $member->display_label() && !$replace;
      
      my $display_label = $core_labels->{$stable_id};
      #Next if there was no core object for the stable ID
      next if ! defined $display_label;
      $member->display_label($display_label);
      push(@members_to_update, $member);
    }
  } else {
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
	
  my $dba = $genome_db->db_adaptor();
  my $h = Bio::EnsEMBL::Utils::SqlHelper->new(-DB_CONNECTION => $dba->dbc());
  
  my $sql = $sql_lookup->{$source_name};
  my $params = [$dba->species_id()];
	
  my $hash = $h->execute_into_hash( -SQL => $sql, -PARAMS => $params );
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
