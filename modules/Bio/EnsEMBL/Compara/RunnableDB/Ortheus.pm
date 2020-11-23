=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2020] EMBL-European Bioinformatics Institute

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

Bio::EnsEMBL::Compara::RunnableDB::Ortheus

=head1 DESCRIPTION

Ortheus wants the files to be provided in the same order as in the tree string. This module starts
by getting all the DnaFragRegions of the SyntenyRegion and then use them to edit the tree (some
nodes must be removed and other ones must be duplicated in order to cope with deletions and
duplications). The build_tree_string methods numbers the sequences in order and changes the
order of the dnafrag_regions array accordingly. Last, the dumpFasta() method dumps the sequences
according to the tree_string order.

Ortheus also generates a set of aligned ancestral sequences. This module stores them in a core-like database.


=head1 PARAMETERS

=over 5

=item * synteny_region_id (int)

Ortheus will align the segments defined in the SyntenyRegion with this dbID.

=item * method_link_species_set_id (int)

Ortheus will store alignments with this method_link_species_set_id

=item * java_options

Options used to run java eg: '-server -Xmx1000M'

=item * options

Additional pecan options eg ['-p', 15]

=item * max_block_size (int)

If an alignment is longer than this value, it will be split in several blocks in the database. All resulting blocks will share the same genomic_align_group_id. 

=back

=head1 APPENDIX

The rest of the documentation details each of the object methods. 
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::RunnableDB::Ortheus;

use strict;
use warnings;

use Data::Dumper;
use File::Basename;

use Bio::EnsEMBL::Utils::Exception qw(throw);
use Bio::EnsEMBL::IO::Parser::Fasta;
use Bio::EnsEMBL::Compara::Graph::NewickParser;
use Bio::EnsEMBL::Compara::GenomicAlign;
use Bio::EnsEMBL::Compara::GenomicAlignBlock;
use Bio::EnsEMBL::Compara::GenomicAlignGroup;
use Bio::EnsEMBL::Compara::GenomicAlignTree;
use Bio::EnsEMBL::Compara::Utils::Cigars;
use Bio::EnsEMBL::Compara::Utils::Preloader;
use Bio::EnsEMBL::Compara::Production::Analysis::Ortheus;
use Bio::EnsEMBL::Hive::Utils ('stringify');

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');




=head2 fetch_input

    Title   :   fetch_input
    Usage   :   $self->fetch_input
    Function:   Fetches input data for repeatmasker from the database
    Returns :   none
    Args    :   none

=cut

sub fetch_input {
  my( $self) = @_;
  my $mlss_id = $self->param_required('mlss_id');

  ## Store DnaFragRegions corresponding to the SyntenyRegion in $self->param('dnafrag_regions'). At this point the
  ## DnaFragRegions are in random order
  $self->param('dnafrag_regions', $self->get_DnaFragRegions($self->param_required('synteny_region_id')) );

  # Set the genome dump directory
  $self->compara_dba->get_GenomeDBAdaptor->dump_dir_location($self->param_required('genome_dumps_dir'));

    ## Get the tree string by taking into account duplications and deletions. Resort dnafrag_regions
    ## in order to match the name of the sequences in the tree string (seq1, seq2...)
    if ($self->get_species_tree) {
      $self->param('tree_string', $self->get_tree_string);
      print "tree_string ", $self->param('tree_string'), "\n";
    }

    # Make sure we start in a clean space, free of any files from a previous job attempt
    $self->cleanup_worker_temp_directory;

    ## Dumps fasta files for the DnaFragRegions. Fasta files order must match the entries in the
    ## newick tree. The order of the files will match the order of sequences in the tree_string.

    $self->compara_dba->dbc->disconnect_if_idle;
    $self->_dump_fasta;

  return 1;
}

