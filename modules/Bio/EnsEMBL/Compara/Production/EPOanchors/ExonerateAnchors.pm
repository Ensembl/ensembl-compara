=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

=head1 AUTHOR

Stephen Fitzgerald

=head1 CONTACT

Please email comments or questions to the public Ensembl
developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

Questions may also be sent to the Ensembl help desk at
<http://www.ensembl.org/Help/Contact>.

=head1 APPENDIX

The rest of the documentation details each of the object methods. 
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::Production::EPOanchors::ExonerateAnchors;

use strict;
use Bio::EnsEMBL::Utils::Exception qw(throw warning);
use Bio::EnsEMBL::Compara::Production::DBSQL::AnchorAlignAdaptor;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub param_defaults {
	return {
		'mapping_exe' => "/usr/local/ensembl/bin/exonerate-1.0.0",
	};
}


sub fetch_input {
	my ($self) = @_;

    $self->param('exonerate_options', $self->analysis->parameters
        ? eval($self->analysis->parameters)
        : { bestn=>11, gappedextension=>'no', softmasktarget=>'no', percent=>75, showalignment=>'no', model=>'affine:local' }
    );

	$self->compara_dba()->dbc->disconnect_if_idle();
	my $anchor_seq_adaptor = $self->compara_dba->get_AnchorSeqAdaptor();

	my $analysis_data_adaptor = $self->db->get_AnalysisDataAdaptor();
	my $target_genome_files = eval $analysis_data_adaptor->fetch_by_dbID($self->param('analysis_data_id'));

	$self->param('target_file', $target_genome_files->{target_genomes}->{ $self->param('target_genome') } );
	my $anchors = $anchor_seq_adaptor->get_anchor_sequences($self->param('ancs_from_to'), $self->param('anchor_sequences_mlssid'));
	my $query_file = $self->worker_temp_directory  . "anchors." . join ("-", @{$self->param('ancs_from_to')});
	open F, ">$query_file" || throw("Couldn't open $query_file");
	foreach my $anchor_seq( @{ $anchors } ) {
		print F ">", join(":", @{$anchor_seq}[0..5]), "\n", $anchor_seq->[-1], "\n";
	}
	$self->param('query_file', $query_file);
}


sub run {
	my ($self) = @_;
	my $program = $self->param('mapping_exe');
	my $query_file = $self->param('query_file');
	my $target_file = $self->param('target_file');
	my $option_st;
	foreach my $option(sort keys %{ $self->param('exonerate_options') }) {
		$option_st .= " --" . $option . " " . $self->param('exonerate_options')->{$option}; 
	}
	my $command = join(" ", $program, $option_st, $query_file, $target_file); 
	print $command, "\n";
	my $exo_fh;
	open( $exo_fh, "$command |" ) or throw("Error opening exonerate command: $? $!"); #run exonerate	
	$self->param('exo_file', $exo_fh);
}


sub write_output {
	my ($self) = @_;
	my $anchor_align_adaptor = $self->compara_dba->get_AnchorAlignAdaptor();
	my $exo_fh = $self->param('exo_file');
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
							$coord_sys, $dnafrag_name, $self->param('target_genome') );
		die "no dnafrag_id found\n" unless($target2dnafrag->{$target_info});
	}
	my $hit_numbers = $self->merge_overlapping_target_regions($hits);
	my $records = $self->process_exonerate_hits($hits, $target2dnafrag, $hit_numbers);	
	$anchor_align_adaptor->store_exonerate_hits($records);
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
				push(@{$records_to_load}, join(":", $self->param('exonerate_mlssid'), $anchor_id, $dnafrag_id, 
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


1;

