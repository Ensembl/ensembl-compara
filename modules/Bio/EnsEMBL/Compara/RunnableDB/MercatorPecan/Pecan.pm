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

Bio::EnsEMBL::Compara::RunnableDB::MercatorPecan::Pecan

=cut

=head1 SYNOPSIS

=cut

=head1 DESCRIPTION

This module acts as a layer between the Hive system and the Bio::EnsEMBL::Analysis::Runnable::Pecan
module since the ensembl-analysis API does not know about ennembl-compara

Pecan wants the files to be provided in the same order as in the tree string. This module starts
by getting all the DnaFragRegions of the SyntenyRegion and then use them to edit the tree (some
nodes must be removed and otehr one must be duplicated in order to cope with deletions and
duplications). The buid_tree_string methods numbers the sequences in order and changes the
order of the dnafrag_regions array accordingly. Last, the dumpFasta() method dumps the sequences
according to the tree_string order.

Supported keys:
   'synteny_region_id' => <number>
       The region to be aligned by Pecan, defined as a SyntenyRegion in the database. Obligatory

   'mlss_id' => <number>
       The MethodLinkSpeciesSet for the resulting Pecan alignment. Obligatory

   'java_options' => <options>
      Options used to run Java, ie: '-server -Xmx1000M'

   'exonerate_exe' => <path>
      Path to exonerate

   'max_block_size' => <number>
       Split blocks longer than this size

   'trim' => <string>  (testing)
       Option to use only part of the SyntenyRegion. For instance, trim=>{from_905394=>125100925,from_2046355=>126902742,to_1045566=>139208434}
       will use the region for DnaFrag 905394 from position 125100925 only,
       the region for DnaFrag 2046355 from position 126902742 only and 
       the region for DnaFrag 1045566 to position 139208434 only

=head1 APPENDIX

The rest of the documentation details each of the object methods. 
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::RunnableDB::MercatorPecan::Pecan;

use strict;
use warnings;
use Bio::EnsEMBL::Utils::Exception qw(throw);
use Bio::EnsEMBL::Compara::Production::Analysis::Pecan;
use Bio::EnsEMBL::Compara::Production::Analysis::Ortheus;
use Bio::EnsEMBL::Compara::DnaFragRegion;
use Bio::EnsEMBL::Compara::Graph::NewickParser;
use Bio::EnsEMBL::Compara::NestedSet;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub param_defaults {
    return {
            'trim' => undef,
            'species_order' => undef, #local
            'species_tree' => undef, #local
            'default_java_class'    => 'bp.pecan.Pecan',
           };
}

=head2 fetch_input

    Title   :   fetch_input
    Usage   :   $self->fetch_input
    Function:   Fetches input data for repeatmasker from the database
    Returns :   none
    Args    :   none

=cut

sub fetch_input {
  my( $self) = @_;

  #set default to 0. Run Ortheus to create the tree if a duplication is found
  $self->param('found_a_duplication', 0);

  #Check that mlss_id has been defined
  $self->param_required('mlss_id');

  # Initialize the array
  $self->param('fasta_files', []);

  ## Store DnaFragRegions corresponding to the SyntenyRegion in $self->dnafrag_regions(). At this point the
  ## DnaFragRegions are in random order
  $self->_load_DnaFragRegions($self->param_required('synteny_region_id'));
  if ($self->param('dnafrag_regions')) {
    ## Get the tree string by taking into account duplications and deletions. Resort dnafrag_regions
    ## in order to match the name of the sequences in the tree string (seq1, seq2...)
    if ($self->get_species_tree and $self->param('dnafrag_regions')) {
      $self->_build_tree_string;
    }
    ## Dumps fasta files for the DnaFragRegions. Fasta files order must match the entries in the
    ## newick tree. The order of the files will match the order of sequences in the tree_string.
    $self->compara_dba->dbc->disconnect_if_idle;
    $self->_dump_fasta;

    #if have duplications, run Ortheus.py with -y option to create a tree 
    if ($self->param('found_a_duplication')) {
	$self->_run_ortheus();
    }  
  } else {
    throw("Cannot start Pecan job because some information is missing");
  }

  return 1;
}

sub run
{
  my $self = shift;

  #Check whether can see exonerate to try to prevent errors in java where the autoloader doesn't seem to always work
  $self->require_executable('exonerate_exe');

  $self->compara_dba->dbc->disconnect_if_idle;

  $self->param('more_heap', 0);
  eval {
      my $pecan_gabs = Bio::EnsEMBL::Compara::Production::Analysis::Pecan::run_pecan($self);
      $self->param('pecan_gabs', $pecan_gabs);
  } or do {
      if ($@ =~ /Java heap space/ || 
	 $@ =~ /GC overhead limit exceeded/ || 
         $@ =~ /Cannot allocate memory/ ||
	 $@ =~ /OutOfMemoryError/ ) {
	  print "Failed due to insufficient heap space or memory\n";
	  $self->param('more_heap', 1);
      } else {
	  throw("Pecan execution failed $@\n");
      }
  };
}

