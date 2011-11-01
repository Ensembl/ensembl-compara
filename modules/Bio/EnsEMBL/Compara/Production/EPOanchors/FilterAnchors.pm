
# You may distribute this module under the same terms as perl itself
# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::Production::GenomicAlignBlock::EPOanchors::FilterAnchors

=cut

=head1 SYNOPSIS

parameters
{input_analysis_id=> ?,method_link_species_set_id=> ?,test_method_link_species_set_id=> ?}

=cut

=head1 DESCRIPTION

There are 3 hard-coded filtering conditions for          
anchor removal: 
1). Anchors which hit > 5 dnafrags in any one genome.
2). Anchors which hit the same dnafrag > 10 in any one genome.
3). Anchors which hit any one genome > 20 times.

=cut

=head1 CONTACT

ensembl-compara@ebi.ac.uk

=cut

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with a _

=cut


package Bio::EnsEMBL::Compara::Production::EPOanchors::FilterAnchors;

use strict;
use Data::Dumper;
use Bio::EnsEMBL::Compara::Production::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Hive::Process;
use Bio::EnsEMBL::Compara::MethodLinkSpeciesSet;
use Bio::EnsEMBL::Compara::Production::EPOanchors::AnchorAlign;
use Bio::EnsEMBL::Utils::Exception qw(throw warning);

use constant MAX_NUMBER_OF_DNAFRAGS_HIT => 5; #max number of dnafrags hit per genome
use constant MAX_NUMBER_OF_HITS_TO_SAME_DNAFRAG => 10;
use constant MAX_NUMBER_OF_HITS_TO_ANY_ONE_GENOME => 20;


our @ISA = qw(Bio::EnsEMBL::Hive::Process);


sub configure_defaults {
  my $self = shift;
  $self->max_number_of_dnafrags_hit(MAX_NUMBER_OF_DNAFRAGS_HIT);
  $self->max_number_of_hits_to_same_dnafrag(MAX_NUMBER_OF_HITS_TO_SAME_DNAFRAG);
  $self->max_number_of_hits_to_any_one_genome(MAX_NUMBER_OF_HITS_TO_ANY_ONE_GENOME);
  return 0;
}

sub fetch_input {
  my ($self) = @_;

  $self->configure_defaults();

  #create a Compara::DBAdaptor which shares the same DBI handle
  #with $self->db (Hive DBAdaptor)
  $self->{'comparaDBA'} = Bio::EnsEMBL::Compara::Production::DBSQL::DBAdaptor->new(-DBCONN=>$self->db->dbc);
  $self->{'comparaDBA'}->dbc->disconnect_when_inactive(0);

  my $dnafrag_adaptor = $self->{'comparaDBA'}->get_DnaFragAdaptor();
  my $anchor_align_adaptor = $self->{'comparaDBA'}->get_AnchorAlignAdaptor();

  $self->get_params($self->parameters);
  $self->get_params($self->input_id);
  return 1;
}

sub run {

	my ($self) = @_;
	my $anchor_align_adaptor = $self->{'comparaDBA'}->get_AnchorAlignAdaptor();
	my(@palindromic_anchors, $all_anchors, %anchor_hits2genomes_and_dnafrags, %anchors2remove);
	$self->anchor_ids_with_zero_strand(
		$anchor_align_adaptor->fetch_all_anchors_with_zero_strand(
			$self->test_method_link_species_set_id));
	$all_anchors = $anchor_align_adaptor->fetch_all_anchor_ids_by_test_mlssid_and_genome_db_ids(
		$self->test_method_link_species_set_id, $self->genome_db_ids);
	foreach my $anchor (@{$all_anchors}) {
		my $dnafrags_and_genomedbs = $anchor_align_adaptor->fetch_dnafrag_and_genome_db_ids_by_test_mlssid(
			$self->test_method_link_species_set_id, $anchor->[0]);
		foreach my $genome_db_dnafrag(@{$dnafrags_and_genomedbs}) {
			$anchor_hits2genomes_and_dnafrags{$anchor->[0]}{$genome_db_dnafrag->[1]}{$genome_db_dnafrag->[0]}++;
		}
	}
	foreach my $anchor_id(sort keys %anchor_hits2genomes_and_dnafrags) {
		foreach my $genome_db_id(sort keys %{$anchor_hits2genomes_and_dnafrags{$anchor_id}}) {
			last if(exists($anchors2remove{$anchor_id}));
			my $num_hits_to_each_genome = 0;
			if(scalar(keys %{$anchor_hits2genomes_and_dnafrags{$anchor_id}{$genome_db_id}}) > $self->max_number_of_dnafrags_hit) {
				$anchors2remove{$anchor_id}++;
#				print "MAX_NUM_DNAFRAGS_HIT : $anchor_id\n";
				last;
			}
			foreach my $dnafrag_id(%{$anchor_hits2genomes_and_dnafrags{$anchor_id}{$genome_db_id}}) {
				if($anchor_hits2genomes_and_dnafrags{$anchor_id}{$genome_db_id}{$dnafrag_id} > $self->max_number_of_hits_to_same_dnafrag) {
					$anchors2remove{$anchor_id}++;
#					print "MAX_NUM_HITS_TO_SAME_DNAFRAG : $anchor_id\n";	
					last;
				}
				else{
					$num_hits_to_each_genome += $anchor_hits2genomes_and_dnafrags{$anchor_id}{$genome_db_id}{$dnafrag_id};
				}
			}
			if($num_hits_to_each_genome > $self->max_number_of_hits_to_any_one_genome) {
				$anchors2remove{$anchor_id}++;
#				print "MAX_NUM_HITS_TO_ANY_ONE_GENOME : $anchor_id\n";
				last;
			}
		}
	}
	$self->anchors2remove(\%anchors2remove);
	return 1;
}

