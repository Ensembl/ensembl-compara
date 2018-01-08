=head1 LICENSE
# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2018] EMBL-European Bioinformatics Institute
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#      http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.

=cut

=head1 AUTHORS

Kathryn Beal

=head1 NAME

Bio::EnsEMBL::Analysis::Runnable::Blat - 

=head1 SYNOPSIS

  my $runnable = Bio::EnsEMBL::Analysis::Runnable::Blat->new(
								 -database    => $self->database,
								 -query  => $self->query,
								 -program        => $self->program,
								 -options     => $self->options,
								);

 $runnable->run; #create and fill Bio::Seq object
 my @results = $runnable->output;
 
 where @results is an array of SeqFeatures, each one representing an aligment (e.g. a transcript), 
 and each feature contains a list of alignment blocks (e.g. exons) as sub_SeqFeatures, which are
 in fact feature pairs.
 
=head1 DESCRIPTION

Blat takes a Bio::Seq (or Bio::PrimarySeq) object and runs Blat
against a set of sequences.  The resulting output file is parsed
to produce a set of features.

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Analysis::Runnable::Blat;

use warnings ;
use vars qw(@ISA);
use strict;

use Bio::EnsEMBL::Utils::Exception qw(throw warning info);
use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use Bio::EnsEMBL::Analysis::Runnable;
use Bio::EnsEMBL::SeqFeature;
use Bio::EnsEMBL::FeaturePair;
use Bio::EnsEMBL::Analysis;
use Bio::PrimarySeqI;
use Bio::SeqI;

@ISA = qw(Bio::EnsEMBL::Analysis::Runnable);

sub new {
  my ($class,@args) = @_;
  my $self = $class->SUPER::new(@args);

  my ($database, $gapped, $query_hseq) = rearrange([qw(DATABASE GAPPED QUERYHSEQ)], @args);
  $self->database($database) if defined $database;
  $self->gapped($gapped) if defined $gapped;
  $self->query_as_hseq($query_hseq) if defined $query_hseq;

  throw("You must supply a database") if not $self->database; 
  throw("You must supply a query") if not $self->query;

  $self->unknown_error_string('FAILED');

  $self->program("blat-32") if not $self->program;

  return $self;
}

############################################################
#
# Analysis methods
#
############################################################

=head2 run

Usage   :   $obj->run($workdir, $args)
Function:   Runs blat script and puts the results into the file $self->results
            It calls $self->parse_results, and results are stored in $self->output

=cut
  
sub run {
  my ($self) = @_;
    
  my $cmd = $self->program  ." ".
            $self->database ." ".
            $self->query ." ".
	    $self->options;

  my $blat_output_pipe = undef;

  $cmd .=  " -out=pslx -noHead stdout";

  info("Running blat to pipe...\n$cmd\n");
  print("Running blat to pipe...\n$cmd\n");

  open($blat_output_pipe, "$cmd |") ||
    throw("Error opening Blat cmd <$cmd>." .
	  " Returned error $? BLAT EXIT: '" .
	  ($? >> 8) . "'," ." SIGNAL '" . ($? & 127) .
	  "', There was " . ($? & 128 ? 'a' : 'no') .
	  " core dump");

  my $results = $self->parse_results($blat_output_pipe);
  unless(close $blat_output_pipe){
      # checking for failures when closing.
      # we should't get here but if we do then $? is translated 
      #below see man perlvar
      throw("Error running Blat cmd <$cmd>. Returned ".
              "error $? BLAT EXIT: '" . ($? >> 8) . 
              "', SIGNAL '" . ($? & 127) . "', There was " . 
              ($? & 128 ? 'a' : 'no') . " core dump");
  }
  $self->output($results);
}