sub run {
  my $self = shift;

  #disconnect pairwise compara database
  if ($self->param('pairwise_compara_dba')) {
      foreach my $dba (values %{$self->param('pairwise_compara_dba')}) {
          $dba->dbc->disconnect_if_idle;
      }
  }

  #disconnect ancestral core database
  my $ancestor_genome_db = $self->compara_dba->get_GenomeDBAdaptor->fetch_by_name_assembly("ancestral_sequences");
  my $ancestor_dba = $ancestor_genome_db->db_adaptor;
  $ancestor_dba->dbc->disconnect_if_idle;

  #disconnect compara database
  $self->compara_dba->dbc->disconnect_if_idle;

  my $ortheus_output = Bio::EnsEMBL::Compara::Production::Analysis::Ortheus::run_ortheus($self);
  print " --- ORTHEUS OUTPUT : $ortheus_output\n\n" if $self->debug;

  #Capture error message from ortheus and write it to the job_message table
  if ( $ortheus_output ) {
      $self->detect_pecan_ortheus_errors($ortheus_output);
  }
  $self->parse_results();
}


sub detect_pecan_ortheus_errors {
      my ($self, $merged_output) = @_;
      my (%err_msgs, $traceback, $trace_open);
      my @lines = split /\n/, $merged_output;
      foreach my $line (@lines) {
          next if ($line =~ /Arguments received/);
          next if ($line =~ /^total_time/);
          next if ($line =~ /^alignment/);

          # group python and Java tracebacks into one error
          if ( $line =~ /^Traceback/ || $line =~ /^Exception in thread/ ) {
              $trace_open = 1;
              $traceback = $line;
          } elsif ($trace_open) {
              $traceback .= "\n" . $line;
              if ( $line =~ /^[^ \t]/ ) { # end of traceback
                  $trace_open = 0;
                  $err_msgs{$traceback} = 1;
              }
          } else {
              $err_msgs{$line} = 1;
          }
      }

      #Write to job_message table but without returing an error
      foreach my $err_msg (keys %err_msgs) {
          $self->warning("Ortheus failed with error: $err_msg\n");
          if ($err_msg =~ /Exception in thread "main" java.lang.IllegalStateException($|:\s+Total is unacceptable (-?Infinity|NaN)|:[0-9 ]*)/m) {
              # Not sure why this happens (the input data looked sensible)
              # Let's discard this job.
              $self->input_job->autoflow(0);
              $self->complete_early( "Pecan failed to align the sequences. Skipping." );
          } elsif ($err_msg =~ /Exception in thread "main" java.lang.IllegalArgumentException($|:\s+fromIndex\([-\d]+\) > toIndex\([-\d]+\)|:\sNegative capacity)/) {
              # Not sure why this happens
              # Let's discard this job.
              $self->input_job->autoflow(0);
              $self->complete_early( "Pecan failed to align the sequences. Skipping." );
          } elsif ($err_msg =~ /No path through alignment possible, so I have no choice but to exit, sorry/) {
              # Not sure why this happens
              # Let's discard this job.
              $self->input_job->autoflow(0);
              $self->complete_early( "Pecan failed to align the sequences. Skipping." );
          } elsif ($err_msg =~ /Zero prob, so I have no choice but to exit, sorry/) {
              # Not sure why this happens
              # Let's discard this job.
              $self->input_job->autoflow(0);
              $self->complete_early( "Pecan failed to align the sequences. Skipping." );
          } elsif ($err_msg =~ /Java heap space/ || $err_msg =~ /GC overhead limit exceeded/ || $err_msg =~ /Cannot allocate memory/ || $err_msg =~ /OutOfMemoryError/) {

              #Flow to next memory.
              $self->complete_early_if_branch_connected("Not enough memory available in this analysis. New job created in the #-1 branch\n", -1);
              throw("Ortheus ". $self->input_job->analysis->logic_name . " still failed due to insufficient heap space");
          }
      }
      die "There were errors when running Pecan/Ortheus. Please investigate\n" if %err_msgs;
}

sub write_output {
    my ($self) = @_;

	my $compara_conn = $self->compara_dba->dbc;
	my $ancestor_genome_db = $self->compara_dba->get_GenomeDBAdaptor->fetch_by_name_assembly("ancestral_sequences");
	my $ancestral_conn = $ancestor_genome_db->db_adaptor->dbc;

	$compara_conn->sql_helper->transaction(-CALLBACK => sub {
	    $ancestral_conn->sql_helper->transaction(-CALLBACK => sub {
		 $self->_write_output;
	     });
         });
}

