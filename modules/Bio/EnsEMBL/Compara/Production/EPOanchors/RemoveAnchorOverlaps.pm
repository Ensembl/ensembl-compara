
# You may distribute this module under the same terms as perl itself
# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::Production::EPOanchors::RemoveAnchorOverlaps

=cut

=head1 SYNOPSIS

parameters
{input_analysis_id=> ?,method_link_species_set_id=> ?,test_method_link_species_set_id=> ?, genome_db_ids => [?],}

=cut

=head1 DESCRIPTION

Removes the minimum number of overlappping anchors.

=cut

=head1 CONTACT

ensembl-compara@ebi.ac.uk

=cut

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::Production::EPOanchors::RemoveAnchorOverlaps;

use strict;
use Data::Dumper;
use Bio::EnsEMBL::Compara::Production::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Hive::Process;
use Bio::EnsEMBL::Compara::MethodLinkSpeciesSet;
use Bio::EnsEMBL::Compara::Production::EPOanchors::AnchorAlign;
use Bio::EnsEMBL::Utils::Exception qw(throw warning);


our @ISA = qw(Bio::EnsEMBL::Hive::Process);


sub configure_defaults {
 	my $self = shift;
  	return 1;
}

sub fetch_input {
	my ($self) = @_;
	$self->configure_defaults();

	$self->{'comparaDBA'} = Bio::EnsEMBL::Compara::Production::DBSQL::DBAdaptor->new(-DBCONN=>$self->db->dbc);
	$self->{'comparaDBA'}->dbc->disconnect_when_inactive(0);
	$self->get_params($self->parameters);
	return 1;
}

sub run {
	my ($self) = @_;
	my $anchor_align_adaptor = $self->{'comparaDBA'}->get_AnchorAlignAdaptor();
	my $dnafrag_ids = $anchor_align_adaptor->fetch_all_dnafrag_ids($self->test_method_link_species_set_id);
	my (%Overlappping_anchors, %Anchors_2_remove, %Scores);
	my $test_mlssid = $self->test_method_link_species_set_id;
	foreach my $genome_db_id(sort keys %{$dnafrag_ids}) {
		my %genome_db_dnafrags;
		foreach my $genome_db_anchors(@{ $anchor_align_adaptor->fetch_all_anchors_by_genome_db_id_and_mlssid(
						$genome_db_id, $test_mlssid) }) {
			push(@{ $genome_db_dnafrags{ $genome_db_anchors->[0] } }, [ @{ $genome_db_anchors }[1..4] ]);	
		}
		foreach my $dnafrag_id(sort keys %genome_db_dnafrags) {
			my @Dnafrag_anchors = @{ $genome_db_dnafrags{$dnafrag_id} };
			for(my$i=0;$i<@Dnafrag_anchors-1;$i++) { #count number of overlaps an anchor has at every position to which it maps
				for(my$j=$i+1;$j<@Dnafrag_anchors;$j++) {
					if($Dnafrag_anchors[$i]->[3] >= $Dnafrag_anchors[$j]->[2]) {
						$Overlappping_anchors{$Dnafrag_anchors[$i]->[1]}{$Dnafrag_anchors[$j]->[1]}++;
						$Overlappping_anchors{$Dnafrag_anchors[$j]->[1]}{$Dnafrag_anchors[$i]->[1]}++;
					}
					else {
						splice(@Dnafrag_anchors, $i, 1);
						$i--;
						last;
					}
				}
			}
		}
	}
	foreach my$anchor(sort keys %Overlappping_anchors) {
		foreach my $overlapping_anchor(sort keys %{$Overlappping_anchors{$anchor}}) {
			$Scores{$anchor} += ($Overlappping_anchors{$anchor}{$overlapping_anchor})**2; #score the anchors according to the number of overlaps
		}
	}
	print STDERR "scores: ", scalar(keys %Scores), "\n";
	my$flag = 1;
	while($flag) {
		$flag = 0;
		foreach my $anchor(sort {$Scores{$b} <=> $Scores{$a}} keys %Scores) { #get highest scoring anchor
			next unless(exists($Scores{$anchor})); #don't add it to "remove list" if it's already gone from the score hash 
			foreach my $anc_with_overlap_2_anchor(sort keys %{$Overlappping_anchors{$anchor}}) { #find all the anchors which overlap this anchor 
				$Scores{$anc_with_overlap_2_anchor} -= ($Overlappping_anchors{$anc_with_overlap_2_anchor}{$anchor})**2; #decrement the score
				delete $Scores{$anc_with_overlap_2_anchor} unless($Scores{$anc_with_overlap_2_anchor});
				#if score is zero remove this anchor from the overlapping list, 
				delete($Overlappping_anchors{$anc_with_overlap_2_anchor}{$anchor}); #remove high scoring anchor from hash of overlaps
			}
			delete($Overlappping_anchors{$anchor}); #remove high scoring anchor from hash 
			delete($Scores{$anchor}); #also remove it from scoring hash
			$Anchors_2_remove{$anchor}++; #add it to list of ancs to remove
		}
		$flag = 1  if (scalar(keys %Scores));
	}
	print STDERR "anchors to remove: ", scalar(keys %Anchors_2_remove), "\n";
	$self->overlapping_ancs_to_remove(\%Anchors_2_remove);
	return 1;
}


