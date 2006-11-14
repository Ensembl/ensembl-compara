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

#FIXME must move this
my $BIN_DIR = "/ecs4/work3/kb3/gerp/GERP_03292006/";
#my $BIN_DIR = "/usr/local/ensembl/gerp/GERP_03292006/";

#temporary files written to worker_temp_directory
my $ALIGN_FILE = "gerp_alignment.mfa";
my $TREE_FILE = "gerp_tree.nw";

#ending appended to parameter file to allow for calculation of neutral rate
#from the tree file
my $PARAM_FILE_SUFFIX = ".tmp";

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

  my $gaba = $self->{'comparaDBA'}->get_GenomicAlignBlockAdaptor;
  my $gab = $gaba->fetch_by_dbID($self->genomic_align_block_id);
  
  my $gas = $gab->get_all_GenomicAligns;

  #only run gerp if there are more than 2 genomic aligns. Gerp requires more
  #than 2 sequences to be represented at a position
  if (scalar(@$gas) > 2) {
      #write out multiple alignment as a mfa file.
      $self->_writeMultiFastaAlignment;

      #write out modified tree depending on sequences represented in this
      #genomic align block (based on Javier's _update_tree in Pecan.pm)
      my $tree_string = $self->_build_tree_string($gas);

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
      close (PARAM_FILE);

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
    if ($self->{'run_gerp'}) { 
	$self->run_gerp;
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
    #parse results and store constraints and conserved elements in database
    $self->_parse_results;
    
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

#read from parameters of analysis table
sub program {
  my $self = shift;
  $self->{'_program'} = shift if(@_);
  return $self->{'_program'};
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

    if (defined($params->{'-program'})) {
	$self->program($params->{'-program'}); 
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

    my $output_format = "fasta";
    my $alignIO = Bio::AlignIO->newFh(
				      -interleaved => 0,
				      -fh => \*ALIGN,                         
				      -format => $output_format,
				      -idlength => 10
				      );
  
    my $gaba = $self->{'comparaDBA'}->get_GenomicAlignBlockAdaptor;
    my $gab = $gaba->fetch_by_dbID($self->genomic_align_block_id);
    
    my $simple_align = Bio::SimpleAlign->new();
    $simple_align->id("GAB#".$gab->dbID);
    $simple_align->score($gab->score);
    
    #create mfa file of multiple alignment from genomic align block
    foreach my $genomic_align (@{$gab->get_all_GenomicAligns}) {
	#my $seq_name = $genomic_align->dnafrag->genome_db->name;
	#$seq_name =~ s/(\w*) (\w*)/$1_$2/;

	#add _ to either side of genome_db id to make GERP like it
	my $seq_name = _get_name_from_GenomicAlign($genomic_align);
	
	my $aligned_sequence = $genomic_align->aligned_sequence;
	my $seq = Bio::LocatableSeq->new(
					 -SEQ    => $aligned_sequence,
					 -START  => $genomic_align->dnafrag_start,
					 -END    => $genomic_align->dnafrag_end,
					 -ID     => $seq_name,
					 -STRAND => $genomic_align->dnafrag_strand,
					 );
	$simple_align->add_seq($seq);
	
	#want the sequence name to be $seq_name not the default name/start-end
	my $start = $genomic_align->dnafrag_start;
	my $end = $genomic_align->dnafrag_end;
	$simple_align->displayname("$seq_name/$start-$end", $seq_name);
    } 
    
    #write out the alignment file
    my $align_file = $self->worker_temp_directory . $ALIGN_FILE;

    open (ALIGN, ">$align_file") || throw "error writing alignment ($align_file) file\n";    
    print $alignIO $simple_align;
    close ALIGN;
}

sub run_gerp {
    my $self = shift;

    #change directory to where the temporary mfa and tree file are written
    chdir $self->worker_temp_directory;

    unless (defined $self->program) {
	$self->program("$BIN_DIR/GERP.pl");
    }

    throw($self->program . " is not executable Gerp::run ")
	unless ($self->program && -x $self->program);

    my $command = $self->program;

    if ($self->param_file) {
	$command .= " " . $self->param_file_tmp;
    }
    #run gerp with parameter file
    unless (system($command) == 0) {
	throw("gerp execution failed\n");
    }
}

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
 
  $self->_parse_cons_file($cons_file);
  $self->_parse_rates_file($rates_file);

}


#This method parses the gerp constraints file and stores the values as 
#genomic_align_blocks
#cons_file : full filename of constraints file
#example : $self->_parse_cons_file(/tmp/worker.2580193/gerp_alignment.mfa.rates_RS8.5_md6_cons.txt);
sub _parse_cons_file {
    my ($self, $cons_file) = @_;

    my $gaba = $self->{'comparaDBA'}->get_GenomicAlignBlockAdaptor;
    my $gab = $gaba->fetch_by_dbID($self->genomic_align_block_id);

    my $mlssa = $self->{'comparaDBA'}->get_MethodLinkSpeciesSetAdaptor;

    my $mlss = $mlssa->fetch_by_method_link_type_genome_db_ids($self->constrained_element_method_link_type, 
							       $self->species_set);
    unless ($mlss) {
	throw("Invalid method_link_species_set\n");
    }

    open CONS, $cons_file || throw("Could not open $cons_file");
    while (<CONS>) {
	unless (/^#/) {
		chomp;
		#extract info from constraints file
		my ($start, $end, $length, $rej_subs) = split /\t/,$_; 

		#create new genomic align blocks by converting alignment 
		#coords to chromosome coords
		my $constrained_gab = $gab->restrict_between_alignment_positions($start, $end, "skip"); 

		#if no restriction was required, it returns the original gab
		#back but I need to reset the dbID in this case otherwise I end
		#up trying to store the original gab again!
		if (defined $constrained_gab->dbID && $constrained_gab->dbID == $gab->dbID) {
		    $constrained_gab->dbID(0);
		    foreach my $genomic_align (@{$constrained_gab->get_all_GenomicAligns}) {
			$genomic_align->dbID(0);
		    }
		}
		$constrained_gab->score($rej_subs);
		$constrained_gab->method_link_species_set($mlss);

		$gaba->store($constrained_gab);
	    }
    }
    close(CONS);
}

#This method parses the gerp rates file and stores the multiple alignment 
#genomic align block id, window size, position, observed and expected scores 
#and difference (expected-observed) scores in the conservation_score table
#rates_file : full filename of rates file
#example    : $self->_parse_rates_file(/tmp/worker.2580193/gerp_alignment.mfa.rates);
sub _parse_rates_file {
    my ($self, $rates_file) = @_;
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
				       obs => 0,        #current observed score
				       obs_scores => "", #observed score string
				       exp => 0,        #current expected score
				       exp_scores => "",#expected score string
				       diff => 0,       #current diff score
				       diff_scores => "",#diff score string
				       delete_cnt => 0, #no. uncalled bases
				       pos => 0,        #current alignment position
				       start_pos => 1}; #alignment position of this block
    }

#length of uncalled region to allow neighbouring called regions to be joined
#doesn't want to be too big because I need to store these uncalled values.
    my $merge_dist = 10;

#maximum called length before cut into smaller parts
    my $max_called_dist = 1000;


    #read in rates file
    open (RATES,$rates_file) || throw "Could not open rates ($rates_file) file\n";
    
    while (<RATES>) {
	unless (/^#/) {
		chomp;
		my ($obs, $exp) = split/\t/,$_;
		my $diff;

		if ($obs == $obs_no_score) {
		    $diff = $diff_no_score;
		} else {
		    $diff = $exp - $obs;
		}
		for ($j = 0; $j < scalar(@$win_sizes); $j++) {

		    #store called obs, exp and diff in each win_size bucket and keep a count of these with win_called
		    if ($diff != $diff_no_score) {
			$bucket->{$win_sizes->[$j]}->{obs} += $obs;
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
			if ($bucket->{$win_sizes->[$j]}->{diff} != $diff_no_score) {
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
				    $bucket->{$win_sizes->[$j]}->{obs_scores} .= "$obs_no_score ";
				    $bucket->{$win_sizes->[$j]}->{exp_scores} .= "$exp_no_score ";
				    $bucket->{$win_sizes->[$j]}->{diff_scores} .= "$diff_no_score ";
				    
				    #store in database
				    if ($bucket->{$win_sizes->[$j]}->{cnt} == $max_called_dist) {
					my $conservation_score =  new Bio::EnsEMBL::Compara::ConservationScore(											       -genomic_align_block => $gab, -window_size => $win_sizes->[$j], -position => $bucket->{$win_sizes->[$j]}->{start_pos}, -observed_score => $bucket->{$win_sizes->[$j]}->{obs_scores}, -expected_score => $bucket->{$win_sizes->[$j]}->{exp_scores}, -diff_score => $bucket->{$win_sizes->[$j]}->{diff_scores});
					
					$cs_adaptor->store($conservation_score);  
					
					#reset bucket values
					$bucket->{$win_sizes->[$j]}->{cnt} = 0;
					$bucket->{$win_sizes->[$j]}->{called} = 0;
					$bucket->{$win_sizes->[$j]}->{obs_scores} = "";
					$bucket->{$win_sizes->[$j]}->{exp_scores} = "";
					$bucket->{$win_sizes->[$j]}->{diff_scores} = "";
					$bucket->{$win_sizes->[$j]}->{start_pos} += $max_called_dist;
				    }
				}
			    }
			    #first time found called score so save current pos 
			    #as start_pos for this block
			    if ($bucket->{$win_sizes->[$j]}->{called} == 1) {
				$bucket->{$win_sizes->[$j]}->{start_pos} = $bucket->{$win_sizes->[$j]}->{pos};
			    }
			   
			    #average over the number of called scores in a 
			    #window and append to score string
			    #$bucket->{$win_sizes->[$j]}->{obs_scores} .= ($bucket->{$win_sizes->[$j]}->{obs}/$bucket->{$win_sizes->[$j]}->{win_called}) . " ";
			    #$bucket->{$win_sizes->[$j]}->{exp_scores} .= ($bucket->{$win_sizes->[$j]}->{exp}/$bucket->{$win_sizes->[$j]}->{win_called}) . " ";
			    #$bucket->{$win_sizes->[$j]}->{diff_scores} .= ($bucket->{$win_sizes->[$j]}->{diff}/$bucket->{$win_sizes->[$j]}->{win_called}) . " "; 
			    $bucket->{$win_sizes->[$j]}->{obs_scores} .= ($bucket->{$win_sizes->[$j]}->{obs}/$win_sizes->[$j]) . " ";
			    $bucket->{$win_sizes->[$j]}->{exp_scores} .= ($bucket->{$win_sizes->[$j]}->{exp}/$win_sizes->[$j]) . " ";
			    $bucket->{$win_sizes->[$j]}->{diff_scores} .= ($bucket->{$win_sizes->[$j]}->{diff}/$win_sizes->[$j]) . " ";
			    
			    #increment counter of total called scores in this 
			    #block
			    $bucket->{$win_sizes->[$j]}->{cnt}++;

			    #if have max_called_dist scores in the score 
			    #string, then store them in the database
			    if ($bucket->{$win_sizes->[$j]}->{cnt} == $max_called_dist) {

				my $conservation_score =  new Bio::EnsEMBL::Compara::ConservationScore(											       -genomic_align_block => $gab, -window_size => $win_sizes->[$j], -position => $bucket->{$win_sizes->[$j]}->{start_pos}, -observed_score => $bucket->{$win_sizes->[$j]}->{obs_scores}, -expected_score => $bucket->{$win_sizes->[$j]}->{exp_scores}, -diff_score => $bucket->{$win_sizes->[$j]}->{diff_scores});
				
				$cs_adaptor->store($conservation_score);  
				
				#reinitialise bucket values
				$bucket->{$win_sizes->[$j]}->{cnt} = 0;
				$bucket->{$win_sizes->[$j]}->{called} = 0;
				$bucket->{$win_sizes->[$j]}->{obs_scores} = "";
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

				my $conservation_score =  new Bio::EnsEMBL::Compara::ConservationScore(											       -genomic_align_block => $gab, -window_size => $win_sizes->[$j], -position => $bucket->{$win_sizes->[$j]}->{start_pos}, -observed_score => $bucket->{$win_sizes->[$j]}->{obs_scores}, -expected_score => $bucket->{$win_sizes->[$j]}->{exp_scores}, -diff_score => $bucket->{$win_sizes->[$j]}->{diff_scores});				
				$cs_adaptor->store($conservation_score);  
				
				$bucket->{$win_sizes->[$j]}->{cnt} = 0;
				$bucket->{$win_sizes->[$j]}->{called} = 0;
				$bucket->{$win_sizes->[$j]}->{exp_scores} = "";
				$bucket->{$win_sizes->[$j]}->{obs_scores} = "";
				$bucket->{$win_sizes->[$j]}->{diff_scores} = "";
			    }
			}
			$bucket->{$win_sizes->[$j]}->{obs} = 0;
			$bucket->{$win_sizes->[$j]}->{exp} = 0;
			$bucket->{$win_sizes->[$j]}->{diff} = 0;
			$bucket->{$win_sizes->[$j]}->{win_called} = 0;
		    }
		}
	    }

    }
    #store last lot
    for ($j = 0; $j < scalar(@$win_sizes); $j++) {

	my $conservation_score =  new Bio::EnsEMBL::Compara::ConservationScore(											       -genomic_align_block => $gab, -window_size => $win_sizes->[$j], -position => $bucket->{$win_sizes->[$j]}->{start_pos}, -observed_score => $bucket->{$win_sizes->[$j]}->{obs_scores}, -expected_score => $bucket->{$win_sizes->[$j]}->{exp_scores}, -diff_score => $bucket->{$win_sizes->[$j]}->{diff_scores});				
	$cs_adaptor->store($conservation_score);  
    }
}


#  Arg [1]    : array reference of genomic_aligns
#  Example    : $self->_build_tree_string();
#  Description: This method sets the tree_string using the orginal
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
 
    my $modified_tree_file = $self->worker_temp_directory . $TREE_FILE;

    open (TREE, ">$modified_tree_file") || throw "error writing alignment ($modified_tree_file) file\n";    
    print TREE $tree_string;
    close TREE;

    return $tree_string;
}

#  Arg [1]    : Bio::EnsEMBL::Compara::NestedSet $tree_root
#  Example    : $self->_update_nodes_names($tree);
#  Description: This method updates the tree by removing or
#               duplicating the leaves according to the orginal
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
