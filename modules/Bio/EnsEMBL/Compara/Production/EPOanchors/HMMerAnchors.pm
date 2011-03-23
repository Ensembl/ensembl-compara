#ensembl module for bio::ensembl::compara::production::epoanchors::hmmeranchors
# you may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code
=head1 NAME

Bio::EnsEMBL::Compara::Production::EPOanchors::HMMerAnchors 

=head1 SYNOPSIS

$exonate_anchors->fetch_input();
$exonate_anchors->run();
$exonate_anchors->write_output(); writes to database

=head1 DESCRIPTION

Given a database with anchor sequences and a target genome. This modules exonerates 
the anchors against the target genome. The required information (anchor batch size,
target genome file, exonerate parameters are provided by the analysis, analysis_job 
and analysis_data tables  

=head1 AUTHOR - Stephen Fitzgerald

This modules is part of the Ensembl project http://www.ensembl.org

Email compara@ebi.ac.uk

=head1 CONTACT

This modules is part of the EnsEMBL project (http://www.ensembl.org)

Questions can be posted to the ensembl-dev mailing list:
ensembl-dev@ebi.ac.uk


=head1 APPENDIX

The rest of the documentation details each of the object methods. 
Internal methods are usually preceded with a _

=cut
#
package Bio::EnsEMBL::Compara::Production::EPOanchors::HMMerAnchors;

use strict;
use Data::Dumper;
use Bio::EnsEMBL::Compara::Production::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Hive::Process;
use Bio::EnsEMBL::Utils::Exception qw(throw warning);
use Bio::EnsEMBL::Analysis;
use Bio::AlignIO;

our @ISA = qw(Bio::EnsEMBL::Hive::Process);


sub configure_defaults {
 	my $self = shift;
	my $nhmmer = "/software/ensembl/compara/hmmer3.1_nhmmer_beta2/src/nhmmer";
	my $hmmbuild = "/software/ensembl/compara/hmmer3.1_nhmmer_beta2/src/hmmbuild";
	$self->analysis->program("{ nhmmer=>\"$nhmmer\", hmmbuild=>\"$hmmbuild\" }") unless $self->analysis->program;
  	return 1;
}

sub fetch_input {
	my ($self) = @_;
	$self->configure_defaults();
	$self->get_parameters($self->parameters);
	#create a Compara::DBAdaptor which shares the same DBI handle with $self->db (Hive DBAdaptor)
	$self->{'comparaDBA'} = Bio::EnsEMBL::Compara::Production::DBSQL::DBAdaptor->new(-DBCONN=>$self->db->dbc);
	$self->{'comparaDBA'}->dbc->disconnect_if_idle();
	$self->{'hiveDBA'} = Bio::EnsEMBL::Hive::DBSQL::DBAdaptor->new(-DBCONN => $self->{'comparaDBA'}->dbc);
	$self->{'hiveDBA'}->dbc->disconnect_if_idle();
	$self->get_input_id($self->input_id);
	my $genomic_align_block_adaptor = $self->{comparaDBA}->get_GenomicAlignBlockAdaptor();
	my $align_slice_adaptor = $self->{comparaDBA}->get_AlignSliceAdaptor();
	my $analysis_data_adaptor = $self->{hiveDBA}->get_AnalysisDataAdaptor();
	my $target_genome_files = eval $analysis_data_adaptor->fetch_by_dbID($self->analysis_data_id);
	$self->target_file( $target_genome_files->{target_genomes}->{ $self->target_genome_db_id } );
	my $genomic_align_block_id = $self->genomic_align_block_id;
	my $genomic_align_block = $genomic_align_block_adaptor->fetch_by_dbID($genomic_align_block_id);
	$self->anchor_id( $genomic_align_block_id );
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
	my $hmm_programs = eval $self->analysis->program;
	$self->nhmmer($hmm_programs->{nhmmer});
	my $hmmbuild_outfile = $self->worker_temp_directory . "$genomic_align_block_id.hmm";
	my $hmmbuild = $hmm_programs->{hmmbuild}; 
	my $hmmbuild_command = "$hmmbuild --dna $hmmbuild_outfile $stockholm_file";
	system($hmmbuild_command);
	$self->query_file($hmmbuild_outfile);
	return 1;
}

sub run {
	my ($self) = @_;
	my $nhmmer_command = join(" ", $self->nhmmer, "--noali", $self->query_file, $self->target_file); 
	my $exo_fh;
	open( $exo_fh, "$nhmmer_command |" ) or throw("Error opening nhmmer command: $? $!"); #run nhmmer	
	$self->exo_file($exo_fh);
	return 1;
}

sub write_output {
	my ($self) = @_;
	my $anchor_align_adaptor = $self->{'comparaDBA'}->get_AnchorAlignAdaptor();
	my $exo_fh = $self->exo_file;
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
		my $dnafrag_adaptor = $self->{comparaDBA}->get_DnaFragAdaptor();
		my $dnafrag_id = $dnafrag_adaptor->fetch_by_GenomeDB_and_name($self->target_genome_db_id, $seq_region_name)->dbID;
		push(@{ $hits{$self->anchor_id} }, [ $dnafrag_id, $alifrom, $alito, $strand, $score, $evalue ]);
	}
#	$anchor_align_adaptor->store_exonerate_hits($records);
	return 1;
}


sub anchor_id {
	my $self = shift;
	if (@_) {
		$self->{anchor_id} = shift;
	}
	return $self->{anchor_id};
}

sub nhmmer {
	my $self = shift;
	if (@_) {
		$self->{nhmmer} = shift;
	}
	return $self->{nhmmer};
}

sub exo_file {
	my $self = shift;
	if (@_) {
		$self->{_exo_file} = shift;
	}
	return $self->{_exo_file};
}

sub analysis_id {
	my $self = shift;
	if (@_) {
		$self->{_analysis_id} = shift;
	}
	return $self->{_analysis_id};
}

sub analysis_data_id {
	my $self = shift;
	if (@_) {
		$self->{_analysis_data_id} = shift;
	}
	return $self->{_analysis_data_id};
}

sub query_file {
	my $self = shift;
	if (@_) {
		$self->{_query_file} = shift;
	}
	return $self->{_query_file};
}		

sub genomic_align_block_id {
	my $self = shift;
	if (@_) {
		$self->{_genomic_align_block_id} = shift;
	}
	return $self->{_genomic_align_block_id};
}

sub target_file {
	my $self = shift;
	if (@_){
		$self->{_target_file} = shift;
	}
	return $self->{_target_file};
}

sub target_genome_db_id {
	my $self = shift;
	if (@_){
		$self->{_target_genome_db_id} = shift;
	}
	return $self->{_target_genome_db_id};
}

sub anchor_sequences_mlssid {
	my $self = shift;
	if (@_){
		$self->{_anchor_sequences_mlssid} = shift;
	}
	$self->{_anchor_sequences_mlssid};
}

sub get_parameters {
	my $self = shift;
	my $param_string = shift;
	
	return unless($param_string);
	my $params = eval($param_string);
	$self->exonerate_options($params);
}

sub get_input_id {
	my $self = shift;
	my $input_id_string = shift;

	return unless($input_id_string);
	print("parsing input_id string : ",$input_id_string,"\n");
	
	my $params = eval($input_id_string);
	return unless($params);
	
	if(defined($params->{'genomic_align_block_id'})) {
		$self->genomic_align_block_id($params->{'genomic_align_block_id'});
	}
	if(defined($params->{'target_genome_db_id'})) {
		$self->target_genome_db_id($params->{'target_genome_db_id'});
	}
	if(defined($params->{'analysis_data_id'})) {
		$self->analysis_data_id($params->{'analysis_data_id'});
	}
	if(defined($params->{'analysis_id'})) {
		$self->analysis_id($params->{'analysis_id'});
	}
	if(defined($params->{'exonerate_mlssid'})) {
		$self->exonerate_mlssid($params->{'exonerate_mlssid'});
	}
	if(defined($params->{'anchor_sequences_mlssid'})) {
		$self->anchor_sequences_mlssid($params->{'anchor_sequences_mlssid'});
	}
	return 1;
}

1;

