=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2022] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::TextSequence::Markup::LineNumbers;

use strict;
use warnings;

use parent qw(EnsEMBL::Web::TextSequence::Markup);

sub markup {
  my ($self, $sequence, $markup, $config) = @_; 

  my $n = 0; # Keep track of which element of $sequence we are looking at
  
  foreach my $sl (@{$config->{'slices'}}) {
    my $slice       = $sl->{'slice'};
    my $seq         = $sequence->[$n];
    my $align_slice = 0;
    my @numbering;
    
    if (!$slice && !$sl->{'seq'}) {
      @numbering = ({});
    } elsif ($slice && $config->{'line_numbering'} eq 'slice') {
      my $start_pos = 0;
    
      if ($slice->isa('Bio::EnsEMBL::Compara::AlignSlice::Slice')) {
       $align_slice = 1;
    
        # Get the data for all underlying slices
        foreach (@{$sl->{'underlying_slices'}}) {
          my $ostrand            = $_->strand;
          my $sl_start           = $_->start;
          my $sl_end             = $_->end;
          my $sl_seq_region_name = $_->seq_region_name;
          my $sl_seq             = $_->seq;
          my $end_pos            = $start_pos + length ($sl_seq) - 1;
    
          if ($sl_seq_region_name ne 'GAP') {
            push @numbering, {
              dir       => $ostrand,
              start_pos => $start_pos,
              end_pos   => $end_pos,
              start     => $ostrand > 0 ? $sl_start : $sl_end,
              end       => $ostrand > 0 ? $sl_end   : $sl_start,
              label     => $sl_seq_region_name . ':' 
            };  
    
            # Padding to go before the label
            $config->{'padding'}{'pre_number'} = length $sl_seq_region_name if length $sl_seq_region_name > $config->{'padding'}{'pre_number'};
          }   
    
          $start_pos += length $sl_seq;
        }   
      } else {
        # Get the data for the slice
        my $ostrand     = $slice->strand;
        my $slice_start = $slice->start;
        my $slice_end   = $slice->end;
    
        @numbering = ({
          dir   => $ostrand,
          start => $ostrand > 0 ? $slice_start : $slice_end,
          end   => $ostrand > 0 ? $slice_end   : $slice_start,
          label => $slice->seq_region_name . ':'
        });
      }
    } else {
      # Line numbers are relative to the sequence (start at 1)
      @numbering = ({
        dir   => 1,
        start => $config->{'sub_slice_start'} || 1,
        end   => $config->{'sub_slice_end'}   || $config->{'length'},
        label => ''
      });
    }
   
    my $data      = shift @numbering;
    my $s         = 0;
    my $e         = $config->{'display_width'} - 1;
    my $row_start = $data->{'start'};
    my $loop_end  = $config->{'length'} + $config->{'display_width'}; # One line longer than the sequence so we get the last line's numbers generated in the loop
    my ($start, $end);
    while ($e < $loop_end) {
      my $shift = 0; # To check if we've got a new element from @numbering
         $start = '';
         $end   = '';

      # Comparison species
      if ($align_slice) {
        # Build a segment containing the current line of sequence
        my $segment        = substr $slice->{'seq'}, $s, $config->{'display_width'};
        my $seq_length_seg = $segment =~ s/\.//rg;
        my $seq_length     = length $seq_length_seg; # The length of the sequence which does not consist of a .
        my $first_bp_pos   = 0; # Position of first letter character
        my $last_bp_pos    = 0; # Position of last letter character
        my $old_label      = '';

        if ($segment =~ /\w/) {
          $segment      =~ /(^\W*).*\b(\W*$)/;
          $first_bp_pos = 1 + length $1 unless length($1) == length $segment;
          $last_bp_pos  = $2 ? length($segment) - length($2) : length $segment;
        }

        # Get the data from the next slice if we have passed the end of the current one
        while (scalar @numbering && $e >= $numbering[0]{'start_pos'}) {          
          $old_label ||= $data->{'label'} if ($data->{'end_pos'} > $s); # Only get the old label for the first new slice - the one at the start of the line
          $shift       = 1;
          $data        = shift @numbering;

          $data->{'old_label'} = $old_label;

          # Only set $row_start if the line begins with a .
          # If it does not, the previous slice ends mid-line, so we just carry on with it's start number
          $row_start = $data->{'start'} if $segment =~ /^\./;
        }

        if ($seq_length && $last_bp_pos) {
          (undef, $row_start) = $slice->get_original_seq_region_position($s + $first_bp_pos); # This is NOT necessarily the same as $end + $data->{'dir'}, as bits of sequence could be hidden
          (undef, $end)       = $slice->get_original_seq_region_position($e + 1 + $last_bp_pos - $config->{'display_width'}); # For AlignSlice display the position of the last meaningful bp

          $start = $row_start;
        }

        $s = $e + 1;
      } else { # Single species
        $end       = $e < $config->{'length'} ? $row_start + ($data->{'dir'} * $config->{'display_width'}) - $data->{'dir'} : $data->{'end'};
        $start     = $row_start;
        $row_start = $end + $data->{'dir'} if $end; # Next line starts at current end + 1 for forward strand, or - 1 for reverse strand
      }

      my $label      = $start && $config->{'comparison'} ? $data->{'label'} : '';
      my $post_label = $shift && $label && $data->{'old_label'} ? $label : '';
         $label      = $data->{'old_label'} if $post_label;

      push @{$config->{'line_numbers'}{$n}}, { start => $start, end => $end || undef, label => $label, post_label => $post_label };

      # Increase padding amount if required
      my $slen = (length $start)||0;
      $config->{'padding'}{'number'} = $slen if length $slen > ($config->{'padding'}{'number'}||0);

      $e += $config->{'display_width'};
    }

    $n++;
  }

  $config->{'padding'}{'pre_number'}++ if $config->{'padding'}{'pre_number'}; # Compensate for the : after the label

  $config->{'alignment_numbering'} = 1 if $config->{'line_numbering'} && $config->{'line_numbering'} eq 'slice' && $config->{'align'};
}

1;
