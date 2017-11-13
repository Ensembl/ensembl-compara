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


=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::SpeciesTree::MashNJTree

=head1 SYNOPSIS

Create a neighbour-joining tree from 'mash dist -t' output

=head1 DESCRIPTION

	Steps:
	1. convert mash output to phylip distance format. This involves
	   replacing species names with their genome_db_id - phylip has
	   a 10-character limit on species names and this would not be
	   unique in our set of species (naked mole rat, for example)
	2. run rapidnj
	3. replace genome_db_ids with species names
	4. check for and correct negative branch lengths
	   http://www.sequentix.de/gelquest/help/neighbor_joining_method.htm

=cut

package Bio::EnsEMBL::Compara::RunnableDB::SpeciesTree::MashNJTree;

use strict;
use warnings;
use Bio::EnsEMBL::Compara::Graph::NewickParser;
use File::Basename;

use Data::Dumper;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub fetch_input {
	my $self = shift;

	my $distance_file = $self->param_required('mash_output_file');

	# create phylip file from mash dist output
	my $phylip_file = $self->worker_temp_directory . '/mash.phy';
	$self->phylip_from_mash($distance_file, $phylip_file);
	$self->param('phylip_file', $phylip_file);
}

sub run {
	my $self = shift;

	my $genome_db_adaptor = $self->compara_dba->get_GenomeDBAdaptor;
	my $rapidnj_exe = $self->param_required('rapidnj_exe');
	# my $output_file = $self->param_required('output_file');
	my $phylip_file = $self->param_required('phylip_file');

	# run rapidnj
	my $rapidnj_cmd = "$rapidnj_exe $phylip_file --no-negative-length";
	print " --- CMD: $rapidnj_cmd\n";
	my $tree = $self->run_command($rapidnj_cmd)->out;


	# replace genome_db_ids with species names
	while ( $tree =~ m/gdb([0-9]+)/g ) {
		my $gdb = $genome_db_adaptor->fetch_by_dbID($1);
		my $species_name = $gdb->name;
		$tree =~ s/'gdb$1'/$species_name/;
	}

	# set output file name based on whether this is the final tree
	# or one to pass to a create_supertree analysis
	my $output_file = $self->_output_file_name;

	print "Writing species tree to $output_file...\n" if $self->debug;
	$self->_spurt( $output_file, $tree );
}

sub write_output {

}

sub _output_file_name {
	my $self = shift;

	if ( $self->param('group_on_taxonomy') ) {
		# this tree is part of a bigger group
		# place it in the same dir as output_file, if it's defined
		my ($opf_filename, $opf_dirs, $opf_suffix) = fileparse($self->param('output_file'), qr/\.[^.]*/);
		my ($msh_filename, $msh_dirs, $msh_suffix) = fileparse($self->param('mash_output_file'), qr/\.[^.]*/);

		my $output_file = '';
		$output_file .= $opf_dirs || $msh_dirs;
		$output_file .= "/$msh_filename.nwk";
		return $output_file;
	} else {
		# this is the final tree
		return $self->param_required('output_file');
	}
}

sub phylip_from_mash {
	my ($self, $mash_file, $phylip_file) = @_;

	my $genome_db_adaptor = $self->compara_dba->get_GenomeDBAdaptor;
	open(DISTS, '<', $mash_file);
	my $species_count = 0;
	my $reformatted_matrix;
	while ( my $line = <DISTS> ) {
		chomp $line;
		next if $line =~ m/^#/;
		$species_count++;

		my @cols = split( /\s+/, $line );
		my $filename = shift @cols;
		my ( $species_name, $assembly_name ) = $self->_get_species_info_from_filename($filename);
		print "species_name: $species_name\tassembly_name: $assembly_name\tfilename: $filename\n";
		my $gdb = $genome_db_adaptor->fetch_by_name_assembly($species_name, $assembly_name);

		my @vals = map {sprintf("%.5f", $_)} @cols;
		$reformatted_matrix .= $self->_padded('gdb' . $gdb->dbID, 10) . "\t";
		$reformatted_matrix .= join("\t", @vals) . "\n";
	}
	close DISTS;

	# spurt
	open( PHY, '>', $phylip_file );
	print PHY "    $species_count\n" . $reformatted_matrix;
	close PHY;
}

sub _get_species_info_from_filename {
	my $self = shift;
	my $basefile = shift;

	my ($filename, $filepath) = fileparse($basefile);

	# parse species name and assembly name from filename
	# e.g. octodon_degus.OctDeg1.0.fa.gz.msh => (octodon_degus, OctDeg1.0)
	$filename =~ m/(^[A-Za-z_0-9]+)\.([A-Za-z0-9_\-\.]+)\.fa/;
	# print STDERR "filename: $filename; species name: $1; assembly: $2\n";
	return ($1, $2);
}

sub _padded {
	my ( $self, $str, $max_len ) = @_;

	my $to_pad = $max_len - length($str);
	return $str . (' 'x$to_pad);
}

1;