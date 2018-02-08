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

Bio::EnsEMBL::Compara::RunnableDB::GenomicAlignBlock::Gerp 

=head1 SYNOPSIS

    $gerp->fetch_input();
    $gerp->run();
    $gerp->write_output(); writes to database

=head1 DESCRIPTION

    Given a multiple alignment Bio::EnsEMBL::Compara::DBSQL::GenomicAlignBlock 
    identifier it fetches GenomicAlignBlocks from a compara database and runs
    the program GERP.pl. It then parses the output and writes the constrained
    elements in the constrained_element table and the conserved scores in the 
    conservation_score table

=head1 APPENDIX

The rest of the documentation details each of the object methods. 
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::RunnableDB::GenomicAlignBlock::Gerp;

use strict;
use warnings;
use File::Basename;
use Bio::EnsEMBL::Utils::Exception qw(throw);
use Bio::EnsEMBL::Compara::DnaFragRegion;
use Bio::EnsEMBL::Compara::ConservationScore;
use Bio::EnsEMBL::Compara::Graph::NewickParser;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

#temporary files written to worker_temp_directory
my $ALIGN_FILE = "gerp_alignment.mfa";
my $TREE_FILE = "gerp_tree.nw";

#ending appended to parameter file to allow for calculation of neutral rate
#from the tree file
my $PARAM_FILE_SUFFIX = ".tmp";

my $RATES_FILE_SUFFIX = ".rates";
my $CONS_FILE_SUFFIX = ".elems";


$| = 1;


sub param_defaults {
    return {
	    'program_version' => 2.1,
            #flag as to whether to write out conservation scores to the conservation_score
            #table. Default is to write them out.
            'no_conservation_scores' => 0,
            'tree_string' => undef, #local parameter only
            'tree_file' => undef, #local parameter only
            'depth_threshold'=> undef,  #local parameter only
            'constrained_element_method_link_type' => 'GERP_CONSTRAINED_ELEMENT',   # you shouldn't have to change this
    };
}


=head2 fetch_input

    Title   :   fetch_input
    Usage   :   $self->fetch_input
    Function:   Fetches input data for gerp from the database
    Returns :   none
    Args    :   none

=cut

sub fetch_input {
  my( $self) = @_;

  #create a Compara::DBAdaptor which shares the same DBI handle
  #with $self->db (Hive DBAdaptor)

  my $gaba = $self->compara_dba->get_GenomicAlignBlockAdaptor;
  my $gab = $gaba->fetch_by_dbID($self->param('genomic_align_block_id'));

  my $gas = $gab->get_all_GenomicAligns;

  #only run gerp if there are more than 2 genomic aligns. Gerp requires more
  #than 2 sequences to be represented at a position
  if (scalar(@$gas) > 2) {

      #if skipping species, need to make sure I enough final species 
      my $num_spp = 0; 

      #decide whether to use GenomicAlignTree object or species tree.
      my $mlss = $gab->method_link_species_set;
      $self->param('mlss', $mlss);
      my $method_class = $mlss->method->class;

      my $tree_string;
      if ($method_class =~ /GenomicAlignTree/) {
	  #use GenomicAlignTree 
	  my $gata = $self->compara_dba->get_GenomicAlignTreeAdaptor;
	  my $gat = $gata->fetch_by_GenomicAlignBlock($gab);

	  foreach my $leaf (@{$gat->get_all_leaves}) {
	      my $genomic_align = (sort {$a->dbID <=> $b->dbID} @{$leaf->genomic_align_group->get_all_GenomicAligns})[0];

	      #skip species in species_to_skip array
	      if (defined $self->param('species_to_skip') && @{$self->param('species_to_skip')}) {
		  if (grep {$_ eq $genomic_align->genome_db->dbID} @{$self->param('species_to_skip')}) {
		      $leaf->disavow_parent;
		      $gat = $gat->minimize_tree;
		      next;
		  }
	      }
	      $num_spp++;
	      my $name = "_" . $genomic_align->genome_db->dbID . "_" .
		$genomic_align->dnafrag_id . "_" . $genomic_align->dnafrag_start . "_" . $genomic_align->dnafrag_end . "_";
	      $leaf->name($name);
	  }

	  #check still have enough species
	  #print "NUM SPP $num_spp\n";
	  if ($num_spp < 3) {
              $self->complete_early('Less than 3 species in this block. Cannot run GERP. (have you asked to skip too many species ?)');
	  }
	  $tree_string = $gat->newick_format("simple");
          $tree_string=~s/:0;/;/; # Remove unused node at end

	  $self->param('modified_tree_file', $self->worker_temp_directory . "/" . $TREE_FILE);

          $self->_spurt($self->param('modified_tree_file'), $tree_string);

          #write out multiple alignment as a mfa file.
          $self->_writeMultiFastaAlignment($gat);
      } else {
          #use species tree

          #write out modified tree depending on sequences represented in this
          #genomic align block (based on Javier's _update_tree in Pecan.pm)
          $tree_string = $self->_build_tree_string($gas);

          #write out multiple alignment as a mfa file.
          $self->_writeMultiFastaAlignment($gab);
      }

      #if param_file defined, assume use GERP.pl else assume use gerpcol
      if ($self->param('program_version') == 1 && (defined $self->param('param_file'))) {
	  #calculate neutral rate if not given in the parameter file
	  open (PARAM_FILE, $self->param('param_file')) || throw "Could not open file " . $self->param('param_file');
	  my $neutral_rate;
	  while (<PARAM_FILE>) {
	      chomp;
	      
	      my ($flag,$value) = split /\s+/,$_;
	      if ($flag eq "neutral_rate") {
		  $neutral_rate = $value;
	      }
	  }
	  close(PARAM_FILE);

	  #copy param file into temporary param file in worker directory
	  my ($filename) = fileparse($self->param('param_file'));

	  $self->param('param_file_tmp', $self->worker_temp_directory . "/" . $filename . $PARAM_FILE_SUFFIX);
	  my $cp_cmd = "cp " . $self->param('param_file') . " " . $self->param('param_file_tmp');
	  unless (system ($cp_cmd) == 0) {
	      throw("error copying " . $self->param('param_file') . " to " . $self->param('param_file_tmp') . "\n");
	  }

	  #if param file doesn't have neutral rate, then append the calculated one
	  if (!defined $neutral_rate) {
	      $neutral_rate = _calculateNeutralRate($tree_string);
	      $self->_spurt($self->param('param_file_tmp'), "neutral_rate\t$neutral_rate\n", 'append');
	  }
      }
  } else {
      $self->complete_early('Less than 3 sequences aligned in this block. Cannot run GERP');
  }
  return 1;
}