sub write_output {
    my ($self) = @_;

    #If job failed due to insufficient heap space, flow into new analysis
    if ($self->param('more_heap')) {
	#Flow to next memory. 
	my $num_jobs = $self->dataflow_output_id(undef, 2);

	#Check if any jobs created (if none, then know that no flow was defined on this branch ie got to last pecan_mem(
	if (@$num_jobs == 0) {
	    throw("Pecan ". $self->input_job->analysis->logic_name . " still failed due to insufficient heap space");
	}

	#Don't want to flow to gerp jobs here
	$self->input_job->autoflow(0);
    } else {
	#Job succeeded, write output
        $self->call_within_transaction( sub {
            $self->_write_output;
        } );
    }
}

sub _write_output {
  my ($self) = @_;

  if ($self->param('tree_to_save')) {
    my $meta_container = $self->compara_dba->get_MetaContainer;
    $meta_container->store_key_value("synteny_region_tree_".$self->param('synteny_region_id'),
        $self->param('tree_to_save'));
  }

  my $mlssa = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor;
  my $mlss = $mlssa->fetch_by_dbID($self->param('mlss_id'));
  my $gaba = $self->compara_dba->get_GenomicAlignBlockAdaptor;
  my $gaa = $self->compara_dba->get_GenomicAlignAdaptor;

  foreach my $gab (@{$self->param('pecan_gabs')}) {
      foreach my $ga (@{$gab->genomic_align_array}) {
	  $ga->adaptor($gaa);
	  $ga->method_link_species_set($mlss);
	  $ga->visible(1);
	  unless (defined $gab->length) {
	      $gab->length(length($ga->aligned_sequence));
	  }
      }
      $gab->adaptor($gaba);
      $gab->method_link_species_set($mlss);
      my $group;

      ## Hard trim condition (testing, this is intended for one single GAB only)
      if ($self->param('trim')) {
        $gab = $self->_hard_trim_gab($gab);
      }
      
      # Split block if it is too long and store as groups
      # Remove any blocks which contain only 1 genomic align and trim the 2
      # neighbouring blocks 
      if ($self->param('max_block_size') and $gab->length > $self->param('max_block_size')) {
	  my $gab_array = undef;
	  my $find_next = 0;
	  for (my $start = 1; $start <= $gab->length; $start += $self->param('max_block_size')) {
	      my $split_gab = $gab->restrict_between_alignment_positions(
			      $start, $start + $self->param('max_block_size') - 1, 1);
	      
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

  my $trim = $self->param('trim');
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
    
#    my $species_set = "[";
#    my $genome_db_set  = $mlss->species_set->genome_dbs;
    
#    foreach my $genome_db (@$genome_db_set) {
#	$species_set .= $genome_db->dbID . ","; 
#    }
#    $species_set .= "]";
#    my $output_id = "{genomic_align_block_id=>" . $gab->dbID . ",species_set=>" .  $species_set;
    my $output_id = { genomic_align_block_id => $gab->dbID };

    $self->dataflow_output_id($output_id,1);
}

##########################################
#
# getter/setter methods
# 
##########################################


sub add_fasta_files {
    my ($self, $value) = @_;

    my $fasta_files = $self->param('fasta_files');
    push @$fasta_files, $value;

    $self->param('fasta_files', $fasta_files);

}
sub add_species_order {
    my ($self, $value) = @_;

    my $species_order = $self->param('species_order');
    push @$species_order, $value;

    $self->param('species_order', $species_order);

}

sub get_species_tree {
  my $self = shift;

  if (defined($self->param('species_tree'))) {
      return $self->param('species_tree');
  }

  my $species_tree =
      $self->compara_dba->get_SpeciesTreeAdaptor->fetch_by_method_link_species_set_id_label($self->param_required('mlss_id'), 'default')->root;

  #if the tree leaves are species names, need to convert these into genome_db_ids
  my $genome_dbs = $self->compara_dba->get_GenomeDBAdaptor->fetch_all();

  my %leaf_check;
  foreach my $genome_db (@$genome_dbs) {
      if ($genome_db->name ne "ancestral_sequences") {
	  $leaf_check{$genome_db->dbID} = 2;
      }
  }
  foreach my $leaf (@{$species_tree->get_all_leaves}) {
      $leaf_check{$leaf->genome_db_id}++;
  }

  #Check have one instance in the tree of each genome_db in the database
  #Don't worry about having extra elements in the tree that aren't in the
  #genome_db table because these will be removed later
  foreach my $name (keys %leaf_check) {
      if ($leaf_check{$name} == 2) {
	  throw("Unable to find genome_db_id $name in species_tree\n");
      }
  }

  $self->param('species_tree', $species_tree);
  return $self->param('species_tree');
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

  my $sra = $self->compara_dba->get_SyntenyRegionAdaptor;
  my $sr = $sra->fetch_by_dbID($synteny_region_id);

  my $regions = $sr->get_all_DnaFragRegions();

  if (scalar(@$regions) == 1) {
      $self->input_job->autoflow(0);
      $self->complete_early('Cannot work with a single region');
  }

  $self->param('dnafrag_regions', $regions);
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

  my $all_dnafrag_regions = $self->param('dnafrag_regions');

  ## Dump FASTA files in the order given by the tree string (needed by Pecan)
  my @seqs;
  if ($self->param('pecan_tree_string')) {
    @seqs = ($self->param('pecan_tree_string') =~ /seq(\d+)/g);
  } else {
    @seqs = (1..scalar(@$all_dnafrag_regions));
  }

  $self->iterate_by_dbc(\@seqs,
      sub {my $seq_id = shift; return $all_dnafrag_regions->[$seq_id-1]->dnafrag->genome_db->db_adaptor->dbc;},
      sub {my $seq_id = shift;

    my $dfr = $all_dnafrag_regions->[$seq_id-1];
    my $file = $self->worker_temp_directory . "/seq" . $seq_id . ".fa";

    my $slice = $dfr->slice;
    throw("Cannot get slice for DnaFragRegion in DnaFrag #".$dfr->dnafrag_id) if (!$slice);
    my $seq = $slice->get_repeatmasked_seq(undef, 1)->seq;
    if ($seq =~ /[^ACTGactgNnXx]/) {
      print STDERR $slice->name, " contains at least one non-ACTGactgNnXx character. These have been replaced by N's\n";
      $seq =~ s/[^ACTGactgNnXx]/N/g;
    }
    $seq =~ s/(.{80})/$1\n/g;
    chomp $seq;

    $self->_spurt($file, join("\n",
            ">DnaFrag". $dfr->dnafrag_id . "|" . $dfr->dnafrag->name . "." . $dfr->dnafrag_start . "-" . $dfr->dnafrag_end . ":" . $dfr->dnafrag_strand,
            $seq,
        ));

    $self->add_fasta_files($file);
    $self->add_species_order($dfr->dnafrag->genome_db_id);

    #push @{$self->fasta_files}, $file;
    #push @{$self->species_order}, $dfr->dnafrag->genome_db_id;
  } );

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

  my $tree = $self->get_species_tree->copy;
  return if (!$tree);

  $tree = $self->_update_tree($tree);

  #if duplications found, $tree will not be defined
  return if (!$tree);

  my $tree_string = $tree->newick_format('simple');
  # Remove quotes around node labels
  $tree_string =~ s/"(seq\d+)"/$1/g;
  # Remove branch length if 0
  $tree_string =~ s/\:0\.0+(\D)/$1/g;
  $tree_string =~ s/\:0([^\.\d])/$1/g;

  $tree->release_tree;
  $self->param('pecan_tree_string', $tree_string);
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

  my $all_dnafrag_regions = $self->param('dnafrag_regions');
  my $ordered_dnafrag_regions = [];

  my $idx = 1;
  my $all_leaves = $tree->get_all_leaves;
  foreach my $this_leaf (@$all_leaves) {
    my $these_dnafrag_regions = [];
    ## Look for DnaFragRegions belonging to this genome_db_id
    foreach my $this_dnafrag_region (@$all_dnafrag_regions) {
      if ($this_dnafrag_region->dnafrag->genome_db_id == $this_leaf->genome_db_id) {
        push (@$these_dnafrag_regions, $this_dnafrag_region);
      }
    }

    if (@$these_dnafrag_regions == 1) {
      ## If only 1 has been found...
      $this_leaf->name("seq".$idx++); #.".".$these_dnafrag_regions->[0]->dnafrag_id);
      push(@$ordered_dnafrag_regions, $these_dnafrag_regions->[0]);

    } elsif (@$these_dnafrag_regions > 1) {

      ## If more than 1 has been found...
      $self->param('found_a_duplication', 1);
      return;

      #No longer use code below, call Ortheus to find better tree
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

  $self->param('dnafrag_regions', $ordered_dnafrag_regions);

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

sub _run_ortheus {
    my ($self) = @_;

    $self->compara_dba->dbc->disconnect_if_idle;

    #run Ortheus.py without running MAKE_FINAL_ALIGNMENT ie OrtheusC
    $self->param('options', ['-y']);
    Bio::EnsEMBL::Compara::Production::Analysis::Ortheus::run_ortheus($self);

    my $tree_file = $self->worker_temp_directory . "/output.$$.tree";
    if (-e $tree_file) {
	## Ortheus estimated the tree. Overwrite the order of the fasta files and get the tree
	open(F, $tree_file) || throw("Could not open tree file <$tree_file>");
	my ($newick, $files) = <F>;
	close(F);
	$newick =~ s/[\r\n]+$//;
	$self->param('pecan_tree_string', $newick);
	$files =~ s/[\r\n]+$//;

	my $all_files = [split(" ", $files)];
	
	#store ordered fasta_files
	#$self->{'_fasta_files'} = $all_files;
	$self->param('fasta_files', $all_files);

	print STDOUT "**NEWICK: $newick\nFILES: ", join(" -- ", @$all_files), "\n";
    } else {
	throw("Ortheus was unable to create a tree");
    }
}


1;
