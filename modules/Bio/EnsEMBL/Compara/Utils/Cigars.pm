=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2019] EMBL-European Bioinformatics Institute

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

=head1 AUTHORSHIP

Ensembl Team. Individual contributions can be found in the GIT log.

=head1 DESCRIPTION

This modules contains common methods used when dealing with CIGAR lines.
CIGAR stands for "Compact Idiosyncratic Gapped Alignment Report" and is
a format to store alignment strings in a compact way.

The CIGAR line defines the sequence of matches/mismatches and deletions
(or gaps). For example, this cigar line 2MD3M2D2M will mean that the
alignment contains 2 matches/mismatches, 1 deletion (number 1 is omitted
in order to save some space), 3 matches/mismatches, 2 deletions and 2
matches/mismatches.

For example, given the following
 - original sequence: AACGCTT
 - cigar line: 2MD3M2D2M

The aligned sequence will be:
 M M D M M M D D M M
 A A - C G C - - T T

=head1 SYNOPSIS

 my $orig_seq = 'AACGCTT';
 my $cigar_line = '2MD3M2D2M';
 my $expanded_cigar = 'MMDMMMDDMM';
 my $aligned_seq = 'AA-CGC--TT';

 (compose_sequence_with_cigar($orig_seq, $cigar_line) ne $aligned_seq) or die;
 (cigar_from_alignment_string($aligned_seq) ne $cigar_line) or die;
 (expand_cigar($cigar_line) ne $expanded_cigar) or die;
 (collapse_cigar($expanded_cigar) ne $cigar_line) or die;

=head1 METHODS

=cut

package Bio::EnsEMBL::Compara::Utils::Cigars;

use strict;
use warnings;
no warnings ('substr');

use Bio::EnsEMBL::Utils::Exception qw(throw);


=head2 compose_sequence_with_cigar

  Arg [1]    : String $sequence
  Arg [2]    : String $cigar_line
  Arg [3]    : Integer $expansion_factor (default: 1)
  Example    : my $alignment_string = compose_sequence_with_cigar($aligned_member->other_sequence('cds'), $aligned_member->cigar_line, 3)
  Description: Converts the given sequence into an alignment string
               by composing it with the cigar_line. $expansion_factor
               can be set to accomodate CDS sequences
  Returntype : string

=cut