=head2 run

    Title   :   run
    Usage   :   $self->run
    Function:   Run gerp
    Returns :   none
    Args    :   none

=cut

sub run {
    my $self = shift;

    $self->compara_dba->dbc->disconnect_if_idle();
    if ($self->param('program_version') == 1) { 
	$self->run_gerp;
    } elsif ($self->param('program_version') == 2.1) { 
	$self->run_gerp_v2;
    } else {
	throw("Invalid version number. Valid values are 1 or 2 or 2.1\n");
    }
}

=head2 write_output

    Title   :   write_output
    Usage   :   $self->write_output
    Function:   Write results to the database
    Returns :   1
    Args    :   none

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
  
    print STDERR "Write Output\n";

    #parse results and store constraints and conserved elements in database
    if ($self->param('program_version') == 1) {
	$self->_parse_results;
    } elsif ($self->param('program_version') == 2.1) {
	$self->_parse_results_v2;
    } else {
	throw("Invalid version number. Valid values are 1 or 2.1\n");
    }

    return 1;
}

#Calculate the neutral rate of a tree by summing all the branch lengths.
#Returns the neutral rate
sub _calculateNeutralRate {
    my ($tree_string) = @_;

    my @num_list = ($tree_string =~ /:(\d*.\d*)/g);
    my $neutral_rate = 0;
    foreach my $num (@num_list) {
	$neutral_rate += $num;
    }

    return $neutral_rate;
}

