=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2021] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::IOWrapper::GXF;

## Parent for GFF/GTF parsers, containing some common functionality

use strict;
use warnings;
no warnings 'uninitialized';

use parent qw(EnsEMBL::Web::IOWrapper);


sub add_to_transcript {
  my ($self, $feature, $args, %transcript) = @_;

  my $no_separate_transcript = $args->{'no_separate_transcript'};
  my $seen = $args->{'seen'}; 

  ## Strip the segment down to its bare essentials
  my $type      = $feature->{'type'};
  my $segment   = {
                   'start' => $feature->{'start'}, 
                   'end'   => $feature->{'end'},
                   'type'  => $type,
                  };

  if ($no_separate_transcript) {
    $transcript{'start'}  = $_->{'start'} if $_->{'start'} < $transcript{'start'};
    $transcript{'end'}    = $_->{'end'} if $_->{'end'} > $transcript{'end'};
  }

  if ($type eq 'UTR') {
    ## which UTR are we in? Note that we go by drawing direction, not strand direction
    if ($seen->{'cds'}) {
      if (!$seen->{'utr_right'}) {
        $seen->{'utr_right'}  = $_->{'start'};
        my $previous_exon = $transcript{'structure'}->[-1];
        $previous_exon->{'end'}   = $_->{'end'};
        $previous_exon->{'utr_3'} = $_->{'start'} - $previous_exon->{'start'};

        #warn ">>> START OF 3' UTR: ".$_->{'start'};
      }
    }
    else {
      $seen->{'utr_left_start'} = $_->{'start'};
      $seen->{'utr_left_end'}   = $_->{'end'};
      #warn ">>> END OF 5' UTR: ".$_->{'end'};
    }
  }  
  elsif ($type eq 'CDS') {
    $seen->{'cds'} = 1;
    if ($seen->{'utr_left_start'} && $seen->{'utr_left_start'} < $_->{'start'}) {
      ## Add 1 to compensate for stop/start codon
      $segment->{'utr_5'} = $seen->{'utr_left_end'} - $seen->{'utr_left_start'} + 1;
      delete $seen->{'utr_left_start'};
      delete $seen->{'utr_left_end'};
    }
    push @{$transcript{'structure'}}, $segment; 
  }
  elsif ($type eq 'exon' && !$seen->{'cds'}) { ## Non-coding gene or UTR
    if (($seen->{'utr_left'} && $seen->{'utr_left'} > $_->{'end'}) || ($_->{'transcript_biotype'} ne 'protein_coding')) {
      $segment->{'non_coding'} = 1;
    }
    push @{$transcript{'structure'}}, $segment; 
  }
  else {
    push @{$transcript{'structure'}}, $segment; 
  }
  return ($args, %transcript);
}

1;
