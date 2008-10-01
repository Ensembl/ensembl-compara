package EnsEMBL::Web::Component::Transcript::ExonsSpreadsheet;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Transcript);
use EnsEMBL::Web::Form;

sub _init {
  my $self = shift;
  $self->cacheable( 1 );
  $self->ajaxable(  1 );
}

sub caption {
  return undef;
}

  

sub content {
  my $self = shift;
  my $object   = $self->object;

  my $table = new EnsEMBL::Web::Document::SpreadSheet( [], [], {'margin' => '1em 0px'} );
  $table->add_columns(
    {'key' => 'Number', 'title' => 'No.', 'width' => '6%', 'align' => 'center' },
    {'key' => 'exint',  'title' => 'Exon / Intron', 'width' => '15%', 'align' => 'center' },
#    {'key' => 'Chr', 'title' => 'Chr', 'width' => '10%', 'align' => 'center' },
#    {'key' => 'Strand',     'title' => 'Strand', 'width' => '10%', 'align' => 'center' },
    {'key' => 'Start', 'title' => 'Start', 'width' => '10%', 'align' => 'right' },
    {'key' => 'End', 'title' => 'End', 'width' => '10%', 'align' => 'right' },
    {'key' => 'StartPhase', 'title' => 'Start Phase', 'width' => '7%', 'align' => 'center' },
    {'key' => 'EndPhase', 'title' => 'End Phase', 'width' => '7%', 'align' => 'center' },
    {'key' => 'Length', 'title' => 'Length', 'width' => '10%', 'align' => 'right' },
    {'key' => 'Sequence', 'title' => 'Sequence', 'width' => '15%', 'align' => 'left' }
  );


  my $seq_cols   = $object->param('seq_cols') || 60;
  my $sscon      = $object->param('sscon');            # no of bp to show either side of a splice site
  my $flanking   = $object->param('flanking') || 50;    # no of bp up/down stream of transcript
  my $full_seq   = $object->param('fullseq') eq 'yes';  # flag to display full sequence (introns and exons)
  my $only_exon  = $object->param('oexon')   eq 'yes';
  my $entry_exon = $object->param('exon');
  

 # display only exons flag
  my $trans = $object->Obj;
  my $coding_start = $trans->coding_region_start;
  my $coding_end = $trans->coding_region_end;
  my @el = @{$trans->get_all_Exons};
  my $strand   = $el[0]->strand;
  my $chr_name = $el[0]->slice->seq_region_name;
  my @exon_col = qw(blue black);
  my @back_col = qw(background1 background3);
  my $background = 'background1';
  my( $exonA, $exonB, $j, $upstream, $exon_info,$intron_info );
    $sscon = 25 unless $sscon >= 1;
# works out length needed to join intron ends with dots
  my $sscon_dot_length = $seq_cols-2*($sscon % ($seq_cols/2) );
  my $flanking_dot_length = $seq_cols-($flanking%$seq_cols);
# upstream flanking seq
  if( $flanking && !$only_exon ){
    my $exon = $el[0];
    if( $strand == 1 ){
      $upstream = $exon->slice()->subseq( ($exon->start)-($flanking),   ($exon->start)-1 , $strand);
    } else {
      $upstream = $exon->slice()->subseq( ($exon->end)+1,   ($exon->end)+($flanking),  $strand);
    }
    $upstream =  lc(('.'x $flanking_dot_length).$upstream);
    $upstream =~ s/([\.\w]{$seq_cols})/$1<br \/>/g;
    $exon_info = { 'exint'    => qq(5\' upstream sequence),
                   'Sequence' => qq(<span class="exons_flank">$upstream</span>) };
    $table->add_row( $exon_info );
  }
  # Loop over each exon
  for( $j=1; $j<= scalar(@el); $j++ ) {
    my( $intron_start, $intron_end, $intron_len, $intron_seq );
    my $col = $exon_col[$j%2];                    #choose exon text colour
    $exonA = $el[$j-1];
    $exonB = $el[$j];

    my $intron_id = "Intron $j-".($j+1)  ;
    my $dots = '.'x $sscon_dot_length;
    my $seq       = uc($exonA->seq()->seq());
    my $seqlen    = length($seq);
    my $exonA_ID  = $exonA->stable_id;
    my $exonA_start   = $exonA->start;
    my $exonA_end     = $exonA->end;
    my $exonB_start   = $exonB->start if $exonB ;
    my $exonB_end     = $exonB->end if $exonB ;
    my $utrspan_start = qq(<span class="exons_utr">);  ##set colour of UTR
    my $count = 0;
    my $k = 0;


 # Is this exon entirely UTR?
    if( $coding_end < $exonA_start || $coding_start > $exonA_end ){
      $seq   =~ s/([\.\w]{$seq_cols})/$1<\/span><br \/>$utrspan_start/g ;
      $seq   .= qq(</span>);
      $seq = "$utrspan_start"."$seq";
    } elsif( $strand eq '-1' ) {
    # Handle reverse strand transcripts.  Yes, this means we have a bunch of
    # duplicated code to handle forward strand.
      my @exon_nt  = split '', $seq;
      my $coding_len =  ($exonA_end) - $coding_start + 1 ;
      my $utr_len =  $exonA_end - $coding_end   ;

      # CDS is within this exon, and we have UTR start and end
      if( $coding_start > $exonA_start &&  $coding_end < $exonA_end ) {
        $seq = qq($utrspan_start);
        for (@exon_nt){
          if( $count == $seq_cols && ($k < $coding_len && $k > $utr_len) ){
            $seq .= "<br />";
            $count =0;
          } elsif( $count == $seq_cols && ($k > $coding_len || $k < $utr_len) ){
            $seq .= "</span><br />$utrspan_start";
            $count =0;
          } elsif ($k == $utr_len) {
            $seq .= "</span>";
            if( $count == $seq_cols ) {
              $seq .= "<br />";
              $count = 0;
            }
          } elsif( $k == $coding_len ) {
            $seq .= "$utrspan_start";
            if( $count == $seq_cols ) {
             $seq .= "<br />";
              $count = 0;
            }
          }
          $seq .= $_ ;
          $count++;
          $k++;
        }
      } elsif ($coding_start > $exonA_start ) { # exon starts with UTR
        $seq = "";
        for( @exon_nt ){
          if ($count == $seq_cols && ($k > $coding_len)){
            $seq .= "</span><br />$utrspan_start";
            $count =0;
          }elsif ($count == $seq_cols && $k < $coding_len){
            $seq .= "<br />";
            $count =0;
          }elsif ($k == $coding_len){
            if ($count == $seq_cols) {
              $seq .= "<br />";
              $count = 0;
            }
            $seq .= qq($utrspan_start);
          }
          $seq .= $_ ;
          $count++;
          $k++;
        }
      } elsif($coding_end < $exonA_end ) { # exon ends with UTR
        $seq = $utrspan_start;
        for( @exon_nt ){
          if ($count == $seq_cols && $utr_len > $k ){
            $seq .= "</span><br />$utrspan_start";
            $count =0;
          } elsif ($count == $seq_cols && $k > $utr_len){
            $seq .= "<br />";
            $count =0;
         } elsif ($k == $utr_len) {
            $seq .= qq(</span>);
            if ($count == $seq_cols) {
              $seq .= "<br />";
              $count = 0;
            }
          }
          $seq .= $_ ;
          $count++;
          $k++;
        }
        $seq .= "</span>";
      } else{ # entirely coding exon
        $seq =~ s/([\.\w]{$seq_cols})/$1<br \/>/g ;
      }
    } else { # Handle forward strand transcripts
      my @exon_nt  = split '', $seq;
      my $utr_len =  $coding_start - $exonA_start ;
      my $coding_len =  $seqlen - ($exonA_end - $coding_end)  ;

      # CDS is within this exon, and we have UTR start and end
      if ($coding_start > $exonA_start &&  $coding_end < $exonA_end){
        $seq = qq($utrspan_start);
        for (@exon_nt){
          if ($count == $seq_cols && ($k > $utr_len && $k < $coding_len)){
            $seq .= "<br />";
            $count =0;
          } elsif ($count == $seq_cols && ($k < $utr_len || $k > $coding_len)){
            $seq .= "</span><br />$utrspan_start";
            $count =0;
          } elsif ($k == $utr_len) {
            $seq .= "</span>";
            if ($count == $seq_cols) {
              $seq .= "<br />";
              $count = 0;
            }
   } elsif ($k == $coding_len) {
            $seq .= "$utrspan_start";
            if ($count == $seq_cols) {
              $seq .= "<br />";
              $count = 0;
            }
          }
          $seq .= $_ ;
          $count++;
          $k++;
        }
      } elsif ($coding_start > $exonA_start ){# exon starts with UTR
        $seq = qq($utrspan_start);
        for (@exon_nt){
          if ($count == $seq_cols && ($k > $utr_len)){
            $seq .= "<br />";
            $count =0;
          } elsif ($count == $seq_cols && $k < $utr_len){
            $seq .= "</span><br />$utrspan_start";
            $count =0;
          } elsif ($k == $utr_len){
            $seq .= "</span>";
            if( $count == $seq_cols) {
              $seq .= "<br />";
              $count = 0;
            }
          }
          $seq .= $_ ;
          $count++;
          $k++;
        }
      } elsif($coding_end < $exonA_end ){ # exon ends with UTR
        $seq = '';
        for (@exon_nt){
          if ($count == $seq_cols && $coding_len > $k ){
            $seq .= "<br />";
            $count =0;
     }elsif ($count == $seq_cols && $k > $coding_len){
            $seq .= "</span><br />$utrspan_start";
            $count =0;
          }elsif ($k == $coding_len){
            if ($count == $seq_cols) {
              $seq .= "<br />";
              $count = 0;
            }
            $seq .= qq($utrspan_start);
          }
          $seq .= $_ ;
          $count++;
          $k++;
        }
        $seq .= "</span>";
      } else { # Entirely coding exon.
        $seq =~ s/([\.\w]{$seq_cols})/$1<br \/>/g ;
      }
    }
    if ($entry_exon && $entry_exon eq $exonA_ID){
      $exonA_ID = "<b>$exonA_ID</b>" ;
    }
    $exon_info = {
      'Number'    => $j,
      'exint'     => qq(<a href="/@{[$object->species]}/contigview?l=$chr_name:$exonA_start-$exonA_end;context=100">$exonA_ID</a>),
    #  'Chr'       => $chr_name, 'Strand'    => $strand,
      'Start'     => $object->thousandify( $exonA_start ),
      'End'       => $object->thousandify( $exonA_end ),
      'StartPhase' => $exonA->phase    >= 0 ? $exonA->phase     : '-',
      'EndPhase'  => $exonA->end_phase >= 0 ? $exonA->end_phase : '-',
      'Length'    => $object->thousandify( $seqlen ),
      'Sequence'  => qq(<span class="exons_exon">$seq</span>)
    };
    $table->add_row( $exon_info );
    if( !$only_exon && $exonB ) {
      eval{
        if($strand == 1 ) { # ...on the forward strand
          $intron_start = $exonA_end+1;
          $intron_end = $exonB_start-1;
          $intron_len = ($intron_end - $intron_start) +1;
          if (!$full_seq && $intron_len > ($sscon *2)){
            my $seq_start_sscon = $exonA->slice()->subseq( ($intron_start),   ($intron_start)+($sscon-1),  $strand);
            my $seq_end_sscon = $exonB->slice()->subseq( ($intron_end)-($sscon-1), ($intron_end), $strand);
            $intron_seq = "$seq_start_sscon$dots$seq_end_sscon";
          } else {
            $intron_seq = $exonA->slice()->subseq( ($intron_start),   ($intron_end),   $strand);
          }
        } else { # ...on the reverse strand
          $intron_start = $exonB_end+1;
          $intron_end = $exonA_start-1;
          $intron_len = ($intron_end - $intron_start) +1;
          if (!$full_seq && $intron_len > ($sscon *2)){
            my $seq_end_sscon = $exonA->slice()->subseq( ($intron_start), ($intron_start)+($sscon-1), $strand);
            my $seq_start_sscon = $exonB->slice()->subseq( ($intron_end)-($sscon-1), ($intron_end), $strand);
            $intron_seq = "$seq_start_sscon$dots$seq_end_sscon";
          } else {
            $intron_seq = $exonA->slice()->subseq( ($intron_start),   ($intron_end),   $strand);
          }
        }
      }; # end of eval
      $intron_seq =  lc($intron_seq);
      $intron_seq =~ s/([\.\w]{$seq_cols})/$1<br \/>/g;

      $intron_info = {
        'Number'    => "&nbsp;",
        'exint'     => qq(<a href="/@{[$object->species]}/contigview?l=$chr_name:$intron_start-$intron_end;context=100">$intron_id</a>),
      # 'Chr'       => $chr_name, 'Strand'    => $strand,
        'Start'     => $object->thousandify( $intron_start ),
        'End'       => $object->thousandify( $intron_end ),
        'Length'    => $object->thousandify( $intron_len ),
        'Sequence'  => qq(<span class="exons_intron">$intron_seq</span>)
      };
      $table->add_row( $intron_info );
    }
  }     #finished foreach loop
  if( $flanking && !$only_exon ){
    my $exon = $exonB ? $exonB : $exonA;
    my $downstream;
    if( $strand == 1 ){
      $downstream = $exon->slice()->subseq( ($exon->end)+1,   ($exon->end)+($flanking),  $strand);
    } else {
      $downstream = $exon->slice()->subseq( ($exon->start)-($flanking),   ($exon->start)-1 , $strand);
    }
    $downstream =  lc($downstream). ('.'x $flanking_dot_length);
    $downstream =~ s/([\.\w]{$seq_cols})/$1<br \/>/g;
    $exon_info = { 'exint'    => qq(3\' downstream sequence),
                   'Sequence' => qq(<span class="exons_flank">$downstream</span>) };
    $table->add_row( $exon_info );
  }

  return $table->render;
}

1;

