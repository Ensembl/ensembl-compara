#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::Production::GenomicAlignBlock::Mlagan

=cut

=head1 SYNOPSIS

=cut

=head1 DESCRIPTION


=cut

=head1 CONTACT

Abel Ureta-Vidal <abel@ebi.ac.uk>

=cut

=head1 APPENDIX

The rest of the documentation details each of the object methods. 
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::Production::GenomicAlignBlock::Mlagan;

use strict;
use Bio::EnsEMBL::Analysis::Runnable::Mlagan;
use Bio::EnsEMBL::Compara::DnaFragRegion;
use Bio::EnsEMBL::Compara::Production::DBSQL::DBAdaptor;;
use Bio::EnsEMBL::Utils::Exception;
use Bio::EnsEMBL::Compara::NestedSet;
use Bio::EnsEMBL::Compara::Graph::NewickParser;
use Time::HiRes qw(time gettimeofday tv_interval);

use Bio::EnsEMBL::Hive::Process;
our @ISA = qw(Bio::EnsEMBL::Hive::Process);

$| = 1;


=head2 fetch_input

    Title   :   fetch_input
    Usage   :   $self->fetch_input
    Function:   Fetches input data for repeatmasker from the database
    Returns :   none
    Args    :   none

=cut

sub fetch_input {
  my( $self) = @_;

  $self->{'comparaDBA'} = Bio::EnsEMBL::Compara::Production::DBSQL::DBAdaptor->new(-DBCONN=>$self->db->dbc);
  $self->{'hiveDBA'} = Bio::EnsEMBL::Hive::DBSQL::DBAdaptor->new(-DBCONN => $self->{'comparaDBA'}->dbc);
  $self->get_params($self->parameters);
  $self->get_params($self->input_id);

  $self->dumpFasta;

  return 1;
}

