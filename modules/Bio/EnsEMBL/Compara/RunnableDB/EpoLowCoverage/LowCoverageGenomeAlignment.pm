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

Bio::EnsEMBL::Compara::Runnable::EpoLowCoverage::LowCoverageGenomeAlignment

=head1 DESCRIPTION

This module acts as a layer between the Hive system and the Bio::EnsEMBL::Analysis::Runnable::LowCoverageGenomeAlignment module since the ensembl-analysis API does not know about ensembl-compara

This module is the alternative module to Ortheus.pm for aligning low coverage (2X) genomes. This takes an existing high coverage alignment and maps the pairwise BlastZ-Net alignments of the low coverage genomes to the human sequence in the high coverage alignment. Any insertions in the low coverage alignments are removed, that is, no gaps are added to the human sequence. In regions where there are duplications, a phylogenetic tree is generated using either treeBest where there are more than 3 sequences in the alignment or semphy where there are 3 or less sequences. This module is still under development.

=head1 APPENDIX

The rest of the documentation details each of the object methods. 
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::RunnableDB::EpoLowCoverage::LowCoverageGenomeAlignment;

use strict;
use warnings;
use Bio::EnsEMBL::Analysis::Runnable::LowCoverageGenomeAlignment;
use Bio::EnsEMBL::Utils::Exception qw(throw);
use Bio::EnsEMBL::Compara::DnaFragRegion;
use Bio::EnsEMBL::Compara::Graph::NewickParser;
use Bio::EnsEMBL::Compara::NestedSet;
use Bio::EnsEMBL::Compara::GenomicAlignGroup;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


=head2 fetch_input

    Arg        :   -none-
    Example    :   $self->fetch_input
    Description:   Fetches input data for the module from the database
    Returntype :   none
    Excptions  :
    Caller     :
    Status     :   At risk

=cut

sub fetch_input {
  my( $self) = @_;

  if (!$self->param('mlss_id')) {
    throw("MethodLinkSpeciesSet->dbID is not defined for this LowCoverageAlignment job");
  }

  #load from genomic_align_block ie using in 2X mode
  $self->_load_GenomicAligns($self->param('genomic_align_block_id'));

  if ($self->param('genomic_aligns')) {
      #load 2X genomes
      $self->_load_2XGenomes($self->param('genomic_align_block_id'));

      ## Get the tree string by taking into account duplications and deletions. Resort dnafrag_regions
      ## in order to match the name of the sequences in the tree string (seq1, seq2...)
      if ($self->get_species_tree) {
	  $self->_build_tree_string;
      }
      ## Dumps fasta files for the DnaFragRegions. Fasta files order must match the entries in the
      ## newick tree. The order of the files will match the order of sequences in the tree_string.
      
      #create multi-fasta file with 2X genomes 
      $self->_create_mfa;
      
      $self->_dump_fasta_and_mfa;

  } else {
    #throw("Cannot start alignment because some information is missing");
    print("No valid genomic_aligns left in genomic_align_block. Unable to start alignment\n") if ($self->debug);
  }
  return 1;
}

=head2 run

    Arg        : -none-
    Example    : $self->run
    Description: runs the  LowCoverageGenomeAlignment analysis module and 
                  parses the results
    Returntype : none
    Exceptions : none
    Caller     :
    Status     :   At risk

=cut

sub run
{
  my $self = shift;
  my $fake_analysis     = Bio::EnsEMBL::Analysis->new;

  #check that have genomic_aligns (may not have if removed some because they
  #consist entirely of Ns)
  return if (!$self->param('genomic_aligns'));

  print "tmp " . $self->worker_temp_directory . " mfa=" . $self->param('multi_fasta_file') . " tree=" . $self->tree_string . " taxon=" . $self->get_taxon_tree . "\n" if $self->debug;

  my $runnable = new Bio::EnsEMBL::Analysis::Runnable::LowCoverageGenomeAlignment(
      -analysis => $fake_analysis,
      -workdir => $self->worker_temp_directory,
      -multi_fasta_file => $self->param('multi_fasta_file'),
      -tree_string => $self->tree_string,
      -taxon_species_tree => $self->get_taxon_tree,
      -semphy_exe => $self->param('semphy_exe'),
      -treebest_exe => $self->param('treebest_exe'),
      );
  $self->param('runnable', $runnable);

  #disconnect pairwise compara database
  if (defined $self->param('pairwise_compara_dba')) {
      foreach my $dba (values %{$self->param('pairwise_compara_dba')}) {
	  $dba->dbc->disconnect_if_idle;
      }
  }

  #disconnect compara database
  $self->compara_dba->dbc->disconnect_if_idle;

  $runnable->run_analysis;
  $self->_parse_results();
}

=head2 write_output

    Arg        : -none
    Example    : $self->write_output
    Description: stores results in a database
    Returntype : none
    Exceptions : none
    Caller     :
    Status     : At risk

=cut

sub write_output {
    my ($self) = @_;

    print "WRITE OUTPUT\n" if $self->debug;

    $self->call_within_transaction( sub {
        $self->_write_output;
    } );

  return 1;

}

sub _write_output {
  my ($self) = @_;

  #check that have genomic_aligns (may not have if removed some because they
  #consist entirely of Ns)
  if (!$self->param('genomic_aligns')) {
      #do not produce gerp jobs
      $self->input_job->autoflow(0);
      return 1;
  }

  my $use_fresh_connection = 1;
  my $skip_left_right_index = 0;

  my $mlssa = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor;
  my $mlss = $mlssa->fetch_by_dbID($self->param('mlss_id'));
  my $mlss_id = $mlss->dbID;
  my $dnafrag_adaptor = $self->compara_dba->get_DnaFragAdaptor;
  my $gaba = $self->compara_dba->get_GenomicAlignBlockAdaptor;
  my $gaa = $self->compara_dba->get_GenomicAlignAdaptor;
  
  my $gata = $self->compara_dba->get_GenomicAlignTreeAdaptor;

  foreach my $genomic_align_tree (@{$self->param('runnable')->output}) {
      my $all_nodes;

      foreach my $genomic_align_node (@{$genomic_align_tree->get_all_nodes}) {
	  next if (!defined $genomic_align_node->genomic_align_group);
	  foreach my $genomic_align (@{$genomic_align_node->genomic_align_group->get_all_GenomicAligns}) {
	      $genomic_align->adaptor($gaa);
	      
	      $genomic_align->method_link_species_set($mlss);
	      $genomic_align->visible(1);
	  }
      }
      my $split_trees;
      #restrict genomic_align_tree if it is too long and store as groups
      
      #need to do it this way in case have no ancestral nodes
      my $gat_length;
      $all_nodes = $genomic_align_tree->get_all_leaves;
      $gat_length = $all_nodes->[0]->length;
      
      if ($self->param('max_block_size') && $gat_length >  $self->param('max_block_size')) {
	  for (my $start = 1; $start <= $gat_length; $start += $self->param('max_block_size')) {
	      my $end = $start+$self->param('max_block_size')-1;
	      if ($end > $gat_length) {
		  $end = $gat_length;
	      }
	      my $new_gat = $genomic_align_tree->restrict_between_alignment_positions($start, $end, "skip_empty_GenomicAligns");
	      push @$split_trees, $new_gat;
	  }
	  $gata->store_group($split_trees);
	  foreach my $tree (@$split_trees) {
	      $self->_write_gerp_dataflow($tree->modern_genomic_align_block_id, $mlss);
	  }
      } else {
	  #If commit is causing a problem again, could theoretically not store the left and right indexes at all and hence
	  #remove the need to call NestedSetAdaptor.pm. However, this would mean making other alterations to the API which use
	  #the left and right indexes.
	  #	      $gata->store($genomic_align_tree, "skip_left_right_indexes");
	  $gata->store($genomic_align_tree, $skip_left_right_index);
	  $self->_write_gerp_dataflow($genomic_align_tree->modern_genomic_align_block_id,
					  $mlss);
      }
  }

  chdir("$self->worker_temp_directory");
  foreach(glob("*")){
      #DO NOT COMMENT THIS OUT!!! (at least not permenantly). Needed
      #to clean up after each job otherwise you get files left over from
      #the previous job.
      unlink($_);
  }
  
  return 1;
}

sub _write_gerp_dataflow {
    my ($self, $gab_id, $mlss) = @_;
    
    my @species_set = map {$_->dbID} @{$mlss->species_set->genome_dbs()};
    
    my $output_id = { genomic_align_block_id => $gab_id, species_set => \@species_set };
    $self->dataflow_output_id($output_id, 2);
}

=head2 _parse_results

    Arg        : none
    Example    : $self->_parse_results
    Description: parse the alignment and tree files
    Returntype : none
    Exceptions : 
    Caller     : run
    Status     : At risk

=cut