#write out multiple alignment in mfa format to $self->worker_temp_directory
sub _writeMultiFastaAlignment {
    my $self = shift;
    my $object = shift;

    #write out the alignment file
    $self->param('mfa_file', $self->worker_temp_directory . "/" . $ALIGN_FILE);
    open (ALIGN, ">" . $self->param('mfa_file') ) or throw "error writing alignment (" . $self->param('mfa_file') . ") file\n";    

    
    #create mfa file of multiple alignment from genomic align block

    # Preload everything needed from Compara so that we can disconnect
    # before moving on to the core databases
    my $segments;
    if (UNIVERSAL::isa($object, "Bio::EnsEMBL::Compara::GenomicAlignTree")) {
      $segments = $object->get_all_leaves;
      $_->genomic_align_group->dnafrag->genome_db for @$segments;
    } elsif (UNIVERSAL::isa($object, "Bio::EnsEMBL::Compara::GenomicAlignBlock")) {
      $segments = $object->get_all_GenomicAligns;
      $_->dnafrag->genome_db for @$segments;
    }

    # Disconnecting
    $self->compara_dba->dbc->disconnect_if_idle();

    $self->iterate_by_dbc($segments,
        sub { my $this_segment = shift; return ($this_segment->isa('Bio::EnsEMBL::Compara::GenomicAlignTree') ? $this_segment->genomic_align_group : $this_segment)->genome_db->db_adaptor->dbc },
        sub { my $this_segment = shift;

        #my $seq_name = $genomic_align->dnafrag->genome_db->name;
        #$seq_name =~ s/(\w*) (\w*)/$1_$2/;

        #add _ to either side of genome_db id to make GERP like it
        # Note: the name of the sequence must match the name of the
        # corresponding leaf in the tree!
        my $seq_name;
        if (UNIVERSAL::isa($this_segment, "Bio::EnsEMBL::Compara::GenomicAlignTree")) {
          $seq_name = $this_segment->name;
        } else {
          $seq_name = _get_name_from_GenomicAlign($this_segment);
        }

        my $aligned_sequence = $this_segment->aligned_sequence;
        $aligned_sequence =~ s/(.{80})/$1\n/g;
        $aligned_sequence =~ s/\./\-/g;
        chomp($aligned_sequence);
        print ALIGN ">$seq_name\n$aligned_sequence\n";
	free_aligned_sequence($this_segment);

    } );

    close ALIGN;
}

sub free_aligned_sequence {
    my ($node) = @_;

    if (UNIVERSAL::isa($node, "Bio::EnsEMBL::Compara::GenomicAlignTree")) {
	my $genomic_align_group = $node->genomic_align_group;
	foreach my $this_genomic_align (@{$genomic_align_group->get_all_GenomicAligns}) {
	    undef($this_genomic_align->{'aligned_sequence'});
	}
    } else {
	undef($node->{'aligned_sequence'});
    }
}


#run gerp version 1
sub run_gerp {
    my $self = shift;

    #change directory to where the temporary mfa and tree file are written
    chdir $self->worker_temp_directory;

    my $command = $self->require_executable('gerp_exe');

    if ($self->param('param_file')) {
	$command .= " " . $self->param('param_file_tmp');
    }
    #run gerp with parameter file
    $self->run_command($command, { die_on_failure => 1 });
}

#run gerp version 2.1
sub run_gerp_v2 {
    my ($self) = @_;
    my $gerpcol_path;
    my $gerpelem_path;
    my $default_depth_threshold = 0.5;

    #change directory to where the temporary mfa and tree file are written
    chdir $self->worker_temp_directory;
    
    $gerpcol_path = $self->param('gerp_exe_dir') . "/gerpcol"; 
    $gerpelem_path = $self->param('gerp_exe_dir') . "/gerpelem"; 

    throw($gerpcol_path . " is not executable Gerp::run ")
      unless ($gerpcol_path && -x $gerpcol_path);

    throw($gerpelem_path . " is not executable Gerp::run ")
      unless ($gerpelem_path && -x $gerpelem_path);

    #run gerpcol
    my $command = $gerpcol_path;
    $command .= " -t " . $self->param('modified_tree_file') . " -f " . $self->param('mfa_file');
    $self->run_command($command, { die_on_failure => 1 });

    #run gerpelem
    $command = $gerpelem_path;

    $command .= " -f " . $self->param('mfa_file').$RATES_FILE_SUFFIX;
    # hack for birds
    # check the database name too because the mlss doesn't have the right name at the moment
    $command .= " -d 0.35" if ($self->param('mlss')->name =~ /(sauropsid|bird)/i) || ($self->dbc && ($self->dbc->dbname =~ /(sauropsid|bird)/i));

    #Calculate the neutral_rate of the species tree for use for those alignments where the default 
    #depth_threshold is too high to call any constrained elements (eg 3way birds)
    my $species_tree = $self->compara_dba->get_SpeciesTreeAdaptor->fetch_by_method_link_species_set_id_label($self->param_required('mlss_id'), 'default');
    my $species_tree_string = $species_tree->root->newick_format('simple');
    $self->compara_dba->dbc->disconnect_if_idle();
    $species_tree_string =~ s/:0;$//;
    my $neutral_rate = _calculateNeutralRate($species_tree_string);

    if (!defined $self->param('depth_threshold') && $neutral_rate < $default_depth_threshold) {
        $self->param('depth_threshold', $neutral_rate);
        print STDERR "Setting depth_threshold to neutral_rate value of $neutral_rate\n";
    }

    if (defined $self->param('depth_threshold')) {
        $command .= " -d " . $self->param('depth_threshold');
    }
    my $cmd_status = $self->run_command($command, { die_on_failure => 1 });
    if ($cmd_status->exit_code) {
        if ($cmd_status->err =~ /The matrix is too big .* and is causing an integer overflow. Aborting/) {
            $self->input_job->autoflow(0);
            $self->complete_early("Cannot run GERP (integer overflow). Discarding this family");
        }
        die "GERP failed:".$cmd_status->err;
    }
}

