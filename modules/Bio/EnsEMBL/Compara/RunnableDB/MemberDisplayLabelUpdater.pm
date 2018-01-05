=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2018] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

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

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with a _

=cut

use strict;
use warnings;

use Scalar::Util qw(looks_like_number);

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub param_defaults {
    return {
        'mode'  => 'display_label',      # one of 'display_label', 'description'
        'source_name' => 'ENSEMBLGENE',  # one of 'ENSEMBLGENE', 'ENSEMBLPEP'
    };
}


#
# Hash containing the description of the possible modes
# A mode entry must contain the following keys:
#  - perl_attr: perl method to get the value from a Member
#  - sql_column: column in the member table
#  - sql_lookups: SQLs to get the values from a core database
#
my $modes = {
    'display_label' => {
        'perl_attr' => 'display_label',
        'sql_column' => 'display_label',
        'sql_lookups' => {
            'ENSEMBLGENE'  => q{select g.stable_id, x.display_label
FROM gene g
join xref x on (g.display_xref_id = x.xref_id)
join seq_region sr on (g.seq_region_id = sr.seq_region_id)
join coord_system cs using (coord_system_id)
where cs.species_id =?},
            'ENSEMBLPEP'   => q{select tr.stable_id, x.display_label
FROM translation tr
join transcript t using (transcript_id)
join xref x on (t.display_xref_id = x.xref_id)
join seq_region sr on (t.seq_region_id = sr.seq_region_id)
join coord_system cs using (coord_system_id)
where cs.species_id =?},
        },
    },

    'description' => {
        'perl_attr' => 'description',
        'sql_column' => 'description',
        'sql_lookups' => {
            'ENSEMBLGENE'  => q{select g.stable_id, g.description
FROM gene g
join seq_region sr on (g.seq_region_id = sr.seq_region_id)
join coord_system cs using (coord_system_id)
where cs.species_id =?},
        },
    },

};

my %source_name2table = (
    'ENSEMBLGENE'   => 'gene_member',
    'ENSEMBLPEP'    => 'seq_member',
);

=head2 fetch_input

    Title   :   fetch_input
    Usage   :   $self->fetch_input
    Function:   prepares global variables and DB connections
    Returns :   none
    Args    :   none

=cut

sub fetch_input {
  my ($self) = @_;

  die $self->param('mode').' is not a valid mode. Valid modes are: '.join(', ', keys %$modes) unless exists $modes->{$self->param('mode')};
  die $self->param('source_name').' is not a valid source_name. Valid modes are: '.join(', ', keys %{$modes->{$self->param('mode')}->{sql_lookups}->{$self->param('source_name')}}) unless exists $modes->{$self->param('mode')}->{sql_lookups}->{$self->param('source_name')};

  my $species_list = $self->param('species') || $self->param('genome_db_ids');

  unless( $species_list ) {
      my $sql = q{SELECT DISTINCT genome_db_id FROM gene_member WHERE genome_db_id IS NOT NULL AND genome_db_id <> 0};
      $species_list = $self->compara_dba->dbc->sql_helper->execute_simple( -SQL => $sql);
  }

  my $genome_db_adaptor = $self->compara_dba()->get_GenomeDBAdaptor();  

  my $genome_dbs = $genome_db_adaptor->fetch_all_by_mixed_ref_lists(-SPECIES_LIST => $species_list);
  $self->param('genome_dbs', $genome_dbs);
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
    $self->_update_field($genome_db);
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
        my $source_name = $self->param('source_name');
        print "Working with ${source_name}\n" if $self->debug();
        if(!$self->_need_to_process_genome_db_source($genome_db, $source_name) && !$replace) {
	    if($self->debug()) {
	      print "No need to update as all members for ${name} and source ${source_name} have display labels\n";
	    }
        } else {
	  my $results = $self->_process($genome_db, $source_name);
	  push(@members_to_update, @{$results});
      }
	
	return \@members_to_update;
}

sub _process {
  my ($self, $genome_db, $source_name) = @_;
  
  my @members_to_update;
  my $replace = $self->param('replace');
  
  my $member_a = ($source_name eq 'ENSEMBLGENE') ? $self->compara_dba()->get_GeneMemberAdaptor() : $self->compara_dba()->get_SeqMemberAdaptor();
  my $members = $member_a->fetch_all_by_GenomeDB($genome_db, $source_name);
  
  if (scalar(@{$members})) {
    my $core_values = $self->_get_field_lookup($genome_db, $source_name);
    my $perl_attr = $modes->{$self->param('mode')}->{perl_attr};

    foreach my $member (@{$members}) {
      
      #Skip if it's already got a value & we are not replacing things
      next if defined $member->$perl_attr() && !$replace;
      
      my $display_value = $core_values->{$member->stable_id};
      push(@members_to_update, [$member->dbID, $display_value]);
    }
  } else {
    my $name = $genome_db->name();
    print "No members found for ${name} and ${source_name}\n" if $self->debug();
  }
	
  return \@members_to_update;
}

sub _need_to_process_genome_db_source {
	my ($self, $genome_db, $source_name) = @_;
	my $sql = sprintf('select count(*) from %s where genome_db_id =? and source_name =?', $source_name2table{$source_name});
      $sql .= sprintf("AND %s IS NULL", $modes->{$self->param('mode')}->{sql_column});
  my $params = [$genome_db->dbID(), $source_name];
	return $self->compara_dba->dbc->sql_helper->execute_single_result( -SQL => $sql, -PARAMS => $params);
}


#
# Get the labels / descriptions as a hash for that species
#
sub _get_field_lookup {
  my ($self, $genome_db, $source_name) = @_;
  	
  my $sql = $modes->{$self->param('mode')}->{sql_lookups}->{$source_name};
	
  my $dba = $genome_db->db_adaptor();
  my $params = [$dba->species_id()];
	
  my $hash = $dba->dbc->sql_helper->execute_into_hash( -SQL => $sql, -PARAMS => $params );
  return $hash;
}

#
# Update the Compara db with the new labels / descriptions
#
sub _update_field {
	my ($self, $genome_db) = @_;
	
	my $name = $genome_db->name();
	my $member_values = $self->param('results')->{$genome_db->dbID()};
	
	if(! defined $member_values || scalar(@{$member_values}) == 0) {
	  print "No members to write back for ${name}\n" if $self->debug();
	  return;
	}
	
    print "Writing members out for ${name}\n" if $self->debug();
	
	my $total = 0;
	
      my $sql_column = $modes->{$self->param('mode')}->{sql_column};
      my $table = $source_name2table{$self->param('source_name')};
	$self->compara_dba->dbc->sql_helper->transaction( -CALLBACK => sub {
	  my $sql = "update $table set $sql_column = ? where ${table}_id =?";
	  $self->compara_dba->dbc->sql_helper->batch(
	   -SQL => $sql,
	   -CALLBACK => sub {
	     my ($sth) = @_;
	     foreach my $arr (@{$member_values}) {
	       my $updated = $sth->execute($arr->[1], $arr->[0]);
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