#
#much of this code is taken from 
#ensembl-pipeline/modules/Bio/EnsEMBL/Pipeline/Runnable/Blat.pm
#
sub parse_results {
    my ($self, $blat_output_pipe) = @_;

    my @alignments;

    while (<$blat_output_pipe>) {
	#print STDERR "$_\n";
    
	############################################################
	#  PSL lines represent alignments and are typically taken from files generated 
	# by BLAT or psLayout. See the BLAT documentation for more details. 
	#
	# 1.matches - Number of bases that match that aren't repeats 
	# 2.misMatches - Number of bases that don't match 
	# 3.repMatches - Number of bases that match but are part of repeats 
	# 4.nCount - Number of 'N' bases 
	# 5.qNumInsert - Number of inserts in query 
	# 6.qBaseInsert - Number of bases inserted in query 
	# 7.tNumInsert - Number of inserts in target 
	# 8.tBaseInsert - Number of bases inserted in target 
	# 9.strand - '+' or '-' for query strand. In mouse, second '+'or '-' is for genomic strand 
	#10.qName - Query sequence name 
	#11.qSize - Query sequence size 
	#12.qStart - Alignment start position in query 
	#13.qEnd - Alignment end position in query 
	#14.tName - Target sequence name 
	#15.tSize - Target sequence size 
	#16.tStart - Alignment start position in target 
	#17.tEnd - Alignment end position in target 
	#18.blockCount - Number of blocks in the alignment 
	#19.blockSizes - Comma-separated list of sizes of each block 
	#20.qStarts - Comma-separated list of starting positions of each block in query 
	#21.tStarts - Comma-separated list of starting positions of each block in target 
	############################################################
	
	# first split on spaces:
	chomp;  
      
	my (
            $matches,      $mismatches,    $rep_matches, $n_count,  $q_num_insert, $q_base_insert,
            $t_num_insert, $t_base_insert, $strand,      $q_name,   $q_length,     $q_start,
            $q_end,        $t_name,        $t_length,    $t_start,  $t_end,        $block_count,
            $block_sizes,  $q_starts,      $t_starts,    $q_seqs,   $t_seqs
	   )
          = split;
	#print STDERR  "$matches,      $mismatches,    $rep_matches, $n_count, $q_num_insert, $q_base_insert,
         #   $t_num_insert, $t_base_insert, $strand,      $q_name,  $q_length,     $q_start,
          #  $q_end,        $t_name,        $t_length,    $t_start, $t_end,        $block_count,
           # $block_sizes,  $q_starts,      $t_starts\n";

	# ignore any preceeding text
	#unless ( defined($matches) and $matches =~/^\d+$/ ){
	 #   next;
	#}

	# create as many features as blocks there are in each output line
	my (%feat1, %feat2);
	$feat1{name} = $t_name;
	$feat2{name} = $q_name;
    
	################
	#Added strand splitter as strand represented by ++ or +- etc
	if (length($strand)>1){
	    ($feat2{strand},$feat1{strand}) = split //,$strand; 
   	} else {
	    $feat2{strand}=$strand;
	    $feat1{strand}=1;
  	}
    
	# all the block sizes add up to $matches + $mismatches + $rep_matches
    
	# percentage identity =  ( matches not in repeats + matches in repeats ) / ( alignment length )
	#print STDERR "calculating percent_id and score:\n";
	#print STDERR "matches: $matches, rep_matches: $rep_matches, mismatches: $mismatches, q_length: $q_length\n";
	#print STDERR "percent_id = 100x".($matches + $rep_matches)."/".( $matches + $mismatches + $rep_matches )."\n";
	#my $percent_id = sprintf "%.2f", ( 100 * ($matches + $rep_matches)/( $matches + $mismatches + $rep_matches ) );
    
	# or is it ...?
	## percentage identity =  ( matches not in repeats + matches in repeats ) / query length
	#my $percent_id = sprintf "%.2d", (100 * ($matches + $rep_matches)/$q_length );
	
	# we put basically score = coverage = ( $matches + $mismatches + $rep_matches ) / $q_length
	#print STDERR "score = 100x".($matches + $mismatches + $rep_matches)."/".( $q_length )."\n";
	
	unless ( $q_length ){
	    warning("length of query is zero, something is wrong!");
	    next;
	}
	my $score   = sprintf "%.2f", ( 100 * ( $matches + $mismatches + $rep_matches ) / $q_length );
	my $percent_id = sprintf "%.2f", ( 100 * ($matches+$rep_matches) / ( $matches + $mismatches + $rep_matches ) );

	# size of each block of alignment (inclusive)
	my @block_sizes     = split ",",$block_sizes;
	
	# start position of each block (you must add 1 as psl output is off by one in the start coordinate)
	my @q_start_positions = split ",",$q_starts;
	my @t_start_positions = split ",",$t_starts;
	my @q_sequences = split ",",$q_seqs;
	my @t_sequences = split ",",$t_seqs;
	
	#    $superfeature->seqname($q_name);
	#    $superfeature->score( $score );
	#    $superfeature->percent_id( $percent_id );

	# each line of output represents one possible entire aligment of the query (feat1) and the target(feat2)
	
	#### working out the coordinates: #########################
	#
	#                s        e
	#                ==========   EST
	#   <----------------------------------------------------| (reversed) genomic of length L
	#
	#   we would store this as a hit in the reverse strand, with coordinates:
	#
	#   |---------------------------------------------------->
	#                                   s'       e'
	#                                   ==========   EST
	#   where e' = L  - s  
	#         s' = e' - ( e - s + 1 ) + 1
	#
	#   Also, hstrand will be always +1
	############################################################
	
	############################################################
	
	
	#NB strand may =++ or +- etc rather than just + or -  
	#
	#if qstrand negative reverse qstarts and blocks and calculate the correct co-ordinates
	#
	#if Tstrand(genomic strand) negative reverse the tstarts and then cal the co-ords
	#
	#if both strands are negative then reverse everything ie blocks and starts before calculating using:
	#
	# newqstart=length - (qstart + blocklength)  
    # newqend = length - qstart
	#NB not sure about when to add the plus 1 -- as psl starts at 0 for start but the end is correct 
	#NB add +1 to the plus strand starts    
	

	my @query_starts; my @target_starts; my @query_ends; my @target_ends; my @reversed_block_sizes;
	my @reversed_q_starts; my @reversed_t_starts;
		
	if ($feat2{strand} eq '+') { # query in the forward strand
	    
	    @query_starts = map {my $val=$_; $val+=1} (@q_start_positions); # use inclusive coord
	    if ($feat1{strand} eq '-') { # target in the reverse strand
		for (my $i=0; $i<$block_count; $i++) {
		    $query_ends[$i] = $q_start_positions[$i] + $block_sizes[$i];
		    $target_ends[$i] = $t_length - $t_start_positions[$i];
		    $target_starts[$i] = ($target_ends[$i] - $block_sizes[$i]) + 1;
		}
	    } else { # target in the forward strand
		@target_starts = map {my $val=$_; $val+=1} (@t_start_positions); # use inclusive coord
		for (my $i=0; $i<$block_count; $i++) {
		    $query_ends[$i] = $q_start_positions[$i] + $block_sizes[$i];
		    $target_ends[$i] = $t_start_positions[$i] + $block_sizes[$i];
		}
	    }
	} else { # query in the reverse strand

	    if ($feat1{strand} eq '-') { 
		for (my $i=0; $i<$block_count; $i++ ) { # target in the reverse strand
		    $query_ends[$i] = $q_length - $q_start_positions[$i];
		    $query_starts[$i] = ($query_ends[$i] - $block_sizes[$i]) + 1;
		    $target_ends[$i] = $t_length - $t_start_positions[$i];
		    $target_starts[$i] = ($target_ends[$i] - $block_sizes[$i]) + 1;
		}
	    } else { # target in forward strand
		@target_starts= map {my $val=$_; $val+=1} (@t_start_positions); # use inclusive coord
		for (my $i=0; $i<$block_count; $i++ ) {
		    $query_ends[$i] = $q_length - $q_start_positions[$i];
		    $query_starts[$i] = ($query_ends[$i] - $block_sizes[$i]) + 1;
		    $target_ends[$i] = $t_start_positions[$i] + $block_sizes[$i];
		}
	    }
	}
        my @ungapped_blocks;
	for (my $i=0; $i<$block_count; $i++ ) {
	    next if ($block_sizes[$i] < 15);
	    
	    $feat2 {start} = $query_starts[$i];
	    $feat2 {end}   = $query_ends[$i];
	    if ( $query_ends[$i] <  $query_starts[$i]) {
		warning("dodgy feature coordinates: end = $query_ends[$i], start = $query_starts[$i]. Reversing...");
		$feat2 {end}   = $query_starts[$i];
		$feat2 {start} = $query_ends[$i];
	    }
	    
	    $feat1 {start} = $target_starts[$i];
	    $feat1 {end}   = $target_ends[$i];
	    
	    my $this_q_bioseq = Bio::Seq->new(
					     -seq => $q_sequences[$i],
					     -moltype => "dna",
					     -alphabet => 'dna',
					     -id => "q_seq");
	    my $this_t_bioseq = Bio::Seq->new(
					      -seq => $t_sequences[$i],
					      -moltype => "dna",
					      -alphabet => 'dna',
					      -id => "t_seq");
            if (not $self->gapped) {
              # calculate a local score and percent id for the block
              ($score, $percent_id) =
                  get_best_score_in_all_frames($this_q_bioseq, $this_t_bioseq);
            }               
            
            $feat2 {score}   = $score;
            $feat1 {score}   = $feat2 {score};
            $feat2 {percent} = $percent_id;
            $feat1 {percent} = $feat2 {percent};
            
	    # other stuff:
	    $feat1 {db}         = undef;
	    $feat1 {db_version} = undef;
	    $feat1 {program}    = 'blat';
	    $feat1 {p_version}  = '1';
	    $feat1 {source}     = 'blat';
	    $feat1 {primary}    = 'similarity';
	    $feat2 {source}     = 'blat';
	    $feat2 {primary}    = 'similarity';
	    
	    ## make strand -1 or 1 rather than - or +
	    my $t_strand = ( $feat1{strand}eq '-')?"-1":"1";
	    my $q_strand = ($feat2{strand} eq '-')?"-1":"1";
	    
	    ## make FeaturePair object
	    my $feature_pair = new Bio::EnsEMBL::FeaturePair;
	    $feature_pair->score($score);
	    $feature_pair->percent_id($percent_id);

            if ($self->query_as_hseq) {
                $feature_pair->seqname($feat1{name});
                $feature_pair->start($target_starts[$i]);
                $feature_pair->end($target_ends[$i]);
                $feature_pair->strand($t_strand);
                $feature_pair->hseqname($feat2{name});
                $feature_pair->hstart($query_starts[$i]);
                $feature_pair->hend($query_ends[$i]);
                $feature_pair->hstrand($q_strand);
            } else {
                $feature_pair->seqname($feat2{name});
                $feature_pair->start($query_starts[$i]);
                $feature_pair->end($query_ends[$i]);
                $feature_pair->strand($q_strand);
                $feature_pair->hseqname($feat1{name});
                $feature_pair->hstart($target_starts[$i]);
                $feature_pair->hend($target_ends[$i]);
                $feature_pair->hstrand($t_strand);
            }              

            if ($self->gapped) {
                push @ungapped_blocks, $feature_pair;
            } else {
              my $alignment = new Bio::EnsEMBL::DnaDnaAlignFeature(-features => [$feature_pair]);
              push @alignments, $alignment;
            }
        }
        if ($self->gapped and @ungapped_blocks) {
          my $alignment = new Bio::EnsEMBL::DnaDnaAlignFeature(-features => \@ungapped_blocks);
          push @alignments, $alignment;
        }
    }
#foreach my $out (@alignments) {
 #      print STDERR $out->seqname."\t"."BLAT"."\tsimilarity\t".$out->start."\t".$out->end."\t".$out->hseqname."\t".$out->hstart."\t".$out->hend."\t".
#    $out->score."\t".$out->p_value."\t".$out->hstrand."\t". $out->strand."\t".$out->identical_matches."\t".$out->positive_matches."\t".$out->cigar_string."\n"; #this line is the start of a gff line for display
#}
    
    return \@alignments;
}

