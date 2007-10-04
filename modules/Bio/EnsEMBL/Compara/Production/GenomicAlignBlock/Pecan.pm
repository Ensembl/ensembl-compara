#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::Production::GenomicAlignBlock::Pecan

=cut

=head1 SYNOPSIS

=cut

=head1 DESCRIPTION

This module acts as a layer between the Hive sysmem and the Bio::EnsEMBL::Analysis::Runnable::Pecan
module since the ensembl-analysis API does not know about ennembl-compara

Pecan wants the files to be provided in the same orer as in the tree string. This module starts
by getting all the DnaFragRegions of the SyntenyRegion and then use them to edit the tree (some
nodes must be removed and otehr one must be duplicated in order to cope with deletions and
duplications). The buid_tree_string methods numbers the sequences in order and changes the
order of the dnafrag_regions array accordingly. Last, the dumpFasta() method dumps the sequences
according to the tree_string order.

=head1 OPTIONS

Both parameters and input_id are read as (string representing) hashes. Here is the list of keys:

=head2 synteny_region_id (mandatory)

The region to be aligned by Pecan, defined as a SyntenyRegion in the database

=head2 method_link_species_set_id (mandatory)

The MethodLinkSpeciesSet for the resulting Pecan alignment

=head2 tree_file

The path to the file containing the species tree in NEWICK format. Leaves names should be the genome_db_ids

=head2 tree_analysis_data_id

analysis_data entry containing the species tree in NEWICK format. Leaves names should be the genome_db_ids

This way of specifying the tree is recommended.

=head2 java_options

options used to run Java, ie: '-server -Xmx1000M'

=head2 exonerate

path to exonerate

=head2 max_block_size

split blocks longer than this size

=head2 trim (testing)

option to use only part of the SyntenyRegion. For instance, trim=>{from_905394=>125100925,from_2046355=>126902742,to_1045566=>139208434}
will use the region for DnaFrag 905394 from position 125100925 only,
the region for DnaFrag 2046355 from position 126902742 only and 
the region for DnaFrag 1045566 to position 139208434 only

=head1 CONTACT

Javier Herrero <jherrero@ebi.ac.uk>

=cut

=head1 APPENDIX

The rest of the documentation details each of the object methods. 
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::Production::GenomicAlignBlock::Pecan;

use strict;
use Bio::EnsEMBL::Analysis::Runnable::Pecan;
use Bio::EnsEMBL::Compara::DnaFragRegion;
use Bio::EnsEMBL::Compara::Production::DBSQL::DBAdaptor;;
use Bio::EnsEMBL::Utils::Exception;
use Bio::EnsEMBL::Compara::Graph::NewickParser;
use Bio::EnsEMBL::Compara::NestedSet;

use Bio::EnsEMBL::Hive::Process;

our @ISA = qw(Bio::EnsEMBL::Hive::Process);


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

  if (!$self->method_link_species_set_id) {
    throw("MethodLinkSpeciesSet->dbID is not defined for this Pecan job");
  }

  ## Store DnaFragRegions corresponding to the SyntenyRegion in $self->dnafrag_regions(). At this point the
  ## DnaFragRegions are in random order
  $self->_load_DnaFragRegions($self->synteny_region_id);
  if ($self->dnafrag_regions) {
    ## Get the tree string by taking into account duplications and deletions. Resort dnafrag_regions
    ## in order to match the name of the sequences in the tree string (seq1, seq2...)
    if ($self->get_species_tree and $self->dnafrag_regions) {
      $self->_build_tree_string;
    }
    ## Dumps fasta files for the DnaFragRegions. Fasta files order must match the entries in the
    ## newick tree. The order of the files will match the order of sequences in the tree_string.
    $self->_dump_fasta;
  } else {
    throw("Cannot start Pecan job because some information is missing");
  }

  return 1;
}

sub run
{
  my $self = shift;

  my $runnable = new Bio::EnsEMBL::Analysis::Runnable::Pecan(
      -workdir => $self->worker_temp_directory,
      -fasta_files => $self->fasta_files,
      -tree_string => $self->tree_string,
      -analysis => $self->analysis,
      -parameters => $self->{_java_options},
      -exonerate => $self->exonerate,
      );
  $self->{'_runnable'} = $runnable;
  $runnable->run_analysis;
}

