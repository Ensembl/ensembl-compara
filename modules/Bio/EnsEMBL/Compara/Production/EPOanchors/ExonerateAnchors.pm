#Ensembl module for Bio::EnsEMBL::Compara::Production::EPOanchors::ExonerateAnchors
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code
=head1 NAME

Bio::EnsEMBL::Compara::Production::EPOanchors::ExonerateAnchors 

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
dev@ensembl.org


=head1 APPENDIX

The rest of the documentation details each of the object methods. 
Internal methods are usually preceded with a _

=cut
#
package Bio::EnsEMBL::Compara::Production::EPOanchors::ExonerateAnchors;

use strict;
use Data::Dumper;
use Bio::EnsEMBL::Compara::Production::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Hive::Process;
use Bio::EnsEMBL::Compara::MethodLinkSpeciesSet;
use Bio::EnsEMBL::Utils::Exception qw(throw warning);
use Bio::EnsEMBL::Analysis;
use Bio::EnsEMBL::Compara::Production::DBSQL::AnchorAlignAdaptor;

our @ISA = qw(Bio::EnsEMBL::Hive::Process);


sub configure_defaults {
 	my $self = shift;
	$self->analysis->program("/usr/local/ensembl/bin/exonerate-1.0.0") unless $self->analysis->program;
	$self->get_parameters( "{ bestn=>11, gappedextension=>\"no\", softmasktarget=>\"no\", percent=>75, showalignment=>\"no\", model=>\"affine:local\", }")
		unless $self->exonerate_options;
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
	my $anchor_seq_adaptor = $self->{comparaDBA}->get_AnchorSeqAdaptor();
	my $analysis_data_adaptor = $self->{hiveDBA}->get_AnalysisDataAdaptor();
	my $target_genome_files = eval $analysis_data_adaptor->fetch_by_dbID($self->analysis_data_id);
	$self->target_file( $target_genome_files->{target_genomes}->{ $self->target_genome_db_id } );
	my $anchors = $anchor_seq_adaptor->get_anchor_sequences($self->ancs_from_to, $self->anchor_sequences_mlssid);
	my $query_file = $self->worker_temp_directory  . "anchors." . join ("-", @{$self->ancs_from_to});
	open F, ">$query_file" || throw("Couldn't open $query_file");
	foreach my $anchor_seq( @{ $anchors } ) {
		print F ">", join(":", @{$anchor_seq}[0..5]), "\n", $anchor_seq->[-1], "\n";
	}
	$self->query_file($query_file);
	return 1;
}

sub run {
	my ($self) = @_;
	my $program = $self->analysis->program;
	my $query_file = $self->query_file;
	my $target_file = $self->target_file;
	my $option_st;
	foreach my $option(sort keys %{ $self->exonerate_options }) {
		$option_st .= " --" . $option . " " . $self->exonerate_options->{$option}; 
	}
	my $command = join(" ", $program, $option_st, $query_file, $target_file); 
	print $command, "\n";
	my $exo_fh;
	open( $exo_fh, "$command |" ) or throw("Error opening exonerate command: $? $!"); #run exonerate	
	$self->exo_file($exo_fh);
	return 1;
}

sub write_output {
	my ($self) = @_;
	my $anchor_align_adaptor = $self->{'comparaDBA'}->get_AnchorAlignAdaptor();
	my $exo_fh = $self->exo_file;
	my ($hits, $target2dnafrag);
	while(my $mapping = <$exo_fh>){ 
		next unless $mapping =~/^vulgar:/;
		my($anchor_info, $targ_strand, $targ_info, $targ_from, $targ_to, $score) = (split(" ",$mapping))[1,8,5,6,7,9];
		($targ_from, $targ_to) = ($targ_to, $targ_from) if ($targ_from > $targ_to); #exonerate can switch these around
		$targ_strand = $targ_strand eq "+" ? "1" : "-1";
		$targ_from++; #modify the exonerate start position
		my($anchor_name, $anc_org) = split(":", $anchor_info);
		push(@{$hits->{$anchor_name}{$targ_info}}, [ $targ_from, $targ_to, $targ_strand, $score, $anc_org ]);
		$target2dnafrag->{$targ_info}++;
	}
	foreach my $target_info (sort keys %{$target2dnafrag}) {
		my($coord_sys, $dnafrag_name) = (split(":", $target_info))[0,2];
		$target2dnafrag->{$target_info} = $anchor_align_adaptor->fetch_dnafrag_id(
							$coord_sys, $dnafrag_name, $self->target_genome_db_id);
		die "no dnafrag_id found\n" unless($target2dnafrag->{$target_info});
	}
	my $hit_numbers = $self->merge_overlapping_target_regions($hits);
	my $records = $self->process_exonerate_hits($hits, $target2dnafrag, $hit_numbers);	
	$anchor_align_adaptor->store_exonerate_hits($records);
	return 1;
}