#Parse results for Gerp version 1
#parse the param file to find the values required to determine what GERP
#called the rates and constrained elements
sub _parse_results {
  my ($self) = @_;

  my $alignment_file;

  #default values as defined in GERP.pl
  my $rej_subs_min = 8.5;
  my $merge_distance = 1;

  #read in options from param file which GERP uses to generate it's output
  #file names.
  open (PARAM_FILE, $self->param('param_file')) || throw "Could not open file " . $self->param('param_file');

  while (<PARAM_FILE>) {
      chomp;
      
      my ($flag,$value) = split /\s+/,$_;
      if ($flag eq "alignment") {
	  $alignment_file = $self->worker_temp_directory . "/" . $value;
      }
      if ($flag eq "rej_subs_min") {
	  $rej_subs_min = $value;
      }
      if ($flag eq "merge_distance") {
	  $merge_distance = $value;
      }
  }
  close (PARAM_FILE);
  
  #generate rates and constraints file names
  my $rates_file = "$alignment_file.rates";  
  my $cons_file = "$rates_file\_RS$rej_subs_min\_md$merge_distance\_cons.txt";
 
  $self->_parse_cons_file($cons_file, 1);
  $self->_parse_rates_file($rates_file, 1);

}

#Parse results for Gerp version 2.1
sub _parse_results_v2 {
  my ($self,) = @_;

  #generate rates and constraints file names
  unless (defined $self->param('no_conservation_scores') && $self->param('no_conservation_scores')) {
      $self->_parse_rates_file($self->param('mfa_file').$RATES_FILE_SUFFIX, 2);
  }
  $self->_parse_cons_file($self->param('mfa_file').$RATES_FILE_SUFFIX.$CONS_FILE_SUFFIX, 2);
}


#This method parses the gerp constraints file and stores the values as 
#constrained_elements
#cons_file : full filename of constraints file
#example : $self->_parse_cons_file(/tmp/worker.2580193/gerp_alignment.mfa.rates_RS8.5_md6_cons.txt);
sub _parse_cons_file {
    my ($self, $cons_file, $version) = @_;

    my $gaba = $self->compara_dba->get_GenomicAlignBlockAdaptor;
    my $gab = $gaba->fetch_by_dbID($self->param('genomic_align_block_id'));

    my $mlssa = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor;

    my $species_set;
    if (!defined $self->param('species_set')) {
	foreach my $gdb (@{$gab->method_link_species_set->species_set->genome_dbs}) {
	    push @$species_set, $gdb->dbID;
	}
    } else {
	$species_set = $self->param('species_set');
    }

    # Fetch the MLSS with the request method_link_type
    my $mlss = $mlssa->fetch_by_method_link_type_genome_db_ids($self->param('constrained_element_method_link_type'), $species_set);
    unless ($mlss) {
	throw("Invalid method_link_species_set\n");
    }

    my $constrained_element_adaptor = $self->compara_dba->get_ConstrainedElementAdaptor;
    unless ($constrained_element_adaptor) {
	throw("could not get a constrained_element_adaptor\n");
    }

    open CONS, $cons_file || throw("Could not open $cons_file");
    my @constrained_elements;
    while (<CONS>) {
	unless (/^#/) {
                chomp;
                #extract info from constraints file
                my ($start, $end, $length, $rej_subs, $p_value);
                ($start, $end, $length, $rej_subs, $p_value) = split /\s/,$_;
                #create new genomic align blocks by converting alignment 
                #coords to chromosome coords
                my $constrained_gab = $gab->restrict_between_alignment_positions($start, $end, "skip");
                my $constrained_element_block;
                my ($taxonomic_level) = join(" ", $mlss->name=~/\b[a-z]+\b/g); #feeble hack to get the taxonomic level
		foreach my $genomic_align (@{$constrained_gab->get_all_GenomicAligns}) {
         	       my $constrained_element =  new Bio::EnsEMBL::Compara::ConstrainedElement(
                	        -reference_dnafrag_id => $genomic_align->dnafrag_id,
				-start => $genomic_align->dnafrag_start,
				-end => $genomic_align->dnafrag_end,
				-strand => $genomic_align->dnafrag_strand,
                        	-score => $rej_subs,
                        	-p_value => $p_value,
                        	-method_link_species_set => $mlss->dbID,
                        	-taxonomic_level => $taxonomic_level,
                	);
                	push(@$constrained_element_block, $constrained_element);
		}
		push(@constrained_elements, $constrained_element_block);
        }
    }
    close(CONS);
    #store in constrained_element table
    $constrained_element_adaptor->store($mlss, \@constrained_elements);	
}


