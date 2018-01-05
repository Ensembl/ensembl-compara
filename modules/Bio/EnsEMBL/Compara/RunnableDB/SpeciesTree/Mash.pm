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


=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::SpeciesTree::Mash

=head1 SYNOPSIS

Wrapper around mash (https://genomebiology.biomedcentral.com/articles/10.1186/s13059-016-0997-x)

=head1 DESCRIPTION

=cut

package Bio::EnsEMBL::Compara::RunnableDB::SpeciesTree::Mash;

use strict;
use warnings;
# use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');
use base ('Bio::EnsEMBL::Hive::RunnableDB::SystemCmd');

sub fetch_input {
	my $self = shift;

	# for use when chaining multiple mash commands together in a pipeline
	$self->param('input_file', $self->param('mash_output_file')) if $self->param('output_as_input');

	my $mash_exe = $self->param_required('mash_exe');
	my $mode = $self->param_required('mode');
	my $additional_options = $self->param('additional_options');
	my $input_file = $self->param_required('input_file');

	# start to build command
	my $mash_cmd = "$mash_exe $mode ";
	$mash_cmd .= "$additional_options " if $additional_options;

	$mash_cmd .= $self->mash_dist_options if $mode eq 'dist';
	$mash_cmd .= $self->mash_paste_options if $mode eq 'paste';
	$mash_cmd .= $self->mash_sketch_options if $mode eq 'sketch';	
	
	print "\nMASH CMD: $mash_cmd\n\n";
	# replace with $self->run_command
	# may need to spurt the output as using the arrayref input does not allow for redirection of STDOUT
	# system($mash_cmd) == 0 or die "Error running command: $mash_cmd";
	unlink $input_file if $self->param('cleanup_input_file');

	$self->param( 'cmd', $mash_cmd );
}

sub write_output {
	my $self = shift;
	$self->SUPER::write_output;

	return unless $self->param('dataflow_branch');

	my $dataflow = { mash_output_file => $self->param('mash_output_file') };
	$dataflow->{'out_prefix'} = $self->param('out_prefix') if $self->param('out_prefix');
	$self->dataflow_output_id( $dataflow, $self->param('dataflow_branch') );
}

sub mash_dist_options {
	my $self = shift;

	my $input_file = $self->param_required('input_file');
	my $out_dir = $self->param('output_dir');
	my $out_prefix = $self->param('out_prefix');

	my $mash_cmd = '';
	my $reference = $self->param('reference') || $input_file;
	$mash_cmd .= "$reference ";

	$mash_cmd .= $input_file;

	my $mash_output_file;
	if ( $out_prefix ) {
		$mash_output_file = $out_dir ? "$out_dir/$out_prefix.dists" : "$out_prefix.dists";
		$mash_cmd .= " > $mash_output_file";
	}

	$self->param('mash_output_file', $mash_output_file);
	return $mash_cmd;
}

sub mash_paste_options {
	my $self = shift;

	my $input_file = $self->param_required('input_file');
	my $out_dir = $self->param('output_dir');
	my $out_prefix = $self->param_required('out_prefix');

	my $outfile = $out_dir ? "$out_dir/$out_prefix" : $out_prefix;
	my $mash_cmd = "$outfile $input_file";

	unlink "$outfile.msh" if $self->param('overwrite_paste_file');

	$self->param('mash_output_file', "$outfile.msh");
	return $mash_cmd;
}

sub mash_sketch_options {
	my $self = shift;
	
	my $input_file = $self->param_required('input_file');
	my $out_dir = $self->param('output_dir');
	my $out_prefix = $self->param('out_prefix');

	my $mash_cmd = '';
	$mash_cmd .= '-s ' . $self->param('sketch_size') . ' ' if $self->param('sketch_size');
	$mash_cmd .= '-k ' . $self->param('kmer_size')   . ' ' if $self->param('kmer_size');
	
	my $outfile;
	if ( $out_prefix ) {
		$outfile = $out_dir ? "$out_dir/$out_prefix" : $out_prefix;
		$mash_cmd .= "-o $outfile ";
	} else {
		$outfile = $input_file;
	}

	$mash_cmd .= $input_file;
	$self->param('mash_output_file', "$outfile.msh");

	return $mash_cmd;
}

1;