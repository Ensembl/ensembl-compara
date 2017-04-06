=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2017] EMBL-European Bioinformatics Institute

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

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

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
	print "\n\n!!!" . scalar(@uniq_list) . " unique mlsses found\n\n" if $self->debug;
	$self->param('uniq_mlss_list', \@uniq_list);

	my @cmd;
    push @cmd, $self->param_required('program');
    push @cmd, '--master', $self->param_required('master_db');
    push @cmd, '--new', $self->param_required('pipeline_db');
    push @cmd, '--reg-conf', $self->param('reg_conf') if $self->param('reg_conf');
    push @cmd, '--old', $self->param_required('old_compara_db');
    push @cmd, '--skip-data';

    $self->param('cmd', \@cmd);
}

sub run {
	my $self = shift;

	system( join( ' ', @{ $self->param('cmd') } ) );
}

sub write_output {
	my $self = shift;
	my $chunk_size = $self->param_required('copy_chunk_size');

	my @copy_dataflow;
	my $x = 0;
	for my $mlss_id ( @{ $self->param('uniq_mlss_list') } ) {
		push( @copy_dataflow, { mlss_id_list => [] } ) if ( $x % $chunk_size == 0 );
		push( @{ $copy_dataflow[-1]->{mlss_id_list} }, $mlss_id );
		$x++;
	}

	$self->dataflow_output_id( { mlss => $self->param('uniq_mlss_list') }, 1 ); # to write_threshold
	$self->dataflow_output_id( \@copy_dataflow, 3 ); # to copy_alignment_tables
	$self->dataflow_output_id( {}, 2 ); # to copy_funnel
}

1;