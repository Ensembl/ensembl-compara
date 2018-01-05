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

# POD documentation - main docs before the code
=head1 NAME

Bio::EnsEMBL::Compara::Production::EPOanchors::HMMerAnchors 

=head1 SYNOPSIS

$exonate_anchors->fetch_input();
$exonate_anchors->run();
$exonate_anchors->write_output(); writes to database

=head1 DESCRIPTION

Given a database with anchor sequences and a target genome. This modules exonerates 
the anchors against the target genome.

=head1 AUTHOR

Stephen Fitzgerald

=head1 CONTACT

This modules is part of the EnsEMBL project (http://www.ensembl.org)

Questions can be posted to the ensembl-dev mailing list:
http://lists.ensembl.org/mailman/listinfo/dev


=head1 APPENDIX

The rest of the documentation details each of the object methods. 
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::Production::EPOanchors::HMMerAnchors;

use strict;
use warnings;
use Bio::AlignIO;
use Bio::EnsEMBL::Utils::Exception qw(throw);

use base('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub fetch_input {
	my ($self) = @_;

	$self->compara_dba->dbc->disconnect_if_idle();

	my $genomic_align_block_adaptor = $self->compara_dba->get_GenomicAlignBlockAdaptor();
	my $align_slice_adaptor = $self->compara_dba->get_AlignSliceAdaptor();

	my $target_genome_files = $self->param('target_genome_files');
	$self->param('target_file', $target_genome_files->{target_genomes}->{ $self->param('target_genome_db_id') } );
	my $genomic_align_block_id = $self->param('genomic_align_block_id');
	my $genomic_align_block = $genomic_align_block_adaptor->fetch_by_dbID($genomic_align_block_id);
	$self->param('anchor_id', $genomic_align_block_id );
	my $align_slice = $align_slice_adaptor->fetch_by_GenomicAlignBlock($genomic_align_block, 1, 0);
	my $simple_align = $align_slice->get_SimpleAlign(); 
	my $stockholm_file = $self->worker_temp_directory . "stockholm." . $genomic_align_block_id;
	#print genomic_align_block in stockholm format
	open F, ">$stockholm_file" || throw("Couldn't open $stockholm_file");
	print F "# STOCKHOLM 1.0\n";
	foreach my $seq( $simple_align->each_seq) {
		print F $genomic_align_block->dbID . "/" . $seq->display_id . "\t" . $seq->seq . "\n";
	}
	print F "//\n";
	close(F);
	#build the hmm from the stockholm format file
	my $hmmbuild_outfile = $self->worker_temp_directory . "$genomic_align_block_id.hmm";
	my $hmmbuild = $self->param_required('hmmbuild');
	my $hmmbuild_command = [$hmmbuild, '--dna', $hmmbuild_outfile, $stockholm_file];
	$self->run_command($hmmbuild_command);
	$self->param('query_file', $hmmbuild_outfile);
}

sub run {
	my ($self) = @_;
	my $nhmmer_command = join(" ", $self->param_required('nhmmer'), "--noali", $self->param('query_file'), $self->param('target_file') );
	my $exo_fh;
	open( $exo_fh, "$nhmmer_command |" ) or throw("Error opening nhmmer command: $? $!"); #run nhmmer	
	$self->param('exo_file', $exo_fh);
}

sub write_output {
	my ($self) = @_;
	my $anchor_align_adaptor = $self->compara_dba->get_AnchorAlignAdaptor();
	my $exo_fh = $self->param('exo_file');
	my (@hits, %hits);
	{ local $/ = ">>";
		while(my $mapping = <$exo_fh>){ 
			next unless $mapping=~/!/;
			push(@hits, $mapping);
		}
	}
	foreach my $hit( @hits ){
		my($target_info, $mapping_info) = (split("\n", $hit))[0,3];
		my($coor_sys, $species, $seq_region_name) = (split(":", $target_info))[0,1,2];
		my($score, $evalue, $alifrom, $alito) = (split(/ +/, $mapping_info))[2,4,8,9];
		my $strand = $alifrom > $alito ? "-1" : "1";
		($alifrom, $alito) = ($alito, $alifrom) if $strand eq "-1";
		my $dnafrag_adaptor = $self->compara_dba->get_DnaFragAdaptor();
		my $dnafrag_id = $dnafrag_adaptor->fetch_by_GenomeDB_and_name($self->param('target_genome_db_id'), $seq_region_name)->dbID;
		push(@{ $hits{$self->param('anchor_id')} }, [ $dnafrag_id, $alifrom, $alito, $strand, $score, $evalue ]);
	}
}


1;

