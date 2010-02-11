package EnsEMBL::Web::Component::Transcript::ExonsSpreadsheet;

use strict;
use warnings;
no warnings "uninitialized";

use EnsEMBL::Web::Document::SpreadSheet;

use base qw(EnsEMBL::Web::Component::Transcript);

sub _init {
  my $self = shift;
  $self->cacheable(1);
  $self->ajaxable(1);
}

sub content {
  my $self         = shift;
  my $object       = $self->object;
  my $seq_cols     = $object->param('seq_cols') || 60;
  my $sscon        = $object->param('sscon')    || 25;   # no of bp to show either side of a splice site
  my $flanking     = $object->param('flanking') || 50;   # no of bp up/down stream of transcript
  my $full_seq     = $object->param('fullseq') eq 'yes'; # flag to display full sequence (introns and exons)
  my $only_exon    = $object->param('oexon')   eq 'yes'; # display only exons
  my $entry_exon   = $object->param('exon');
  my $transcript   = $object->Obj;
  my $coding_start = $transcript->coding_region_start;
  my $coding_end   = $transcript->coding_region_end;
  my @exons        = @{$transcript->get_all_Exons};
  my $strand       = $exons[0]->strand;
  my $chr_name     = $exons[0]->slice->seq_region_name;
  my $dots         = '.' x ($seq_cols - 2*($sscon % ($seq_cols/2))); # works out length needed to join intron ends with dots;
  my $i            = 0;
  my @data;
  
  # Loop over each exon
  foreach my $exon (@exons) {
    my $next_exon  = $exons[++$i];
    my $seq        = uc $exon->seq->seq;
    my $seq_length = length $seq;
    my $exon_id    = $exon->stable_id;
    my $exon_start = $exon->start;
    my $exon_end   = $exon->end;
    my $utr_start  = $coding_start > $exon_start; # exon starts with UTR
    my $utr_end    = $coding_end   < $exon_end;   # exon ends with UTR
    my $count      = 0;
    my $j          = 0;
    
    $exon_id = "<strong>$exon_id</strong>" if $entry_exon && $entry_exon eq $exon_id;
    
    if ($utr_start || $utr_end) {
      my @exon_nt   = split '', $seq;
      my ($coding_length, $utr_length) = $strand == 1 ? ($seq_length - ($exon_end - $coding_end), $coding_start - $exon_start) : ($exon_end - $coding_start + 1, $exon_end - $coding_end);
      
      $seq = ($strand == 1 && $utr_start) || ($strand == -1 && $utr_end) ? '<span class="exons_utr">' : '';
      
      my ($open_span, $close_span) = $strand == 1 ? ($utr_end, $utr_start) : ($utr_start, $utr_end);
      my $open_spans = !!$seq;
      
      foreach (@exon_nt) {
        if ($count == $seq_cols) {
          $seq  .= "\n";
          $count = 0;
        }
        
        if ($open_span && $j == $coding_length) {
          $seq .= '<span class="exons_utr">';
          $open_spans++;
        } elsif ($close_span && $j == $utr_length) {
          $seq .= '</span>';
          $open_spans--;
        }
        
        $seq .= $_;
        
        $count++;
        $j++;
      }
      
      $seq .= '</span>' while $open_spans--;
    } else { # Entirely coding exon
      $seq =~ s/([\.\w]{$seq_cols})/$1\n/g;
      $seq = qq{<span class="exons_utr">$seq</span>} if $coding_end < $exon_start || $coding_start > $exon_end;
    }
    
    push @data, {
      Number     => $i,
      exint      => sprintf('<a href="%s">%s</a>', $object->_url({ type => 'Location', action => 'View', r => "$chr_name:" . ($exon_start - 50) . '-' . ($exon_end + 50) }), $exon_id),
      Start      => $self->thousandify($exon_start),
      End        => $self->thousandify($exon_end),
      StartPhase => $exon->phase     >= 0 ? $exon->phase     : '-',
      EndPhase   => $exon->end_phase >= 0 ? $exon->end_phase : '-',
      Length     => $self->thousandify($seq_length),
      Sequence   => qq{<pre class="exons_exon">$seq</pre>}
    };
    
    # Add intronic sequence
    if ($next_exon && !$only_exon) {
      my ($intron_start, $intron_end) = $strand == 1 ? ($exon_end + 1, $next_exon->start - 1) : ($next_exon->end + 1, $exon_start - 1);
      my $intron_length = $intron_end - $intron_start + 1;
      my $intron_id     = "Intron $i-" . ($i+1);
      my $intron_seq;
      
      eval {
        if (!$full_seq && $intron_length > ($sscon * 2)) {
          my $start = $exon->slice->subseq($intron_start, $intron_start + $sscon - 1, $strand);
          my $end   = $next_exon->slice->subseq($intron_end - ($sscon - 1), $intron_end, $strand);
          
          $intron_seq = $strand == 1 ? "$start$dots$end" : "$end$dots$start";
        } else {
          $intron_seq = $exon->slice->subseq($intron_start, $intron_end, $strand);
        }
      };
      
      $intron_seq = lc $intron_seq;
      $intron_seq =~ s/([\.\w]{$seq_cols})/$1\n/g;
      
      push @data, {
        Number   => '&nbsp;',
        exint    => sprintf('<a href="%s">%s</a>', $object->_url({ type => 'Location', action => 'View', r => "$chr_name:" . ($intron_start - 50) . '-' . ($intron_end + 50) }), $intron_id),
        Start    => $self->thousandify($intron_start),
        End      => $self->thousandify($intron_end),
        Length   => $self->thousandify($intron_length),
        Sequence => qq{<pre class="exons_intron">$intron_seq</pre>}
      };
    }
  }
  
  # Add flanking sequence
  if ($flanking && !$only_exon) {
    my ($first, $last) = ($exons[0], $exons[-1]);
    my $flanking_dots  = '.' x ($seq_cols - ($flanking % $seq_cols));
    my ($upstream, $downstream);
    
    if ($strand == 1) {
      $upstream   = $first->slice->subseq($first->start - $flanking, $first->start - 1, $strand);
      $downstream = $last->slice->subseq($last->end + 1, $last->end + $flanking, $strand);
    } else {
      $upstream   = $first->slice->subseq($first->end + 1, $first->end + $flanking, $strand);
      $downstream = $last->slice->subseq($last->start - $flanking, $last->start - 1, $strand);
    }
    
    $upstream   = lc($flanking_dots . $upstream);
    $downstream = lc($downstream . $flanking_dots);
    
    s/([\.\w]{$seq_cols})/$1\n/g for $upstream, $downstream;
    
    unshift @data, {
      exint    => "5' upstream sequence", 
      Sequence => qq{<pre class="exons_flank">$upstream</pre>}
    };
    
    push @data, { 
      exint    => "3' downstream sequence", 
      Sequence => qq(<pre class="exons_flank">$downstream</pre>)
    };
  }
  
  my $table = new EnsEMBL::Web::Document::SpreadSheet([
      { key => 'Number',     title => 'No.',           width => '6%',  align => 'center' },
      { key => 'exint',      title => 'Exon / Intron', width => '15%', align => 'center' },
      { key => 'Start',      title => 'Start',         width => '10%', align => 'right'  },
      { key => 'End',        title => 'End',           width => '10%', align => 'right'  },
      { key => 'StartPhase', title => 'Start Phase',   width => '7%',  align => 'center' },
      { key => 'EndPhase',   title => 'End Phase',     width => '7%',  align => 'center' },
      { key => 'Length',     title => 'Length',        width => '10%', align => 'right'  },
      { key => 'Sequence',   title => 'Sequence',      width => '15%', align => 'left'   }
    ], 
    \@data, 
    { margin => '1em 0px' }
  );
  
  return $table->render;
}

1;