sub compose_sequence_with_cigar {
    my $sequence = shift;
    my $cigar_line = uc shift;
    my $expansion_factor = shift || 1;

    my $seq_has_spaces = ($sequence =~ tr/ //);
    my $alignment_string = "";
    my $seq_start = 0;

    throw("Invalid cigar_line '$cigar_line'\n") if $cigar_line !~ /^[0-9A-Z]*$/;

    while ($cigar_line =~ /(\d*)([A-Z])/g) {

        my $length = ($1 || 1) * $expansion_factor;
        my $char = $2;

        if ($char eq 'D') {

            $alignment_string .= "-" x $length;

        } elsif ($char eq 'M' or $char eq 'I') {

            my $substring = substr($sequence, $seq_start, $length) || '';
            if ($seq_has_spaces) {
                my $nsp = 0;
                while ((my $nsp2 = ($substring =~ tr/ //)) != $nsp) {
                    $substring = substr($sequence, $seq_start, $length+$nsp2);
                    $nsp = $nsp2;
                }
                $length += $nsp;
            }
            if (length($substring) < $length) {
                # Some codons may be incomplete
                $substring .= ('N' x ($length - length($substring)));
            }
            $alignment_string .= $substring if ($char eq 'M');
            $seq_start += $length;

        } else {
            throw("'$char' characters in cigar lines are not currently handled. But perhaps they should :)\n");
        }
    }

    # NOTE: It would be good to check that the length of the cigar line
    # matches the length of the sequence but it is unfortunately not
    # possible when applying a protein cigar to its cds. In Ensembl, there
    # is often a slight difference at the last nucleotides. There are even
    # cases (d.melanogaster) where the difference is hundreds of
    # nucleotides.

    return $alignment_string;
}


=head2 cigar_from_alignment_string

  Arg [1]    : String $alignment_string
  Example    : my $cigar_line = cigar_from_alignment_string($alignment_string)
  Description: Converts the given aligned sequence into a cigar line.
               The gaps indicated by '-' in the alignment string are
               transformed in 'D'. The matches (non '-' character) are
               transformed in 'M'.
  Returntype : string

=cut

sub cigar_from_alignment_string {
    my $alignment_string = shift;
    $alignment_string =~ s/\*/X/g;

    my $cigar_line = '';
    while($alignment_string=~/(?:\b|^)(.)(.*?)(?:\b|$)/g) {
        $cigar_line .= ($2 ? length($2)+1 : '').(($1 eq '-') ? 'D' : ($1 eq '.' ? 'X' : 'M'));
    }

    return $cigar_line;
}


=head2 expand_cigar

  Arg [1]    : String $cigar_line
  Example    : my $expanded_cigar = expand_cigar($cigar_line)
  Description: Expands each block of the cigar line (like '4D')
               into a string of the matching length (here: 'DDDD')
  Returntype : string

=cut

sub expand_cigar {
    my $cigar = shift;
    my $expanded_cigar = '';
    #$cigar =~ s/(\d*)([A-Z])/$2 x ($1||1)/ge; #Expand
    while ($cigar =~ /(\d*)([A-Za-z])/g) {
        $expanded_cigar .= $2 x ($1 || 1);
    }
    return $expanded_cigar;
}


=head2 collapse_cigar

  Arg [1]    : String $cigar_line
  Example    : my $collapsed_cigar = collapse_cigar($cigar_line)
  Description: Collapses each stretch of the cigar line (like 'DDDD')
               into a compact form (here: '4D')
  Returntype : string

=cut

sub collapse_cigar {
    my $cigar = shift;
    my $collapsed_cigar = '';
    while ($cigar =~ /(\w)(\1*)/g) {
        $collapsed_cigar .= $2 ? (length($2)+1).$1 : $1;
    }
    return $collapsed_cigar;
}


=head2 alignment_length_from_cigar

  Arg [1]    : String $cigar_line
  Example    : my $alignment_length = alignment_length_from_cigar($cigar_line)
  Description: Returns how long the alignment string would be (without expanding it in memory)
  Returntype : int

=cut

sub alignment_length_from_cigar {
    my $cigar = shift;
    my $length = 0;
    while ($cigar =~ /(\d*)([A-Za-z])/g) {
        $length += ($1 || 1);
    }
    return $length;
}


=head2 consensus_cigar_line

  Arg [1..n] : String $cigar_line
  Example    : my $consensus_cigar = consensus_cigar_line($cigar1, $cigar2, $cigar3);
  Description: Creates a consensus cigar line showing the conservation of
               each position. The final cigar line is based on the three
               characters D, m, and M:
                - M indicates that the conservation is > 2/3
                - m indicates that the conservation is between 1/3 and 2/3
                - D indicates that the conservation is < 1/3
  Returntype : string

=cut

sub consensus_cigar_line {

   my @expanded_cigars = map {expand_cigar($_)} @_;
   my $num_cigars = scalar(@expanded_cigars);

   my @chars = qw(M m D);
   my $n_chars = scalar(@chars);
   push @chars, $chars[$n_chars-1];

   # Itterate through each character of the expanded cigars.
   # If there is a 'D' at a given location in any cigar,
   # set the consensus to 'D', otherwise assume an 'M'.

   my %cigar_lens = ();
   $cigar_lens{length($_)}++ for @expanded_cigars;
   throw("Not all the cigars have the same length !\n") if scalar(keys %cigar_lens) > 1;
   my $cigar_len = length( $expanded_cigars[0] );

   my $cons_cigar;
   for( my $i=0; $i<$cigar_len; $i++ ){
       my $num_deletions = 0;
       foreach my $cigar (@expanded_cigars) {
           if ( substr($cigar,$i,1) eq 'D'){
               $num_deletions++;
           }
       }
       $cons_cigar .= $chars[int($num_deletions * $n_chars / $num_cigars)];
   }

   return collapse_cigar($cons_cigar);
}


=head2 cigar_from_two_alignment_strings

  Arg [1]    : String $alignment_string1
  Arg [2]    : String $alignment_string2
  Example    : my $cigar = cigar_from_two_alignment_strings($alignment_string1, $alignment_string2);
  Description: Creates a cigar_line that refers to both alignment strings.
               The character set is composed of D, M, and I.
                - D shows a deletion in the first sequence
                - I shows a deletion in the second sequence
                - M shows a match between the two sequences
               Double gaps are not allowed.
  Exceptions : Dies if the two alignment strings have a gap at the same
               position
  Returntype : string

=cut

sub cigar_from_two_alignment_strings {

    my $seq1 = shift;
    my $seq2 = shift;

    my @chunks1;
    my @chunks2;

    $seq1 =~ s/\*/X/g;
    $seq2 =~ s/\*/X/g;

    while($seq1=~/(?:\b|^)(.)(.*?)(?:\b|$)/g) {
        push @chunks1, [($1 eq '-'), ($2 ? length($2)+1 : 1)];
    }
    while($seq2=~/(?:\b|^)(.)(.*?)(?:\b|$)/g) {
        push @chunks2, [($1 eq '-'), ($2 ? length($2)+1 : 1)];
    }

    my $len1;
    my $gap1;
    my $len2;
    my $gap2;
    my $cigar_line;
    while (@chunks1 or @chunks2) {

        ($gap1, $len1) = @{shift @chunks1} unless $len1;
        ($gap2, $len2) = @{shift @chunks2} unless $len2;
        die "Double gaps are not allowed in '$seq1' / '$seq2'" if $gap1 and $gap2;
        #if ($gap1 and $gap2) {
        #    if ($gap1 < $gap2) {
        #        $gap2 -= $gap1;
        #        $gap1 = 0;
        #    } else {
        #        $gap1 -= $gap2;
        #        $gap2 = 0;
        #    }
        #}

        my $minlen = $len1 <= $len2 ? $len1 : $len2;
        $cigar_line .= ($minlen > 1 ? $minlen : '').($gap1 ? 'D' : ($gap2 ? 'I' : 'M'));
        $len2 -= $minlen;
        $len1 -= $minlen;
    };
    die "lengths do not match: $len1 / $len2" if $len1 or $len2;
    return $cigar_line;
}


=head2 minimize_cigars

  Arg [1..n] : String $cigar_lines
  Example    : my @subcigars = minimize_cigars($member1->cigar_line, $member2->cigar_line);
  Description: Removes the columns that are composed of gaps only and
               builds shorter cigar lines.
  Returntype : array of strings

=cut

sub minimize_cigars {

    my @expanded_cigars = map {[split(//, expand_cigar($_))]} @_;
    my $num_cigars = scalar(@expanded_cigars);
    my $len = scalar(@{$expanded_cigars[0]});

    my @good_i;
    foreach my $i (0..($len-1)) {
        if (grep {$_->[$i] eq 'M'} @expanded_cigars) {
            push @good_i, $i;
        }
    }

    my @new_cigars;
    foreach my $exp_cig (@expanded_cigars) {
        push @new_cigars, collapse_cigar(join('', map {$exp_cig->[$_]} @good_i));
    }

    return @new_cigars;
}


=head2 identify_removed_columns

  Arg [1]    : Hashref of the initial alignment strings
  Arg [2]    : Hashref of the filtered alignment strings
  Arg [3]    : "scaling" integer (default 1). Use 3 to scale cDNA alignments to protein-space coordinates
  Example    : my $removed_columns = identify_removed_columns({'seq1' => $aln1, 'seq2' => $aln2}, {'seq1' => $fil1, 'seq2' => $fil2});
  Description: Compares each alignment string to its filtered version
               and compiles a list of kept / discarded columns.
               The return string is like "[0,0],[6,8]". Here, two regions
               are removed: from column 0 to 0, and from column 6 to 8.
               That string can be "eval"ed and given to Bio::SimpleAlign::remove_columns()
  Returntype : string

=cut

sub identify_removed_columns {

    my $initial_strings  = shift;
    my $filtered_strings = shift;
    my $cdna             = shift;

    #print STDERR Dumper($initial_strings, $filtered_strings);
    die sprintf("The number of sequences do not match: initial=%d filtered=%d\n", scalar(keys %$initial_strings), scalar(keys %$filtered_strings)) if scalar(keys %$initial_strings) != scalar(keys %$filtered_strings);

    my $start_segment = undef;
    my @filt_segments = ();
    my $j = 0;
    my $next_filt_column = undef;

    my @seq_keys = keys %$initial_strings;
    my $ini_length = length($initial_strings->{$seq_keys[0]});
    my $filt_length = length($filtered_strings->{$seq_keys[0]});
    #print Dumper($ini_length, $filt_length, scalar(@seq_keys));

    foreach my $i (0..($ini_length-1)) {
        unless ($next_filt_column) {
            $next_filt_column = uc join('', map {substr($filtered_strings->{$_}, $j, 1)} @seq_keys);
        }
        my $next_ini_column = uc join('', map {substr($initial_strings->{$_}, $i, 1)} @seq_keys);
        #print STDERR "Comparing ini=$i:$next_ini_column to fil=$j:$next_filt_column\n";

        # Treebest also replaces segments with Ns
        my $filt_without_N = $next_filt_column;
        $filt_without_N =~ s/N/substr($next_ini_column, pos($filt_without_N), 1) ne '-' ? substr($next_ini_column, pos($filt_without_N), 1) : 'N'/eg;

        if (($next_ini_column eq $next_filt_column) or ($next_ini_column eq $filt_without_N)) {
            $j++;
            $next_filt_column = undef;
            if (defined $start_segment) {
                push @filt_segments, [$start_segment, $i-1];
                $start_segment = undef;
            }
        } else {
            if (not defined $start_segment) {
                $start_segment = $i;
            }
        }
    }
    die "Could not match alignments" if $j+1 < $filt_length;

    if (defined $start_segment) {
        push @filt_segments, [$start_segment, $ini_length-1];
    }

    if ($cdna) {
        # the coordinates are for the CDNA alignments
        foreach my $x (@filt_segments) {
            $x->[0] /= 3;
            $x->[1] = ($x->[1]-2)/3;
        }
    }

    return join(',', map {sprintf('[%d,%d]', @$_)} @filt_segments);
}

=head2 get_cigar_breakout

  Arg [1]    : String $cigar_line
  Example    : my %cigar_breakout = get_cigar_breakout($cigar_line)
  Description: Return a hash with the quantities of 'M', 'I' and 'D' of the cigar line (like '2M D 3M 2D I 2M')
               'M' => 7
               'I' => 1
               'D' => 3

  Returntype : hash

=cut

sub get_cigar_breakout {
    my $cigar = shift;
    my %breakout;
    while ($cigar =~ /(\d*)([A-Za-z])/g) {
        $breakout{$2} += $1 || 1;
    }
    return %breakout;
}

=head2 get_cigar_array

  Arg [1]    : String $cigar_line
  Example    : my %cigar_breakout = get_cigar_array($cigar_line)
  Description: Return an array of the cigar line, e.g.: [['M', 34], ['D', 12], ['M', 5] ...]

  Returntype : arrayref

=cut

sub get_cigar_array {
    my $cigar = shift;
    my @cigar_array;
    while ($cigar =~ /(\d*)([A-Za-z])/g) {
        push(@cigar_array,[$2,$1||1]);
    }
    return \@cigar_array;
}

=head2 create_2x_cigar_line

    Arg[1]      : String $aligned_sequence
    Arg[2]      : Arrayref $genomic_align_deletions
    Description : create cigar line for 2x genomes manually because I need to add in the
                  insertions, that is "I" in the cigar_line to represent the 2x-only sequences
                  that are not found in the reference species which I removed during the
                  creation of the _create_mfa routine.
    Returntype  : String $cigar_line
                  
=cut

sub create_2x_cigar_line {
    my ($self, $aligned_sequence, $ga_deletions) = @_;

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
	    $elem = _cigar_element($mode, $this_len);
	} elsif ($piece =~ /\./) {
	    $mode = "X"; # X for pads (in 2X genomes)
	    $elem = _cigar_element($mode, $this_len);
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
		    $elem .= _cigar_element($mode, $piece_len);
		    $elem .= _cigar_element("I", $this_del->{len});
		    $prev_pos = $this_del->{pos};
		    
		}
		#add final bit
		$elem .= _cigar_element($mode, ($base_pos+$this_len) - $this_del_array->[-1]->{pos});
	    } else {
		$elem = _cigar_element($mode, $this_len);
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
sub _cigar_element {
    my ($mode, $len) = @_;
    my $elem = '';
    if ($len == 1) {
	$elem = $mode;
    } elsif ($len > 1) { #length can be 0 if the sequence starts with a gap
	$elem = $len.$mode;
    }
    return $elem;
}

=head2 check_cigar_line

    Arg[1]      : Bio::EnsEMBL::Compara::GenomicAlign $genomic_align
    Arg[2]      : int $total_gap
    Description : check the new cigar_line is consistent ie the seq_length and number of 
                  (M+I) agree and the alignment length and total of cig_elems agree.

=cut

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
sub _add_match_elem {
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

1;