sub _parse_results {
    my ($self) = @_;

    #Taken from Analysis/Runnable/LowCoverageGenomeAlignment.pm module
    print "PARSE RESULTS\n" if $self->debug;

    ## The output file contains one fasta aligned sequence per original sequence + ancestral sequences.
    ## The first seq. corresponds to the fist leaf of the tree, the second one will be an internal
    ## node, the third is the second leaf and so on. The fasta header in the result file correspond
    ## to the names of the leaves for the leaf nodes and to the concatenation of the names of all the
    ## underlying leaves for internal nodes. For instance:
    ## ----------------------------------
    ## >0
    ## ACTTGG--CCGT
    ## >0_1
    ## ACTTGGTTCCGT
    ## >1
    ## ACTTGGTTCCGT
    ## >1_2_3
    ## ACTTGCTTCCGT
    ## >2
    ## CCTTCCTTCCGT
    ## ----------------------------------
    ## The sequence of fasta files and leaves in the tree have the same order. If Ortheus is run
    ## with a given tree, the sequences in the file follow the tree. If Ortheus estimate the tree,
    ## the tree output file contains also the right order of files:
    ## ----------------------------------
    ## ((1:0.0157,0:0.0697):0.0000,2:0.0081);
    ## /tmp/file3.fa /tmp/file1.fa /tmp/file2.fa
    ## ----------------------------------

    my $workdir;
    my $tree_file = $self->worker_temp_directory . "/output.$$.tree";

    #print "tree_file $tree_file\n";

    my $ordered_fasta_files = $self->fasta_files;

    #Check for existance of self->tree_string. It will only exist if there are no duplications
    #in the high coverage alignment. If there are duplications, self->tree_string will not 
    #exist and treebest will have been run to generate a tree.
    unless ($self->tree_string) {
	if (-e $tree_file) {
	    ## Estimated tree. Overwrite the order of the fasta files and get the tree
	    my $newick = $self->_slurp($tree_file);
	    $newick =~ s/[\r\n]+$//;
	    $self->tree_string($newick);
	    
	    #print "newick $newick\n";
	
	    my $this_tree =
	      Bio::EnsEMBL::Compara::Graph::NewickParser::parse_newick_into_tree($newick);
	    
	    #created tree via semphy or treebest
	    $ordered_fasta_files = undef;
	    my $all_leaves = $this_tree->get_all_leaves;
	    foreach my $this_leaf (@$all_leaves) {
		push @$ordered_fasta_files, $this_leaf->name . ".fa";
	    }
	    
	    $self->fasta_files(@$ordered_fasta_files);
	    #print STDOUT "**NEWICK: $newick\nFILES: ", join(" -- ", @$ordered_fasta_files), "\n";
	} else {
	    throw "Expected to find $tree_file created by treebest, but did not\n";
	}
    }

    my (@ordered_leaves) = $self->tree_string =~ /[(,]([^(:)]+)/g;
    #print "++NEWICK: ", $self->tree_string, "\nLEAVES: ", join(" -- ", @ordered_leaves), "\nFILES: ", join(" -- ", @{$self->fasta_files}), "\n";

    my $alignment_file;
    #read in mfa file created for input into treebest
    $alignment_file = $self->param('multi_fasta_file');

    my $this_genomic_align_block = new Bio::EnsEMBL::Compara::GenomicAlignBlock;
    open(F, $alignment_file) || throw("Could not open $alignment_file");
    my $seq = "";
    my $this_genomic_align;

    #Create genomic_align_group object to store genomic_aligns for
    #each node. For 2x genomes, there may be several genomic_aligns
    #for a node but for other genomes there will only be one
    #genomic_align in the genomic_align_group
    my $genomic_align_group;

    my $tree = Bio::EnsEMBL::Compara::Graph::NewickParser::parse_newick_into_tree($self->tree_string);
    $tree->print_tree(100) if ($self->debug);
    
    print $tree->newick_format("simple"), "\n";
    print join(" -- ", map {$_->name} @{$tree->get_all_leaves}), "\n";
    print "Reading $alignment_file...\n";
    my $ids;

    foreach my $this_file (@$ordered_fasta_files) {
	push(@$ids, qx"head -1 $this_file");
	#print "add ids $this_file " . $ids->[-1] . "\n";
    }
    #print join(" :: ", @$ids), "\n\n";

    my $genomic_aligns_2x_array = [];
    my @num_frag_pads;
    my $frag_limits;
    my @ga_lengths;
    my $ga_deletions;

    while (<F>) {
	next if (/^\s*$/);
	chomp;
	## FASTA headers correspond to the tree and the order of the leaves in the tree corresponds
	## to the order of the files

	if (/^>/) {
	    print "PARSING $_\n" if ($self->debug);
	    #print $tree->newick_format(), "\n" if ($self->debug);
	    my ($name) = $_ =~ /^>(.+)/;
	    if (defined($this_genomic_align) and  $seq) {
		if (@$genomic_aligns_2x_array) {
		    print "*****FOUND 2x seq " . length($seq) . "\n" if ($self->debug);
		    #starting offset
		    my $offset = $num_frag_pads[0];
		    #how many X's to add at the start of the cigar_line
		    my $start_X;

		    #how many X's to add to the end of the cigar_line
		    my $end_X;

		    my $align_offset = 0;
		    for (my $i = 0; $i < @$genomic_aligns_2x_array; $i++) {
			my $genomic_align = $genomic_aligns_2x_array->[$i];
			my $num_pads = $num_frag_pads[$i+1];
			my $ga_length = $genomic_align->dnafrag_end-$genomic_align->dnafrag_start+1;

			#print "ga-length $ga_length dnafrag_id=" . $genomic_align->dnafrag_id. " start=" . $genomic_align->dnafrag_start . " end=" . $genomic_align->dnafrag_end . " " , $ga_lengths[$i] . " align_offset=$align_offset " . "seq length= " . length($seq) . "\n";

			my ($subseq, $aligned_start, $aligned_end) = _extract_sequence($seq, $align_offset, $ga_lengths[$i]);

			$align_offset = $aligned_end;
			#print "final subseq $aligned_start $aligned_end $subseq\n";
			#Add aligned sequence
			$genomic_align->aligned_sequence($subseq);

			my $cigar_line = create_2x_cigar_line($subseq, $ga_deletions->[$i]);
			$genomic_align->cigar_line($cigar_line);


			#Add X padding characters to ends of seq
			$start_X = $aligned_start;
			$end_X = length($seq) - ($start_X+length($subseq));

			print "start_X $start_X end_X $end_X subseq_length " . length($subseq) . "\n" if ($self->debug);
			#print "before cigar_line " . $genomic_align->cigar_line . "\n";

			
			$genomic_align->cigar_line($start_X . "X" .$genomic_align->cigar_line . $end_X . "X");

			#print "after cigar_line " . $genomic_align->cigar_line . "\n";

			#free aligned_sequence now that I've used it to 
			#create the cigar_line
			undef($genomic_align->{'aligned_sequence'});

			#Add genomic align to genomic align block
			$this_genomic_align_block->add_GenomicAlign($genomic_align);
			#$offset += $num_pads + $ga_length;
			$offset += $ga_length;
		    }
		    $genomic_aligns_2x_array = [];
		    undef @num_frag_pads;
		    undef @ga_lengths;
		    undef $ga_deletions;
		    undef $frag_limits;
		} else {

		    print "add aligned_sequence " . $this_genomic_align->dnafrag_id . " " . $this_genomic_align->dnafrag_start . " " . $this_genomic_align->dnafrag_end . "\n" if $self->debug;

		    $this_genomic_align->aligned_sequence($seq);

		    #need to add original sequence here because the routine
		    #remove_empty_columns can delete parts of the alignment and
		    #so the original_sequence cannot be reconstructed from the
		    #aligned_sequence
		    if ($this_genomic_align->dnafrag_id == -1) {
			$this_genomic_align->original_sequence;
		    }
		    #undef aligned_sequence now. Necessary because otherwise 
		    #when I remove_empty_columns, this
		    #modifies the cigar_line only and not the aligned_sequence
		    #so not removing it here causes the genomic_align_block
		    #length to be wrong since it finds the length of the
		    #aligned_sequence
		    $this_genomic_align->cigar_line;
		    undef($this_genomic_align->{'aligned_sequence'});

		    $this_genomic_align_block->add_GenomicAlign($this_genomic_align);

		}
	    }
	    my $header = shift(@$ids);
	    $this_genomic_align = new Bio::EnsEMBL::Compara::GenomicAlign;

	    if (!defined($header)) {
		print "INTERNAL NODE $name\n" if ($self->debug);
		my $this_node;
		foreach my $this_leaf_name (split("_", $name)) {
		    if ($this_node) {
			my $other_node = $tree->find_node_by_name($this_leaf_name);
			if (!$other_node) {
			    throw("Cannot find node <$this_leaf_name>\n");
			}
			$this_node = $this_node->find_first_shared_ancestor($other_node);
		    } else {
			print $tree->newick_format() if ($self->debug);
			print " LEAF: $this_leaf_name\n" if ($self->debug);
			$this_node = $tree->find_node_by_name($this_leaf_name);
		    }
		}
		print join("_", map {$_->name} @{$this_node->get_all_leaves}), "\n" if ($self->debug);
		## INTERNAL NODE: dnafrag_id and dnafrag_end must be edited somewhere else

		$this_genomic_align->dnafrag_id(-1);
		$this_genomic_align->dnafrag_start(1);
		$this_genomic_align->dnafrag_end(0);
		$this_genomic_align->dnafrag_strand(1);

		bless($this_node, "Bio::EnsEMBL::Compara::GenomicAlignTree");
		$genomic_align_group = new Bio::EnsEMBL::Compara::GenomicAlignGroup(
				-type => "epo");
		$genomic_align_group->add_GenomicAlign($this_genomic_align);

		$this_node->genomic_align_group($genomic_align_group);
		$this_node->name($name);
	    } elsif ($header =~ /^>SeqID(\d+)/) {
		#print "old $name\n";
		print "leaf_name?? $name\n" if ($self->debug);

		my $this_leaf = $tree->find_node_by_name($name);
		if (!$this_leaf) {
		    #print $tree->newick_format(), " ****\n" if ($self->debug);
		    print $tree->newick_format(), " ****\n";
		    die "Unable to find leaf with name $name";
		}
		#print "$this_leaf\n";
		#         print "****** $name -- $header -- ";
		#         if ($this_leaf) {
		#           $this_leaf->print_node();
		#         } else {
		#           print "[none]\n";
		#         }

		#information extracted from fasta header
		my $seq_id = ($1);

		my $all_genomic_aligns = $self->param('genomic_aligns');

		my $ga = $all_genomic_aligns->[$seq_id-1];

		if (!UNIVERSAL::isa($ga, 'Bio::EnsEMBL::Compara::GenomicAlign')) {
		    print "FOUND 2X GENOME\n" if $self->debug;
		    print "num of frags " . @$ga . "\n" if $self->debug;
		    print "*** NAME  " . $ga->[0]->{genomic_align}->genome_db->name . " start " . $ga->[0]->{genomic_align}->dnafrag_start . " end " . $ga->[0]->{genomic_align}->dnafrag_end . " name " . $ga->[0]->{genomic_align}->dnafrag->name . "\n" if $self->debug;
		    #reorder fragments if reference slice is on the reverse
		    #strand
		    my $first_ref_ga = $ga->[0]->{ref_ga};

		    if ($first_ref_ga->dnafrag_strand == -1) { 
		      @{$ga} = sort {$b->{genomic_align_block}->reference_genomic_align->dnafrag_start <=> $a->{genomic_align_block}->reference_genomic_align->dnafrag_start} @{$ga};
		  }

		    #first pads
		    push @num_frag_pads, $ga->[0]->{first_pads};
		    #create new genomic_align for each pairwise fragment
		    foreach my $ga_frag (@$ga) {
			my $genomic_align = new Bio::EnsEMBL::Compara::GenomicAlign;
			my $genomic_align_block = $ga_frag->{genomic_align_block};
			my $non_ref_genomic_align = $genomic_align_block->get_all_non_reference_genomic_aligns->[0];

			$genomic_align->dnafrag_id($non_ref_genomic_align->dnafrag_id);
			$genomic_align->dnafrag_start($non_ref_genomic_align->dnafrag_start);
			$genomic_align->dnafrag_end($non_ref_genomic_align->dnafrag_end);
			$genomic_align->dnafrag_strand($non_ref_genomic_align->dnafrag_strand);

			print "store start " . $genomic_align->dnafrag_start . " end " . $genomic_align->dnafrag_end . " strand " . $genomic_align->dnafrag_strand . "\n" if $self->debug;

			#print "LENGTHS " . $ga_frag->{length} . "\n";
			push @$ga_deletions, $ga_frag->{deletions};
			push @ga_lengths, $ga_frag->{length};
			push @num_frag_pads, $ga_frag->{num_pads};
			push @$genomic_aligns_2x_array, $genomic_align;
		    }
		    #Add genomic align to genomic align group 
		    $genomic_align_group = new Bio::EnsEMBL::Compara::GenomicAlignGroup(
											#-genomic_align_array => $genomic_aligns_2x_array,
										        -type => "epo");
		    foreach my $this_genomic_align (@$genomic_aligns_2x_array) {
			$genomic_align_group->add_GenomicAlign($this_genomic_align);
		    }

		    bless($this_leaf, "Bio::EnsEMBL::Compara::GenomicAlignTree");
		    $this_leaf->genomic_align_group($genomic_align_group);
		    print "size of array " . @$genomic_aligns_2x_array . "\n" if $self->debug;
		    print "store gag1 $this_leaf\n" if $self->debug;

		    #$self->{$this_leaf} = $genomic_align_group;
		} else  {
		    print "normal name " . $ga->genome_db->name . "\n" if $self->debug;


		    $this_genomic_align->dnafrag_id($ga->dnafrag_id);
		    $this_genomic_align->dnafrag_start($ga->dnafrag_start);
		    $this_genomic_align->dnafrag_end($ga->dnafrag_end);
		    $this_genomic_align->dnafrag_strand($ga->dnafrag_strand);

		    $genomic_align_group = new Bio::EnsEMBL::Compara::GenomicAlignGroup(
											#-genomic_align_array => [$this_genomic_align],
										        -type => "epo");
		    $genomic_align_group->add_GenomicAlign($this_genomic_align);

		    bless($this_leaf, "Bio::EnsEMBL::Compara::GenomicAlignTree");
		    $this_leaf->genomic_align_group($genomic_align_group);
		    print "store gag2 $this_leaf\n" if $self->debug;
		}
	    } else {
		throw("Error while parsing the FASTA header. It must start by \">DnaFrag#####\" where ##### is the dnafrag_id\n$_");
	    }
	    $seq = "";
	} else {
	    $seq .= $_;
	}
    }
    close F;

    #last genomic_align
    print "Last genomic align\n" if ($self->debug);
    if (@$genomic_aligns_2x_array) {
	print "*****FOUND 2x seq " . length($seq) . "\n" if ($self->debug);

	#starting offset
	my $offset = $num_frag_pads[0];

	#how many X's to add at the start and end of the cigar_line
	my ($start_X , $end_X);
	
	my $align_offset = 0;
	for (my $i = 0; $i < @$genomic_aligns_2x_array; $i++) {
	    my $genomic_align = $genomic_aligns_2x_array->[$i];

 	    my $num_pads = $num_frag_pads[$i+1];
 	    my $ga_length = $genomic_align->dnafrag_end-$genomic_align->dnafrag_start+1;

 	    print "extract_sequence $offset " .($offset+$ga_length) . " num pads $num_pads\n" if ($self->debug); 
 	    my ($subseq, $aligned_start, $aligned_end) = _extract_sequence($seq, $align_offset, $ga_lengths[$i]);

	    $align_offset = $aligned_end;

# 	    #Add aligned sequence
 	    $genomic_align->aligned_sequence($subseq);

	    my $cigar_line = create_2x_cigar_line($subseq, $ga_deletions->[$i]);
	    $genomic_align->cigar_line($cigar_line);

# 	    #Add X padding characters to ends of seq
 	    $start_X = $aligned_start;
 	    $end_X = length($seq) - ($start_X+length($subseq));
 	    print "start_X $start_X end_X $end_X subseq_length " . length($subseq) . "\n" if ($self->debug);
	    
 	    $genomic_align->cigar_line($start_X . "X" .$genomic_align->cigar_line . $end_X . "X");
	    
	    #free aligned_sequence now that I've used it to 
	    #create the cigar_line
	    undef($genomic_align->{'aligned_sequence'});

	    #Add genomic align to genomic align block
	    $this_genomic_align_block->add_GenomicAlign($genomic_align);
	    $offset += $num_pads + $ga_length;
	}
    } else {
	if (defined $this_genomic_align && 
	    $this_genomic_align->dnafrag_id != -1) {
	    $this_genomic_align->aligned_sequence($seq);
	    $this_genomic_align_block->add_GenomicAlign($this_genomic_align);
	}
    }

    #Where there is no ancestral sequences ie 2X genomes
    #convert all the nodes of the tree to Bio::EnsEMBL::GenomicAlignTree objects
    foreach my $this_node (@{$tree->get_all_nodes}) {
	if (!UNIVERSAL::isa($this_node, 'Bio::EnsEMBL::Compara::GenomicAlignTree')) {
	    bless($this_node, "Bio::EnsEMBL::Compara::GenomicAlignTree");
	}
    }

    #fetch group_id from base alignment block if there is one
    my $multi_gab_id = $self->param('genomic_align_block_id');
    my $multi_gaba = $self->compara_dba->get_GenomicAlignBlockAdaptor;
    my $multi_gab = $multi_gaba->fetch_by_dbID($multi_gab_id);
    my $group_id = $multi_gab->group_id;

    #fix the group_id so that it starts with the current mlss_id not that of
    #the base alignment. Will always do this.
    if ($group_id) {
	$group_id = _fix_internal_ids($multi_gab->group_id, $multi_gab->method_link_species_set_id, $self->param('mlss_id'));
    } 
    $tree->group_id($group_id);

    #print $tree->newick_format("simple"), "\n";
    #print join(" -- ", map {$_."+".$_->node_id."+".$_->name} (@{$tree->get_all_nodes()})), "\n";
    #$self->output([$tree]);
    $self->param('runnable')->output([$tree]);
}

#Fix the group_id so that it starts with the current mlss_id not that of
#the base alignment. 
sub _fix_internal_ids {
    my ($group_id, $multi_mlss_id, $new_mlss_id) = @_;
    my $multiplier = 10**10;
    my $lower_limit = $multi_mlss_id * $multiplier;
    my $upper_limit = ($multi_mlss_id+1) * $multiplier;
    my $new_group_id;
    my $new_lower_limit = $new_mlss_id * $multiplier;


    #group_id has previous fix applied
    if ($group_id > $lower_limit && $group_id < $upper_limit) {
	$new_group_id = $group_id - $lower_limit + $new_lower_limit;
    } elsif ($group_id < $multiplier) {
	#group_id has had no fix applied
	$new_group_id = $group_id + $new_lower_limit;
    } else {
	#fix has already been applied!
	$new_group_id = $group_id;
    }
    return $new_group_id;
}

#create cigar line for 2x genomes manually because I need to add in the
#insertions, that is "I" in the cigar_line to represent the 2x-only sequences
#that are not found in the reference species which I removed during the
#creation of the _create_mfa routine.
sub create_2x_cigar_line {
    my ($aligned_sequence, $ga_deletions) = @_;

    my $cigar_line = "";
    my $base_pos = 0;
    my $current_deletion;
    if (defined $ga_deletions && @$ga_deletions > 0) {
	$current_deletion = shift @$ga_deletions;
    }
    
    my @pieces = grep {$_} split(/(\-+)|(\.+)/, $aligned_sequence);
    foreach my $piece (@pieces) {
	my $elem = '';

	#length of current piece
	my $this_len = length($piece);
	
	my $mode;
	if ($piece =~ /\-/) {
	    $mode = "D"; # D for gaps (deletions)
	    $elem = cigar_element($mode, $this_len);
	} elsif ($piece =~ /\./) {
	    $mode = "X"; # X for pads (in 2X genomes)
	    $elem = cigar_element($mode, $this_len);
	} else {
	    $mode = "M"; # M for matches/mismatches
	    my $next_pos = $base_pos + $this_len;

	    #TODO need special case if have insertion as the last base.
	    #need to have >= and < (not <=) otherwise if an insertion occurs
	    #in the same position as a - then I is added twice.

	    #check to see if next deletion occurs in this cigar element
	    if (defined $current_deletion && 
		$current_deletion->{pos} >= $base_pos && 
		$current_deletion->{pos} < $next_pos) {
		
		#find all deletions that occur in this cigar element
		my $this_del_array;
		while ($current_deletion->{pos} >= $base_pos && 
		       $current_deletion->{pos} < $next_pos) {
		    push @$this_del_array, $current_deletion;

		    last if (@$ga_deletions == 0);
		    $current_deletion = shift @$ga_deletions;
		} 
		
		#loop through all deletions, adding them instead of this cigar element
		my $prev_pos = $base_pos;
		foreach my $this_del (@$this_del_array) {
		    my $piece_len = ($this_del->{pos} - $prev_pos);
		    $elem .= cigar_element($mode, $piece_len);
		    $elem .= cigar_element("I", $this_del->{len});
		    $prev_pos = $this_del->{pos};
		    
		}
		#add final bit
		$elem .= cigar_element($mode, ($base_pos+$this_len) - $this_del_array->[-1]->{pos});
	    } else {
		$elem = cigar_element($mode, $this_len);
	    }
	    
	    $base_pos += $this_len;
	    #print "LENGTH $this_len BASE POS $base_pos\n";
	}
	$cigar_line .= $elem;
    }	
    #print "cigar $cigar_line\n";
    return $cigar_line;
}

#create cigar element from mode and length
sub cigar_element {
    my ($mode, $len) = @_;
    my $elem = '';
    if ($len == 1) {
	$elem = $mode;
    } elsif ($len > 1) { #length can be 0 if the sequence starts with a gap
	$elem = $len.$mode;
    }
    return $elem;
}

#check the new cigar_line is consistent ie the seq_length and number of (M+I) 
#agree and the alignment length and total of cig_elems agree.
sub check_cigar_line {
    my ($genomic_align, $total_gap) = @_;

    #can't check ancestral nodes because these don't have a dnafarg_start
    #or dnafrag_end.
    return if ($genomic_align->dnafrag_id == -1);

    my $seq_pos = 0;
    my $align_len = 0;
    my $cigar_line = $genomic_align->cigar_line;
    my $length = $genomic_align->dnafrag_end-$genomic_align->dnafrag_start+1;
    my $gab = $genomic_align->genomic_align_block;

    my @cig = ( $cigar_line =~ /(\d*[GMDXI])/g );
    for my $cigElem ( @cig ) {
	my $cigType = substr( $cigElem, -1, 1 );
	my $cigCount = substr( $cigElem, 0 ,-1 );
	$cigCount = 1 unless ($cigCount =~ /^\d+$/);

	if( $cigType eq "M" ) {
	    $seq_pos += $cigCount;
	} elsif( $cigType eq "I") {
	    $seq_pos += $cigCount;
	} elsif( $cigType eq "X") {
	} elsif( $cigType eq "G" || $cigType eq "D") {	
	}
	if ($cigType ne "I") {
	    $align_len += $cigCount;
	}
    }

    throw ("Cigar line aligned length $align_len does not match (genomic_align_block_length (" . $gab->length . ") - num of gaps ($total_gap)) " . ($gab->length - $total_gap) . " for gab_id " . $gab->dbID . "\n")
      if ($align_len != ($gab->length - $total_gap));

    throw("Cigar line ($seq_pos) does not match sequence length $length\n") 
      if ($seq_pos != $length);
}



#If a gap has been found in a cig_elem of type M, need to split it into
#firstM - I - lastM. This function adds firstM and I to new_cigar_line
sub add_match_elem {
    my ($firstM, $gap_len, $new_cigar_line) = @_;

    #add firstM
    if ($firstM == 1) {
	$new_cigar_line .= "M";
    } elsif($firstM > 1) {
	$new_cigar_line .= $firstM . "M";
    } 
    
    if ($gap_len == 1) {
	$new_cigar_line .= "I";
    } elsif ($gap_len > 1) {
	$new_cigar_line .= $gap_len . "I";
    } 
    return ($new_cigar_line);
}

#
# Extract the sequence corresponding to the 2X genome fragment
# extracts subsequence from seq starting from aligned_start (alignment coords)
# for $seq_length bases (not counting pads)
sub _extract_sequence {
    my ($seq, $aligned_start, $seq_length) = @_;
    my $curr_length = 0;
    my $aligned_length = 0;
    #my $aligned_start;
    my $aligned_end;

    #print "original_start $aligned_start length $seq_length\n";

    #create new seq starting from aligned_start to the end
    my $new_seq = substr($seq, $aligned_start);

    #find the end in alignment coords counting seq_length bases.
    foreach my $subseq (grep {$_} split /(\-+)/, $new_seq) {
	#print "subseq $subseq\n";
	my $length = length($subseq);
	if ($subseq !~ /\-/) {
	    if (!defined($aligned_end) && ($curr_length + $length >= $seq_length)) {
		$aligned_end = $aligned_length + ($seq_length - $curr_length) + $aligned_start;
		#print "aligned_end $aligned_end\n";
		last;
	    }
	    #length in bases
	    $curr_length += $length;
	}
	#length in alignment coords
	$aligned_length += $length;
    }
    
    my $subseq = substr($seq, $aligned_start, ($aligned_end-$aligned_start));
    return ($subseq, $aligned_start, $aligned_end);
}

##########################################
#
# getter/setter methods
# 
##########################################

sub fasta_files {
  my $self = shift;

  $self->param('_fasta_files', []) unless (defined $self->param('_fasta_files'));
  my $fasta_files = $self->param('_fasta_files');

  if (@_) {
    my $value = shift;
    push @$fasta_files, $value;
  }
  $self->param('_fasta_files', $fasta_files);

  return $self->param('_fasta_files');
}

sub species_order {
  my $self = shift;

  $self->param('_species_order', []) unless (defined $self->param('_species_order'));
  my $species_order = $self->param('_species_order');

  if (@_) {
    my $value = shift;
    push @$species_order, $value;
  }
  $self->param('_species_order', $species_order);

  return $self->param('_species_order');
}

sub get_species_tree {
  my $self = shift;

  if (defined($self->param('_species_tree'))) {
    return $self->param('_species_tree');
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
  

  $self->param('_species_tree', $species_tree);
  return $self->param('_species_tree');
}

sub get_taxon_tree {
  my $self = shift;

  my $newick_taxon_tree;
  if (defined($self->param('_taxon_tree'))) {
      #already read in taxon_tree, simply return
    return $self->param('_taxon_tree');
  } elsif ($self->param('taxon_tree_file')) {
      print "Taking taxon tree from file\n";
      #read from file
      $newick_taxon_tree = $self->_slurp($self->param('taxon_tree_file'));
  } else {
      #read from mlss_tag table
      my $mlss = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor->fetch_by_dbID($self->param('mlss_id'));
      die "Could not fetch MethodLinkSpeciesSet with the dbID '" . $self->param('mlss_id') . "'" unless defined $mlss;
      $newick_taxon_tree = $mlss->species_tree->root->newick_format("ncbi_taxon");
  }

  if (!defined($newick_taxon_tree)) {
    return undef;
  }

  $self->param('_taxon_tree', $newick_taxon_tree);

  return $self->param('_taxon_tree');
  
}

sub tree_string {
  my ($self, $tree_string) = @_;
  $self->param('_tree_string', $tree_string) if(defined $tree_string);
  return $self->param('_tree_string');
}

sub _load_GenomicAligns {
  my ($self, $genomic_align_block_id) = @_;
  my $genomic_aligns = [];

  # Fail if dbID has not been provided
  return $genomic_aligns if (!$genomic_align_block_id);

  my $gaba = $self->compara_dba->get_GenomicAlignBlockAdaptor;
  my $gab = $gaba->fetch_by_dbID($genomic_align_block_id);
  foreach my $ga (@{$gab->get_all_GenomicAligns}) {  
    $ga->dnafrag->genome_db->db_adaptor->dbc->prevent_disconnect( sub {
      #check that the genomic_align sequence is not just N's. This causes 
      #complications with treeBest and we end up with very long branch lengths

      my $slice = $ga->get_Slice();
      my $seqlevel = $slice->coord_system->adaptor->fetch_sequence_level();
      my @projection = @{$slice->project($seqlevel->name(), $seqlevel->version())};
      if (@projection > 0) {
	  push(@{$genomic_aligns}, $ga);
      }
    });
  }

  #only store genomic_aligns if there are more than 1 genomic_align left in the
  #genomic_align_block
  if (@$genomic_aligns > 1) {
      $self->param('genomic_aligns', $genomic_aligns);
  } 

}

=head2 _load_2XGenomes

  Arg [1]    : int genomic_align_block_id
  Description: Creates a fake assembly for each 2X genome by stitching
               together the LASTZ_NET alignments found on this synteny_region
               between the reference species and each 2X genome.
               Creates a listref of genomic_align fragments.
  Returntype : 
  Exception  : 
  Warning    :

=cut

sub _load_2XGenomes {
  my ($self, $genomic_align_block_id) = @_;

  #extract location of pairwise blocks
  my $pairwise_exception_location = $self->param('pairwise_exception_location');
  my $default_location = $self->param('pairwise_default_location');

  my $pairwise_locations = $self->_construct_pairwise_locations();


  #if no 2x genomes defined, return
  if (!defined $pairwise_locations) {
      print "No 2x genomes to load\n" if $self->debug;
      return;
  }

  #Find the slice on the reference genome
  my $genome_db_adaptor = $self->compara_dba->get_GenomeDBAdaptor;

  #DEBUG this opens up connections to all the databases
  my $ref_genome_db = $genome_db_adaptor->fetch_by_name_assembly($self->param('reference_species'));
  #my $ref_dba = $ref_genome_db->db_adaptor;
  #my $ref_slice_adaptor = $ref_dba->get_SliceAdaptor();

  #Get multiple alignment genomic_align_block adaptor
  my $multi_gaba = $self->compara_dba->get_GenomicAlignBlockAdaptor;

  #Find all the dnafrag_regions for the reference genome in this synteny region
  my $ref_gas =[];
  my $multi_gab = $multi_gaba->fetch_by_dbID($genomic_align_block_id);
  my $all_gas = $multi_gab->get_all_GenomicAligns;

  foreach my $ga (@$all_gas) {
      if ($ga->genome_db->dbID == $ref_genome_db->dbID) {
	  push @$ref_gas, $ga;
      }
  }
  
  #Return if there is no reference sequence in this gab region
  if (scalar(@$ref_gas) == 0) {
      print "No " . $self->param('reference_species') . " sequences found in genomic_align_block $genomic_align_block_id\n";
      return;
  }

  print "GAB $genomic_align_block_id num ref copies " . scalar(@$ref_gas) . "\n" if $self->debug;

  #Find the LASTZ_NET alignments between the reference species and each
  #2X genome.

  foreach my $mlss_id (keys %$pairwise_locations) {
      my $target_species;

      #open compara database containing 2x genome vs $ref_name blastz results
      #my $compara_db_url = $param->{'compara_db_url'};
      my $compara_db_url = $pairwise_locations->{$mlss_id};

      my $compara_dba = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new( -url => $compara_db_url );

      #need to store this to allow disconnect when call ortheus
      my $pairwise_compara_dba = $self->param('pairwise_compara_dba');
      $pairwise_compara_dba->{$compara_dba->dbc->dbname} = $compara_dba;

      #Get pairwise genomic_align_block adaptor
      my $pairwise_gaba = $compara_dba->get_GenomicAlignBlockAdaptor;

      #Get pairwise method_link_species_set
      my $p_mlss_adaptor = $compara_dba->get_MethodLinkSpeciesSetAdaptor;
      #my $pairwise_mlss = $p_mlss_adaptor->fetch_by_dbID($param->{'method_link_species_set_id'});
      my $pairwise_mlss = $p_mlss_adaptor->fetch_by_dbID($mlss_id);

      #find non_reference species name in pairwise alignment
      foreach my $genome_db (@{$pairwise_mlss->species_set->genome_dbs}) {
	  if ($genome_db->name ne $self->param('reference_species')) {
	      $target_species = $genome_db->name;
	      last;
	  }
      }
     
      my $target_genome_db = $genome_db_adaptor->fetch_by_name_assembly($target_species);
      #my $target_dba = $target_genome_db->db_adaptor;
      #my $target_slice_adaptor = $target_dba->get_SliceAdaptor();

      #Foreach copy of the ref_genome in the multiple alignment block, 
      #find the alignment blocks between the ref_genome and the 2x 
      #target_genome in the pairwise database

      my $ga_frag_array = $self->_create_frag_array($pairwise_gaba, $pairwise_mlss, $ref_gas);
  
      #not found 2x genome
      next if (!defined $ga_frag_array);

      #must first sort so I have a reasonable chance of finding duplicates


      #4/10/08 don't think sorting here is a good idea. The order is very
      #important for when I store the fragments and work out their offsets.
#      for (my $i = 0; $i < scalar(@$ga_frag_array); $i++) {
#	  @{$ga_frag_array->[$i]} = sort {$a->{genomic_align}->dnafrag_start <=> $b->{genomic_align}->dnafrag_start} @{$ga_frag_array->[$i]};
#      }
    
      #find the total length of all the fragments in the ref_region
      my $sum_lengths;
      for (my $i = 0; $i < scalar(@$ga_frag_array); $i++) {
	  for (my $j = 0; $j < scalar(@{$ga_frag_array->[$i]}); $j++) {
	      #print "*** gab *** " . $ga_frag_array->[$i][$j]->{genomic_align}->genome_db->name . " " . $ga_frag_array->[$i][$j]->{genomic_align}->genomic_align_block . "\n";

	      $sum_lengths->[$i] += ($ga_frag_array->[$i][$j]->{genomic_align}->dnafrag_end - $ga_frag_array->[$i][$j]->{genomic_align}->dnafrag_start + 1);
	  }
      }

      #check if there is any overlap between pairwise blocks on the ref_genomes
      #if there is an overlap, then choose ref_genome duplication which is the 
      #longest in 2x genome
      #if there is no overlap, save dnafrags on all duplications
      my $found_overlap;
      my $j = 0;

      #Simple case: only found one reference region containing 2x genome 
      #fragments
      if (@$ga_frag_array == 1) {
	  my $cluster;
	  $cluster = _add_to_cluster($cluster, 0);
	  _print_cluster($cluster) if $self->debug;
	  my $longest_ref_region = 0;

	  print "SIMPLE CASE: longest_region $longest_ref_region length " . $sum_lengths->[$longest_ref_region] . "\n" if $self->debug;
	  
	  #_build_2x_composite_seq($self, $compara_dba, $ref_slice_adaptor, $target_slice_adaptor, $ga_frag_array->[$longest_ref_region]);
	  
	  my $ga_frag = $self->param('ga_frag');
	  my $x2_dnafrag_region = $self->param('2x_dnafrag_region');
	  push @$ga_frag, $ga_frag_array->[$longest_ref_region];
	  push @$x2_dnafrag_region, $ga_frag_array->[$longest_ref_region]->[0]->{genomic_align};
	  $self->param('ga_frag', $ga_frag);
	  $self->param('2x_dnafrag_region', $x2_dnafrag_region);

	  #push @{$self->param('ga_frag')}, $ga_frag_array->[$longest_ref_region];
	  #push @{$self->param('2x_dnafrag_region')}, $ga_frag_array->[$longest_ref_region]->[0]->{genomic_align};
	  next;
      }

      #Found more than one reference region in this synteny block
      for (my $region1 = 0; $region1 < scalar(@$ga_frag_array)-1; $region1++) {
	  for (my $region2 = $region1+1; $region2 <  scalar(@$ga_frag_array); $region2++) {
	      #initialise found_overlap hash
	      if (!defined $found_overlap->{$region1}{$region2}) {
		  $found_overlap->{$region1}{$region2} = 0;
	      }
	      
	      #loop through the 2x genome fragments on region1
	      for (my $j = 0; ($j < @{$ga_frag_array->[$region1]}); $j++) {
		  
		  #if I've already found an overlap, then stop
		  last if ($found_overlap->{$region1}{$region2});
		  
		  #loop through 2x genome fragments on region2
		  for (my $k = 0; ($k < @{$ga_frag_array->[$region2]}); $k++) {

		    #if I've already found an overlap, then stop
		      last if ($found_overlap->{$region1}{$region2});
		      
		      #check if 2x genome fragments have the same name
		      if ($ga_frag_array->[$region1][$j]->{seq_region_name} eq $ga_frag_array->[$region2][$k]->{seq_region_name}) {
			  
			  #check these overlap
			  if (($ga_frag_array->[$region1][$j]->{start} <= $ga_frag_array->[$region2][$k]->{end}) && ($ga_frag_array->[$region1][$j]->{end} >= $ga_frag_array->[$region2][$k]->{start})) {

			      $found_overlap->{$region1}{$region2} = 1;
			      print "found overlap $region1 $region2\n" if $self->debug;
			      #found overlap so can stop.
			      last;
			  }
		      }
		  }
	      }
	  }
      }

      #Cluster all the alignment blocks that are overlapping together
      my $cluster = $self->_cluster_regions($found_overlap);
      _print_cluster($cluster) if $self->debug;
      my $longest_regions = $self->_find_longest_region_in_cluster($cluster, $sum_lengths);

      #find the reference with the longest region
      my $slice_array;
      foreach my $longest_ref_region (@$longest_regions) {
	  print "longest_ref_region $longest_ref_region length " . $sum_lengths->[$longest_ref_region] . "\n" if $self->debug;

	  #store composite_seq in ga_frag_array->[$longest_ref_region]
	  #_build_2x_composite_seq($self, $compara_dba, $ref_slice_adaptor, $target_slice_adaptor, $ga_frag_array->[$longest_ref_region]);
	  my $ga_frag = $self->param('ga_frag');
	  my $x2_dnafrag_region = $self->param('2x_dnafrag_region');
	  push @$ga_frag, $ga_frag_array->[$longest_ref_region];
	  push @$x2_dnafrag_region, $ga_frag_array->[$longest_ref_region]->[0]->{genomic_align};
	  $self->param('ga_frag', $ga_frag);
	  $self->param('2x_dnafrag_region', $x2_dnafrag_region);

	  #push @{$self->param('ga_frag')}, $ga_frag_array->[$longest_ref_region];

	  #push @{$self->param('2x_dnafrag_region')}, $ga_frag_array->[$longest_ref_region]->[0]->{genomic_align};

      }
  } 
}

sub _construct_pairwise_locations {
    my $self = shift;

    my $pairwise_location;

    #list of mlss to be found in the default location (usually previous compara database)
    my @mlsss = @{ $self->param('pairwise_default_mlss') };

    #Add exceptions
    $pairwise_location = $self->param('pairwise_exception_location');

    #Add defaults which may overwrite the exceptions if the exception mlss is now in
    #default location
    foreach my $mlss (@mlsss) {
	$pairwise_location->{$mlss} = $self->param('pairwise_default_location');
    }

    #Need a check here that I have pairwise_mlss for all the low coverage genomes.
    my $gab_adaptor = $self->compara_dba->get_GenomicAlignBlockAdaptor;
    my $gab = $gab_adaptor->fetch_by_dbID($self->param('genomic_align_block_id'));
    my $high_epo_mlss = $gab->method_link_species_set;
    my $genome_db_adaptor = $self->compara_dba->get_GenomeDBAdaptor;

    my $mlss_adaptor = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor;
    my $low_mlss = $mlss_adaptor->fetch_by_dbID($self->param('mlss_id'));

    my $low_coverage_species_set;

    my %all_species_set;
    foreach my $genome_db (@{$low_mlss->species_set->genome_dbs}) {
	$all_species_set{$genome_db->dbID} = 1;
    }
    #Find only low coverage species by removing the high coverage ones from the list of all of them
    foreach my $high_species (@{$high_epo_mlss->species_set->genome_dbs}) {
	$all_species_set{$high_species->dbID} = 2;
    }
    foreach my $genome_db_id (keys %all_species_set) {
	if ($all_species_set{$genome_db_id} == 1) {
	    push @$low_coverage_species_set, $genome_db_id;
	}
    }

    #Check found all low coverage pairwise mlss_ids
    if (@$low_coverage_species_set != scalar keys %$pairwise_location) {
	print("Failed to find all the pairwise low coverage species method_link_species_set ids\n");

	foreach my $genome_db_id (@$low_coverage_species_set) {
	    my $species;
	    my $found = 0;
	    foreach my $mlss_id (keys %$pairwise_location) {
		
		my $compara_db_url = $pairwise_location->{$mlss_id};
		
        my $compara_dba = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new( -url => $compara_db_url );
		
		my $mlss_adaptor = $compara_dba->get_MethodLinkSpeciesSetAdaptor;
		my $mlss = $mlss_adaptor->fetch_by_dbID($mlss_id);
		$species = $genome_db_adaptor->fetch_by_dbID($genome_db_id)->name;
		
		foreach my $this_spp (@{$mlss->species_set->genome_dbs}) {
		    if ($this_spp->name ne $self->param('reference_species')) {
			if ($this_spp->dbID == $genome_db_id) {
			    $found = 1;
			    print "Found $species mlss $mlss_id " . $pairwise_location->{$mlss_id} . "\n";
			    last;
			}
		    }
		}
	    }
	    if (!$found) {
		throw ("Failed to find a pairwise method_link_species_set for " . $species);
	    }
	}
    }

    if ($self->debug) {
	foreach my $key (keys %$pairwise_location) {
	    print "key $key " . $pairwise_location->{$key} . "\n";
	}
    }
    return $pairwise_location;
}

=head2 _dump_fasta_and_mfa

  Arg [1]    : -none-
  Example    : $self->_dump_fasta();
  Description: Dumps FASTA files in the order given by the tree
               string (needed by Pecan). Resulting file names are
               stored using the fasta_files getter/setter
  Returntype : 1
  Exception  :
  Warning    :

=cut

sub _dump_fasta_and_mfa {
  my $self = shift;
  my $all_genomic_aligns = $self->param('genomic_aligns');

  ## Dump FASTA files in the order given by the tree string (needed by Pecan)
  my @seqs;
  if ($self->tree_string) {
    @seqs = ($self->tree_string =~ /seq(\d+)/g);
  } else {
    @seqs = (1..scalar(@$all_genomic_aligns));
  }

  my $mfa_file = $self->worker_temp_directory . "/epo_alignment.$$.mfa";
  $self->param('multi_fasta_file', $mfa_file);

  print "mfa_file $mfa_file\n" if $self->debug;
  open MFA, ">$mfa_file" || throw("Couldn't open $mfa_file");

  foreach my $seq_id (@seqs) {
    my $ga = $all_genomic_aligns->[$seq_id-1];

    my $file = $self->worker_temp_directory . "/seq" . $seq_id;

    #Check if I have a DnaFragRegion object or my 2x genome object
    #if (!UNIVERSAL::isa($dfr, 'Bio::EnsEMBL::Compara::DnaFragRegion')) {
    if (!UNIVERSAL::isa($ga, 'Bio::EnsEMBL::Compara::GenomicAlign')) {
	print "FOUND 2X GENOME\n" if $self->debug;
	print "num of frags " . @$ga . "\n" if $self->debug;
	$self->_dump_2x_fasta($ga, $file, $seq_id, \*MFA);
	next;
    }

    #add taxon_id to end of fasta files
    $file .= "_" . $ga->genome_db->taxon_id . ".fa";
    print "file $file\n" if $self->debug;
    
    #print MFA ">SeqID" . $seq_id . "\n";

    #print MFA ">seq" . $seq_id . "\n";
    print MFA ">seq" . $seq_id . "_" . $ga->genome_db->taxon_id . "\n";

    print ">DnaFrag", $ga->dnafrag->dbID, "|", $ga->dnafrag->name, ".",
        $ga->dnafrag_start, "-", $ga->dnafrag_end, ":", $ga->dnafrag_strand,"\n" if $self->debug;

    $ga->dnafrag->genome_db->db_adaptor->dbc->prevent_disconnect( sub {

    my $slice = $ga->get_Slice;
    throw("Cannot get slice for DnaFragRegion in DnaFrag #".$ga->dnafrag->dbID) if (!$slice);
    
    my $seq = $slice->get_repeatmasked_seq(undef, 1)->seq;

    if ($seq =~ /[^ACTGactgNnXx]/) {
      print STDERR $slice->name, " contains at least one non-ACTGactgNnXx character. These have been replaced by N's\n";
      $seq =~ s/[^ACTGactgNnXx]/N/g;
    }
    $seq =~ s/(.{80})/$1\n/g;

    chomp $seq;

    $self->_spurt($file, join("\n",
            '>SeqID'.$seq_id,
            $seq,
        ));

    my $aligned_seq = $ga->aligned_sequence;
    $aligned_seq =~ s/(.{60})/$1\n/g;
    $aligned_seq =~ s/\n$//;
    print MFA $aligned_seq, "\n";

    } );

    push @{$self->fasta_files}, $file;
    push @{$self->species_order}, $ga->dnafrag->genome_db_id;
  }
  close MFA;

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
  
  $tree = $self->_update_tree_2x($tree);

  return if (!$tree);

  my $tree_string = $tree->newick_format('simple');


  # Remove quotes around node labels
  $tree_string =~ s/"(seq\d+)"/$1/g;
  # Remove branch length if 0
  $tree_string =~ s/\:0\.0+(\D)/$1/g;
  $tree_string =~ s/\:0([^\.\d])/$1/g;

  $tree->release_tree;

  $self->tree_string($tree_string);
}


=head2 _update_tree_2x

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

sub _update_tree_2x {
  my $self = shift;
  my $tree = shift;

  my $all_genomic_aligns = $self->param('genomic_aligns');
  my $ordered_genomic_aligns = [];
  my $ordered_2x_genomes = [];

  my $idx = 1;
  my $all_leaves = $tree->get_all_leaves;
  foreach my $this_leaf (@$all_leaves) {
    my $these_genomic_aligns = [];
    my $these_2x_genomes = [];
    ## Look for genomic_aligns belonging to this genome_db_id
    foreach my $this_genomic_align (@$all_genomic_aligns) {
      if ($this_genomic_align->dnafrag->genome_db_id == $this_leaf->genome_db_id) {
        push (@$these_genomic_aligns, $this_genomic_align);
      }
    }

    my $index = 0;
    if ($self->param('ga_frag')) {
	foreach my $ga_frags (@{$self->param('ga_frag')}) {
	    my $first_frag = $ga_frags->[0];
	    
	    #print "update_tree first_frag " . $first_frag->{genomic_align}->genome_db->dbID . " this leaf " . $this_leaf->genome_db_id . "\n";
	    if ($first_frag->{genomic_align}->dnafrag->genome_db->dbID == $this_leaf->genome_db_id) {
		push(@$these_2x_genomes, $index);
	    }
	    $index++;
	}
    }
    print "num " . @$these_genomic_aligns . " " . @$these_2x_genomes . "\n" if $self->debug;

    if (@$these_genomic_aligns == 1) {
      ## If only 1 has been found...
	my $taxon_id = $these_genomic_aligns->[0]->dnafrag->genome_db->taxon_id;
      print "seq$idx" . "_" . $taxon_id . " genome_db_id=" . $these_genomic_aligns->[0]->dnafrag->genome_db_id . "\n" if $self->debug;
      
      $this_leaf->name("seq".$idx++."_".$taxon_id); #.".".$these_dnafrag_regions->[0]->dnafrag_id);

      push(@$ordered_genomic_aligns, $these_genomic_aligns->[0]);

    } elsif (@$these_genomic_aligns > 1) {
      ## If more than 1 has been found, let Ortheus estimate the Tree
	print "Let ortheus estimate the tree\n" if $self->debug;
	#need to add on 2x genomes to genomic_aligns array
	my $ga = $self->param('genomic_aligns');
	if ($self->param('ga_frag')) {
	    foreach my $ga_frags (@{$self->param('ga_frag')}) {
		push @$ga, $ga_frags;
	    }
	}
	$self->param('genomic_aligns', $ga);
	return undef;

   } elsif (@$these_2x_genomes == 1) {
	#See what happens...
	#Find 2x genomes
       my $ga_frags = $self->param('ga_frag')->[$these_2x_genomes->[0]];
       print "number of frags " . @$ga_frags . "\n" if $self->debug;

       my $taxon_id = $ga_frags->[0]->{taxon_id};
	print "2x seq$idx" . "_" . $taxon_id . " " . $ga_frags->[0]->{genome_db_id} . "\n" if $self->debug;
	$this_leaf->name("seq".$idx++."_".$taxon_id);
	#push(@$ordered_2x_genomes, $these_2x_genomes->[0]);
	push(@$ordered_genomic_aligns, $ga_frags);
   } else {
      ## If none has been found...
      $this_leaf->disavow_parent;
      $tree = $tree->minimize_tree;
    }
  }

  $self->param('genomic_aligns', $ordered_genomic_aligns);

  $self->param('ordered_2x_genomes', $ordered_2x_genomes);

  if ($tree->get_child_count == 1) {
    my $child = $tree->children->[0];
    $child->parent->merge_children($child);
    $child->disavow_parent;
  }
  
  return $tree;
}

#
# Create array of 2x fragments defined by the $pairwise_mlss found for the reference 
#genomic_aligns (may be more than one) in $ref_gas
#
sub _create_frag_array {
    my ($self, $gab_adaptor, $pairwise_mlss, $ref_gas) = @_;

    my $ga_frag_array;

    my $ga_num_ns = 0;

    #Multiple alignment reference genomic_aligns (maybe more than 1)
    foreach my $ref_ga (@$ref_gas) {
	print "  " . $ref_ga->dnafrag->name . " " . $ref_ga->dnafrag_start . " " . $ref_ga->dnafrag_end . " " . $ref_ga->dnafrag_strand . "\n" if $self->debug;
	
	#find the slice corresponding to the ref_genome
	#my $slice = $ref_ga->get_Slice;

	#print "ref_seq " . $slice->start . " " . $slice->end . " " . $slice->strand . " " . substr($slice->seq,0,120) . "\n" if $self->debug;

	#find the pairwise blocks between ref_genome and the 2x genome
	#my $pairwise_gabs = $gab_adaptor->fetch_all_by_MethodLinkSpeciesSet_Slice($pairwise_mlss, $slice, undef,undef,"restrict");

	my $pairwise_gabs = $gab_adaptor->fetch_all_by_MethodLinkSpeciesSet_DnaFrag($pairwise_mlss, $ref_ga->dnafrag, $ref_ga->dnafrag_start, $ref_ga->dnafrag_end, undef,undef,"restrict");
        #Need to reverse_complement if I use the DnaFrag method (Do not need to do this with the Slice method)
        foreach my $pairwise_gab (@$pairwise_gabs) {
             $pairwise_gab->reverse_complement()
            if ($ref_ga->dnafrag_strand != $pairwise_gab->reference_genomic_align->dnafrag_strand);

        }

	#sort by reference_genomic_align start position (NB I sort again when parsing
	#the results if the ref strand is reverse since the fragments will be in the
	#reverse order ie A-B-C should be C-B-A). Don't do it here because I try to find
	#duplicates in load_2XGenomes.
	@$pairwise_gabs = sort {$a->reference_genomic_align->dnafrag_start <=> $b->reference_genomic_align->dnafrag_start} @$pairwise_gabs;

	print "    pairwise gabs " . scalar(@$pairwise_gabs) . "\n" if $self->debug;
	#if there are no pairwise matches found to 2x genome, then escape
	#back to loop
	next if (scalar(@$pairwise_gabs) == 0);
	
	my $ga_frags;

	#need to save each match separately but still use same structure as
	#create_span_frag_array in case we change our minds back again
	foreach my $pairwise_gab (@$pairwise_gabs) {

	    #should only have 1!
	    my $ga = $pairwise_gab->get_all_non_reference_genomic_aligns->[0];

	    my $ref_start = $ga->genomic_align_block->reference_genomic_align->dnafrag_start;
	    my $ref_end = $ga->genomic_align_block->reference_genomic_align->dnafrag_end;

	    #need to store gab too otherwise it goes out of scope and I can't
	    #access it from ga
	    my $ga_fragment = {genomic_align => $ga,
			       genomic_align_block => $ga->genomic_align_block,
			       taxon_id => $ga->genome_db->taxon_id,
			       genome_db_id => $ga->dnafrag->genome_db_id,
			       ref_ga => $ref_ga,
			      };

	    print "GAB " . $ga_fragment->{genomic_align}->genome_db->name . " " . $ga_fragment->{genomic_align}->dnafrag_start . " " . $ga_fragment->{genomic_align}->dnafrag_end . " " . $ga_fragment->{genomic_align}->dnafrag_strand . " " . $ga_fragment->{genomic_align}->cigar_line . " " . substr($ga_fragment->{genomic_align}->get_Slice->seq,0,120) . "\n" if $self->debug;
	    push @$ga_frags, $ga_fragment;
	}
	#add to array of fragments for each reference genomic_align
	push @$ga_frag_array, $ga_frags;
    }

    return $ga_frag_array;
}


#foreach cluster, find the longest region.
sub _find_longest_region_in_cluster {
    my ($self, $cluster, $sum_lengths) = @_;

    my $max_frag = 0;
    my $final_region = -1;
    my @overlap_frag;

    my $overlap_cnt = 0;
    my $not_overlap_cnt = 0;
    my $longest_clusters;

    foreach my $this_cluster (@$cluster) {
	my $longest_frag;
	my $longest_region;

	foreach my $region (keys %{$this_cluster}) {
	    #initialise variables
	    if (!defined $longest_frag) {
		$longest_frag = $sum_lengths->[$region];
		$longest_region = $region;
	    }

 	    if ($sum_lengths->[$region] >= $longest_frag) {
 		$longest_frag = $sum_lengths->[$region];
 		$longest_region = $region;
 	    }
	}
	push @$longest_clusters, $longest_region;
    }
    print "overlap_cnt $overlap_cnt not $not_overlap_cnt\n" if $self->debug;
    return $longest_clusters;
}

#Put overlapping regions in the same cluster. If region 0 overlaps with region 
#1 and region 2, but not with region 3, create 2 clusters: (0,1,2), (3)
sub _cluster_regions {
    my ($self, $found_overlap) = @_;

    my $overlap_cnt = 0;
    my $not_overlap_cnt = 0;

    my $cluster;

    foreach my $region1 (keys %$found_overlap) {
	foreach my $region2 (keys %{$found_overlap->{$region1}}) {
	    print "FOUND OVERLAP $region1 $region2 " . $found_overlap->{$region1}{$region2} . "\n" if $self->debug;
	    if ($found_overlap->{$region1}{$region2}) {
		$overlap_cnt++;

		$cluster = _add_to_same_cluster($cluster, $region1, $region2);
	    } else {
		$not_overlap_cnt++;
		$cluster = _add_to_different_cluster($cluster, $region1, $region2);
	    }
	}
    }
    print "overlap_cnt $overlap_cnt not $not_overlap_cnt\n" if $self->debug;
    return $cluster;
}

#add single region to cluster. No overlaps found.
sub _add_to_cluster {
    my ($cluster, $region1) = @_;

    if (!defined $cluster) {
	 $cluster->[0]->{$region1} = 1;
     }
    return $cluster;
}

 sub _add_to_same_cluster {
     my ($cluster, $region1, $region2) = @_;

     #print "add to same cluster $region1 $region2\n";

     if (!defined $cluster) {
	 $cluster->[0]->{$region1} = 1;
	 $cluster->[0]->{$region2} = 1;
	 return $cluster;
     }

     my $cluster_size = @$cluster;

     my $index1 = _in_cluster($cluster, $region1);
     my $index2 = _in_cluster($cluster, $region2);

     if ($index1 == -1 && $index2 == -1) {
	 #neither found, add both to new cluster
	 $cluster->[$cluster_size]->{$region1} = 1;
	 $cluster->[$cluster_size]->{$region2} = 1;
     } elsif ($index1 != -1 && $index2 == -1) {
	 #id1 found, id2 not. add id2 to id1 cluster
	 $cluster->[$index1]->{$region2} = 1;
     } elsif ($index1 == -1 && $index2 != -1) {
	 #id2 found, id1 not. add id1 to id2 cluster
	 $cluster->[$index2]->{$region1} = 1;
     } else {
	 #both ids set in different clusters. Merge the clusters together
	 $cluster = _merge_clusters($cluster, $index1, $index2);
     }
     return $cluster;
 }

sub _add_to_different_cluster {
     my ($cluster, $region1, $region2) = @_;

     if (!defined $cluster) {
	 $cluster->[0]->{$region1} = 1;
	 $cluster->[1]->{$region2} = 1;
	 return $cluster;
     }
     my $cluster_size = @$cluster;

     my $index1 = _in_cluster($cluster, $region1);
     my $index2 = _in_cluster($cluster, $region2);

     if ($index1 == -1) {
	 $cluster->[@$cluster]->{$region1} = 1;
     } 
     if ($index2 == -1) {
	 $cluster->[@$cluster]->{$region2} = 1;
     }

     return $cluster;
 }

 sub _in_cluster {
     my ($cluster, $region) = @_;

     for (my $i = 0; $i < @$cluster; $i++) {
 	if ($cluster->[$i]->{$region}) {
 	    return $i;
 	}
     }
     return -1;
 }

sub _merge_clusters {
    my ($cluster, $index1, $index2) = @_;
    
    #already in same cluster
    if ($index1 != -1 && $index1 == $index2) {
	return $cluster;
    }

    #copy over keys from index2 to index1
    foreach my $region (keys %{$cluster->[$index2]}) {
	#print "region $region\n";
	$cluster->[$index1]->{$region} = 1;
    }
 
    #delete index2
    splice(@$cluster, $index2, 1);

    return $cluster;
}

sub _print_cluster {
    my ($cluster) = @_;

    print "FINAL cluster ";
    foreach my $this_cluster (@$cluster) {
	print "(";
	foreach my $group (keys %{$this_cluster}) {
	    print "$group ";
	}
	print "), ";
    }
    print "\n";
}

sub _dump_2x_fasta {
    my ($self, $ga_frags, $file, $seq_id, $mfa_fh) = @_;

    $file .= "_" . $ga_frags->[0]->{taxon_id} . ".fa";

    #print MFA ">SeqID" . $seq_id . "\n";
    #print MFA ">seq" . $seq_id . "\n";
    print MFA ">seq" . $seq_id . "_" . $ga_frags->[0]->{taxon_id} . "\n";
    my $aligned_seq = $ga_frags->[0]->{aligned_seq};
    my $seq = $aligned_seq;
    $seq =~ tr/-//d;

    $self->_spurt($file, join("\n",
            '>SeqID'.$seq_id,
            $seq,
        ));

    $aligned_seq =~ s/(.{60})/$1\n/g;
    $aligned_seq =~ s/\n$//;
    print $mfa_fh $aligned_seq, "\n";

    push @{$self->fasta_files}, $file;
    
    push @{$self->species_order}, $ga_frags->[0]->{genome_db_id};

}

#create alignment from multiple genomic_align_block and 2X genomes.
sub _create_mfa {
    my ($self) = @_;

    my $multi_gab_id = $self->param('genomic_align_block_id');
    my $multi_gaba = $self->compara_dba->get_GenomicAlignBlockAdaptor;
    my $multi_gab = $multi_gaba->fetch_by_dbID($multi_gab_id);
    my $multi_gas = $multi_gab->get_all_GenomicAligns;

    my $pairwise_frags = $self->param('ga_frag');

    my $species_order = $self->species_order;

    
    foreach my $ga_frag_array (@$pairwise_frags) {
	my $multi_ref_ga = $ga_frag_array->[0]->{ref_ga};
	my $multi_mapper = $multi_ref_ga->get_Mapper;
	#my $multi_gab_length = length($multi_ref_ga->aligned_sequence);
	my $multi_gab_length = $multi_ref_ga->genomic_align_block->length;

	## New aligned sequence for the 2X genome. Empty (only dashes) at creation time
	my $aligned_sequence = "-" x $multi_gab_length;
	
	foreach my $ga_frag (@$ga_frag_array) {
	    my $pairwise_gab = $ga_frag->{genomic_align_block};
	    
	    my $pairwise_non_ref_ga = $pairwise_gab->get_all_non_reference_genomic_aligns->[0];
	    my $pairwise_ref_ga = $pairwise_gab->reference_genomic_align;

            my $pairwise_fixed_seq;
            $pairwise_non_ref_ga->dnafrag->genome_db->db_adaptor->dbc->prevent_disconnect( sub {
	        $pairwise_fixed_seq = $pairwise_non_ref_ga->aligned_sequence("+FIX_SEQ");
            });
	    
	    #undef($pairwise_non_ref_ga->{'aligned_sequence'});

	    print "pairwise " . $pairwise_non_ref_ga->genome_db->name . " " . substr($pairwise_fixed_seq,0,120) . "\n" if $self->debug;
	    my $depad = $pairwise_fixed_seq;
	    $depad =~ tr/-//d;
	    #print "depad length " . length($depad) . "\n";

	    #my $deletion_array = find_ref_deletions($pairwise_ref_ga);
	    my $deletion_array = find_ref_deletions($pairwise_gab);

	    my @coords = $multi_mapper->map_coordinates("sequence",
							$pairwise_ref_ga->dnafrag_start,
							$pairwise_ref_ga->dnafrag_end,
							$pairwise_ref_ga->dnafrag_strand,
							    "sequence");
	    my $length = 0;
	    my $start = undef;
	    my $end = undef;
	    foreach my $this_coord (@coords) {
		next if ($this_coord->isa("Bio::EnsEMBL::Mapper::Gap"));
		$length += $this_coord->length;
		## Extract the first N characters from $other_fixed_seq
		my $subseq = substr($pairwise_fixed_seq, 0, $this_coord->length, "");
		## Copy extracted characters into the new aligned sequence for the 2X genome.
		substr($aligned_sequence, $this_coord->start-1, $this_coord->length, $subseq);
		$start = $this_coord->start if (!defined($start) or $this_coord->start < $start);
		$end = $this_coord->end if (!defined($end) or $this_coord->end > $end);
	    }

	    $ga_frag->{deletions} = $deletion_array;
	    $ga_frag->{length} = length($depad);

	    $ga_frag_array->[0]->{cigar_line} = undef;
	    $ga_frag_array->[0]->{aligned_seq} = $aligned_sequence;
	} 
	#for (my $x = 0; $x < length($multi_ref_ga->aligned_sequence); $x += 80) {
	#   print substr($aligned_sequence, $x, 80), "\n";
	#  print substr($multi_ref_ga->aligned_sequence, $x, 80), "\n\n";
	#}
    }
}


#find deletions in reference species and store the position in slice coords
#and the length
sub find_ref_deletions {
    my ($gab) = @_;
    my $deletion_array;

    my $ref_ga = $gab->reference_genomic_align;
    my $non_ref_ga = $gab->get_all_non_reference_genomic_aligns->[0];

    my $ref_mapper = $ref_ga->get_Mapper;

    my $non_ref_mapper = $non_ref_ga->get_Mapper;

    my @ref_coords = $ref_mapper->map_coordinates("sequence",
						  $ref_ga->dnafrag_start,
						  $ref_ga->dnafrag_end,
						  $ref_ga->dnafrag_strand,
						  "sequence");
    #print "num coords " . @ref_coords . "\n";
    #print "non_ref start " . $non_ref_ga->dnafrag_start . " end " . $non_ref_ga->dnafrag_end . "\n";
    my $start_del;
    my $end_del;
    my $num_del = 0;
    foreach my $this_coord (@ref_coords) {
	#print "coords " . $this_coord->start . " end " . $this_coord->end . " strand " . $this_coord->strand . "\n";
	my @non_ref_coords = $non_ref_mapper->map_coordinates("alignment",
							      $this_coord->start,
							      $this_coord->end,
							      $this_coord->strand,
							      "alignment");

	#want all coords starting from left hand end
	if ($non_ref_ga->dnafrag_strand == -1) {
	    #print "start " . $non_ref_ga->dnafrag_end . " " . $non_ref_coords[0]->start . "\n";
	    $end_del = ($non_ref_ga->dnafrag_end - $non_ref_coords[0]->end +1);
	} else {
	    $end_del = $non_ref_coords[0]->start - $non_ref_ga->dnafrag_start+1;
	}
	if (defined $start_del) {
	    #print "found del $start_del $end_del\n";
	    my $deletion;
	    $deletion->{pos} = $start_del - $num_del;
	    $deletion->{len} = ($end_del-$start_del-1);
	    push @$deletion_array, $deletion;
	    $num_del += $deletion->{len};

	    #print "del pos " . $deletion->{pos} . " len " . $deletion->{len} . "\n";
	}
	if ($non_ref_ga->dnafrag_strand == -1) {
	    #print "end " . $non_ref_ga->dnafrag_end . " " . $non_ref_coords[-1]->end . "\n";
	    $start_del = ($non_ref_ga->dnafrag_end - $non_ref_coords[-1]->start +1);
	} else {	
	    $start_del = $non_ref_coords[-1]->end-$non_ref_ga->dnafrag_start+1;
	}
#  	foreach my $non_ref (@non_ref_coords) {
#  	    if ($non_ref->isa("Bio::EnsEMBL::Mapper::Gap")) {
#  		print "   found gap " . $non_ref->start . " end ". $non_ref->end . "\n";
#  	    } else {
#  		print "   non ref " . ($non_ref->start-$non_ref_ga->dnafrag_start+1) . " end " . ($non_ref->end-$non_ref_ga->dnafrag_start+1) . "\n";
#  		print "   non ref real " . $non_ref->start . " end " . $non_ref->end . "\n";
	  
#  	    }
#  	}

    }
    return $deletion_array;
}

sub get_seq_length_from_cigar {
    my ($cigar_line) = @_;
    my $seq_pos;

    my @cig = ( $cigar_line =~ /(\d*[GMDXI])/g );
    for my $cigElem ( @cig ) {
	my $cigType = substr( $cigElem, -1, 1 );
	my $cigCount = substr( $cigElem, 0 ,-1 );
	$cigCount = 1 unless ($cigCount =~ /^\d+$/);

	if( $cigType eq "M" ) {
	    $seq_pos += $cigCount;
	} elsif( $cigType eq "I") {
	    $seq_pos += $cigCount;
	}
    }
    return $seq_pos;
}

1;
