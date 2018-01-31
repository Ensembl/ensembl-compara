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

Bio::EnsEMBL::Compara::RunnableDB::Ortheus

=head1 DESCRIPTION

This module acts as a layer between the Hive system and the Bio::EnsEMBL::Compara::Production::Analysis::Ortheus
module since the ensembl-analysis API does not know about ensembl-compara

Ortheus wants the files to be provided in the same order as in the tree string. This module starts
by getting all the DnaFragRegions of the SyntenyRegion and then use them to edit the tree (some
nodes must be removed and other ones must be duplicated in order to cope with deletions and
duplications). The build_tree_string methods numbers the sequences in order and changes the
order of the dnafrag_regions array accordingly. Last, the dumpFasta() method dumps the sequences
according to the tree_string order.

This module can be used to include low coverage 2X genomes in the alignment. To do this, the pairwise LASTZ_NET alignments between each 2X genome and a reference species (eg human) are retrieved from specified databases. 

Ortheus also generates a set of aligned ancestral sequences. This module stores them in a core-like database.


=head1 PARAMETERS

=over 5

=item * synteny_region_id (int)

Ortheus will align the segments defined in the SyntenyRegion with this dbID.

=item * method_link_species_set_id (int)

Ortheus will store alignments with this method_link_species_set_id

=item * java_options

Options used to run java eg: '-server -Xmx1000M'

=item * tree_file

Optional. A list of database locations and method_link_species_set_id pairs for the 2X geonome LASTZ_NET alignments. The database locations should be identified using the url format.ie mysql://user:pass\@host:port/db_name.

=item * reference_species 

Optional. The reference species for the 2X genome LASTZ_NET alignments

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
use Bio::EnsEMBL::Utils::Exception qw(throw);
use Bio::EnsEMBL::Compara::DnaFragRegion;
use Bio::EnsEMBL::Compara::Graph::NewickParser;
use Bio::EnsEMBL::Compara::GenomicAlign;
use Bio::EnsEMBL::Compara::GenomicAlignBlock;
use Bio::EnsEMBL::Compara::GenomicAlignGroup;
use Bio::EnsEMBL::Compara::GenomicAlignTree;
use Bio::EnsEMBL::Compara::Production::Analysis::Ortheus;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

#Padding character and max_pads to be added when creating the 2X genome
#composite sequence
my $pad_char = "N";

my $max_pads = 100;
#my $max_pads = 1000000;

#percentage of max_pads to use ie to use 80% of the actual pad number, set max_pads to be
#very large (so won't be trimmed) and set max_pad_percent to 0.8. 
#my $max_pads_percent = 0.8; 
my $max_pads_percent = 1.0; 

#which method to use for creating the 2X fragments. If this is true (1), use
#only the pairwise matching blocks. If this is false (0), use the entire net
#including the inter-block spanning regions aswell. This leads to large regions
#in the final alignment containing a single sequence but was useful for 
#aligning gorilla in the 5way primate alignment before gorilla had chromosomes
my $create_block_frag_array = 1;

=head2 fetch_input

    Title   :   fetch_input
    Usage   :   $self->fetch_input
    Function:   Fetches input data for repeatmasker from the database
    Returns :   none
    Args    :   none

=cut

sub fetch_input {
  my( $self) = @_;
  $self->param('ga_frag', []);
  my $mlss_id = $self->param_required('mlss_id');

  ## Store DnaFragRegions corresponding to the SyntenyRegion in $self->param('dnafrag_regions'). At this point the
  ## DnaFragRegions are in random order
  $self->param('dnafrag_regions', $self->get_DnaFragRegions($self->param_required('synteny_region_id')) );

    ## Get the tree string by taking into account duplications and deletions. Resort dnafrag_regions
    ## in order to match the name of the sequences in the tree string (seq1, seq2...)
    if ($self->get_species_tree) {
      $self->param('tree_string', $self->get_tree_string);
      print "seq_string ", $self->param('tree_string'), "\n";
    }
    ## Dumps fasta files for the DnaFragRegions. Fasta files order must match the entries in the
    ## newick tree. The order of the files will match the order of sequences in the tree_string.

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
      my (%err_msgs, $traceback, $trace_open);
      my @lines = split /\n/, $ortheus_output;
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
          if ($err_msg =~ /Exception in thread "main" java.lang.IllegalStateException($|:\s+Total is unacceptable (-?Infinity|NaN))/m) {
              # Not sure why this happens (the input data looked sensible)
              # Let's discard this job.
              $self->input_job->autoflow(0);
              $self->complete_early( "Pecan failed to align the sequences. Skipping." );
          } elsif ($err_msg =~ /Java heap space/ || $err_msg =~ /GC overhead limit exceeded/ || $err_msg =~ /Cannot allocate memory/ || $err_msg =~ /OutOfMemoryError/) {

              #Flow to next memory.
              my $num_jobs = $self->dataflow_output_id(undef, -1);

              #Check if any jobs created (if none, then know that no flow was defined on this branch ie got to last pecan_mem(
              if (@$num_jobs == 0) {
                  throw("Ortheus ". $self->input_job->analysis->logic_name . " still failed due to insufficient heap space");
              }

              #Don't want to flow to gerp jobs here
              $self->input_job->autoflow(0);
              $self->complete_early( "Not enough memory available in this analysis. New job created in the #-1 branch\n" );
          }
      }
      die "There were errors when running Ortheus. Please investigate\n" if %err_msgs;
  }

  $self->parse_results();
}