#This method parses the gerp rates file and stores the multiple alignment 
#genomic align block id, window size, position, expected scores 
#and difference (expected-observed) scores in the conservation_score table
#rates_file : full filename of rates file
#example    : $self->_parse_rates_file(/tmp/worker.2580193/gerp_alignment.mfa.rates);
sub _parse_rates_file {
    my ($self, $rates_file, $version) = @_;
    my %win_cnt;
    my $win_sizes = $self->param('window_sizes');

    my $j;
    
    my $obs_no_score = -1.0; #uncalled observed score
    my $exp_no_score = 0.0;  #uncalled expected score
    my $diff_no_score = 0.0; 

    my $bucket;

    my $gaba = $self->compara_dba->get_GenomicAlignBlockAdaptor;
    my $gab = $gaba->fetch_by_dbID($self->param('genomic_align_block_id'));
    my $cs_adaptor = $self->compara_dba->get_ConservationScoreAdaptor;

    #create and initialise bucket structure for each window size
    for ($j = 0; $j < scalar(@$win_sizes); $j++) {
	$bucket->{$win_sizes->[$j]} = {called => 0,     #no. called bases in block
				       win_called => 0, #no. called bases in window
				       cnt => 0,        #no. bases in block
				       exp => 0,        #current expected score
				       exp_scores => "",#expected score string
				       diff => 0,       #current diff score
				       diff_scores => "",#diff score string
				       delete_cnt => 0, #no. uncalled bases
				       pos => 0,        #current alignment position
				       start_pos => 1}; #alignment position of this block
    }

#length of uncalled region to allow neighboring called regions to be joined
#doesn't want to be too big because I need to store these uncalled values.
    my $merge_dist = 10;

#maximum called length before cut into smaller parts
    my $max_called_dist = 1000;

    #read in rates file
    open (RATES,$rates_file) or throw "Could not open rates ($rates_file) file\n";

    while (<RATES>) {
	if (/^#/) {
	    next;
	}
	chomp;
	my ($obs, $exp, $diff);
	if ($version == 1) {
	    ($obs, $exp) = split/\t/,$_;
	    if ($obs == $obs_no_score) {
		$diff = $diff_no_score;
	    } else {
		$diff = $exp - $obs;
	    }
	} elsif ($version == 2) {
	    ($exp, $diff) = split/\t/,$_;
	} else {
	    print STDERR "Invalid version, must be 1 or 2\n";
	    return;
	}
	
	for ($j = 0; $j < scalar(@$win_sizes); $j++) {
	    
	    #store called obs, exp and diff in each win_size bucket and keep a count of these with win_called
	    #if ($diff != $diff_no_score) {
	    if (($version == 1 && $obs != $obs_no_score) ||
		($version == 2 && $exp != $exp_no_score)) {
		$bucket->{$win_sizes->[$j]}->{exp} += $exp;
		$bucket->{$win_sizes->[$j]}->{diff} += $diff;
		$bucket->{$win_sizes->[$j]}->{win_called}++;
	    }
	    #total count for this bucket
	    $bucket->{$win_sizes->[$j]}->{win_cnt}++;
	    
	    #increment alignment position
	    $bucket->{$win_sizes->[$j]}->{pos}++;
	    
	    #if the bucket is full....
	    if ($bucket->{$win_sizes->[$j]}->{win_cnt} == $win_sizes->[$j]) {
		
		#re-initialise win_cnt
		$bucket->{$win_sizes->[$j]}->{win_cnt} = 0;
		
		#FOUND CALLED SCORE
		#if ($bucket->{$win_sizes->[$j]}->{diff} != $diff_no_score) {

		#Use the fact that win_called keeps count of how many called
		#scores I have. If win_called is 0, no called scores have 
		#been found
		if ($bucket->{$win_sizes->[$j]}->{win_called} > 0) {
		    #count how many called bases in this block
		    $bucket->{$win_sizes->[$j]}->{called}++;
		    
		    #if found delete_cnt uncalled bases which is less 
		    #than merge_dist then add these to the 
		    #relevant score string. If this makes the score 
		    #string bigger than max_called_dist, then
		    #store the object in the database
		    if ($bucket->{$win_sizes->[$j]}->{delete_cnt} > 0 && 
			$bucket->{$win_sizes->[$j]}->{delete_cnt} <= $merge_dist) {
			#add uncalled values to span merge_dist
			for (my $i=0; $i < $bucket->{$win_sizes->[$j]}->{delete_cnt}; $i++) {
			    $bucket->{$win_sizes->[$j]}->{cnt}++;
			    $bucket->{$win_sizes->[$j]}->{exp_scores} .= "$exp_no_score ";
			    $bucket->{$win_sizes->[$j]}->{diff_scores} .= "$diff_no_score ";
			    
			    #store in database
			    if ($bucket->{$win_sizes->[$j]}->{cnt} == $max_called_dist) {
				my $conservation_score =  new Bio::EnsEMBL::Compara::ConservationScore(											       -genomic_align_block => $gab, -window_size => $win_sizes->[$j], -position => $bucket->{$win_sizes->[$j]}->{start_pos}, -expected_score => $bucket->{$win_sizes->[$j]}->{exp_scores}, -diff_score => $bucket->{$win_sizes->[$j]}->{diff_scores});
				
				$cs_adaptor->store($conservation_score);  
				#reset bucket values
				$bucket->{$win_sizes->[$j]}->{cnt} = 0;
				$bucket->{$win_sizes->[$j]}->{called} = 0;
				$bucket->{$win_sizes->[$j]}->{exp_scores} = "";
				$bucket->{$win_sizes->[$j]}->{diff_scores} = "";
				$bucket->{$win_sizes->[$j]}->{start_pos} += $max_called_dist;
			    }
			}
		    }
		    #first time found called score so save current pos 
		    #as start_pos for this block
		    if ($bucket->{$win_sizes->[$j]}->{called} == 1) {
			
			#12.04.07 kfb fixed bug which occurs when the 
			#1000th score is in a region of 10 or less 
			#uncalled bases because the next start_pos was
			#set to be the next called position instead of 
			#the next (uncalled) position. 
			#$bucket->{$win_sizes->[$j]}->{start_pos} = $bucket->{$win_sizes->[$j]}->{pos};
			
			$bucket->{$win_sizes->[$j]}->{start_pos} = $bucket->{$win_sizes->[$j]}->{pos} - ($bucket->{$win_sizes->[$j]}->{cnt} * $win_sizes->[$j]);
		    }
		    
		    #average over the number of called scores in a 
		    #window and append to score string
		    #$bucket->{$win_sizes->[$j]}->{exp_scores} .= ($bucket->{$win_sizes->[$j]}->{exp}/$bucket->{$win_sizes->[$j]}->{win_called}) . " ";
		    #$bucket->{$win_sizes->[$j]}->{diff_scores} .= ($bucket->{$win_sizes->[$j]}->{diff}/$bucket->{$win_sizes->[$j]}->{win_called}) . " "; 
		    $bucket->{$win_sizes->[$j]}->{exp_scores} .= ($bucket->{$win_sizes->[$j]}->{exp}/$win_sizes->[$j]) . " ";
		    $bucket->{$win_sizes->[$j]}->{diff_scores} .= ($bucket->{$win_sizes->[$j]}->{diff}/$win_sizes->[$j]) . " ";
		    
		    #increment counter of total called scores in this 
		    #block
		    $bucket->{$win_sizes->[$j]}->{cnt}++;
		    #if have max_called_dist scores in the score 
		    #string, then store them in the database
		    if ($bucket->{$win_sizes->[$j]}->{cnt} == $max_called_dist) {
			my $conservation_score =  new Bio::EnsEMBL::Compara::ConservationScore(											       -genomic_align_block => $gab, -window_size => $win_sizes->[$j], -position => $bucket->{$win_sizes->[$j]}->{start_pos}, -expected_score => $bucket->{$win_sizes->[$j]}->{exp_scores}, -diff_score => $bucket->{$win_sizes->[$j]}->{diff_scores});
			
			$cs_adaptor->store($conservation_score);  
			
			#reinitialise bucket values
			$bucket->{$win_sizes->[$j]}->{cnt} = 0;
			$bucket->{$win_sizes->[$j]}->{called} = 0;
			$bucket->{$win_sizes->[$j]}->{exp_scores} = "";
			$bucket->{$win_sizes->[$j]}->{diff_scores} = "";
			$bucket->{$win_sizes->[$j]}->{start_pos} += $max_called_dist;
		    }
		    
		    #reset count for uncalled bases
		    $bucket->{$win_sizes->[$j]}->{delete_cnt} = 0;
		} else {
		    #FOUND UNCALLED SCORE
		    #count how many uncalled bases in this block
		    $bucket->{$win_sizes->[$j]}->{delete_cnt}++;
		    
		    #add previous called values to the database
		    if ($bucket->{$win_sizes->[$j]}->{called} > 0 && $bucket->{$win_sizes->[$j]}->{delete_cnt} > $merge_dist) {
			
			my $conservation_score =  new Bio::EnsEMBL::Compara::ConservationScore(											       -genomic_align_block => $gab, -window_size => $win_sizes->[$j], -position => $bucket->{$win_sizes->[$j]}->{start_pos}, -expected_score => $bucket->{$win_sizes->[$j]}->{exp_scores}, -diff_score => $bucket->{$win_sizes->[$j]}->{diff_scores});				
			
			$cs_adaptor->store($conservation_score);  
			
			$bucket->{$win_sizes->[$j]}->{cnt} = 0;
			$bucket->{$win_sizes->[$j]}->{called} = 0;
			$bucket->{$win_sizes->[$j]}->{exp_scores} = "";
			$bucket->{$win_sizes->[$j]}->{diff_scores} = "";
		    }
		}
		$bucket->{$win_sizes->[$j]}->{exp} = 0;
		$bucket->{$win_sizes->[$j]}->{diff} = 0;
		$bucket->{$win_sizes->[$j]}->{win_called} = 0;
	    }
	}
    }

    #store last lot
    for ($j = 0; $j < scalar(@$win_sizes); $j++) {
	if ($bucket->{$win_sizes->[$j]}->{delete_cnt} >= 0 && 
	    $bucket->{$win_sizes->[$j]}->{delete_cnt} <= $merge_dist) {
	    my $conservation_score =  new Bio::EnsEMBL::Compara::ConservationScore(
          -genomic_align_block => $gab, 
          -window_size => $win_sizes->[$j], 
          -position => $bucket->{$win_sizes->[$j]}->{start_pos}, 
          -expected_score => $bucket->{$win_sizes->[$j]}->{exp_scores}, 
          -diff_score => $bucket->{$win_sizes->[$j]}->{diff_scores}
      );				
	    $cs_adaptor->store($conservation_score);  
	}
    }
}