sub _write_output {
    my ($self) = @_;

  my $skip_left_right_index = 0;

  my $mlssa = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor;
  my $mlss = $mlssa->fetch_by_dbID($self->param('mlss_id'));
  my $dnafrag_adaptor = $self->compara_dba->get_DnaFragAdaptor;
  my $gaba = $self->compara_dba->get_GenomicAlignBlockAdaptor;
  my $gaa = $self->compara_dba->get_GenomicAlignAdaptor;

  my $gata = $self->compara_dba->get_GenomicAlignTreeAdaptor;

  my $ancestor_genome_db = $self->compara_dba->get_GenomeDBAdaptor->fetch_by_name_assembly("ancestral_sequences");
  my $ancestor_dba = $ancestor_genome_db->db_adaptor;

  my $slice_adaptor = $ancestor_dba->get_SliceAdaptor();
  my $ancestor_coord_system_adaptor = $ancestor_dba->get_CoordSystemAdaptor();
  my $ancestor_coord_system;
  eval{
    $ancestor_coord_system = $ancestor_coord_system_adaptor->fetch_by_name("ancestralsegment");
  };
  if(!$ancestor_coord_system){
    $ancestor_coord_system = new Bio::EnsEMBL::CoordSystem(
            -name            => "ancestralsegment",
            -VERSION         => undef,
            -DEFAULT         => 1,
            -SEQUENCE_LEVEL  => 1,
            -RANK            => 1
        );
    $ancestor_coord_system_adaptor->store($ancestor_coord_system);
  }

  my $seq_region_sql = "UPDATE seq_region SET name = ? WHERE seq_region_id = ?";
  my $sth = $ancestor_coord_system_adaptor->prepare($seq_region_sql);

  foreach my $genomic_align_tree (@{$self->param('output')}) {
       foreach my $genomic_align_node (@{$genomic_align_tree->get_all_nodes}) {
	   foreach my $genomic_align (@{$genomic_align_node->genomic_align_group->get_all_GenomicAligns}) {
 	      $genomic_align->adaptor($gaa);
 	      $genomic_align->method_link_species_set($mlss);
 	      $genomic_align->visible(1);

 	      if ($genomic_align->dnafrag_id == -1) {
 		  ## INTERNAL NODE, i.e. an ancestral sequence
 		  my $length = length($genomic_align->original_sequence);
 		  
 		  #Trigger loading of seq adaptor to avoid locked table problems
 		  $slice_adaptor->db()->get_SequenceAdaptor();

		  #Insert into seq_region with dummy name to get the seq_region_id and then update with the new name
		  #"Ancestor_" . $mlss_id . "_$seq_region_id";
		  #Need to make unique dummy name
		  #my $dummy_name = "dummy_" . $$;

		  #Use worker id instead of $$ to create unique name
		  my $dummy_name = "dummy_" . ($self->worker->dbID || $$);
 		  my $slice = new Bio::EnsEMBL::Slice(
 						      -seq_region_name   => $dummy_name,
 						      -start             => 1,
 						      -end               => $length,
 						      -seq_region_length => $length,
 						      -strand            => 1,
 						      -coord_system      => $ancestor_coord_system,
 						     );
 		  my $this_seq_region_id = $slice_adaptor->store($slice, \$genomic_align->original_sequence);

 		  my $name = "Ancestor_" . $mlss->dbID . "_" . $this_seq_region_id;
		  #print "name $dummy_name $name\n";
		  $sth->execute($name, $this_seq_region_id) or die "Unable to update seq_region name from $dummy_name to $name with error " . $sth->errstr;
 		  my $dnafrag = new Bio::EnsEMBL::Compara::DnaFrag(
					   -name => $name,
					   -genome_db => $ancestor_genome_db,
					   -length => $length,
					   -coord_system_name => "ancestralsegment",
								  );
 		  $dnafrag_adaptor->store($dnafrag);

 		  $genomic_align->dnafrag_id($dnafrag->dbID);
 		  $genomic_align->dnafrag_end($length);
		  $genomic_align->dnafrag($dnafrag);
	      }
	  }
       }

       #restrict genomic_align_tree if it is too long and store as groups
       if ($self->param('max_block_size') && 
  	   $genomic_align_tree->length >  $self->param('max_block_size')) {
  	   my $split_trees;
  	   for (my $start = 1; $start <= $genomic_align_tree->length; 
  		$start += $self->param('max_block_size')) {
  	       my $end = $start+$self->param('max_block_size')-1;
  	       if ($end > $genomic_align_tree->length) {
  		   $end = $genomic_align_tree->length;
  	       }
  	       my $new_gat = $genomic_align_tree->restrict_between_alignment_positions($start, $end, "skip_empty_GenomicAligns");
	       # Some ancestral genomic_aligns may have become full-gaps,
	       # break the trees around those
	       my $subtrees = $self->split_if_empty_ancestral_seq($new_gat);
	       push @$split_trees, @$subtrees;
  	   }
	   $gata->store_group($split_trees);
	   foreach my $tree (@$split_trees) {
	       $self->_assert_cigar_lines_in_block($tree->modern_genomic_align_block_id);
	       $self->_assert_binary_tree($tree);
	       $self->_write_gerp_dataflow($tree->modern_genomic_align_block_id);
	       
	   }
       } else {
	   $gata->store($genomic_align_tree, $skip_left_right_index);
	   $self->_assert_cigar_lines_in_block($genomic_align_tree->modern_genomic_align_block_id);
	   $self->_assert_binary_tree($genomic_align_tree);
	   $self->_write_gerp_dataflow($genomic_align_tree->modern_genomic_align_block_id);
       }
   }
}

