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

=pod

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::PrepTableCopy

=head1 SYNOPSIS

	Used as a funnel for collecting alignment mlss_ids from SelectMLSS.pm
	Assumes data is stored as a parameter/accu called alignment_mlsses
	Fans out jobs to copy the relevant tables and prepare the orthologs

=cut

package Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::PrepTableCopy;

use strict;
use warnings;
use Data::Dumper;

use base ('Bio::EnsEMBL::Hive::RunnableDB::SystemCmd');

sub fetch_input {
	my $self = shift;

	my $mlss_info = $self->param_required('alignment_mlsses');

	my %uniq_mlss;
	for my $row ( @$mlss_info ) {
		for my $mlss_id ( @{ $row->{aln_mlss_ids} } ) {
			$uniq_mlss{$mlss_id} = 1;
		}
	}
	my @uniq_list = keys %uniq_mlss;
	print "\n\n!!! " . scalar(@uniq_list) . " unique mlsses found\n\n" if $self->debug;
	$self->param('uniq_mlss_list', \@uniq_list);

	my @cmd;
    push @cmd, $self->param_required('program');
    push @cmd, '--master', $self->param_required('master_db');
    push @cmd, '--new', $self->param_required('pipeline_db');
    push @cmd, '--reg-conf', $self->param('reg_conf') if $self->param('reg_conf');
    push @cmd, '--old', $self->param_required('master_db');
    push @cmd, '--skip-data';

    $self->param('cmd', \@cmd);
}


sub write_output {
	my $self = shift;

        # To check for failures
        $self->SUPER::write_output();

	my $chunk_size = $self->param_required('copy_chunk_size');

	my @copy_dataflow;
	# if data lives across multiple dbs, group the mlsses from the same db together
	if ( $self->param('alt_aln_dbs') ) {
		my %mlss_mapping = %{ $self->param('mlss_db_mapping') };
		my %group_mlss_per_db;
		while (my ($key, $value) = each %mlss_mapping) {
   			push( @{ $group_mlss_per_db{$value} }, $key);
		}

		foreach my $db ( keys %group_mlss_per_db ) {
			my @these_ids = @{ $group_mlss_per_db{$db} };
			if ( scalar @these_ids <= $chunk_size ) {
				push( @copy_dataflow, { mlss_id_list => \@these_ids, src_db_conn => $db } );
			} else {
				push( @copy_dataflow, @{ $self->_split_into_chunks( \@these_ids, $chunk_size, $db ) } );
			}
		}

	} else {
		@copy_dataflow = $self->_split_into_chunks($self->param('uniq_mlss_list'), $chunk_size, $self->param('compara_db'));
	}

	$self->dataflow_output_id( { mlss => $self->param('uniq_mlss_list') }, 1 ); # to write_threshold
	$self->dataflow_output_id( \@copy_dataflow, 3 ); # to copy_alignment_tables
	$self->dataflow_output_id( {}, 2 ); # to copy_funnel
}

sub _split_into_chunks {
	my ($self, $list, $chunk_size, $db) = @_;

	my $x = 0;
	my @chunks;
	for my $mlss_id ( @$list ) {
		push( @chunks, { mlss_id_list => [], src_db_conn => $db } ) if ( $x % $chunk_size == 0 );
		push( @{ $chunks[-1]->{mlss_id_list} }, $mlss_id );
		$x++;
	}
	return \@chunks;
}

1;