#  Arg [1]    : array reference of genomic_aligns
#  Example    : $self->_build_tree_string();
#  Description: This method sets the tree_string using the original
#               species tree and the set of GenomicAligns. The
#               tree is edited by the _update_tree method  
#               (see _update_tree elsewhere in this document)
#  Returntype : -none-
#  Exception  : 
#  Warning    :

sub _build_tree_string {
    my ($self, $genomic_aligns) = @_;

    my $db_tree = $self->compara_dba->get_SpeciesTreeAdaptor->fetch_by_method_link_species_set_id_label($self->param_required('mlss_id'), 'default')->root;
    my $tree = $db_tree->copy();

    #if the tree leaves are species names, need to convert these into genome_db_ids
    my $genome_dbs = $self->compara_dba->get_GenomeDBAdaptor->fetch_all();
    
    my %leaf_check;
    foreach my $genome_db (@$genome_dbs) {
        if ($genome_db->name ne "ancestral_sequences") {
	    $leaf_check{$genome_db->dbID} = 2;
	} 
    }

    if ( $self->debug ) {
      use Data::Dumper;
      print Dumper \%leaf_check;
      $tree->print_tree(100);
    }

    foreach my $leaf (@{$tree->get_all_leaves}) {
        $leaf_check{$leaf->genome_db_id}++;
    }

    #Check have one instance in the tree of each genome_db in the database
    #Don't worry about having extra elements in the tree that aren't in the
    #genome_db table because these will be removed later
    foreach my $name (keys %leaf_check) {
	if ($leaf_check{$name} == 2) {
	    throw("Unable to find genome_db_id $name in tree\n");
	}
    }
    
    $tree = $self->_update_tree($tree, $genomic_aligns);
    
    my $tree_string = $tree->newick_format('simple');

    # Remove quotes around node labels
    $tree_string =~ s/"(_\d+_)"/$1/g;
    $tree_string=~s/:0;/;/; # Remove unused node at end
    # $tree->release_tree;
 
    $self->param('modified_tree_file', $self->worker_temp_directory . "/" . $TREE_FILE);

    $self->_spurt($self->param('modified_tree_file'), $tree_string);

    return $tree_string;
}

