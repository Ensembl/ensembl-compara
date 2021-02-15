=head1 LICENSE

# See the NOTICE file distributed with this work for additional information
# regarding copyright ownership.
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

=head1 NAME

Bio::EnsEMBL::Compara::Production::Analysis::Blat

=head1 SYNOPSIS

 run_blat returns an array of SeqFeatures, each one representing an aligment (e.g. a transcript), 
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

package Bio::EnsEMBL::Compara::Production::Analysis::Blat;

use warnings ;
use strict;

use Bio::EnsEMBL::Utils::Exception qw(warning);
use Bio::EnsEMBL::FeaturePair;
use Bio::EnsEMBL::DnaDnaAlignFeature;

use Bio::PrimarySeqI;
use Bio::SeqI;


sub run_blat {
  my ($self, $query, $database) = @_;
    
  my $cmd = $self->param('pair_aligner_exe')." ".
            $database ." ".
            $query ." ".
	    $self->param('method_link_species_set')->get_value_for_tag('param');

  $cmd .=  " -out=pslx -noHead stdout";

  my $results;
  $self->read_from_command($cmd, sub {
          my $blat_output_pipe = shift;
          $results = parse_results($blat_output_pipe);
      } );
  return $results;
}

#
#much of this code is taken from 
#ensembl-pipeline/modules/Bio/EnsEMBL/Pipeline/Runnable/Blat.pm
#
sub parse_results {
    my ($blat_output_pipe) = @_;

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

              # calculate a local score and percent id for the block
              ($score, $percent_id) =
                  get_best_score_in_all_frames($this_q_bioseq, $this_t_bioseq);
            
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

                $feature_pair->seqname($feat2{name});
                $feature_pair->start($query_starts[$i]);
                $feature_pair->end($query_ends[$i]);
                $feature_pair->strand($q_strand);
                $feature_pair->hseqname($feat1{name});
                $feature_pair->hstart($target_starts[$i]);
                $feature_pair->hend($target_ends[$i]);
                $feature_pair->hstrand($t_strand);

              my $alignment = new Bio::EnsEMBL::DnaDnaAlignFeature(-features => [$feature_pair]);
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

1;

