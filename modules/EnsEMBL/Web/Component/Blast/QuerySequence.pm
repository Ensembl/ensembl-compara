package EnsEMBL::Web::Component::Blast::Alignment;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Blast);
use CGI qw(escapeHTML);
use EnsEMBL::Web::Form;

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  0 );
  $self->configurable( 0 );
}

sub content {
  my $self = shift;
  my $object = $self->object;
  my $run = $object->retrieve_runnable;
  my $hit = $object->retrieve_hit;
  my $hsp = $object->retrieve_hsp;

  my $seq  = $run->seq();
  my @hsps = ( $hit ? $hit->hsps : $hsp );

  # Define some maps
  my %colour_map = (D=>'black',
                    M=>'darkblue',
                    S=>'darkred');

  my %cigar_map = ( 'DD' => 'D',
                    'DM' => 'M',
                    'MD' => 'M',
                    'MM' => 'M',
                    'SD' => 'S',
                    'SM' => 'S',
                    'SS' => 'S',
                    'DS' => 'S',
                    'MS' => 'S' );
  # End maps

  $html .= qq(
<span class="sequence" style="color:$colour_map{'S'}">THIS STYLE:</span> Matching bases for selected HSP<br /> );

  if( @hsps > 1 ){
    $html .= qq(
<span class="sequence" style="color:$colour_map{'M'}">THIS STYLE:</span> Matching bases for other HSPs in selected hit<br /> );
  }
  $html .= qq(
<pre>);

  $html .= "&gt;".$seq->display_id."\n";
#  my $start = $hsp->query->start;
#  my $end   = $hsp->query->end;

  my $chars  = 60;
  my $length = $seq->length;
  my $hsp_id = $hsp ? $hsp->token : '';

  # Create string mask representing formats for the query sequence
  my $sel_hsp;
  my $strmask = 'D' x $length; # Initially unmatched
  foreach my $ihsp( @hsps ){
    my $start  = $ihsp->query->start - 1;
    my $end    = $ihsp->query->end;
    my $lnth   = $end - $start;
    substr( $strmask, $start, $lnth ) = 'M' x $lnth; # Mask the matches
    if( ! $sel_hsp and $ihsp->token eq $hsp_id ){ $sel_hsp = $hsp }
  }
  if( my $ihsp = $sel_hsp ){
    my $start  = $ihsp->query->start - 1;
    my $end    = $ihsp->query->end;
    my $lnth   = $end - $start;
    substr( $strmask, $start, $lnth ) = 'S' x $lnth; # Mask the selected match
  }

    # Split the string mask into same-letter chunks,
  # and create a cigar string from the chunks
  my $f = 0; # flip-flop
  my @hit_cigar = map{
    ($f=1-$f) ? [ length($_), substr($_,0,1) ] : ()
  } $strmask =~ /((.)\2*)/g;

  # Create the marked-up FASTA-like string from the sequence and cigar mask
  my $i = 0;
  while( $i < $length ){
    my $j = 0;
    while( $j < $chars ){
      my $cig = shift @hit_cigar || last;

      my( $n, $t ) = @$cig;
      if( ! $n ){ next }

      if( $n > $chars-$j ){
        unshift( @hit_cigar, [ $n-($chars-$j), $t ] );
        $n = $chars-$j;
      }
      $html .= qq(<span style="color:$colour_map{$t}">);
      $html .= $seq->subseq( $i+$j+1, $i+$j+$n);
      $html .= qq(</span>);
      $j += $n;
    }
    $html .= "\n";
    $i += $chars;
  }
  $html .= "</span></pre>\n";

  $html .= $self->add_links('query');

  return $html;
}

1;
