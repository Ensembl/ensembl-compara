#
# Ensembl module for Bio::EnsEMBL::Compara::Production::GenomicAlignBlock::Gerp
#
# Cared for by Kathryn Beal <kbeal@ebi.ac.uk>
#
# Copyright Ewan Birney
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code
=head1 NAME

Bio::EnsEMBL::Compara::Production::GenomicAlignBlock::Gerp 

=head1 SYNOPSIS

    $gerp->fetch_input();
    $gerp->run();
    $gerp->write_output(); writes to database

=head1 DESCRIPTION

    Given a mulitple alignment Bio::EnsEMBL::Compara::DBSQL::GenomicAlignBlock 
    identifier it fetches GenomicAlignBlocks from a compara database and runs
    the program GERP.pl. It then parses the output and writes the constrained
    elements in the GenomicAlignBlock table and the conserved scores in the 
    ConservationScore table

=head1 AUTHOR - Kathryn Beal

This modules is part of the Ensembl project http://www.ensembl.org

Email kbeal@ebi.ac.uk

=head1 CONTACT

This modules is part of the EnsEMBL project (http://www.ensembl.org)

Questions can be posted to the ensembl-dev mailing list:
ensembl-dev@ebi.ac.uk


=head1 APPENDIX

The rest of the documentation details each of the object methods. 
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::Production::GenomicAlignBlock::Gerp;

use strict;
use File::Basename;

use Bio::EnsEMBL::Compara::DnaFragRegion;
use Bio::EnsEMBL::Compara::Production::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Utils::Exception;
use Bio::SimpleAlign;
use Bio::AlignIO;
use Bio::LocatableSeq;
use Bio::EnsEMBL::Compara::ConservationScore;
use Bio::EnsEMBL::Compara::Graph::NewickParser;

use Bio::EnsEMBL::Hive::Process;
our @ISA = qw(Bio::EnsEMBL::Hive::Process);

#location of gerp version 1
my %BIN_DIR;
$BIN_DIR{"1"} = "/software/ensembl/compara/gerp/GERP_03292006";

#location of gerp version 2.1
$BIN_DIR{"2.1"} = "/software/ensembl/compara/gerp/GERPv2.1";

#default program_version
my $program_version = 2.1;

#temporary files written to worker_temp_directory
my $ALIGN_FILE = "gerp_alignment.mfa";
my $TREE_FILE = "gerp_tree.nw";

#ending appended to parameter file to allow for calculation of neutral rate
#from the tree file
my $PARAM_FILE_SUFFIX = ".tmp";

my $RATES_FILE_SUFFIX = ".rates";
my $CONS_FILE_SUFFIX = ".elems";


$| = 1;


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
  $self->{'comparaDBA'} = Bio::EnsEMBL::Compara::Production::DBSQL::DBAdaptor->new(-DBCONN=>$self->db->dbc);
  $self->{'comparaDBA'}->dbc->disconnect_when_inactive(0);

  #read from analysis table
  $self->get_params($self->parameters); 

  #read from analysis_job table
  $self->get_params($self->input_id);

  unless (defined $self->program_version) {
      if (defined($self->analysis) and defined($self->analysis->program_version)) {
	  $self->program_version($self->analysis->program_version);
      } else {
	  $self->program_version($program_version);
      }
  }

  my $gaba = $self->{'comparaDBA'}->get_GenomicAlignBlockAdaptor;
  my $gab = $gaba->fetch_by_dbID($self->genomic_align_block_id);

  my $gas = $gab->get_all_GenomicAligns;

  #print "NUM GAS " . scalar(@$gas) . "\n";

  #only run gerp if there are more than 2 genomic aligns. Gerp requires more
  #than 2 sequences to be represented at a position
  if (scalar(@$gas) > 2) {

      #decide whether to use GenomicAlignTree object or species tree.
      my $mlss = $gab->method_link_species_set;
      my $method_link_class = $mlss->method_link_class;

      my $tree_string;
      if ($method_link_class eq "GenomicAlignTree.tree_alignment") {
	  #use GenomicAlignTree 
	  my $gata = $self->{'comparaDBA'}->get_GenomicAlignTreeAdaptor;
	  my $gat = $gata->fetch_by_GenomicAlignBlock($gab);
	  foreach my $leaf (@{$gat->get_all_leaves}) {
	      my $genomic_align = (sort {$a->dbID <=> $b->dbID} @{$leaf->genomic_align_group->get_all_GenomicAligns})[0];
	      my $name = "_" . $genomic_align->genome_db->dbID . "_" .
		$genomic_align->dnafrag_id . "_" . $genomic_align->dnafrag_start . "_" . $genomic_align->dnafrag_end . "_";
	      $leaf->name($name);
	  }
	  $tree_string = $gat->newick_simple_format();

	  $self->{'modified_tree_file'} = $self->worker_temp_directory . $TREE_FILE;

          open (TREE, ">$self->{'modified_tree_file'}") or throw "error writing alignment ($self->{'modified_tree_file'}) file\n";
          print TREE $tree_string;
          close TREE;

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
      if ($self->program_version == 1 && (defined $self->param_file)) {
	  #calculate neutral rate if not given in the parameter file
	  open (PARAM_FILE, $self->param_file) || throw "Could not open file " . $self->param_file;
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
	  my ($filename) = fileparse($self->param_file);

	  $self->param_file_tmp($self->worker_temp_directory . $filename . $PARAM_FILE_SUFFIX);
	  my $cp_cmd = "cp " . $self->param_file . " " . $self->param_file_tmp;
	  unless (system ($cp_cmd) == 0) {
	      throw("error copying " . $self->param_file . " to " . $self->param_file_tmp . "\n");
	  }

	  #if param file doesn't have neutral rate, then append the calculated one
	  if (!defined $neutral_rate) {
	      $neutral_rate = _calculateNeutralRate($tree_string);
	      open (PARAM_FILE_TMP, ">>".$self->param_file_tmp) || throw "Could not open file " . $self->param_file_tmp . " for writing";
	      print PARAM_FILE_TMP "neutral_rate\t$neutral_rate\n";
	  }
	  close (PARAM_FILE_TMP);
      }
      $self->{'run_gerp'} = 1;
  } else {
      $self->{'run_gerp'} = 0;
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

    #only run gerp if there are sufficient species present in the genomic align block
    if (!$self->{'run_gerp'}) {
	return;
    }
    if ($self->program_version == 1) { 
	$self->run_gerp;
    } elsif ($self->program_version == 2.1) { 
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
  
    #if haven't run gerp, don't try to store any results!
    if (!$self->{'run_gerp'}) { 
	return 1;
    }

    print STDERR "Write Output\n";

    #parse results and store constraints and conserved elements in database
    if ($self->program_version == 1) {
	$self->_parse_results;
    } elsif ($self->program_version == 2.1) {
	$self->_parse_results_v2;
    } else {
	throw("Invalid version number. Valid values are 1 or 2.1\n");
    }
    
    return 1;
}

##########################################
#
# getter/setter methods
# 
##########################################
#read from input_id from analysis_job table
sub genomic_align_block_id {
  my $self = shift;
  $self->{'_genomic_align_block_id'} = shift if(@_);
  return $self->{'_genomic_align_block_id'};
}

#read species_set from analysis_job table
sub species_set {
  my $self = shift;
  $self->{'_species_set'} = shift if(@_);
  return $self->{'_species_set'};
}

#read method_link_type from analysis table
sub constrained_element_method_link_type {
  my $self = shift;
  $self->{'_constrained_element_method_link_type'} = shift if(@_);
  return $self->{'_constrained_element_method_link_type'};
}

#read options from analysis table
sub options {
  my $self = shift;
  $self->{'_options'} = shift if(@_);
  return $self->{'_options'};
}

#read from parameters of analysis table
sub program {
  my $self = shift;
  $self->{'_program'} = shift if(@_);
  return $self->{'_program'};
}

sub program_file {
  my $self = shift;
  $self->{'_program_file'} = shift if(@_);
  return $self->{'_program_file'};
}

#read from parameters of analysis table
sub program_version {
  my $self = shift;
  $self->{'_program_version'} = shift if(@_);
  return $self->{'_program_version'};
}

#read from parameters of analysis table
sub param_file {
  my $self = shift;
  $self->{'_param_file'} = shift if(@_);
  return $self->{'_param_file'};
}

#read from parameters of analysis table
sub tree_file {
  my $self = shift;
  $self->{'_tree_file'} = shift if(@_);
  return $self->{'_tree_file'};
}

#read from parameters of analysis table
sub window_sizes {
  my $self = shift;
  $self->{'_window_sizes'} = shift if(@_);
  return $self->{'_window_sizes'};
}

#name of temporary parameter file
sub param_file_tmp {
  my $self = shift;
  $self->{'_param_file_tmp'} = shift if(@_);
  return $self->{'_param_file_tmp'};
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
    
    my $params = eval($param_string);
    return unless($params);

    if (defined($params->{'program'})) {
	$self->program($params->{'program'}); 
    }
    
    #read from parameters in analysis table
    if (defined($params->{'param_file'})) {
	$self->param_file($params->{'param_file'});
    }
    if (defined($params->{'tree_file'})) {
	$self->tree_file($params->{'tree_file'});
    }
    if (defined($params->{'window_sizes'})) {
	$self->window_sizes($params->{'window_sizes'});
    }
    if (defined($params->{'constrained_element_method_link_type'})) {
	$self->constrained_element_method_link_type($params->{'constrained_element_method_link_type'});
    }
    if (defined($params->{'options'})) {
	$self->options($params->{'options'});
    }

    #read from input_id in analysis_job table
    if (defined($params->{'genomic_align_block_id'})) {
        $self->genomic_align_block_id($params->{'genomic_align_block_id'}); 
    }
    if(defined($params->{'species_set'})) {
        $self->species_set($params->{'species_set'});
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
    $self->{'mfa_file'} = $self->worker_temp_directory . $ALIGN_FILE;
    open (ALIGN, ">$self->{'mfa_file'}") or throw "error writing alignment ($self->{'mfa_file'}) file\n";    

    
    #create mfa file of multiple alignment from genomic align block
    my $segments;
    if (UNIVERSAL::isa($object, "Bio::EnsEMBL::Compara::GenomicAlignTree")) {
      $segments = $object->get_all_leaves;
    } elsif (UNIVERSAL::isa($object, "Bio::EnsEMBL::Compara::GenomicAlignBlock")) {
      $segments = $object->get_all_GenomicAligns;
    }

    foreach my $this_segment (@{$segments}) {
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
    }
    close ALIGN;
}

#run gerp version 1
sub run_gerp {
    my $self = shift;

    #change directory to where the temporary mfa and tree file are written
    chdir $self->worker_temp_directory;

    unless (defined $self->program_file) {
	if (defined($self->analysis) and defined($self->analysis->program_file)) {
	    $self->program_file($self->analysis->program_file);
	} else {
	    #$self->program_file("$BIN_DIR[0]/GERP.pl");
	    $self->program_file("$BIN_DIR{$self->program_version}/GERP.pl");
	}
    }

    throw($self->program_file . " is not executable Gerp::run ")
	unless ($self->program_file && -x $self->program_file);

    my $command = $self->program_file;

    if ($self->param_file) {
	$command .= " " . $self->param_file_tmp;
    }
    #run gerp with parameter file
    unless (system($command) == 0) {
	throw("gerp execution failed\n");
    }
}

#run gerp version 2.1
sub run_gerp_v2 {
    my ($self, $bin_dir) = @_;
    my @program_files;
    my $gerpcol_path;
    my $gerpelem_path;

    #change directory to where the temporary mfa and tree file are written
    chdir $self->worker_temp_directory;

    unless (defined $self->program_file) {
	if (defined($self->analysis) and defined($self->analysis->program_file)) {
	    $gerpcol_path = $self->analysis->program_file . "/gerpcol";
	    $gerpelem_path = $self->analysis->program_file . "/gerpelem";
	} else {
	    $gerpcol_path = "$BIN_DIR{$self->program_version}/gerpcol";
	    $gerpelem_path = "$BIN_DIR{$self->program_version}/gerpelem";
	}
    }
    throw($gerpcol_path . " is not executable Gerp::run ")
      unless ($gerpcol_path && -x $gerpcol_path);

    throw($gerpelem_path . " is not executable Gerp::run ")
      unless ($gerpelem_path && -x $gerpelem_path);

    #run gerpcol
    my $command = $gerpcol_path;
    $command .= " -t " . $self->{'modified_tree_file'} . " -f " . $self->{'mfa_file'};
    print STDERR "command $command\n";

    unless (system($command) == 0) {
	throw("gerpcol execution failed\n");
    }

    #run gerpelem
    $command = $gerpelem_path;

    $command .= " -f " . $self->{'mfa_file'}.$RATES_FILE_SUFFIX;
    print STDERR "command $command\n";
    unless (system($command) == 0) {
	throw("gerpelem execution failed\n");
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
  open (PARAM_FILE, $self->param_file) || throw "Could not open file " . $self->param_file;

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
  $self->_parse_rates_file($self->{'mfa_file'}.$RATES_FILE_SUFFIX, 2);

  $self->_parse_cons_file($self->{'mfa_file'}.$RATES_FILE_SUFFIX.$CONS_FILE_SUFFIX, 2);
}


#This method parses the gerp constraints file and stores the values as 
#genomic_align_blocks
#cons_file : full filename of constraints file
#example : $self->_parse_cons_file(/tmp/worker.2580193/gerp_alignment.mfa.rates_RS8.5_md6_cons.txt);
sub _parse_cons_file {
    my ($self, $cons_file, $version) = @_;

    my $gaba = $self->{'comparaDBA'}->get_GenomicAlignBlockAdaptor;
    my $gab = $gaba->fetch_by_dbID($self->genomic_align_block_id);

    my $mlssa = $self->{'comparaDBA'}->get_MethodLinkSpeciesSetAdaptor;

    my $mlss = $mlssa->fetch_by_method_link_type_genome_db_ids($self->constrained_element_method_link_type, 
							       $self->species_set);
    unless ($mlss) {
	throw("Invalid method_link_species_set\n");
    }
    my $constrained_element_adaptor = $self->{'comparaDBA'}->get_ConstrainedElementAdaptor;
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
    my $win_sizes = eval($self->window_sizes);

    my $j;
    
    my $obs_no_score = -1.0; #uncalled observed score
    my $exp_no_score = 0.0;  #uncalled expected score
    my $diff_no_score = 0.0; 

    my $bucket;

    my $gaba = $self->{'comparaDBA'}->get_GenomicAlignBlockAdaptor;
    my $gab = $gaba->fetch_by_dbID($self->genomic_align_block_id);
    my $cs_adaptor = $self->{'comparaDBA'}->get_ConservationScoreAdaptor;

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
	    my $conservation_score =  new Bio::EnsEMBL::Compara::ConservationScore(											       -genomic_align_block => $gab, -window_size => $win_sizes->[$j], -position => $bucket->{$win_sizes->[$j]}->{start_pos}, -expected_score => $bucket->{$win_sizes->[$j]}->{exp_scores}, -diff_score => $bucket->{$win_sizes->[$j]}->{diff_scores});				
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
    
    my $tree_file = $self->tree_file;

    my $newick = "";
    if (-e $tree_file) {
	open NEWICK_FILE, $tree_file || throw("Can not open $tree_file");
	$newick = join("", <NEWICK_FILE>);
	close NEWICK_FILE;
    } else {
	## Look in the meta table
	my $meta_adaptor = $self->{'comparaDBA'}->get_MetaContainer;
	$tree_file =~ s/.*\/([^\/]+)$/$1/;
	$newick = $meta_adaptor->list_value_by_key("$tree_file")->[0];
    }
    return if (!$newick);
    
    $newick =~ s/^\s*//;
    $newick =~ s/\s*$//;
    $newick =~ s/[\r\n]//g;
  
    my $tree = Bio::EnsEMBL::Compara::Graph::NewickParser::parse_newick_into_tree($newick);
    
    $tree = $self->_update_tree($tree, $genomic_aligns);
    
    my $tree_string = $tree->newick_simple_format;
    
    # Remove quotes around node labels
    $tree_string =~ s/"(_\d+_)"/$1/g;

    $tree->release_tree;
 
    $self->{'modified_tree_file'} = $self->worker_temp_directory . $TREE_FILE;

    open (TREE, ">$self->{'modified_tree_file'}") or throw "error writing alignment ($self->{'modified_tree_file'}) file\n";    
    print TREE $tree_string;
    close TREE;

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
	    if ($this_genomic_align->dnafrag->genome_db_id == $this_leaf->name) {
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