sub _assert_binary_tree {
    my ($self, $gat) = @_;
    foreach my $node (@{$gat->get_all_nodes}) {
        if (!$node->is_leaf && ($node->get_child_count != 2)) {
            $self->_backup_data_and_throw($gat, sprintf("Node %s is not binary", $node->name));
        }
    }
}

sub _assert_cigar_lines_in_block {
    my ($self, $gab_id) = @_;
    my $gat = $self->compara_dba->get_GenomicAlignTreeAdaptor->fetch_by_genomic_align_block_id($gab_id);

    my %lengths;
    foreach my $genomic_align_node (@{$gat->get_all_nodes}) {
        foreach my $genomic_align (@{$genomic_align_node->genomic_align_group->get_all_GenomicAligns}) {
            my $cigar_length = Bio::EnsEMBL::Compara::Utils::Cigars::sequence_length_from_cigar($genomic_align->cigar_line);
            my $region_length = $genomic_align->dnafrag_end - $genomic_align->dnafrag_start + 1;
            if ($cigar_length != $region_length) {
                $self->_backup_data_and_throw($gat, "cigar_line's sequence length ($cigar_length) doesn't match the region length ($region_length)" );
            }
            my $aln_length = Bio::EnsEMBL::Compara::Utils::Cigars::alignment_length_from_cigar($genomic_align->cigar_line);
            $lengths{$aln_length}++;
        }
    }
    if (scalar(keys %lengths) > 1) {
        $self->_backup_data_and_throw($gat, "Multiple alignment lengths: ". stringify(\%lengths));
    }
}

sub _backup_data_and_throw {
    my ($self, $gat, $err) = @_;
    my $target_dir = $self->param_required('work_dir') . '/' . $self->param('synteny_region_id') . '.' . basename($self->worker_temp_directory);
    system('cp', '-a', $self->worker_temp_directory, $target_dir);
    $self->_print_report($gat, "$target_dir/report.txt");
    $self->_print_regions("$target_dir/regions.txt");
    $self->_spurt("$target_dir/tree.nh", $gat->newick_format);
    throw("Error: $err\nData copied to $target_dir");
}

sub _print_regions {
    my ($self, $filename) = @_;
    open(my $fh, '>', $filename);
    foreach my $region (@{$self->param('dnafrag_regions')}) {
        print $fh join("\t",
            $region->genome_db->name,
            $region->genome_db->dbID,
            $region->dnafrag->name,
            $region->dnafrag_id,
            $region->dnafrag->length,
            $region->dnafrag_start,
            $region->dnafrag_end,
            $region->dnafrag_strand,
        ), "\n";
    }
    close($fh);
}

sub _print_report {
    my ($self, $gat, $filename) = @_;
    open(my $fh, '>', $filename);
    foreach my $node (@{$gat->get_all_nodes}) {
        my $ga = $node->genomic_align_group->get_all_GenomicAligns->[0];
        print $fh join("\t",
            $node->name,
            $ga->dnafrag_id,
            $ga->dnafrag_start,
            $ga->dnafrag_end,
            $ga->dnafrag_end - $ga->dnafrag_start + 1,
            length($ga->original_sequence),
            length($ga->aligned_sequence),
            stringify(Bio::EnsEMBL::Compara::Utils::Cigars::get_cigar_breakout($ga->cigar_line)),
        ), "\n";
    }
    close($fh);
}

