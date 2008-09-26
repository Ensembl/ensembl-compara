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

  my $hsp = $object->retrieve_data('hsp');
  return "No data found" unless $hsp;
  my $query = $hsp->query;
  my $sbjct = $hsp->hit;

  # Space to reserve for the numbering at the line start
  my $seq_cols = 60;
  my( $num_length ) = sort{ $b<=>$a } ( $query->start,
                                        $query->end,
                                        $sbjct->start,
                                        $sbjct->end );
  $num_length = length( $num_length );

  # Templates for the lines
  my $qtmpl = "Query: %${num_length}d %s %d\n";
  my $xtmpl = ( " " x ( $num_length + 8 ) ) .  "%s\n";
  my $htmpl = "Sbjct: %${num_length}d %s %d\n";

  # Divide the alignment strings onto lines
  my $rows = ( ( length($hsp->query_string) - 1 ) / $seq_cols ) + 1;
  my @qlines = unpack( "a$seq_cols" x $rows, $hsp->query_string );
  my @xlines = unpack( "a$seq_cols" x $rows, $hsp->homology_string );
  my @hlines = unpack( "a$seq_cols" x $rows, $hsp->hit_string );

# Things needed for counting; DNA|peptide
  my $qmultiplier = ( ( $query->end - $query->start ) /
                      ( $sbjct->end - $sbjct->start ) );
  my $smultiplier;
  if( $qmultiplier < 0.5  ){ $qmultiplier = 1; $smultiplier=3 }
  elsif( $qmultiplier > 2 ){ $qmultiplier = 3; $smultiplier=1 }
  else                     { $qmultiplier = 1; $smultiplier=1 }

  # More counting things; strand
  my $qstrand = $query->strand < 0 ? -1 : 1;
  my $sstrand = $sbjct->strand < 0 ? -1 : 1;
  my( $qstart, $qryend ) = $query->strand < 0 ?
     ( $query->end, $query->start) : ( $query->start, $query->end );
  my( $hstart, $sbjend ) = $sbjct->strand < 0 ?
    ( $sbjct->end, $sbjct->start ) : ( $sbjct->start, $sbjct->end );

  # Generate text for each line-triplet
  my @lines;
  for( my $i=0; $i<@qlines; $i++ ){

    my $qseq = $qlines[$i];
    my $hseq = $hlines[$i];
    my $qgaps = $qseq =~ tr/-/-/; # Count gaps
    my $hgaps = $hseq =~ tr/-/-/; # Count gaps
    my $qend = $qstart +((($seq_cols-$qgaps)*$qmultiplier-1)*$qstrand);
    my $hend = $hstart +((($seq_cols-$hgaps)*$smultiplier-1)*$sstrand );
    if( $i == @qlines - 1 ){
      $qend = $qryend;
      $hend = $sbjend;
    }
  my $line = '';
    $line .= sprintf( $qtmpl, $qstart, $qseq, $qend );
    $line .= sprintf( $xtmpl, $xlines[$i] );
    $line .= sprintf( $htmpl, $hstart, $hseq, $hend );
    push @lines, $line;
    $qstart = $qend + ( 1 * $qstrand );
    $hstart = $hend + ( 1 * $sstrand );
  }

  my $html .= join( "\n", @lines );
  $html .= '</pre>';

  $html .= $self->add_links('align');

  return $html;
}

1;