sub write_output {
    my ($self) = @_;

    print "WRITE OUTPUT\n" if $self->debug;
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
		  my $dummy_name = "dummy_" . $self->worker->dbID;
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

       my $split_trees;
       #restrict genomic_align_tree if it is too long and store as groups
       if ($self->param('max_block_size') && 
  	   $genomic_align_tree->length >  $self->param('max_block_size')) {
  	   for (my $start = 1; $start <= $genomic_align_tree->length; 
  		$start += $self->param('max_block_size')) {
  	       my $end = $start+$self->param('max_block_size')-1;
  	       if ($end > $genomic_align_tree->length) {
  		   $end = $genomic_align_tree->length;
  	       }
  	       my $new_gat = $genomic_align_tree->restrict_between_alignment_positions($start, $end, "skip_empty_GenomicAligns");
	       push @$split_trees, $new_gat;
  	   }
	   $gata->store_group($split_trees);
	   foreach my $tree (@$split_trees) {
	       $self->_write_gerp_dataflow($tree->modern_genomic_align_block_id,
					   $mlss);
	       
	   }
       } else {
	   $gata->store($genomic_align_tree, $skip_left_right_index);
	   $self->_write_gerp_dataflow(
			    $genomic_align_tree->modern_genomic_align_block_id,
			    $mlss);
       }
   }
    #print "tmp worker dir " . $self->worker_temp_directory . "\n";
    chdir("$self->worker_temp_directory");
    foreach(glob("*")){
	#DO NOT COMMENT THIS OUT!!! (at least not permenantly). Needed
	#to clean up after each job otherwise you get files left over from
	#the previous job.
	unlink($_);
    }
    #throw("Test commit");
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
    my ($self, $gab_id, $mlss) = @_;
    
    my @species_set = map {$_->dbID} @{$mlss->species_set->genome_dbs()};
    
    my $output_id = { genomic_align_block_id => $gab_id, species_set => \@species_set };
    $self->dataflow_output_id($output_id);
}