sub get_best_score_in_all_frames {
    my ($seq1, $seq2, $matrix) = @_;
    
    #Using our fixed version of this
    my @aa_seq1_6fr = _translate_6frames($seq1);
    my @aa_seq2_6fr = _translate_6frames($seq2);
    
    my $score;
    my $perc_id = 0;
    my $frame = 0;
    ##  my $seqs;
    for (my $i=0; $i<6; $i++) {
	my $this_score = 0;
	my $this_perc_id = 0;
	my $this_seq1 = $aa_seq1_6fr[$i]->seq;
	my $this_seq2 = $aa_seq2_6fr[$i]->seq;
	my $length = length($this_seq1);
	$length = length($this_seq2) if (length($this_seq2) < $length);
	my @this_seq1 = split("", $this_seq1);
	my @this_seq2 = split("", $this_seq2);
	
	if (defined($matrix)) {
	    for (my $j=0; $j<$length; $j++) {
		my $aa1 = $this_seq1[$j];
		my $aa2 = $this_seq2[$j];
		$this_score += $matrix->{$aa1}->{$aa2};
		$this_perc_id++ if ($aa1 eq $aa2);
	    }
	} else {
	    for (my $j=0; $j<$length; $j++) {
		my $aa1 = $this_seq1[$j];
		my $aa2 = $this_seq2[$j];
		if ($aa1 eq $aa2) {
		    $this_score += 2;
		    $this_perc_id++;
		} else {
		    $this_score--;
		}
	    }
	}
	
	if (!defined($score) or ($this_score > $score)) {
	    $score = $this_score;
	    if ($length) {
		$perc_id = int(100 * $this_perc_id / $length);
	    } else {
		$perc_id = 0;
	    }
	    $frame = $i;
	    ##      $seqs = $this_seq1."\n".$this_seq2;
	}
    }
    
    return ($score, $perc_id, $frame);
}