sub run
{
  my $self = shift;

  throw("Wrong tree: ".$self->tree_string) if ($self->tree_string !~ /^\(/);
  my $runnable = new Bio::EnsEMBL::Analysis::Runnable::Mlagan
    (-workdir => $self->worker_temp_directory,
     -fasta_files => $self->fasta_files,
     -tree_string => $self->tree_string,
     -analysis => $self->analysis);
  $self->{'_runnable'} = $runnable;
  $runnable->run_analysis;
}

sub write_output {
  my ($self) = @_;

  my $mlssa = $self->{'comparaDBA'}->get_MethodLinkSpeciesSetAdaptor;
  my $mlss = $mlssa->fetch_by_dbID($self->method_link_species_set_id);
  my $gaba = $self->{'comparaDBA'}->get_GenomicAlignBlockAdaptor;
  my $gaga = $self->{'comparaDBA'}->get_GenomicAlignGroupAdaptor;

  foreach my $gab (@{$self->{'_runnable'}->output}) {
    foreach my $ga (@{$gab->genomic_align_array}) {
      $ga->method_link_species_set($mlss);
      my $dfr = $self->{'_dnafrag_regions'}{$ga->dnafrag_id};
      $ga->dnafrag_id($dfr->dnafrag_id);
      $ga->dnafrag($dfr->dnafrag);
      $ga->dnafrag_start($dfr->dnafrag_start);
      $ga->dnafrag_end($dfr->dnafrag_end);
      $ga->dnafrag_strand($dfr->dnafrag_strand);
      $ga->level_id(1);
      $dfr->release;
      unless (defined $gab->length) {
        $gab->length(length($ga->aligned_sequence));
      }
    }
    $gab->method_link_species_set($mlss);
    
    my $group;
    # Split block if it is too long and store as groups
    if ($self->max_block_size() and $gab->length > $self->max_block_size()) {
	my $gab_array = undef;
	my $find_next = 0;

	for (my $start = 1; $start <= $gab->length; $start += $self->max_block_size()) {
	    my $split_gab = $gab->restrict_between_alignment_positions(
			   $start, $start + $self->max_block_size() - 1, 1);

	    #less than 2 genomic_aligns
	    if (@{$split_gab->get_all_GenomicAligns()} < 2) {
		#set find_next flag to remember to trim the block to the right if it has more than 2 genomic_aligns
		$find_next = 1;
		
		#trim the previous block
		my $prev_gab = pop @$gab_array;
		my $trim_gab = _trim_gab_right($prev_gab);
		
		#check it has at least 2 genomic_aligns, otherwise try again 
		while (@{$trim_gab->get_all_GenomicAligns()} < 2) {
		    $prev_gab = pop @$gab_array;
		    $trim_gab = _trim_gab_right($prev_gab);
		}
		#add trimmed block to array
		if ($trim_gab) {
		    push @$gab_array, $trim_gab;
		}
	    } else {
		#more than 2 genomic_aligns
		push @$gab_array, $split_gab; 
		#but may be to the right of a gab with only 1 ga and 
		#therefore needs to be trimmed
		if ($find_next) {
		    my $next_gab = pop @$gab_array;
		    my $trim_gab = _trim_gab_left($next_gab);
		    if (@{$trim_gab->get_all_GenomicAligns()} >= 2) {
			push @$gab_array, $trim_gab;
			$find_next = 0;
		    }
		}
	    }
	}
	#store the first block to get the dbID which is used to create the
	#group_id. 
	my $first_block = shift @$gab_array;
	$gaba->store($first_block);
	my $group_id = $first_block->dbID;
	$gaba->store_group_id($first_block, $group_id);
	$self->_write_gerp_dataflow($first_block, $mlss);
	
	#store the rest of the genomic_align_blocks
	foreach my $this_gab (@$gab_array) {
	    $this_gab->group_id($group_id);
	    $gaba->store($this_gab);
	    $self->_write_gerp_dataflow($this_gab, $mlss);
	}
    } else {
	$gaba->store($gab);
	$self->_write_gerp_dataflow($gab, $mlss);
    }
  }
  return 1;
}


#trim genomic align block from the left hand edge to first position having at
#least 2 genomic aligns which overlap
sub _trim_gab_left {
    my ($gab) = @_;
    
    if (!defined($gab)) {
	return undef;
    }
    my $align_length = $gab->length;
    
    my $gas = $gab->get_all_GenomicAligns();
    my $d_length;
    my $m_length;
    my $min_d_length = $align_length;
    
    my $found_min = 0;

    #take first element in cigar string for each genomic_align and if it is a
    #match, it must extend to the start of the block. Find the shortest delete.
    #If the shortest delete and the match are the same length, there is no
    #overlap between them so restrict to the end of the delete and try again.
    #If the delete is shorter than the match, there must be an overlap.
    foreach my $ga (@$gas) {
	my ($cigLength, $cigType) = ( $ga->cigar_line =~ /^(\d*)([GMD])/ );
	$cigLength = 1 unless ($cigLength =~ /^\d+$/);

	if ($cigType eq "D" or $cigType eq "G") {
	    $d_length = $cigLength; 
	    if ($d_length < $min_d_length) {
		$min_d_length = $d_length;
	    }
	} else {
	    $m_length = $cigLength;
	    $found_min++;
	}
    }
    #if more than one alignment filled to the left edge, no need to restrict
    if ($found_min > 1) {
	return $gab;
    }

    my $new_gab = ($gab->restrict_between_alignment_positions(
							      $min_d_length+1, $align_length, 1));

    #no overlapping genomic_aligns
    if ($new_gab->length == 0) {
	return $new_gab;
    }

    #if delete length is less than match length then must have sequence overlap
    if ($min_d_length < $m_length) {
	return $new_gab;
    }
    #otherwise try again with restricted gab
    return _trim_gab_left($new_gab);
}

#trim genomic align block from the right hand edge to first position having at
#least 2 genomic aligns which overlap
sub _trim_gab_right {
    my ($gab) = @_;
    
    if (!defined($gab)) {
	return undef;
    }
    my $align_length = $gab->length;

    my $max_pos = 0;
    my $gas = $gab->get_all_GenomicAligns();
    
    my $found_max = 0;
    my $d_length;
    my $m_length;
    my $min_d_length = $align_length;

    #take last element in cigar string for each genomic_align and if it is a
    #match, it must extend to the end of the block. Find the shortest delete.
    #If the shortest delete and the match are the same length, there is no
    #overlap between them so restrict to the end of the delete and try again.
    #If the delete is shorter than the match, there must be an overlap.
    foreach my $ga (@$gas) {
	my ($cigLength, $cigType) = ( $ga->cigar_line =~ /(\d*)([GMD])$/ );
	$cigLength = 1 unless ($cigLength =~ /^\d+$/);

	if ($cigType eq "D" or $cigType eq "G") {
	    $d_length =$cigLength;
	    if ($d_length < $min_d_length) {
		$min_d_length = $d_length;
	    }
	} else {
	    $m_length = $cigLength;
	    $found_max++;
	}
    }
    #if more than one alignment filled the right edge, no need to restrict
    if ($found_max > 1) {
	return $gab;
    }

    my $new_gab = $gab->restrict_between_alignment_positions(1, $align_length - $min_d_length, 1);

    #no overlapping genomic_aligns
    if ($new_gab->length == 0) {
	return $new_gab;
    }

    #if delete length is less than match length then must have sequence overlap
    if ($min_d_length < $m_length) {
	return $new_gab;
    }
    #otherwise try again with restricted gab
    return _trim_gab_right($new_gab);
}

sub _write_gerp_dataflow {
    my ($self, $gab, $mlss) = @_;

    my $species_set = "[";
    my $genome_db_set  = $mlss->species_set;

    foreach my $genome_db (@$genome_db_set) {
	$species_set .= $genome_db->dbID . ","; 
    }
    $species_set .= "]";
      
    my $output_id = "{genomic_align_block_id=>" . $gab->dbID . ",species_set=>" .  $species_set . "}";
    $self->dataflow_output_id($output_id);

}

##########################################
#
# getter/setter methods
# 
##########################################

#sub input_dir {
#  my $self = shift;
#  $self->{'_input_dir'} = shift if(@_);
#  return $self->{'_input_dir'};
#}

sub synteny_region_id {
  my $self = shift;
  $self->{'_synteny_region_id'} = shift if(@_);
  return $self->{'_synteny_region_id'};
}

sub fasta_files {
  my $self = shift;

  $self->{'_fasta_files'} = [] unless (defined $self->{'_fasta_files'});

  if (@_) {
    my $value = shift;
    push @{$self->{'_fasta_files'}}, $value;
  }

  return $self->{'_fasta_files'};
}

sub get_species_tree {
  my $self = shift;

  my $newick_species_tree;
  if (defined($self->{_species_tree})) {
    return $self->{_species_tree};
  } elsif ($self->{_tree_analysis_data_id}) {
    my $analysis_data_adaptor = $self->{hiveDBA}->get_AnalysisDataAdaptor();
    $newick_species_tree = $analysis_data_adaptor->fetch_by_dbID($self->{_tree_analysis_data_id});
  } elsif ($self->{_tree_file}) {
    open(TREE_FILE, $self->{_tree_file}) or throw("Cannot open file ".$self->{_tree_file});
    $newick_species_tree = join("", <TREE_FILE>);
    close(TREE_FILE);
  }

  if (!defined($newick_species_tree)) {
    throw("Cannot get the species tree");
  }

  $newick_species_tree =~ s/^\s*//;
  $newick_species_tree =~ s/\s*$//;
  $newick_species_tree =~ s/[\r\n]//g;

  $self->{'_species_tree'} =
      Bio::EnsEMBL::Compara::Graph::NewickParser::parse_newick_into_tree($newick_species_tree);

  return $self->{'_species_tree'};
}

sub tree_string {
  my $self = shift;
  $self->{'_tree_string'} = shift if(@_);
  return $self->{'_tree_string'};
}

sub method_link_species_set_id {
  my $self = shift;
  $self->{'_method_link_species_set_id'} = shift if(@_);
  return $self->{'_method_link_species_set_id'};
}

sub max_block_size {
  my $self = shift;
  $self->{'_max_block_size'} = shift if(@_);
  return $self->{'_max_block_size'};
}


##########################################
#
# internal methods
#
##########################################

sub get_params {
  my $self         = shift;
  my $param_string = shift;

  return unless($param_string);
#   print("parsing parameter string : ",$param_string,"\n");

  my $params = eval($param_string);
  return unless($params);

  if(defined($params->{'synteny_region_id'})) {
    $self->synteny_region_id($params->{'synteny_region_id'});
  }
  if(defined($params->{'method_link_species_set_id'})) {
    $self->method_link_species_set_id($params->{'method_link_species_set_id'});
  }
  if(defined($params->{'tree_file'})) {
    $self->{_tree_file} = $params->{'tree_file'};
  }
  if(defined($params->{'tree_analysis_data_id'})) {
    $self->{_tree_analysis_data_id} = $params->{'tree_analysis_data_id'};
  }
  if(defined($params->{'max_block_size'})) {
    $self->{_max_block_size} = $params->{'max_block_size'};
  }

  return 1;
}

sub dumpFasta {
  my $self = shift;

#  $self->{'comparaDBA'}->dbc->disconnect_when_inactive(1);

  my $sra = $self->{'comparaDBA'}->get_SyntenyRegionAdaptor;

  my $sr = $sra->fetch_by_dbID($self->synteny_region_id);

  my $idx = 1;

  foreach my $dfr (@{$sr->children}) {  
    my $file = $self->worker_temp_directory . "/seq" . $idx . ".fa";
    my $masked_file = $self->worker_temp_directory . "/seq" . $idx . ".fa.masked";
    $idx++;

    open F, ">$file" || throw("Couldn't open $file");
    open MF, ">$masked_file" || throw("Couldn't open $masked_file");

    # WARNING this is a hack. It won't work at all on self comparisons!!!
    # This will be more generic and fixed when the retain/release call will be
    # cleaned from the Node/Link/NestedSet code.
    # !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    $self->{'_dnafrag_regions'}{$dfr->dnafrag_id} = $dfr;
    $dfr->retain;
    $dfr->disavow_parent;
    my $slice = $dfr->slice;
    print F ">DnaFrag" . $dfr->dnafrag_id . ".\n";
    print MF ">DnaFrag" . $dfr->dnafrag_id . ".\n";
    my $seq = $slice->seq;
    $seq =~ s/(.{80})/$1\n/g;
    chomp $seq;
    print F $seq,"\n";
    $seq = $slice->get_repeatmasked_seq->seq;
    $seq =~ s/(.{80})/$1\n/g;
    chomp $seq;
    print MF $seq,"\n";
  
    close F;
    close MF;

    push @{$self->fasta_files}, $file;
  }
#  $self->{'comparaDBA'}->dbc->disconnect_when_inactive(0);

  $sr->release_tree;

  if ($self->get_species_tree) {
    my $tree_string = $self->build_tree_string;
    $self->tree_string($tree_string);
  }

  return 1;
}

sub build_tree_string {
  my $self = shift;

  my $tree = $self->get_species_tree;
  return if (!$tree);

  $tree = $self->update_node_names($tree);

  my $tree_string = $tree->newick_simple_format;

  $tree_string =~ s/:\d+\.\d+//g;
  $tree_string =~ s/[,;]/ /g;
  $tree_string =~ s/\"//g;

  $tree->release_tree;

  return $tree_string;
}

sub update_node_names {
  my $self = shift;
  my $tree = shift;
  my %gdb_id2dfr;
  foreach my $dfr (values %{$self->{'_dnafrag_regions'}}) {
    $gdb_id2dfr{$dfr->dnafrag->genome_db->dbID} = "DnaFrag".$dfr->dnafrag_id .".";
  }

  foreach my $leaf (@{$tree->get_all_leaves}) {
    if (defined $gdb_id2dfr{$leaf->name}) {
      $leaf->name($gdb_id2dfr{$leaf->name});
    } else {
      $leaf->disavow_parent;
      $tree = $tree->minimize_tree;
    }
  }
  if (@{$tree->get_all_leaves} != scalar(values %{$self->{'_dnafrag_regions'}})) {
    throw("Tree has a wrong number of leaves after updating the node names");
  }
  if ($tree->get_child_count == 1) {
    my $child = $tree->children->[0];
    $child->parent->merge_children($child);
    $child->disavow_parent;
  }
  return $tree;
}

1;