#Taken from Analysis/Runnable/Ortheus.pm module
sub parse_results {
    my ($self, $run_number) = @_;

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
        open(F, $tree_file) || throw("Could not open tree file <$tree_file>");
        my ($newick, $files) = <F>;
        close(F);
        $newick =~ s/[\r\n]+$//;
        $self->param('tree_string', $newick);

            #store ordered fasta_files
        $files =~ s/[\r\n]+$//;
        $ordered_fasta_files = [split(" ", $files)];
        $self->param('fasta_files', $ordered_fasta_files);
        print STDOUT "**NEWICK: $newick\nFILES: ", join(" -- ", @$ordered_fasta_files), "\n";
    }
    
    
    #   $self->param('tree_string', "((0:0.06969,1:0.015698):1e-05,2:0.008148):1e-05;");
    #   $self->param('fasta_files', ["/home/jherrero/ensembl/worker.8139/seq1.fa", "/home/jherrero/ensembl/worker.8139/seq2.fa", "/home/jherrero/ensembl/worker.8139/seq3.fa"]);
    
    
    my (@ordered_leaves) = $self->param('tree_string') =~ /[(,]([^(:)]+)/g;
    print "++NEWICK: ", $self->param('tree_string'), "\nLEAVES: ", join(" -- ", @ordered_leaves), "\nFILES: ", join(" -- ", @{$self->param('fasta_files')}), "\n";

    #my $alignment_file = $self->workdir . "/output.$$.mfa";

    my $alignment_file = $self->worker_temp_directory . "/output.$$.mfa";

    my $this_genomic_align_block = new Bio::EnsEMBL::Compara::GenomicAlignBlock;
    
    open(F, $alignment_file) || throw("Could not open $alignment_file");
    my $seq = "";
    my $this_genomic_align;

    #Create genomic_align_group object to store genomic_aligns for
    #each node. For 2x genomes, there may be several genomic_aligns
    #for a node but for other genomes there will only be one
    #genomic_align in the genomic_align_group
    my $genomic_align_group;

    my $tree = Bio::EnsEMBL::Compara::Graph::NewickParser::parse_newick_into_tree( $self->param('tree_string') );
  $tree->print_tree(100);
    
    print $tree->newick_format("simple"), "\n";
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

    my $genomic_aligns_2x_array = [];
    my @num_frag_pads;

    while (<F>) {
	next if (/^\s*$/);
	chomp;
	## FASTA headers correspond to the tree and the order of the leaves in the tree corresponds
	## to the order of the files

	if (/^>/) {
	    print "PARSING $_\n" if ($self->debug);
	    print $tree->newick_format(), "\n" if ($self->debug);
	    my ($name) = $_ =~ /^>(.+)/;
	    if (defined($this_genomic_align) and  $seq) {
		if (@$genomic_aligns_2x_array) {
		    print "*****FOUND 2x seq " . length($seq) . "\n" if ($self->debug);
		    #starting offset
		    #my $offset = $max_pads;
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

			print "extract_sequence $offset " .($offset+$ga_length) . " num pads $num_pads\n" if ($self->debug); 

			my ($subseq, $aligned_start, $aligned_end) = _extract_sequence($seq, $offset+1, ($offset+$ga_length));

			#Add aligned sequence
			$genomic_align->aligned_sequence($subseq);

			#Add X padding characters to ends of seq
			$start_X = $aligned_start;
			$end_X = length($seq) - ($start_X+length($subseq));

			print "start_X $start_X end_X $end_X subseq_length " . length($subseq) . "\n" if ($self->debug);

			$genomic_align->cigar_line($start_X . "X" .$genomic_align->cigar_line . $end_X . "X");

			#my $aln_seq = "." x $start_X;
			#$aln_seq .= $genomic_align->aligned_sequence();
			#$aln_seq .= "." x $end_X;
			#$genomic_align->aligned_sequence($aln_seq);

			#free aligned_sequence now that I've used it to 
			#create the cigar_line
			undef($genomic_align->{'aligned_sequence'});

			#Add genomic align to genomic align block
			$this_genomic_align_block->add_GenomicAlign($genomic_align);
			$offset += $num_pads + $ga_length;
		    }
		    $genomic_aligns_2x_array = [];
		    undef @num_frag_pads;
		} else {

		    print "add aligned_sequence " . $this_genomic_align->dnafrag_id . " " . $this_genomic_align->dnafrag_start . " " . $this_genomic_align->dnafrag_end . "\n" if $self->debug;

		    $this_genomic_align->aligned_sequence($seq);
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
			print "LEAF: $this_leaf_name\n" if ($self->debug);
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
		#$this_node->genomic_align($this_genomic_align);
		$genomic_align_group = new Bio::EnsEMBL::Compara::GenomicAlignGroup();
		$genomic_align_group->add_GenomicAlign($this_genomic_align);

		
		$this_node->genomic_align_group($genomic_align_group);
		$this_node->name($name);
	    #} elsif ($header =~ /^>DnaFrag(\d+)\|(.+)\.(\d+)\-(\d+)\:(\-?1)$/) {
	    } elsif ($header =~ /^>SeqID(\d+)/) {
		#print "old $name\n";

		print "leaf_name?? $name\n" if ($self->debug);
		my $this_leaf = $tree->find_node_by_name($name);
		if (!$this_leaf) {
		    print $tree->newick_format(), " ****\n" if ($self->debug);
		    die "Unable to find_node_by_name $name";
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

		my $all_dnafrag_regions = $self->param('dnafrag_regions');

		my $dfr = $all_dnafrag_regions->[$seq_id-1];

		if (!UNIVERSAL::isa($dfr, 'Bio::EnsEMBL::Compara::DnaFragRegion')) {
		    print "FOUND 2X GENOME\n" if $self->debug;
		    print "num of frags " . @$dfr . "\n" if $self->debug;

		    #first pads
		    push @num_frag_pads, $dfr->[0]->{first_pads};

		    #create new genomic_align for each pairwise fragment
		    foreach my $ga_frag (@$dfr) {
			my $genomic_align = new Bio::EnsEMBL::Compara::GenomicAlign;
		    
			print "2x dnafrag_id " . $ga_frag->{dnafrag_region}->dnafrag_id . "\n" if $self->debug;

			$genomic_align->dnafrag_id($ga_frag->{dnafrag_region}->dnafrag_id);
			$genomic_align->dnafrag_start($ga_frag->{dnafrag_region}->dnafrag_start);
			$genomic_align->dnafrag_end($ga_frag->{dnafrag_region}->dnafrag_end);
			$genomic_align->dnafrag_strand($ga_frag->{dnafrag_region}->dnafrag_strand);

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
		    print "normal dnafrag_id " . $dfr->dnafrag_id . "\n" if $self->debug;

		    $this_genomic_align->dnafrag_id($dfr->dnafrag_id);
		    $this_genomic_align->dnafrag_start($dfr->dnafrag_start);
		    $this_genomic_align->dnafrag_end($dfr->dnafrag_end);
		    $this_genomic_align->dnafrag_strand($dfr->dnafrag_strand);

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
	#my $offset = $max_pads;
	my $offset = $num_frag_pads[0];

	#how many X's to add at the start and end of the cigar_line
	my ($start_X , $end_X);
	
	my $align_offset = 0;
	for (my $i = 0; $i < @$genomic_aligns_2x_array; $i++) {
	    my $genomic_align = $genomic_aligns_2x_array->[$i];
	    my $num_pads = $num_frag_pads[$i+1];
	    my $ga_length = $genomic_align->dnafrag_end-$genomic_align->dnafrag_start+1;
	    print "extract_sequence $offset " .($offset+$ga_length) . " num pads $num_pads\n" if ($self->debug); 
	    my ($subseq, $aligned_start, $aligned_end) = _extract_sequence($seq, $offset+1, ($offset+$ga_length));
	    
	    #Add aligned sequence
	    $genomic_align->aligned_sequence($subseq);
	    
	    #Add X padding characters to ends of seq
	    $start_X = $aligned_start;
	    $end_X = length($seq) - ($start_X+length($subseq));
	    print "start_X $start_X end_X $end_X subseq_length " . length($subseq) . "\n" if ($self->debug);
	    
	    $genomic_align->cigar_line($start_X . "X" .$genomic_align->cigar_line . $end_X . "X");
	    my $aln_seq = "." x $start_X;
	    $aln_seq .= $genomic_align->aligned_sequence();
	    $aln_seq .= "." x $end_X;
	    $genomic_align->aligned_sequence($aln_seq);
	    
	    #Add genomic align to genomic align block
	    $this_genomic_align_block->add_GenomicAlign($genomic_align);
	    $offset += $num_pads + $ga_length;
	}
    } else {
	if ($this_genomic_align->dnafrag_id == -1) {
	} else {
	    $this_genomic_align->aligned_sequence($seq);
	    $this_genomic_align_block->add_GenomicAlign($this_genomic_align);
	}
    }

    $self->remove_empty_cols($tree);
    print $tree->newick_format("simple"), "\n";
    print join(" -- ", map {$_."+".$_->node_id."+".$_->name} (@{$tree->get_all_nodes()})), "\n";
    $self->param('output', [$tree]);

#     foreach my $ga_node (@{$tree->get_all_nodes}) {
# 	if ($ga_node) {
# 	    my $ga = $ga_node->genomic_align;
# 	    print "name " . $ga_node->name . " $ga \n";
# 	    my $gab = $ga->genomic_align_block;
# 	    if (defined $gab) {
# 		print "Parse number of genomic_aligns " . $gab . " " . @{$gab->genomic_align_array} . "\n";
# 	    } else {
# 		print "Parse no genomic_aligns\n";
# 	    }
# 	} else {
# 	    print "no ga_node\n";
# 	}
	
#     }


}

sub remove_empty_cols {
    my ($self, $tree) = @_;

    my $gaa = $self->compara_dba->get_GenomicAlignAdaptor;

    ## $seqs is a hash for storing segments of sequence in the alignment
    my $seqs = {}; ## key => start, value => end; both in e! coord.
    foreach my $this_leaf (@{$tree->get_all_leaves}) {
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


#
# Extract the sequence corresponding to the 2X genome fragment
#
sub _extract_sequence {
    my ($seq, $original_start, $original_end) = @_;
    my $original_count = 0;
    my $aligned_count = 0;
    my $aligned_start;
    my $aligned_end;

    #print "original_start $original_start original_end $original_end\n";
    foreach my $subseq (grep {$_} split /(\-+)/, $seq) {
	my $length = length($subseq);
	if ($subseq !~ /\-/) {
	    if (!defined($aligned_start) && ($original_count + $length >= $original_start)) {
		$aligned_start = $aligned_count + ($original_start - $original_count) - 1;
	    }
	    if (!defined($aligned_end) && ($original_count + $length >= $original_end)) {
		$aligned_end = $aligned_count + $original_end - $original_count - 1;
		last;
	    }
	    $original_count += $length;
	}
	$aligned_count += $length;
    }

    my $subseq = substr($seq, $aligned_start, ($aligned_end-$aligned_start+1));
    return ($subseq, $aligned_start, $aligned_end);
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

  my $species_tree = $self->compara_dba->get_SpeciesTreeAdaptor->fetch_by_method_link_species_set_id_label($self->param('mlss_id'), 'default')->root;

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
  return [@$regions];
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

    #Check if I have a DnaFragRegion object or my 2x genome object
    if (!UNIVERSAL::isa($dfr, 'Bio::EnsEMBL::Compara::DnaFragRegion')) {
        print "FOUND 2X GENOME\n" if $self->debug;
        print "num of frags " . @$dfr . "\n" if $self->debug;
        $self->_dump_2x_fasta($dfr, $file, $seq_id);
        next;
    }

    print ">DnaFrag", $dfr->dnafrag_id, "|", $dfr->dnafrag->name, "|", $dfr->dnafrag->genome_db->name, "|", $dfr->dnafrag->genome_db_id, "|",
        $dfr->dnafrag_start, "-", $dfr->dnafrag_end, ":", $dfr->dnafrag_strand," $seq_id***\n" if $self->debug;

    $dfr->dnafrag->genome_db->db_adaptor->dbc->prevent_disconnect( sub {

# my $slice = $dfr->dnafrag->slice->sub_Slice($dfr->dnafrag_start,$dfr->dnafrag_end,$dfr->dnafrag_strand);
 
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
            ">SeqID" . $seq_id,
            $seq,
        ));

    } );

    push @{$self->param('fasta_files')}, $file;
    push @{$self->param('species_order')}, $dfr->dnafrag->genome_db_id;
  }

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
  my $all_leaves = $tree->get_all_leaves;
  foreach my $this_leaf (@$all_leaves) {
    my $these_dnafrag_regions = [];
    my $these_2x_genomes = [];
    ## Look for DnaFragRegions belonging to this genome_db_id
    foreach my $this_dnafrag_region (@$all_dnafrag_regions) {
      if ($this_dnafrag_region->dnafrag->genome_db_id == $this_leaf->genome_db_id) {
        push (@$these_dnafrag_regions, $this_dnafrag_region);
      }
    }

    my $index = 0;
    foreach my $ga_frags (@{$self->param('ga_frag')}) {
	my $first_frag = $ga_frags->[0];
	if ($first_frag->{genome_db_id} == $this_leaf->genome_db_id) {
	    push(@$these_2x_genomes, $index);
	}
	$index++;
    }
    print $this_leaf->name, ": num " . @$these_dnafrag_regions . " " . @$these_2x_genomes . "\n" if $self->debug;

    if (@$these_dnafrag_regions == 1) {
      ## If only 1 has been found...
      print "seq$idx genome_db_id=" . $these_dnafrag_regions->[0]->dnafrag->genome_db_id . "\n" if $self->debug;

      $this_leaf->name("seq".$idx++); #.".".$these_dnafrag_regions->[0]->dnafrag_id);

      push(@$ordered_dnafrag_regions, $these_dnafrag_regions->[0]);

    } elsif (@$these_dnafrag_regions > 1) {
      ## If more than 1 has been found, let Ortheus estimate the Tree
	#need to add on 2x genomes to dnafrag_regions array
	my $dfa = $self->param('dnafrag_regions');
	foreach my $ga_frags (@{$self->param('ga_frag')}) {
	    push @$dfa, $ga_frags;
	}
	$self->param('dnafrag_regions', $dfa);
	return undef;

   } elsif (@$these_2x_genomes == 1) {
	#See what happens...
	#Find 2x genomes
       my $ga_frags = $self->param('ga_frag')->[$these_2x_genomes->[0]];
       print "number of frags " . @$ga_frags . "\n" if $self->debug;

	print "2x seq$idx " . $ga_frags->[0]->{genome_db_id} . "\n" if $self->debug;
	$this_leaf->name("seq".$idx++);
	push(@$ordered_dnafrag_regions, $ga_frags);
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

#
#From each reference genomic_align, find all the pairwise alignments for this
#pairwise_mlss. Store only the pairwise match, NOT the region between blocks
# as the create_span_frag_array does. Return an array
#of ga_fragments for each reference genomic_align
#
sub _create_block_frag_array {
    my ($self, $gab_adaptor, $ref_slice_adaptor, $pairwise_mlss, $ref_dnafrags) = @_;

    my $ga_frag_array;

    my $ga_num_ns = 0;

    #Multiple alignment reference genomic_aligns (maybe more than 1)
    foreach my $ref_dnafrag (@$ref_dnafrags) {
	print "  " . $ref_dnafrag->dnafrag->name . " " . $ref_dnafrag->dnafrag_start . " " . $ref_dnafrag->dnafrag_end . " " . $ref_dnafrag->dnafrag_strand . "\n" if $self->debug;
	
	#find the slice corresponding to the ref_genome
	my $slice = $ref_slice_adaptor->fetch_by_region('toplevel', $ref_dnafrag->dnafrag->name, $ref_dnafrag->dnafrag_start, $ref_dnafrag->dnafrag_end, $ref_dnafrag->dnafrag_strand);

	print "ref_seq " . $slice->start . " " . $slice->end . " " . $slice->strand . " " . substr($slice->seq,0,120) . "\n" if $self->debug;

	#find the pairwise blocks between ref_genome and the 2x genome
	my $pairwise_gabs = $gab_adaptor->fetch_all_by_MethodLinkSpeciesSet_Slice($pairwise_mlss, $slice, undef,undef,1);
	
	#sort by reference_genomic_align start position
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
	    my $gas = $pairwise_gab->get_all_non_reference_genomic_aligns;
	    
	    my $ga = $gas->[0];
	    my $ref_start = $ga->genomic_align_block->reference_genomic_align->dnafrag_start;
	    my $ref_end = $ga->genomic_align_block->reference_genomic_align->dnafrag_end;

	    #need to reverse order of fragments if ref is on reverse strand
	    if ($slice->strand == -1) {
		my $tmp_start = $ref_start;
		$ref_start = $slice->end - $ref_end + $slice->start;
		$ref_end = $slice->end - $tmp_start + $slice->start;
		#print "REVERSE $ref_start $ref_end\n";
	    }

	    my $dnafrag_adaptor = $self->compara_dba->get_DnaFragAdaptor;
	    
	    my $dnafrag_region = new Bio::EnsEMBL::Compara::DnaFragRegion(
			      -dnafrag_id => $ga->dnafrag->dbID,
			      -dnafrag_start => $ga->dnafrag_start,
			      -dnafrag_end => $ga->dnafrag_end,
                              -dnafrag_strand => $ga->dnafrag_strand,
                              -adaptor => $dnafrag_adaptor
		              );
		

	    my $ga_fragment = {dnafrag_region => $dnafrag_region,
			       genome_db => $ga->dnafrag->genome_db,
			       genome_db_id => $ga->dnafrag->genome_db_id,
			       ref_dnafrag => $ref_dnafrag,
			       ref_start => $ref_start,
			       ref_end => $ref_end,
			       ref_slice_start => $slice->start,
			       ref_slice_end => $slice->end};
	    
	    push @$ga_frags, $ga_fragment;
	}
	#add to array of fragments for each reference genomic_align
	push @$ga_frag_array, $ga_frags;
    }
    return $ga_frag_array;
}



#
#From each reference genomic_align, find all the pairwise alignments for this
#pairwise_mlss. Summarise the genomic_aligns in the same group_id by storing 
#the min start and max end and create a new DnaFragRegion. Return an array
#of ga_fragments for each reference genomic_align
#
sub _create_span_frag_array {
    my ($self, $gab_adaptor, $ref_slice_adaptor, $pairwise_mlss, $ref_dnafrags) = @_;

    my $ga_frag_array;

    my $ga_num_ns = 0;

    #Multiple alignment reference genomic_aligns (maybe more than 1)
    foreach my $ref_dnafrag (@$ref_dnafrags) {
	print "  " . $ref_dnafrag->dnafrag->name . " " . $ref_dnafrag->dnafrag_start . " " . $ref_dnafrag->dnafrag_end . " " . $ref_dnafrag->dnafrag_strand . "\n" if $self->debug;
	

	#find the slice corresponding the ref_genome
	my $slice = $ref_slice_adaptor->fetch_by_region('toplevel', $ref_dnafrag->dnafrag->name, $ref_dnafrag->dnafrag_start, $ref_dnafrag->dnafrag_end, $ref_dnafrag->dnafrag_strand);

	print "ref_seq " . $slice->start . " " . $slice->end . " " . $slice->strand . " " . substr($slice->seq,0,120) . "\n" if $self->debug;

	#find the pairwise blocks between ref_genome and the 2x genome
	my $pairwise_gabs = $gab_adaptor->fetch_all_by_MethodLinkSpeciesSet_Slice($pairwise_mlss, $slice, undef,undef,1);
	
	#sort by reference_genomic_align start position
	@$pairwise_gabs = sort {$a->reference_genomic_align->dnafrag_start <=> $b->reference_genomic_align->dnafrag_start} @$pairwise_gabs;


	print "    pairwise gabs " . scalar(@$pairwise_gabs) . "\n" if $self->debug;
	
	#if there are no pairwise matches found to 2x genome, then escape
	#back to loop
	next if (scalar(@$pairwise_gabs) == 0);
	
	my $ga_frags;
	
	#Group together blocks in the same contiguous group and store the left most
	#and right most coords in a slice object
	
	#initialise prev_group_id
	my $prev_group_id = $pairwise_gabs->[0]->group_id;
	my $min_start;
	my $max_end;
	my $dnafrag_name;
	my $genome_db_id;
	my $genome_db;
	my $dnafrag_strand;
	my $prev_ga;
	my $ref_min_start;
	my $ref_max_end;
	my $dnafrag;

	foreach my $pairwise_gab (@$pairwise_gabs) {

	    #should only have 1!
	    my $gas = $pairwise_gab->get_all_non_reference_genomic_aligns;

	    my $ga = $gas->[0];


	    print "    " . $ga->genome_db->name . " " . $ga->dnafrag->name . " " . $ga->dnafrag_start . " " . $ga->dnafrag_end . " " . $ga->dnafrag_strand . " " . $pairwise_gab->group_id . " " . $ga->dnafrag->coord_system_name . " " . $ga->genomic_align_block->reference_genomic_align->dnafrag_start . " " . $ga->genomic_align_block->reference_genomic_align->dnafrag_end . " " . $ga->genomic_align_block->reference_genomic_align->dnafrag_strand . "\n" if $self->debug;
	    
	    my $ga_slice = $ga->get_Slice;

	    $ga_num_ns += $ga_slice->seq =~ tr/N/N/;

	    #need to group all genomic_aligns of the same group together
	    if ($prev_group_id == $pairwise_gab->group_id) {
		if (!defined $min_start || $ga->dnafrag_start < $min_start) {
		    $min_start = $ga->dnafrag_start;

		    #if the ref and non-ref genomic_aligns are on different
		    #strands, need to swap start and end
		    if ($ga->dnafrag_strand == $slice->strand) {
			$ref_min_start = $ga->genomic_align_block->reference_genomic_align->dnafrag_start;
		    } else {
			$ref_max_end = $ga->genomic_align_block->reference_genomic_align->dnafrag_end;
		    }
		} 
		if (!defined $max_end || $ga->dnafrag_end > $max_end) {
		    $max_end = $ga->dnafrag_end;

		    #if the ref and non-ref genomic_aligns are on different
		    #strands, need to swap start and end
		    if ($ga->dnafrag_strand == $slice->strand) {
			$ref_max_end = $ga->genomic_align_block->reference_genomic_align->dnafrag_end;
		    } else { 
			$ref_min_start = $ga->genomic_align_block->reference_genomic_align->dnafrag_start; 
		    }
		} 
	    } else {

		print "ref_min_start $ref_min_start ref_max_end $ref_max_end\n" if ($self->debug);
		#need to reverse order of fragments if ref is on reverse strand
		if ($slice->strand == -1) {
		    $ref_min_start = $slice->end - $ref_min_start + $slice->start;
		    $ref_max_end = $slice->end - $ref_max_end + $slice->start;
		}

		#ensure than ref_start is always smaller than ref_end (can be
		#larger if strand is 0)
		my $ref_start;
		if ($ref_min_start > $ref_max_end) {
		    $ref_start = $ref_max_end;
		    $ref_max_end = $ref_min_start;
		    $ref_min_start = $ref_start;
		}
		
		my $dnafrag_adaptor = $self->compara_dba->get_DnaFragAdaptor;

		my $dnafrag_region = new Bio::EnsEMBL::Compara::DnaFragRegion(
  	               -dnafrag_id => $dnafrag->dbID,
	               -dnafrag_start => $min_start,
                       -dnafrag_end => $max_end,
                       -dnafrag_strand => $dnafrag_strand,
                       -adaptor => $dnafrag_adaptor
		       );
		

		my $ga_fragment = {dnafrag_region => $dnafrag_region,
				   genome_db => $genome_db,
				   genome_db_id => $genome_db_id,
				   ref_dnafrag => $ref_dnafrag,
				   ref_start => $ref_min_start,
				   ref_end => $ref_max_end,
				   ref_slice_start => $slice->start,
				   ref_slice_end => $slice->end};
		
		print "store frag $min_start $max_end " . ($max_end - $min_start) . "\n" if $self->debug;
		print "final seq $ref_min_start $ref_max_end " . substr($dnafrag_region->slice->seq,0,10) . "\n" if $self->debug;
		
		push @$ga_frags, $ga_fragment;
		
		#reinitialise min_start and max_end
		$min_start = $ga->dnafrag_start;
		$ref_min_start = $ga->genomic_align_block->reference_genomic_align->dnafrag_start;
		$max_end = $ga->dnafrag_end;
		$ref_max_end = $ga->genomic_align_block->reference_genomic_align->dnafrag_end;
	    }
	    $dnafrag_name = $ga->dnafrag->name;
	    $genome_db_id = $ga->dnafrag->genome_db_id;
	    $genome_db = $ga->dnafrag->genome_db;
	    $dnafrag = $ga->dnafrag;
		
	    #now get ref slice in correct orientation so this is fine now.
	    $dnafrag_strand = $ga->dnafrag_strand;
	    
	    $prev_group_id = $pairwise_gab->group_id;
	    $prev_ga = $ga;
	}
	#store last frag

	#need to reverse order of fragments if ref is on reverse strand
	if ($slice->strand == -1) {
	    $ref_min_start = $slice->end - $ref_min_start + $slice->start;
	    $ref_max_end = $slice->end - $ref_max_end + $slice->start;
	}

	#ensure than ref_start is always smaller than ref_end (can be
	#larger if strand is -1)
	my $ref_start;
	if ($ref_min_start > $ref_max_end) {
	    $ref_start = $ref_max_end;
	    $ref_max_end = $ref_min_start;
	    $ref_min_start = $ref_start;
	}
	print "store last $min_start $max_end $ref_min_start $ref_max_end \n" if $self->debug;

	my $dnafrag_region = new Bio::EnsEMBL::Compara::DnaFragRegion(
	       -dnafrag_id => $dnafrag->dbID,
	       -dnafrag_start => $min_start,
               -dnafrag_end => $max_end,
               -dnafrag_strand => $dnafrag_strand
	       );

	my $ga_fragment = {dnafrag_region => $dnafrag_region,
			   genome_db => $genome_db,
			   genome_db_id => $genome_db_id,
			   ref_dnafrag => $ref_dnafrag,
			   ref_start => $ref_min_start,
			   ref_end => $ref_max_end,
			   ref_slice_start => $slice->start,
			   ref_slice_end => $slice->end};

	#store last $ga_fragment
	push @$ga_frags, $ga_fragment;

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

#Build a sequence by concatenating all the fragments together and adding
#num_pads between each fragment. If the distance between one fragment and the
#next is less than max_pads, num_pads = distance else num_pads = max_pads.
#Store the number of pads added in the ga_fragment structure as num_pads
#This is the num_pads added to the end of fragment so should be indexed using
#ga_frag->{ref_end}+1. Note that the number of pads added to the beginning is
#currently *not* stored.
sub _build_2x_composite_seq {
    my ($self, $pairwise_dba, $ref_slice_adaptor, $target_slice_adaptor, $ga_frags) = @_;

    my $slice_array;
    my $composite_seq;

    #need to sort on ref_start
    @$ga_frags = sort {$a->{ref_start} <=> $b->{ref_start}} @$ga_frags;

    my $first_frag = $ga_frags->[0];
    my $num_pads;

    my $prev_end;
    my $prev_frag;

    my $dnafrag_adaptor = $pairwise_dba->get_DnaFragAdaptor;

    #work out how many pads to add to the beginning from the reference seq
    $num_pads = $first_frag->{ref_start} - $first_frag->{ref_slice_start};
    #print "slice start " . $first_frag->{ref_slice_start} . " end " . $first_frag->{ref_slice_end} . " num pads $num_pads\n";
    $num_pads = $max_pads if ($num_pads > $max_pads);
    $num_pads = int($num_pads * $max_pads_percent);

    $composite_seq .= $pad_char x $num_pads;

    #store first set of pads in {first_pads}
    $first_frag->{first_pads} = $num_pads;

    #always add $max_pads to the beginning
    #$composite_seq .= $pad_char x $max_pads;
    foreach my $ga_frag (@$ga_frags) {

	my $dnafrag = $dnafrag_adaptor->fetch_by_dbID($ga_frag->{dnafrag_region}->dnafrag_id);

	print "species " . $dnafrag->genome_db->name . " name " . $dnafrag->name . " start " . $ga_frag->{dnafrag_region}->dnafrag_start . " end " . $ga_frag->{dnafrag_region}->dnafrag_end . " len " . ($ga_frag->{dnafrag_region}->dnafrag_end-$ga_frag->{dnafrag_region}->dnafrag_start+1) . " strand " . $ga_frag->{dnafrag_region}->dnafrag_strand . " ref_name " . $ga_frag->{ref_dnafrag}->dnafrag->name . " ref_start " . $ga_frag->{ref_start} . " ref_end " . $ga_frag->{ref_end} . " ref_len " . ($ga_frag->{ref_end}-$ga_frag->{ref_start}+1) . "\n" if $self->debug;
	if (defined($prev_frag)) {

	    print "prev_end " . $prev_frag->{ref_end} . " start " . $ga_frag->{ref_start} . "\n" if $self->debug;

	    #Find the number of bases between fragments
	    $num_pads = $ga_frag->{ref_start} - $prev_frag->{ref_end} - 1;

	    print "before max_pads $num_pads\n" if $self->debug;

	    #Add up to $max_pads between fragments
	    $num_pads = $max_pads if ($num_pads > $max_pads);
	    $num_pads = int($num_pads * $max_pads_percent);

	    print "pads $num_pads\n" if $self->debug;
	    $composite_seq .= $pad_char x $num_pads;

	    #Store number of pads added to the end of previous frag. Use
	    #{ref_end} to identify where the pads have been added
	    $prev_frag->{num_pads} = $num_pads;
	}
	
	my $ref_slice = $ref_slice_adaptor->fetch_by_region('toplevel', $ga_frag->{ref_dnafrag}->dnafrag->name, $ga_frag->{ref_dnafrag}->dnafrag_start, $ga_frag->{ref_dnafrag}->dnafrag_end, $ga_frag->{ref_dnafrag}->dnafrag_strand);
	
	my $slice = $target_slice_adaptor->fetch_by_region('toplevel', $dnafrag->name, $ga_frag->{dnafrag_region}->dnafrag_start, $ga_frag->{dnafrag_region}->dnafrag_end, $ga_frag->{dnafrag_region}->dnafrag_strand);
							   
	my $seq = $slice->get_repeatmasked_seq(undef, 1)->seq;
	if ($seq =~ /[^ACTGactgNnXx]/) {
	    print STDERR $slice->name, " contains at least one non-ACTGactgNnXx character. These have been replaced by N's\n";
	    $seq =~ s/[^ACTGactgNnXx]/N/g;
	}
	$composite_seq .= $seq;

	#store end of previous fragment 
	$prev_frag = $ga_frag;
    }

    my $last_frag = $ga_frags->[-1];

    #work out how many pads to add to the end
    $num_pads = $first_frag->{ref_slice_end} - $last_frag->{ref_end};
    $num_pads = $max_pads if ($num_pads > $max_pads);
    $num_pads = int($num_pads * $max_pads_percent);

    #print "ref slice end " . $first_frag->{ref_slice_end} . " last ele " . $ga_frags->[-1]->{ref_end} . " num pads $num_pads\n";
    $composite_seq .= $pad_char x $num_pads;

    #store last pads
    $last_frag->{num_pads} = $num_pads;

    #always write $max_pads at the end
    #print "last pads $max_pads\n" if $self->debug;

    #$composite_seq .= $pad_char x $max_pads;

    $composite_seq =~ s/(.{80})/$1\n/g;
    chomp $composite_seq;

    #store sequence in first object in ga_frags array
    $first_frag->{seq} = $composite_seq;

    return $composite_seq;
}

sub _dump_2x_fasta {
    my ($self, $ga_frags, $file, $seq_id) = @_;

    #stored concatenated mfa sequence on first frag
    $self->_spurt($file, join("\n",
            ">SeqID" . $seq_id,
            $ga_frags->[0]->{seq},
        ));

    push @{$self->param('fasta_files')}, $file;
    push @{$self->param('species_order')}, $ga_frags->[0]->{genome_db_id};

}

1;