sub write_output {
	my ($self) = @_;
	my $anchor_align_adaptor = $self->{'comparaDBA'}->get_AnchorAlignAdaptor();
	my $current_analysis_id = $self->input_analysis_id();
	my $Anchors_2_remove = $self->overlapping_ancs_to_remove(); 
	my $test_mlssid = $self->test_method_link_species_set_id();
	$anchor_align_adaptor->update_failed_anchor($Anchors_2_remove, $current_analysis_id, $test_mlssid);	
	return 1;
}

sub test_method_link_species_set_id {
	my $self = shift;
	if (@_) {
		$self->{test_method_link_species_set_id} = shift;
	}
	return $self->{test_method_link_species_set_id};
}	

sub overlapping_ancs_to_remove {
	my $self = shift;
	if (@_) {
		$self->{overlapping_ancs_to_remove} = shift;
	}
	return $self->{overlapping_ancs_to_remove};
}

sub genome_db_ids {
	my $self = shift;
	if (@_) {
		$self->{genome_db_ids} = shift;
	}
	return $self->{genome_db_ids};
}

sub method_link_species_set_id {
	my $self = shift;
	if (@_) {
		$self->{method_link_species_set_id} = shift;
	}
	return $self->{method_link_species_set_id};
}

sub input_analysis_id {
	my $self = shift;
	if (@_) {
		$self->{input_analysis_id} = shift;
	}
	return $self->{input_analysis_id};
}

sub get_params {
  my $self         = shift;
  my $param_string = shift;

  return unless($param_string);
  print("parsing parameter string : ",$param_string,"\n");

  my $params = eval($param_string);
  return unless($params);

  if(defined($params->{'genome_db_ids'})) {
    $self->genome_db_ids($params->{'genome_db_ids'});
  }
  if(defined($params->{'test_method_link_species_set_id'})) {
	$self->test_method_link_species_set_id($params->{'test_method_link_species_set_id'});
  }
  if(defined($params->{'method_link_species_set_id'})) {
	$self->method_link_species_set_id($params->{'method_link_species_set_id'});
  }
  if(defined($params->{'input_analysis_id'})) {
    $self->input_analysis_id($params->{'input_analysis_id'});
  }
  return 1;
}

#sub store_input {
#  my $self = shift;
#
#  if (@_) {
#    $self->{_store_input} = shift;
#  }
#
#  return $self->{_store_input};
#}
#
#sub store_output {
#  my $self = shift;
#
#  if (@_) {
#    $self->{_store_output} = shift;
#  }
#
#  return $self->{_store_output};
#}

1;

