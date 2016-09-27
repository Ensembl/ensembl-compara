package EnsEMBL::Web::TextSequence::Markup::TranscriptLineNumbers;

use strict;
use warnings;

use parent qw(EnsEMBL::Web::TextSequence::Markup);

sub markup {
  my ($self, $sequence, $markup, $config) = @_; 

  # Keep track of which element of $sequence we are looking at
  my $n = 0;
  my $length = $config->{'length'};

  foreach my $name (@{$config->{'names'}}) {
    my $seq  = $sequence->[$n]->legacy;
    my $data = $name ne 'snp_display' ? { 
      dir   => 1,  
      start => 1,
      end   => $length,
      label => ''
    } : {}; 
       
    my $s = 0;
    my $e = $config->{'display_width'} - 1;
       
    my $row_start = $data->{'start'};
    my ($start, $end);
       
    # One line longer than the sequence so we get the last line's numbers generated in the loop
    my $loop_end = $length + $config->{'display_width'};
       
    while ($e < $loop_end) {
      $start = ''; 
      $end   = ''; 
        
      my $seq_length = 0;
      my $segment    = ''; 
        
      # Build a segment containing the current line of sequence        
      for ($s..$e) {
        # Check the array element exists - must be done so we don't create new elements and mess up the padding at the end of the last line
        if ($seq->[$_]) {
          $seq_length++ if $config->{'line_numbering'} eq 'slice' || $seq->[$_]{'letter'} =~ /\w/;
          $segment .= $seq->[$_]{'letter'};
        }   
      }   
       
      # Reference sequence starting with N or NN means the transcript begins mid-codon, so reduce the sequence length accordingly.
      $seq_length -= length $1 if $segment =~ /^(N+)\w/;
        
      $end   = $row_start + $seq_length - $data->{'dir'};
      $start = $row_start if $seq_length;
        
      # If the line starts --,  =- or -= it is at the end of a protein section, so take one off the line number
      $start-- if ($start||0) > $data->{'start'} && $segment =~ /^([=-]{2})/;
        
      # Next line starts at current end + 1 for forward strand, or - 1 for reverse strand
      $row_start = $end + $data->{'dir'} if $start && $end;
        
      # Remove the line number if the sequence doesn't start at the beginning of the line
      $start = '' if $segment =~ /^(\.|N+\w)/;
      $end = '' if $segment =~ /^(\.|N+\w)+$/;

      $s = $e + 1;

      push @{$config->{'line_numbers'}{$n}}, { start => $start, end => $end || undef };

      # Increase padding amount if required
      $config->{'padding'}{'number'} = length $start if length $start > $config->{'padding'}{'number'};

      $e += $config->{'display_width'};
    }

    $n++;
  }

  $config->{'padding'}{'pre_number'}++ if $config->{'padding'}{'pre_number'}; # Compensate for the : after the label
}

1;