sub process_exonerate_hits {
	my $self = shift;
	my($hits, $target2dnafrag, $hit_numbers) = @_;
	my($records_to_load);
	foreach my $anchor_id (sort keys %{$hits}) {
		foreach my $targ_dnafrag_info (sort keys %{$hits->{$anchor_id}}) {
			my $dnafrag_id = $target2dnafrag->{$targ_dnafrag_info};
			foreach my $hit_position (@{$hits->{$anchor_id}->{$targ_dnafrag_info}}) {
				my $index = join(":", $anchor_id, $targ_dnafrag_info, $hit_position->[0]);
				my $number_of_org_hits = keys %{$hit_numbers->{$index}->{anc_orgs}};
				my $number_of_seq_hits = $hit_numbers->{$index}->{seq_nums};
				push(@{$records_to_load}, join(":", $self->exonerate_mlssid, $anchor_id, $dnafrag_id, 
							@{$hit_position}[0..3], $number_of_org_hits, $number_of_seq_hits));
			}
		}
	}
	return $records_to_load;
}

sub merge_overlapping_target_regions { #merge overlapping target regions hit by different seqs in the same anchor
	my $self = shift;
	my $mapped_anchors = shift;
	my $HIT_NUMS;
	foreach my $anchor(sort {$a <=> $b} keys %{$mapped_anchors}) {
	        foreach my $targ_info(sort keys %{$mapped_anchors->{$anchor}}) {
	                @{$mapped_anchors->{$anchor}{$targ_info}} = sort {$a->[0] <=> $b->[0]} @{$mapped_anchors->{$anchor}{$targ_info}};
	                for(my$i=0;$i<@{$mapped_anchors->{$anchor}{$targ_info}};$i++) {
	                        my $anc_look_up_name = join(":", $anchor, $targ_info, $mapped_anchors->{$anchor}{$targ_info}->[$i]->[0]);
				if($i < @{$mapped_anchors->{$anchor}{$targ_info}} - 1) {
		                        if($mapped_anchors->{$anchor}{$targ_info}->[$i]->[1] >= $mapped_anchors->{$anchor}{$targ_info}->[$i+1]->[0]) {  
		                                unless($mapped_anchors->{$anchor}{$targ_info}->[$i]->[2] eq 
							$mapped_anchors->{$anchor}{$targ_info}->[$i+1]->[2]) {       
		                                        print STDERR "possible palindromic sequences: $anchor ", 
								"$mapped_anchors->{$anchor}{$targ_info}->[$i]->[2] ", 
								$mapped_anchors->{$anchor}{$targ_info}->[$i+1]->[2], "\n";
		                                        $mapped_anchors->{$anchor}{$targ_info}->[$i]->[2] = 0;
		                                }       
		                                if($mapped_anchors->{$anchor}{$targ_info}->[$i]->[1] < 
							$mapped_anchors->{$anchor}{$targ_info}->[$i+1]->[1]) {
		                                        $mapped_anchors->{$anchor}{$targ_info}->[$i]->[1] = 
								$mapped_anchors->{$anchor}{$targ_info}->[$i+1]->[1];
		                                }       
		                                $mapped_anchors->{$anchor}{$targ_info}->[$i]->[3] += $mapped_anchors->{$anchor}{$targ_info}->[$i+1]->[3];
		                                $mapped_anchors->{$anchor}{$targ_info}->[$i]->[3] /= 2; # simplistic scoring
						#count the organisms from which the anchor seqs were derived 
		                                $HIT_NUMS->{$anc_look_up_name}{anc_orgs}{$mapped_anchors->{$anchor}{$targ_info}->[$i+1]->[4]}++;
						#count number of anchor seqs that map
						$HIT_NUMS->{$anc_look_up_name}{seq_nums}++;
		                                splice(@{$mapped_anchors->{$anchor}{$targ_info}}, $i+1, 1);
		                                $i--;   
						next;
		                        }       
				}
				$HIT_NUMS->{$anc_look_up_name}{anc_orgs}{$mapped_anchors->{$anchor}{$targ_info}->[$i]->[4]}++;
				$HIT_NUMS->{$anc_look_up_name}{seq_nums}++;
	                }       
	        }       
	}
	return $HIT_NUMS;
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

sub ancs_from_to {
	my $self = shift;
	if (@_) {
		$self->{_ancs_from_to} = shift;
	}
	return $self->{_ancs_from_to};
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

sub exonerate_mlssid {
	my $self = shift;
	if (@_){
		$self->{_exonerate_mlssid} = shift;
	}
	$self->{_exonerate_mlssid};
}

sub exonerate_options {
	my $self = shift;
	if (@_){
		$self->{_exonerate_options} = shift;
	}
	$self->{_exonerate_options};
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
	
	if(defined($params->{'ancs_from_to'})) {
		$self->ancs_from_to($params->{'ancs_from_to'});
	}
	if(defined($params->{'target_genome'})) {
		$self->target_genome_db_id($params->{'target_genome'});
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