sub write_output {
	my ($self) = @_;
	my $anchor_align_adaptor = $self->{'comparaDBA'}->get_AnchorAlignAdaptor();
	print join(":", $self->input_analysis_id, $self->test_method_link_species_set_id), "\n";
	$anchor_align_adaptor->update_zero_strand_anchors($self->anchor_ids_with_zero_strand, 
		$self->input_analysis_id, $self->test_method_link_species_set_id);
	if(scalar (keys %{$self->anchors2remove})) {
		$anchor_align_adaptor->update_failed_anchor($self->anchors2remove, $self->input_analysis_id, $self->test_method_link_species_set_id);
	}			
	else{
		print "No anchors to remove\n";
	}
  return 1;
}

sub anchor_ids_with_zero_strand {
	my $self = shift;
	if (@_) {
		$self->{anchor_ids_with_zero_strand} = shift;
	}
	return $self->{anchor_ids_with_zero_strand};
}

sub anchors2remove {
	my $self = shift;
	if (@_) {
		$self->{anchors2remove} = shift;
	}
	return $self->{anchors2remove};
}

sub max_number_of_dnafrags_hit {
	my $self = shift;
	if (@_) {
		$self->{max_number_of_dnafrags_hit} = shift;
	}
	return $self->{max_number_of_dnafrags_hit};
}

sub max_number_of_hits_to_same_dnafrag {
	my $self = shift;
	if (@_) {
		$self->{max_number_of_hits_to_same_dnafrag} = shift;
	}
	return $self->{max_number_of_hits_to_same_dnafrag};
}

sub max_number_of_hits_to_any_one_genome {
	my $self = shift;
	if (@_) {
		$self->{max_number_of_hits_to_any_one_genome} = shift;
	}
	return $self->{max_number_of_hits_to_any_one_genome};
}

sub test_method_link_species_set_id {
	my $self = shift;
	if (@_) {
		$self->{test_method_link_species_set_id} = shift;
	}
	return $self->{test_method_link_species_set_id};
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

sub genome_db_ids {
	my $self = shift;
	if (@_) {
		$self->{genome_db_ids} = shift;
	}
	return $self->{genome_db_ids};
}

#sub method_link_type {
#	my $self = shift;
#	if (@_) {
#		$self->{method_link_type} = shift;
#	}
#	return $self->{method_link_type};
#}
#
#sub input_anchor_id {
#	my $self = shift;
#	if (@_) {
#		$self->{input_anchor_id} = shift;
#	}
#	return $self->{input_anchor_id};
#}

sub get_params {
  my $self         = shift;
  my $param_string = shift;

  return unless($param_string);
  print("parsing parameter string : ",$param_string,"\n");

  my $params = eval($param_string);
  return unless($params);

  if(defined($params->{'test_method_link_species_set_id'})) {
    $self->test_method_link_species_set_id($params->{'test_method_link_species_set_id'});
  }
  if(defined($params->{'method_link_species_set_id'})) {
	$self->method_link_species_set_id($params->{'method_link_species_set_id'});
  }
  if(defined($params->{'input_analysis_id'})) {
    $self->input_analysis_id($params->{'input_analysis_id'});
  }
  if(defined($params->{'genome_db_ids'})) {
    $self->genome_db_ids($params->{'genome_db_ids'});
  }
  
  if(defined($params->{'method_link_type'})) {
    $self->method_link_type($params->{'method_link_type'});
  }
  if(defined($params->{'input_anchor_id'})) { #same as anchor_id
	$self->input_anchor_id($params->{'input_anchor_id'});
  }
  if(defined($params->{'anchor_id'})) { #same as input_anchor_id
	$self->input_anchor_id($params->{'anchor_id'});
  }
  return 1;
}

#sub store_input {
#  my $self = shift;
#
#  if (@_) {
#    $self->{store_input} = shift;
#  }
#
#  return $self->{store_input};
#}


1;