#Taken from BioPerl since the 1.2.3 version incorrectly lets Bio::PrimarySeq
#decide what the reversed complemented sequence is; we know it's the same
#type therefore it stays as the same type
sub _translate_6frames {
  my ($seq, @args) = @_;    
  my @seqs = Bio::SeqUtils->translate_3frames($seq, @args);
  $seq->seq($seq->revcom->seq, $seq->alphabet());
  my @seqs2 = Bio::SeqUtils->translate_3frames($seq, @args);
  foreach my $seq2 (@seqs2) {
    my ($tmp) = $seq2->id;
    $tmp =~ s/F$/R/g;
    $seq2->id($tmp);
  }
  return @seqs, @seqs2;
}

sub unknown_error_string{
  my $self = shift;
  $self->{'unknown_error_string'} = shift if(@_);
  return $self->{'unknown_error_string'};
}


############################################################
#
# get/set methods
#
############################################################

=head2 query

    Title   :   query
    Usage   :   $self->query($seq)
    Function:   Get/set method for query.  If set with a Bio::Seq object it
                will get written to the local tmp directory
    Returns :   filename
    Args    :   Bio::PrimarySeqI, or filename

=cut

sub query {
    my ($self, $val) = @_;
    
    if (defined $val) {
	if (not ref($val)) {   
	    throw("[$val] : file does not exist\n") unless -e $val;
	} elsif (not $val->isa("Bio::PrimarySeqI")) {
	    throw("[$val] is neither a Bio::Seq not a file");
	}
	$self->{_query} = $val;
    }
    
    return $self->{_query}
}