sub write_output {
  my ($self) = @_;

  if ($self->{'_runnable'}->{tree_to_save}) {
    my $meta_container = $self->{'comparaDBA'}->get_MetaContainer;
    $meta_container->store_key_value("synteny_region_tree_".$self->synteny_region_id,
        $self->{'_runnable'}->{tree_to_save});
  }

  my $mlssa = $self->{'comparaDBA'}->get_MethodLinkSpeciesSetAdaptor;
  my $mlss = $mlssa->fetch_by_dbID($self->method_link_species_set_id);
  my $gaba = $self->{'comparaDBA'}->get_GenomicAlignBlockAdaptor;
#   $gaba->use_autoincrement(0);
  my $gaa = $self->{'comparaDBA'}->get_GenomicAlignAdaptor;
#   $gaa->use_autoincrement(0);

  my $gaga = $self->{'comparaDBA'}->get_GenomicAlignGroupAdaptor;

  foreach my $gab (@{$self->{'_runnable'}->output}) {
      foreach my $ga (@{$gab->genomic_align_array}) {
	  $ga->adaptor($gaa);
	  $ga->method_link_species_set($mlss);
	  $ga->level_id(1);
	  unless (defined $gab->length) {
	      $gab->length(length($ga->aligned_sequence));
	  }
      }
      $gab->adaptor($gaba);
      $gab->method_link_species_set($mlss);
      my $group;

      ## Hard trim condition (testing, this is intended for one single GAB only)
$gab->_print(\*STDERR);
      if ($self->trim) {
        $gab = $self->_hard_trim_gab($gab);
      }
$gab->_print(\*STDERR);

      # Split block if it is too long and store as groups
      # Remove any blocks which contain only 1 genomic align and trim the 2
      # neighbouring blocks 
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

sub _hard_trim_gab {
  my ($self, $gab) = @_;

  my $trim = $self->trim;
  die "Wrong trim argument" if (!%$trim);
  die "Wrong number of keys in trim argument" if (keys %$trim != @{$gab->get_all_GenomicAligns()});

  ## Check that trim hash matches current GAB
  my $match;
  while (my ($key, $value) = each %$trim) {
    my ($opt, $dnafrag_id) = $key =~ m/(\w+)_(\d+)/;
    $match = 0;
    foreach my $this_ga (@{$gab->get_all_GenomicAligns()}) {
      if ($this_ga->dnafrag_id == $dnafrag_id and $this_ga->dnafrag_start <= $value and
          $this_ga->dnafrag_end >= $value) {
        $match = 1;
        last;
      }
    }
    if (!$match) {
      last;
    }
  }
  die "Trim argument does not match current GAB" if (!$match);

  ## Get the right trimming coordinates
  print "Trying to trim this GAB... ", join("; ", map {$_." => ".$trim->{$_}} keys %$trim), "\n";
  my $final_start = $gab->length;
  my $final_end = 1;
  while (my ($key, $value) = each %$trim) {
    my ($opt, $dnafrag_id) = $key =~ m/(\w+)_(\d+)/;
    my $ref_ga = undef;
    foreach my $this_ga (@{$gab->get_all_GenomicAligns()}) {
      if ($this_ga->dnafrag_id == $dnafrag_id and $this_ga->dnafrag_start <= $value and
        $this_ga->dnafrag_end >= $value) {
        $ref_ga = $this_ga;
        last;
      }
    }
    if ($ref_ga) {
      my ($tmp_gab, $start, $end);
      if ($opt eq "from") {
        ($tmp_gab, $start, $end) = $gab->restrict_between_reference_positions($value, undef, $ref_ga);
      } elsif ($opt eq "to") {
        ($tmp_gab, $start, $end) = $gab->restrict_between_reference_positions(undef, $value, $ref_ga);
        my $tmp_start = $gab->length - $end + 1;
        my $tmp_end = $gab->length - $start + 1;
        $start = $tmp_start;
        $end = $tmp_end;
      } else {
        die;
      }
      ## Need to use the smallest start and largest end as the GAB may start with a gap for
      ## some of the GAs
      if ($start < $final_start) {
        $final_start = $start;
      }
      if ($end > $final_end) {
        $final_end = $end;
      }
      print " DNAFRAG $dnafrag_id : $start -- $end (alignment coordinates)\n";
    }
  }
  print " RESTRICT: $final_start -- $final_end (1 -- ", $gab->length, ")\n";
  $gab = $gab->restrict_between_alignment_positions($final_start, $final_end);

  ## Check result
  foreach my $this_ga (@{$gab->get_all_GenomicAligns()}) {
    my $check = 0;
    while (my ($key, $value) = each %$trim) {
      my ($opt, $dnafrag_id) = $key =~ m/(\w+)_(\d+)/;
      if ($dnafrag_id == $this_ga->dnafrag_id) {
        if ($opt eq "from" and $this_ga->dnafrag_start == $value) {
          $check = 1;
        } elsif ($opt eq "to" and $this_ga->dnafrag_end == $value) {
          $check = 1;
        } else {
          last;
        }
      }
    }
    die("Cannot trim this GAB as requested\n") if (!$check);
  }
  print "GAB trimmed as requested\n\n";

  return $gab;
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

sub dnafrag_regions {
  my $self = shift;
  $self->{'_dnafrag_regions'} = shift if(@_);
  return $self->{'_dnafrag_regions'};
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
    return undef;
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

sub exonerate {
  my $self = shift;
  $self->{'_exonerate'} = shift if(@_);
  return $self->{'_exonerate'};
}

sub trim {
  my $self = shift;
  $self->{'_trim'} = shift if(@_);
  return $self->{'_trim'};
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
  print("parsing parameter string : ",$param_string,"\n");

  my $params = eval($param_string);
  return unless($params);

  if(defined($params->{'synteny_region_id'})) {
    $self->synteny_region_id($params->{'synteny_region_id'});
  }
  if(defined($params->{'method_link_species_set_id'})) {
    $self->method_link_species_set_id($params->{'method_link_species_set_id'});
  }
  if(defined($params->{'java_options'})) {
    $self->{_java_options} = $params->{'java_options'};
  }
  if(defined($params->{'exonerate'})) {
    $self->exonerate($params->{'exonerate'});
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
  if(defined($params->{'trim'})) {
    $self->trim($params->{'trim'});
  }

  return 1;
}


=head2 _load_DnaFragRegions

  Arg [1]    : int syteny_region_id
  Example    : $self->_load_DnaFragRegions();
  Description: Gets the list of DnaFragRegions for this
               syteny_region_id. Resulting DnaFragRegions are
               stored using the dnafrag_regions getter/setter.
  Returntype : listref of Bio::EnsEMBL::Compara::DnaFragRegion objects
  Exception  :
  Warning    :

=cut

sub _load_DnaFragRegions {
  my ($self, $synteny_region_id) = @_;
  my $dnafrag_regions = [];

  # Fail if dbID has not been provided
  return $dnafrag_regions if (!$synteny_region_id);

  my $sra = $self->{'comparaDBA'}->get_SyntenyRegionAdaptor;
  my $sr = $sra->fetch_by_dbID($self->synteny_region_id);

  foreach my $dfr (@{$sr->children}) {  
    $dfr->disavow_parent;
    push(@{$dnafrag_regions}, $dfr);
  }

  $sr->release_tree;

  $self->dnafrag_regions($dnafrag_regions);
}


=head2 _dump_fasta

  Arg [1]    : -none-
  Example    : $self->_dump_fasta();
  Description: Dumps FASTA files in the order given by the tree
               string (needed by Pecan). Resulting file names are
               stored using the fasta_files getter/setter
  Returntype : 1
  Exception  :
  Warning    :

=cut

sub _dump_fasta {
  my $self = shift;

  my $all_dnafrag_regions = $self->dnafrag_regions;

  ## Dump FASTA files in the order given by the tree string (needed by Pecan)
  my @seqs;
  if ($self->tree_string) {
    @seqs = ($self->tree_string =~ /seq(\d+)/g);
  } else {
    @seqs = (1..scalar(@$all_dnafrag_regions));
  }
  foreach my $seq_id (@seqs) {
    my $dfr = $all_dnafrag_regions->[$seq_id-1];
    my $file = $self->worker_temp_directory . "/seq" . $seq_id . ".fa";

    open F, ">$file" || throw("Couldn't open $file");

    print F ">DnaFrag", $dfr->dnafrag_id, "|", $dfr->dnafrag->name, ".",
        $dfr->dnafrag_start, "-", $dfr->dnafrag_end, ":", $dfr->dnafrag_strand,"\n";
    my $slice = $dfr->slice;
    throw("Cannot get slice for DnaFragRegion in DnaFrag #".$dfr->dnafrag_id) if (!$slice);
    my $seq = $slice->get_repeatmasked_seq(undef, 1)->seq;
    if ($seq =~ /[^ACTGactgNnXx]/) {
      print STDERR $slice->name, " contains at least one non-ACTGactgNnXx character. These have been replaced by N's\n";
      $seq =~ s/[^ACTGactgNnXx]/N/g;
    }
    $seq =~ s/(.{80})/$1\n/g;
    chomp $seq;
    print F $seq,"\n";

    close F;

    push @{$self->fasta_files}, $file;
  }

  return 1;
}


=head2 _build_tree_string

  Arg [1]    : -none-
  Example    : $self->_build_tree_string();
  Description: This method sets the tree_string using the orginal
               species tree and the set of DnaFragRegions. The
               tree is edited by the _update_tree method which
               resort the DnaFragRegions (see _update_tree elsewwhere
               in this document)
  Returntype : -none-
  Exception  :
  Warning    :

=cut

sub _build_tree_string {
  my $self = shift;

  my $tree = $self->get_species_tree;
  return if (!$tree);

  $tree = $self->_update_tree($tree);

  my $tree_string = $tree->newick_simple_format;
  # Remove quotes around node labels
  $tree_string =~ s/"(seq\d+)"/$1/g;
  # Remove branch length if 0
  $tree_string =~ s/\:0\.0+(\D)/$1/g;
  $tree_string =~ s/\:0([^\.\d])/$1/g;

  $tree->release_tree;

  $self->tree_string($tree_string);
}


=head2 _update_tree

  Arg [1]    : Bio::EnsEMBL::Compara::NestedSet $tree_root
  Example    : $self->_update_nodes_names($tree);
  Description: This method updates the tree by removing or
               duplicating the leaves according to the orginal
               tree and the set of DnaFragRegions. The tree nodes
               will be renamed seq1, seq2, seq3 and so on and the
               DnaFragRegions will be resorted in order to match
               the names of the nodes (the first DnaFragRegion will
               correspond to seq1, the second to seq2 and so on).
  Returntype : Bio::EnsEMBL::Compara::NestedSet (a tree)
  Exception  :
  Warning    :

=cut

sub _update_tree {
  my $self = shift;
  my $tree = shift;

  my $all_dnafrag_regions = $self->dnafrag_regions();
  my $ordered_dnafrag_regions = [];

  my $idx = 1;
  my $all_leaves = $tree->get_all_leaves;
  foreach my $this_leaf (@$all_leaves) {
    my $these_dnafrag_regions = [];
    ## Look for DnaFragRegions belonging to this genome_db_id
    foreach my $this_dnafrag_region (@$all_dnafrag_regions) {
      if ($this_dnafrag_region->dnafrag->genome_db_id == $this_leaf->name) {
        push (@$these_dnafrag_regions, $this_dnafrag_region);
      }
    }

    if (@$these_dnafrag_regions == 1) {
      ## If only 1 has been found...
      $this_leaf->name("seq".$idx++); #.".".$these_dnafrag_regions->[0]->dnafrag_id);
      push(@$ordered_dnafrag_regions, $these_dnafrag_regions->[0]);

    } elsif (@$these_dnafrag_regions > 1) {
      ## If more than 1 has been found...
      foreach my $this_dnafrag_region (@$these_dnafrag_regions) {
        my $new_node = new Bio::EnsEMBL::Compara::NestedSet;
        $new_node->name("seq".$idx++);
        $new_node->distance_to_parent(0);
        push(@$ordered_dnafrag_regions, $this_dnafrag_region);
        $this_leaf->add_child($new_node);
      }

    } else {
      ## If none has been found...
      $this_leaf->disavow_parent;
      $tree = $tree->minimize_tree;
    }
  }
  $self->dnafrag_regions($ordered_dnafrag_regions);

  if (scalar(@$all_dnafrag_regions) != scalar(@$ordered_dnafrag_regions) or
      scalar(@$all_dnafrag_regions) != scalar(@{$tree->get_all_leaves})) {
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