#  Arg [1]    : Bio::EnsEMBL::Compara::NestedSet $tree_root
#  Example    : $self->_update_nodes_names($tree);
#  Description: This method updates the tree by removing or
#               duplicating the leaves according to the original
#               tree and the set of GenomicAligns. The tree nodes
#               will be renamed ..... 
#  Returntype : Bio::EnsEMBL::Compara::NestedSet (a tree)
#  Exception  :
#  Warning    :
sub _update_tree {
    my $self = shift;
    my $tree = shift;
    my $all_genomic_aligns = shift;

    my $idx = 1;
    foreach my $this_leaf (@{$tree->get_all_leaves}) {
	my $these_genomic_aligns = [];
	## Look for GenomicAligns belonging to this genome_db_id
	foreach my $this_genomic_align (@$all_genomic_aligns) {
	    if ($this_genomic_align->dnafrag->genome_db_id == $this_leaf->genome_db_id) {
		push (@$these_genomic_aligns, $this_genomic_align);
	    }
	}

	if (@$these_genomic_aligns == 1) {
	    ## If only 1 has been found...
	    $this_leaf->name(_get_name_from_GenomicAlign($these_genomic_aligns->[0]));
	} elsif (@$these_genomic_aligns > 1) {
	    ## If more than 1 has been found, create as many bifurcations as needed
	    for (my $i=0; $i<@$these_genomic_aligns-1; $i++) {
	      my $new_node = new Bio::EnsEMBL::Compara::NestedSet;
	      $new_node->name(_get_name_from_GenomicAlign($these_genomic_aligns->[$i]));
	      $new_node->distance_to_parent(0);
	      $this_leaf->add_child($new_node);
	      my $new_internal_node = new Bio::EnsEMBL::Compara::NestedSet;
	      $new_internal_node->distance_to_parent(0);
	      $this_leaf->add_child($new_internal_node);
	      $this_leaf = $new_internal_node;
	    }
	    $this_leaf->name(_get_name_from_GenomicAlign($these_genomic_aligns->[-1]));
	    
	} else {
	    ## If none has been found...
	    $this_leaf->disavow_parent;
	    $tree = $tree->minimize_tree;
	}
    }
    
    if ($tree->get_child_count == 1) {
	my $child = $tree->children->[0];
	$child->parent->merge_children($child);
	$child->disavow_parent;
    }
    
    ## Gerp wants unrooted trees. Takes one of the two children and attach the other one to it
    if ($tree->get_child_count() == 2 and scalar(@{$tree->get_all_leaves()}) >= 3) {
      my $distance = $tree->children->[0]->distance_to_parent +
          $tree->children->[1]->distance_to_parent;
      my $new_root;
      my $new_child;
      if ($tree->children->[0]->get_child_count >= 2) {
        $new_root = $tree->children->[0];
        $new_child = $tree->children->[1];
      } else {
        $new_root = $tree->children->[1];
        $new_child = $tree->children->[0];
      }
      $new_root->disavow_parent();
      $new_child->disavow_parent;
      $new_child->distance_to_parent($distance);
      $new_root->add_child($new_child);
      $tree = $new_root;
    }
    return $tree;
}


#  Arg [1]    : Bio::EnsEMBL::Compara::GenomicAlign
#  Example    : _get_name_from_GenomicAlign($genomic_align);
#  Description:
#  Returntype : string $name
#  Exception  :
#  Warning    :

sub _get_name_from_GenomicAlign {
  my ($genomic_align) = @_;

  my $name = "_" . $genomic_align->dnafrag->genome_db->dbID . "_" .
    $genomic_align->dnafrag_id . "_" .
    $genomic_align->dnafrag_start . "_" .
    $genomic_align->dnafrag_end . "_";

  return $name;
}


1;