=head2 database
  
    Title   :   database
    Usage   :   $self->database($seq)
    Function:   Get/set method for database.  If set with a Bio::Seq object it
                will get written to the local tmp directory
    Returns :   filename
    Args    :   Bio::PrimarySeqI, or filename

=cut

sub database {
    my ($self, $val) = @_;
    
    if (defined $val) {
	if (not ref($val)) {   
	    throw("[$val] : file does not exist\n") unless -e $val;
	} else {
	    if (ref($val) eq 'ARRAY') {
		foreach my $el (@$val) {
		    throw("All elements of given database array should be Bio::PrimarySeqs")
		      if not ref($el) or not $el->isa("Bio::PrimarySeq");
		}
	    } elsif (not $val->isa("Bio::PrimarySeq")) {
		throw("[$val] is neither a file nor array of Bio::Seq");
	    } else {
		$val = [$val];
	    }
	}
	$self->{_database} = $val;
    }
    
    return $self->{_database};
}

############################################################

sub blat {
    my ($self, $location) = @_;
    if ($location) {
	throw("Blat not found at $location: $!\n") unless (-e $location);
	$self->{_blat} = $location ;
    }
    return $self->{_blat};
}

############################################################

sub query_type {
    my ($self, $mytype) = @_;
    if (defined($mytype) ){
	my $type = lc($mytype);
	unless( $type eq 'dna' || $type eq 'rna' || $type eq 'prot' || $type eq 'dnax' || $type eq 'rnax' ){
	    throw("not the right query type: $type");
	}
	$self->{_query_type} = $type;
    }
    return $self->{_query_type};
}

############################################################

sub target_type {
    my ($self, $mytype) = @_;
    if (defined($mytype) ){
	my $type = lc($mytype);
	unless( $type eq 'dna' || $type eq 'prot' || $type eq 'dnax' ){
	    throw("not the right target type: $type");
	}
	$self->{_target_type} = $type ;
    }
    return $self->{_target_type};
}

############################################################

sub options {
    my ($self, $options) = @_;
    if ($options) {
	$self->{_options} = $options ;
    }
    return $self->{_options};
}

############################################################

sub parse {
    my ($self, $parse) = @_;
    if ($parse) {
	$self->{_parse} = $parse;
    }
    return $self->{_parse};
}

############################################################

sub gapped {
    my ($self, $gapped) = @_;
    if ($gapped) {
	$self->{_gapped} = $gapped;
    }
    return $self->{_gapped};
}

############################################################

sub query_as_hseq {
    my ($self, $qashseq) = @_;
    if ($qashseq) {
	$self->{_query_as_hseq} = $qashseq;
    }
    return $self->{_query_as_hseq};
}

############################################################


1;