sub _write_gerp_dataflow {
    my ($self, $gab_id) = @_;
    
    my $output_id = { genomic_align_block_id => $gab_id };
    $self->dataflow_output_id($output_id);
}

#Taken from Analysis/Runnable/Ortheus.pm module
sub parse_results {
    my ($self) = @_;

    #print STDERR 
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


      #   $self->workdir("/home/jherrero/ensembl/worker.8139/");
    my $tree_file = $self->worker_temp_directory . "/output.$$.tree";

    my $ordered_fasta_files = $self->param('fasta_files');

    if (-e $tree_file) {
            ## Ortheus estimated the tree. Overwrite the order of the fasta files and get the tree
        open(my $fh, '<', $tree_file) || throw("Could not open tree file <$tree_file>");
        my ($newick, $files) = <$fh>;
        close($fh);
        $newick =~ s/[\r\n]+$//;
        $self->param('tree_string', $newick);

            #store ordered fasta_files
        $files =~ s/[\r\n]+$//;
        $ordered_fasta_files = [split(" ", $files)];
        $self->param('fasta_files', $ordered_fasta_files);
        print STDOUT "**NEWICK: $newick\nFILES: ", join(" -- ", @$ordered_fasta_files), "\n";
    } else {
        print "++NEWICK: ", $self->param('tree_string'), "\nFILES: ", join(" -- ", @{$self->param('fasta_files')}), "\n";
    }
    
    my (@ordered_leaves) = $self->param('tree_string') =~ /[(,]([^(:)]+)/g;
    print "LEAVES: ", join(" -- ", @ordered_leaves), "\n";

    my $alignment_file = $self->worker_temp_directory . "/output.$$.mfa";

    unless ($self->param('tree_string') && -s $alignment_file) {
        # MEMLIMIT in progress ?
        sleep(30);
        throw("Empty tree string") unless $self->param('tree_string');
        throw("Empty alignment file $alignment_file");
    }

    my $this_genomic_align_block = new Bio::EnsEMBL::Compara::GenomicAlignBlock;
    
    my $tree = Bio::EnsEMBL::Compara::Graph::NewickParser::parse_newick_into_tree( $self->param('tree_string') );
  $tree->print_tree(100);
    
    print $tree->_simple_newick, "\n";
    print join(" -- ", map {$_->name} @{$tree->get_all_leaves}), "\n";
    print "Reading $alignment_file...\n";
    my $ids;

    #foreach my $this_file (@{$self->param('fasta_files')}) {
    foreach my $this_file (@$ordered_fasta_files) {

	push(@$ids, qx"head -1 $this_file");
	push(@$ids, undef); ## There is an internal node after each leaf..
    }
    pop(@$ids); ## ...except for the last leaf which is the end of the tree
    #print join(" :: ", @$ids), "\n\n";

    my $parser = Bio::EnsEMBL::IO::Parser::Fasta->open($alignment_file);
    while ($parser->next()) {
        my $name = $parser->getHeader;
        my $seq  = $parser->getSequence;

        my $this_genomic_align = new Bio::EnsEMBL::Compara::GenomicAlign;
        $this_genomic_align->aligned_sequence($seq);
        $this_genomic_align_block->add_GenomicAlign($this_genomic_align);
        my $genomic_align_group = new Bio::EnsEMBL::Compara::GenomicAlignGroup;
        $genomic_align_group->add_GenomicAlign($this_genomic_align);

        my $this_node;
        foreach my $this_leaf_name (split("_", $name)) {
            my $this_leaf = $tree->find_node_by_name($this_leaf_name);
            if (!$this_leaf) {
                die "Unable to find_node_by_name $this_leaf_name";
            }
            if ($this_node) {
                $this_node = $this_node->find_first_shared_ancestor($this_leaf);
            } else {
                $this_node = $this_leaf;
            }
        }
        print "Found node: ", join("_", map {$_->name} @{$this_node->get_all_leaves}), "\n" if ($self->debug);

        $this_node->cast('Bio::EnsEMBL::Compara::GenomicAlignTree');
        $this_node->genomic_align_group($genomic_align_group);

        ## FASTA headers correspond to the tree and the order of the leaves in the tree corresponds
        ## to the order of the files
        my $header = shift(@$ids);
        if (not defined $header) {

            print "INTERNAL NODE $name\n" if ($self->debug);
            ## INTERNAL NODE: dnafrag_id and dnafrag_end must be edited somewhere else

            $this_genomic_align->dnafrag_id(-1);
            $this_genomic_align->dnafrag_start(1);
            $this_genomic_align->dnafrag_end(0);
            $this_genomic_align->dnafrag_strand(1);
            $this_node->name($name);

        } else {

            if ($header =~ /^>SeqID(\d+)/) {

                print "leaf_name?? $name\n" if ($self->debug);

                #information extracted from fasta header
                my $seq_id = ($1);
                my $all_dnafrag_regions = $self->param('dnafrag_regions');
                my $dfr = $all_dnafrag_regions->[$seq_id-1];
                print "normal dnafrag_id " . $dfr->dnafrag_id . "\n" if $self->debug;

                $this_genomic_align->dnafrag_id($dfr->dnafrag_id);
                $this_genomic_align->dnafrag_start($dfr->dnafrag_start);
                $this_genomic_align->dnafrag_end($dfr->dnafrag_end);
                $this_genomic_align->dnafrag_strand($dfr->dnafrag_strand);

                print "store gag2 $this_node\n" if $self->debug;

		    my $region_length = $dfr->dnafrag_end - $dfr->dnafrag_start + 1;
		    my $original_sequence = $seq;
		    $original_sequence =~ s/-//g;
		    if (length($original_sequence) != $region_length) {
			throw("Length mismatch: $region_length from the coordinates, ".length($original_sequence)." from the aligned string");
		    }

            } else {
                throw("Error while parsing '$header' header in '$alignment_file'. It must start by \">SeqID#####\" where ##### is the internal integer id\n");
            }
        }
    }
    $parser->close();

    print join(" -- ", map {$_."+".$_->node_id."+".$_->name} (@{$tree->get_all_nodes()})), "\n";
    my $trees = $self->split_if_empty_ancestral_seq($tree);
    $self->param('output', $trees);
}


sub split_if_empty_ancestral_seq {
    my ($self, $genomic_align_tree) = @_;

    my @non_empty_nodes;
    # Check all the nodes
    foreach my $node (@{$genomic_align_tree->get_all_nodes}) {
        if ($node->aligned_sequence =~ /^-+$/) {
            # Disconnect the ones that have an empty sequence
            $node->disavow_parent if $node->has_parent;
            $_->disavow_parent for @{$node->children};
        } else {
            # And record the others
            push @non_empty_nodes, $node;
        }
    }

    # The roots are all the nodes that we kept and have no parent.
    # Valid trees must have at least two sequences and be minimized.
    my @subtrees = map {$_->minimize_tree()}
                   grep {scalar(@{$_->get_all_leaves}) >= 2}
                   grep {!$_->has_parent}
                   @non_empty_nodes;

    # Remove the columns that have become gap-only
    $self->remove_empty_cols($_) for @subtrees;

    return \@subtrees;
}


sub remove_empty_cols {
    my ($self, $tree) = @_;

    my $gaa = $self->compara_dba->get_GenomicAlignAdaptor;

    ## $seqs is a hash for storing segments of sequence in the alignment
    my $seqs = {}; ## key => start, value => end; both in e! coord.
    foreach my $this_leaf (@{$tree->get_all_nodes}) {
        foreach my $this_genomic_align (@{$this_leaf->genomic_align_group->get_all_GenomicAligns}) {
            my $cigar_line = $this_genomic_align->cigar_line;
            my $pos = 1; ## $pos in e! coordinates
            foreach my $cig_elem (grep {$_} split(/(\d*[DMIGX])/, $cigar_line)) {
                my ($num, $mode) = $cig_elem =~ /(\d*)([DMIGX])/;
                $num = 1 if ($num eq "");
                if ($mode eq "M" or $mode eq "I") {
                    my $start = $pos;
                    my $end = $pos + $num - 1;
                    unless (exists($seqs->{$start}) and $seqs->{$start} >= $end) {
                        $seqs->{$start} = $end;
                    }
                }
                $pos += $num;
            }
	}
    }

    ## Now goes through all the segments and detect gap-only cols as coordinates with no sequence
    my $last_start_pos = 0;
    my $last_end_pos = 0;
    my $gaps = {};
    foreach my $start_pos (sort {$a <=> $b} keys %$seqs) {
        my $end_pos = $seqs->{$start_pos};
        # print " $start_pos -> $end_pos\n" if $self->debug;
        if ($end_pos <= $last_end_pos) {
            ## Included in the current block. Skip this
            # print " XXX\n" if $self->debug;
            next;
        } elsif ($start_pos <= $last_end_pos + 1) {
            ## Overlapping or consecutive segments. Change last_end
            $last_end_pos = $end_pos;
            # print " ---> $end_pos\n" if $self->debug;
        } else {
            ## New segment: there are gap-only cols
            $gaps->{$last_end_pos + 1} = $start_pos - 1 if ($last_end_pos);
            # print " ---> GAP (" . ($last_end_pos + 1) . "-" . ($start_pos - 1) . ")\n" if $self->debug;
            $last_start_pos = $start_pos;
            $last_end_pos = $end_pos;
        }
    }

    ## Trim the sequences to remove gap-only cols.
    foreach my $this_leaf (@{$tree->get_all_nodes}) {
	foreach my $this_genomic_align (@{$this_leaf->genomic_align_group->get_all_GenomicAligns}) {
	    #set adaptor to get the aligned sequence using the dnafrag_id
	    if (!defined $this_genomic_align->{'adaptor'}) {
		$this_genomic_align->adaptor($gaa);
	    }
            my $aligned_sequence = $this_genomic_align->aligned_sequence;
	          # print "before cigar " . $this_genomic_align->cigar_line . "\n" if $self->debug;
            foreach my $start_pos (sort {$b <=> $a} keys %$gaps) { ## IN REVERSE ORDER!!
                my $end_pos = $gaps->{$start_pos};
                ## substr works with 0-based coordinates
                substr($aligned_sequence, $start_pos - 1, ($end_pos - $start_pos + 1), "");
	    }
	    ## Uses the new sequence
            $this_genomic_align->{cigar_line} = undef;
            $this_genomic_align->aligned_sequence($aligned_sequence);
	    # print "after cigar " . $this_genomic_align->cigar_line . "\n" if $self->debug;
	}
    }
}


##########################################
#
# getter/setter methods
# 
##########################################


sub get_species_tree {
  my $self = shift;

  if (defined($self->param('species_tree'))) {
      return $self->param('species_tree');
  }

  my $mlss = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor->fetch_by_dbID($self->param('mlss_id'));
  my $species_tree = $mlss->species_tree->root;

  #if the tree leaves are species names, need to convert these into genome_db_ids
  my $genome_dbs = $mlss->species_set->genome_dbs;

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



##########################################
#
# internal methods
#
##########################################

=head2 get_DnaFragRegions

  Arg [1]    : int syteny_region_id
  Example    : $self->get_DnaFragRegions();
  Description: Gets the list of DnaFragRegions for this syteny_region_id.
  Returntype : listref of Bio::EnsEMBL::Compara::DnaFragRegion objects
  Exception  :
  Warning    :

=cut

sub get_DnaFragRegions {
  my ($self, $synteny_region_id) = @_;

  my $sra = $self->compara_dba->get_SyntenyRegionAdaptor;
  my $sr = $sra->fetch_by_dbID($self->param('synteny_region_id'));
  die "No SyntenyRegion for this dbID '$synteny_region_id'\n" unless $sr;

  my $regions = $sr->get_all_DnaFragRegions();
  Bio::EnsEMBL::Compara::Utils::Preloader::load_all_DnaFrags($self->compara_dba->get_DnaFragAdaptor, $regions);
  return [sort {$a->dnafrag_id <=> $b->dnafrag_id || $a->dnafrag_start <=> $b->dnafrag_start} @$regions];
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
  if ($self->param('tree_string')) {
    @seqs = ($self->param('tree_string') =~ /seq(\d+)/g);
  } else {
    @seqs = (1..scalar(@$all_dnafrag_regions));
  }

  $self->param('fasta_files', []);
  $self->param('species_order', []);

  foreach my $seq_id (@seqs) {

    my $dfr = $all_dnafrag_regions->[$seq_id-1];

    my $file = $self->worker_temp_directory . "/seq" . $seq_id . ".fa";

    print "file $file name " . $dfr->dnafrag->genome_db->name . "\n" if $self->debug;

    print ">DnaFrag", $dfr->dnafrag_id, "|", $dfr->dnafrag->name, "|", $dfr->dnafrag->genome_db->name, "|", $dfr->dnafrag->genome_db_id, "|",
        $dfr->dnafrag_start, "-", $dfr->dnafrag_end, ":", $dfr->dnafrag_strand," $seq_id***\n" if $self->debug;

    my $seq = $dfr->get_sequence('soft');
    if ($seq =~ /[^ACTGactgNnXx]/) {
      print STDERR $dfr->toString, " contains at least one non-ACTGactgNnXx character. These have been replaced by N's\n";
      $seq =~ s/[^ACTGactgNnXx]/N/g;
    }
    $seq =~ s/(.{80})/$1\n/g;
    chomp $seq;

    $self->_spurt($file, join("\n",
            ">SeqID" . $seq_id,
            $seq,
        ));

    push @{$self->param('fasta_files')}, $file;
    push @{$self->param('species_order')}, $dfr->dnafrag->genome_db_id;

  };

  return 1;
}


=head2 get_tree_string

  Arg [1]    : -none-
  Example    : $self->get_tree_string();
  Description: This method generates the tree_string using the orginal
               species tree and the set of DnaFragRegions. The
               tree is edited by the _update_tree method which
               resort the DnaFragRegions (see _update_tree elsewhere in this document)
  Returntype : -none-
  Exception  :
  Warning    :

=cut

sub get_tree_string {
  my $self = shift;

  my $tree = $self->get_species_tree;
  return if (!$tree);

  $tree = $self->_update_tree($tree->copy);

  return if (!$tree);

  my $tree_string = $tree->newick_format("simple");
  # Remove quotes around node labels
  $tree_string =~ s/"(seq\d+)"/$1/g;
  # Remove branch length if 0
  $tree_string =~ s/\:0\.0+(\D)/$1/g;
  $tree_string =~ s/\:0([^\.\d])/$1/g;

  $tree->release_tree;

  return $tree_string;
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
  my $all_leaves = $tree->get_all_sorted_leaves;
  foreach my $this_leaf (@$all_leaves) {
    my $these_dnafrag_regions = [];
    ## Look for DnaFragRegions belonging to this genome_db_id
    foreach my $this_dnafrag_region (@$all_dnafrag_regions) {
      if ($this_dnafrag_region->dnafrag->genome_db_id == $this_leaf->genome_db_id) {
        push (@$these_dnafrag_regions, $this_dnafrag_region);
      }
    }

    my $index = 0;
    print $this_leaf->name, ": num " . @$these_dnafrag_regions . "\n" if $self->debug;

    if (@$these_dnafrag_regions == 1) {
      ## If only 1 has been found...
      print "seq$idx genome_db_id=" . $these_dnafrag_regions->[0]->dnafrag->genome_db_id . "\n" if $self->debug;

      $this_leaf->name("seq".$idx++); #.".".$these_dnafrag_regions->[0]->dnafrag_id);

      push(@$ordered_dnafrag_regions, $these_dnafrag_regions->[0]);

    } elsif (@$these_dnafrag_regions > 1) {
      ## If more than 1 has been found, let Ortheus estimate the Tree
	return undef;

  } else {
      ## If none has been found...
      $this_leaf->disavow_parent;
      $tree = $tree->minimize_tree;
    }
 }
 $self->param('dnafrag_regions', $ordered_dnafrag_regions);

  #if (scalar(@$all_dnafrag_regions) != scalar(@$ordered_dnafrag_regions) or
   #   scalar(@$all_dnafrag_regions) != scalar(@{$tree->get_all_leaves})) {
   # throw("Tree has a wrong number of leaves after updating the node names");
  #}

  if ($tree->get_child_count == 1) {
    my $child = $tree->children->[0];
    $child->parent->merge_children($child);
    $child->disavow_parent;
  }
  return $tree;
}

1;
