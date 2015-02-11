=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

package EnsEMBL::Draw::GlyphSet::bam;

### Module for drawing data in BAM format (either user-attached, or
### internally configured via an ini file or database record
### Note: uses Inline C for faster handling of these huge files

use strict;
use base qw(EnsEMBL::Draw::GlyphSet::sequence);

use EnsEMBL::Draw::GlyphSet;

use Bio::EnsEMBL::ExternalData::BAM::BAMAdaptor;
use Bio::EnsEMBL::DBSQL::DataFileAdaptor;
use Data::Dumper;

sub errorTrack {
## Hack to override parent errorTrack method
## sequence glyph errorTrack has been hacked so this unhacks it
  EnsEMBL::Draw::GlyphSet::errorTrack(@_); 
}

sub render_histogram {
## Render only the coverage histogram (by disabling the reads)
  my ($self) = @_;
  $self->render_normal(show_reads => 0);
}

sub render_unlimited {
## Display "all" reads 
  my ($self) = @_;
  # Set the maximum row number to 3000 - it's likely the browser will timeout even at a lesser limit
  # SMJS 3000 just never works, go down to something which might - 500
  # SMJS 3000 does now render - BUT it sends such a big image map it upsets the browser!
  #$self->render_normal(max_depth => 3000); # effectively unlimited
  $self->render_normal(max_depth => 500); # effectively unlimited
}

sub render_normal {
  my ($self, %options) = @_;
  
  # show everything by default
  $options{show_reads} = 1 unless defined $options{show_reads}; # show reads by default 
  $options{show_coverage} = 1 unless defined $options{show_coverage}; # show coverage by default 
  #$options{show_consensus} = $options{show_reads} unless defined $options{show_consensus}; # show consensus if showing reads
  $options{show_consensus} = 1 unless defined $options{show_consensus};
  
  # check threshold
  my $slice = $self->{'container'};
  if (my $threshold = $self->my_config('threshold')) {
    if (($threshold * 1000) < $slice->length) {
      $self->errorTrack($self->error_track_name. " is displayed only for regions less then $threshold Kbp (" . $slice->length . ")");
      return;
    }
  }
  
  $self->{_yoffset} = 0; # used to track the y offset as we draw
  
  # wrap the rendering within a timeout alarm
  my $timeout = 30; # seconds
  eval {
    local $SIG{ALRM} = sub { die "alarm\n" }; # NB: \n required
    alarm $timeout;
    # render
    if (!scalar(@{$self->features})) {
      $self->no_features;
    } else {

      #print STDERR "Rendering coverage\n";
      $self->render_coverage(%options) if $options{show_coverage};
      #print STDERR "Done rendering coverage\n";
      #print STDERR "Rendering reads\n";
      $self->render_sequence_reads(%options) if $options{show_reads};
      #print STDERR "Done rendering reads\n";
      $self->render_caption;
    }
    alarm 0;
  };
  if ($@) {
    die unless $@ eq "alarm\n"; # propagate unexpected errors
    # timed-out
    $self->reset;
    $self->errorTrack($self->error_track_name . " could not be rendered within the specified time limit (${timeout}sec)");
  }
}

sub reset {
  my ($self) = @_;
  $self->{'glyphs'} = [];
  foreach (qw(x y width minx miny maxx maxy bumped)) {
      delete $self->{$_};
  }
}

sub bam_adaptor {
## get a bam adaptor
  my $self = shift;
 
  my $url = $self->my_config('url');
  if ($url) { ## remote bam file
    if ($url =~ /\#\#\#CHR\#\#\#/) {
      my $region = $self->{'container'}->seq_region_name;
      $url =~ s/\#\#\#CHR\#\#\#/$region/g;
    }
    $self->{_cache}->{_bam_adaptor} ||= Bio::EnsEMBL::ExternalData::BAM::BAMAdaptor->new($url);
  }
  else { ## Local bam file
    my $config    = $self->{'config'};
    my $hub       = $config->hub;
    my $dba       = $hub->database($self->my_config('type'), $self->species);

    if ($dba) {
      my $dfa = $dba->get_DataFileAdaptor();
      $dfa->global_base_path($hub->species_defs->DATAFILE_BASE_PATH);
      my ($logic_name) = @{$self->my_config('logic_names')||[]};
      my $datafiles = $dfa->fetch_all_by_logic_name($logic_name);
      my ($df) = @{$datafiles};

      $self->{_cache}->{_bam_adaptor} ||= $df->get_ExternalAdaptor(undef, 'BAM');
    }
  }
   
  return $self->{_cache}->{_bam_adaptor};
}

sub features {
## get the alignment features
  my $self = shift;

  my $slice = $self->{'container'};
  if (!exists($self->{_cache}->{features})) {
    $self->{_cache}->{features} = $self->bam_adaptor->fetch_alignments_filtered($slice->seq_region_name, $slice->start, $slice->end);
  }

  # $self->{_cache}->{features} ||= $self->bam_adaptor->fetch_alignments_filtered($slice->seq_region_name, $slice->start, $slice->end);

  return $self->{_cache}->{features};
}

sub consensus_features {
## get the consensus features
  my $self = shift;
 
  unless ($self->{_cache}->{consensus_features}) {
    my $slice = $self->{'container'};
    my $START = $self->{'container'}->start;
    my $consensus = $self->bam_adaptor->fetch_consensus($slice->seq_region_name, $slice->start, $slice->end);
    my @features;
    
    foreach my $a (@$consensus) {
      my $x = $a->{x} - $START+1;
      my $feat = Bio::EnsEMBL::Feature->new_fast( {
                         'start' => $x,
                         'end' => $x,
                         'strand' => 1,
                         'seqname' => $a->{bp},
                        } );

#      my $feat = Bio::EnsEMBL::Feature->new( 
#        -start => $x,
#        -end => $x,
#        -strand => 1,
#        -seqname => $a->{bp},
#      );

#     push @features, $feat;

      $features[$x-1] = $feat;
    }

    
    $self->{_cache}->{consensus_features} = \@features;
  }
  
  return $self->{_cache}->{consensus_features};
}

sub feature_title {
## generate zmenu info for the feature
  my ($self, $f) = @_;
  my $slice  = $self->{'container'};
  my $seq_id = $slice->seq_region_name();

#  my $title = sprintf("%s; Score: %s; Cigar: %s; Location: %s:%s-%s; Strand: %s; Length: %d; Type: %s",
#    $f->qname,
#    $f->qual,
#    $f->cigar_str,
#    $seq_id,
#    $f->start,
#    $f->end,
#    $f->reversed ? 'Reverse' : 'Forward',
#    $f->end - $f->start,
#    $f->atype,
#  );
#
#  $title .= sprintf("; Insert size: %s", $f->isize);
#  $title .= sprintf("; Paired: %s", $f->paired ? 'Yes' : 'No');
#  if ($f->paired) {
#    $title .= sprintf("; Mate: %s", ($f->flag & 0x80) ? 'Second' : ($f->flag & 0x40) ? 'First' : 'Unknown');
#  }

  my $title = $f->qname . 
              "; Score: ".       $f->qual .
              "; Cigar: ".       $f->cigar_str .
              "; Location: ".    $seq_id . ":" . $f->start . "-" . $f->end .
              "; Strand: ".      ($f->reversed ? 'Reverse' : 'Forward') .
              "; Length: ".      ($f->end - $f->start +1) .
             # "; Type: ".        $self->get_atype($f) . ###### $f->atype .
              "; Insert size: ". abs($f->isize) .
              "; Paired: ".       ($f->paired ? 'Yes' : 'No');

  if ($f->paired) {
    $title .= "; Mate: " . (($f->flag & 0x80) ? 'Second' : ($f->flag & 0x40) ? 'First' : 'Unknown');
  }

  return $title;
}

sub feature_brief_title {
## generate zmenu info for the feature
  my ($self, $f) = @_;
  my $slice = $self->{'container'};
  my $seq_id = $slice->seq_region_name();

  my $title = $f->qname .
              "; Location: " . $seq_id. ":" . $f->start . "-" . $f->end .
              "; Strand: ".  ($f->reversed ? 'Reverse' : 'Forward');

  return $title;
}

sub my_colour {
  my ($self, $key) = @_;
  my $colours = $self->my_config('colours');
  return $colours->{$key}->{default} || $colours->{default}->{default} || 'grey80';
}

sub render_caption {
  my $self = shift;

  my( $fontname_i, $fontsize_i ) = $self->get_font_details( 'innertext' );

  $self->push($self->Text({
        'x'         => 0,
        'y'         => $self->{_yoffset}, 
        'height'    => $fontsize_i + 2,
        'font'      => $fontname_i,
        'ptsize'    => $fontsize_i,
        'colour'    => $self->my_colour('consensus'), 
        'text'      => $self->my_config('caption'),
   }));


}

sub render_coverage {
## render coverage histogram with consensus text overlaid
  my ($self, %options) = @_;
  
  # defaults
  $options{show_consensus} = 1 unless defined $options{show_consensus};
  
  my @coverage = @{$self->calc_coverage};

  
  my $max = (sort {$b <=> $a} @coverage)[0];
  return if $max == 0; # nothing to show

  my $viewLimits = $self->my_config('viewLimits');
  if ($viewLimits) {
    my ($min_score,$max_score) = split ":",$viewLimits;
    $max = $max_score;
  }

  my $slice = $self->{'container'};
  my $smax = 100;
  my $scale = 3;
  my $ppbp = $self->scalex;

  my @consensus;
  if ($ppbp > 1 && $options{show_consensus}) {
    @consensus = @{$self->consensus_features};
  }
  #print STDERR "Have " . scalar(@consensus) . " consensus features\n";

  # text stuff
  my($font, $fontsize) = $self->get_font_details( $self->can('fixed') ? 'fixed' : 'innertext' );
  my($tmp1, $tmp2, $font_w, $font_h) = $self->get_text_width(0, 'X', '', 'font' => $font, 'ptsize' => $fontsize);
  my $text_fits = $font_w * $slice->length <= int($slice->length * $ppbp);

#  print STDERR "font_w = $font_w slice length = " . $slice->length . " ppbp = $ppbp\n";


  foreach my $i (0..$#coverage) {
    my $cvrg = $coverage[$i];
    my $cons = $consensus[$i]; 
    
    my $title = $cvrg;
    my $sval;

    if ($cvrg > $max) { $cvrg = $max }; 

    my $sval   = $smax * $cvrg / $max;

    my $y = int($smax/$scale - $sval/$scale +0.5);
    # SMJS Calculating height this way was leading to 50% off by ones in pixel coordinates
    #my $h1 = int($sval/$scale + 0.5);

    my $h1 = int($smax/$scale - $y );

    #print STDERR " Coverage: y = $y h1 = $h1   sval = $sval  scale = $scale  smax = $smax\n";
    
    my $colour;
    if ($ppbp < 1 or !$options{show_consensus}) {
      $colour =  $self->my_colour('consensus');
    } else {
      $colour = $cons ? $self->my_colour(lc($cons->seqname)) : $self->my_colour('consensus');
    }
    
    # coverage rectangle          
    $self->push($self->Rect({
      'x'      => $i,
      'y'      => $self->{_yoffset} + $y,
      'width'  => 0.97,
      'height' => $h1,
      'colour' => $colour,
      'absolutex' => $ppbp < 1 ? 1 : 0,
      'title' => $title,
    }));
    
    # consensus text
    if ($options{show_consensus} and $text_fits and $cons) {
      $self->push($self->Text({
        'x'         => $i,
        'y'         => $self->{_yoffset} + ($smax / $scale) + 1 - $font_h,
        'width'     => 1,
        'height'    => $font_h,
        'font'      => 'Tiny',
        'colour'    => $self->my_colour('consensus_text'),
        'text'      => $cons->seqname,
        'absolutey' => 1,
      }));
    };    
  }

  $self->push($self->Rect({
    'x'      => 0,
    'y'      => $self->{_yoffset} + $smax / $scale + 1,
    'width'  => $slice->length,
    'height' => 0,
    'colour' => 'background1',
  }));
  
  # max score label
  my $display_max_score = $max;

  my( $fontname_i, $fontsize_i ) = $self->get_font_details( 'innertext' );
  my @res_i = $self->get_text_width(0, $display_max_score, '', 'font'=>$fontname_i, 'ptsize' => $fontsize_i );
  my $textheight_i = $res_i[3];
  my $ppbp = $self->scalex;

  $self->push( $self->Text({
    'text'          => $display_max_score,
    'width'         => $res_i[2],
    'textwidth'     => $res_i[2],
    'font'          => $fontname_i,
    'ptsize'        => $fontsize_i,
    'halign'        => 'right',
    'valign'        => 'top',
    'colour'        => $self->my_colour('consensus_max'),
    'height'        => $textheight_i,
    'y'             => $self->{_yoffset} + 1,
    'x'             => -4 - $res_i[2],
    'absolutey'     => 1,
    'absolutex'     => 1,
    'absolutewidth' => 1,
  }));
  
  $self->{_yoffset} += $smax / $scale + 2; # add on height of area just drawn
 
  $self->push( $self->Text({
    'text'          => '0',
    'width'         => $res_i[2],
    'textwidth'     => $res_i[2],
    'font'          => $fontname_i,
    'ptsize'        => $fontsize_i,
    'halign'        => 'right',
    'valign'        => 'top',
    'colour'        => 'slategray', 
    'height'        => $textheight_i,
    'y'             => $self->{_yoffset} - ($textheight_i + 2),
    'x'             => -4 - $res_i[2],
    'absolutey'     => 1,
    'absolutex'     => 1,
    'absolutewidth' => 1,
  }));
 
  return;
}

#sub pre_filter_depth {
#  my ($self,$features,$depth) = @_;
#
##  print STDERR "Started sort\n";
##  $features =   [ map { $_->[2] } sort { $a->[0] <=> $b->[0] ? $a->[0] <=> $b->[0] : $b->[1] <=> $a->[1] } map { [$_->start, $_->end, $_] } @$features ];
##  print STDERR "Finished sort\n";
#
#  my @row_ends;
#  my $num_rows = 0;
#  my @filtered;
#
#
#  print STDERR "Filtering " . scalar(@$features) . " features maximum depth $depth\n";
#  FEAT: foreach my $f (@$features) {
#    my $fstart = $f->start;
#   
#    my $max = $num_rows+1 > $depth ? $depth : $num_rows+1;
#
#    for (my $row_num=0; $row_num<$max; $row_num++) {
#      if ($fstart > $row_ends[$row_num]) {
#        $row_ends[$row_num] = $f->end;
#        push @filtered,$f;
#
#        if ($row_num == $num_rows) {
#          $num_rows++;
#        }
#        next FEAT; 
#      }
#    }
#  }
#  print STDERR "Filtered to " . scalar(@filtered) . " features after pre bump (num rows $num_rows)\n";
#  return \@filtered;
#}

use Inline C => Config => INC => "-I$SiteDefs::SAMTOOLS_DIR",
                          LIBS => "-L$SiteDefs::SAMTOOLS_DIR -lbam",
                          DIRECTORY => "$SiteDefs::ENSEMBL_WEBROOT/cbuild";

##    Inline->init;
#
use Inline C => <<'END_OF_C_CODE';

#include "bam.h"

AV * pre_filter_depth (SV* features_ref, int depth, double ppbp, int slicestart, int sliceend) {
  AV* filtered = newAV();
  AV* features;
  int *row_ends = calloc(depth+2,sizeof(int));
  int num_rows = 0;
  int i;
  int nfeatures;
  int slicelength = sliceend-slicestart+1;

  for (i=0;i<depth+2;i++) {
    row_ends[i] = -1;
  }

  if (! SvROK(features_ref)) {
    croak("features_ref is not a reference");
  }

  features = (AV*)SvRV(features_ref);

  nfeatures = av_len(features)+1;

//  fprintf(stderr,"Filtering %d features maximum depth %d\n",nfeatures,depth);
//  fflush(stderr);

  for (i=0; i<nfeatures; i++) {
    SV** elem = av_fetch(features, i, 0);
    bam1_t *f;
    int fstart;
    int start;
    int bumpstart;
    int max;
    int row_num;

      
    if (elem == NULL) {
      continue;
    }

    f = (bam1_t *)SvIV(SvRV(*elem));

    //fprintf(stderr,"f = %x diff = %d size = %d\n",f,(int)f-(int)prev, sizeof(bam1_t));
    //fflush(stderr);


    //fstart = SvIV(*hv_fetchs(f,"start",0));
    //D fstart = f->core.pos+1;
    fstart = f->core.pos+1;

    start = fstart - slicestart;
    if (start < 0) start = 0;

    bumpstart = (int)(start * ppbp);

    //fprintf(stderr,"fstart = %d\n",fstart);
    //fflush(stderr);
   
    max = num_rows+1 > depth ? depth : num_rows+1;

    for (row_num=0; row_num<max; row_num++) {
      //Dif (fstart > row_ends[row_num]) {
      if (bumpstart > row_ends[row_num]) {
        //int fend = SvIV(*hv_fetchs(f,"end",0));
        int end;
        int bumpend;
        int width;
        int fend = bam_calend(&f->core,bam1_cigar(f));

        end = fend - slicestart;
        if (end < 0) end = 0;
        if (end > slicelength) end = slicelength;
        width = end - start + 1;
        bumpend = bumpstart + (int)(width * ppbp) + 1;

        //fprintf(stderr,"fend = %d\n",fend);
        //fflush(stderr);
        //D row_ends[row_num] = fend;
        row_ends[row_num] = bumpend;

        av_push(filtered,*elem);

        if (row_num == num_rows) {
          num_rows++;
        }
        break; 
      }
    }
  }
  free(row_ends);

  //fprintf(stderr,"Filtered to %d features after pre bump (num rows %d)\n",av_len(filtered)+1,num_rows);
  //fflush(stderr);

  return filtered;
}

END_OF_C_CODE


sub render_sequence_reads {
## render reads with sequence overlaid and variations from consensus highlighted
  my ($self, %options) = @_;
  
  # defaults
  unless (defined $options{max_depth}) {
    $options{max_depth} = $self->my_config('max_depth') || 50;
  }

  my $fs =   [ map { $_->[1] } sort { $a->[0] <=> $b->[0] } map { [$_->start, $_] } @{$self->features} ];

  my $ppbp = $self->scalex; # pixels per base pair
  my $slice = $self->{'container'};

  my $features = pre_filter_depth($fs, $options{max_depth},$ppbp,$slice->start,$slice->end);
     $features = [reverse @$features] if $slice->strand == -1;
  
  # text stuff
  my($font, $fontsize) = $self->get_font_details( $self->can('fixed') ? 'fixed' : 'innertext' );
  my($tmp1, $tmp2, $font_w, $font_h) = $self->get_text_width(0, 'X', '', 'font' => $font, 'ptsize' => $fontsize);
  my $text_fits = $font_w * $slice->length <= int($slice->length * $ppbp);

  my $h = 1;

  my @consensus;
  if ($text_fits) {
    @consensus = @{$self->consensus_features};
    $h = 8; 
  }

  my $row_height = 1.3 * $h;
  my $max_y = 0;

  my $slicestart  = $slice->start;
  my $sliceend    = $slice->end;
  my $slicelength = $slice->length;
  my $slicestrand = $slice->strand;
  my $read_colour = $self->my_colour('read'),

  # init bump
  $self->_init_bump(undef, $options{max_depth});

  my $nrendered =0;
  foreach my $f (@$features) {
    my $fstart = $f->start;
    my $fend = $f->end;

    next unless $fstart and $fend;
    
    # init
   # my $start = $fstart - $slicestart;
   # my $end = $fend - $slicestart;
    
    my $start = $slicestrand == -1 ? $sliceend - $fend   + 1 : $fstart - $slicestart;
    my $end   = $slicestrand == -1 ? $sliceend - $fstart + 1 : $fend   - $slicestart;
    
    
    $start = 0 if $start < 0;
    $end = 0 if $end < 0;
    $end = $slicelength if $end > $slicelength;
    my $width = $end - $start + 1;
    
    # bump it to the next row with enough free space
    my $bump_start = int($start * $ppbp);
    my $bump_end = $bump_start + int($width * $ppbp) + 1;
    my $row = $self->bump_sorted_row( $bump_start, $bump_end );
    
    if ($row > $options{max_depth}) {
      # not interested in this row as beyond our display limit
      next; 
    }

    # new composite object
    my $composite = $self->Composite({
      'height' => $h,
#      'title' => ($text_fits ? $self->feature_title($f) : $self->feature_brief_title($f)),
      'title' => $self->feature_title($f),
    });
    
    # draw box    
    $composite->push($self->Rect({
      'x' => $start,
      'y' => 0,
      'width' => $width,
      'height' => $h,
      'colour'=> $read_colour,
      'absolutey' => 1,
    }));   
    
    # draw lines to indicate direction of read
    if (($f->reversed and $fstart >= $slicestart) or (!$f->reversed and $fend <= $sliceend)) {
      my $line_length_pix = 2;
      $line_length_pix = $width * $ppbp if $width * $ppbp < $line_length_pix;
      my $stroke_width_pix = 1;
      
      # colour the arrow based on read type
      my $arrow_colour = $self->my_colour('type_' . $self->_read_type($f));
      
      # horizontal
      $composite->push($self->Rect({
        'x' => $f->reversed ^ $slicestrand == -1 ? $start : $end + 1 - ($line_length_pix / $ppbp),
        'y' => 0,
        'width' => ($line_length_pix / $ppbp),
        'height' => $stroke_width_pix,
        'colour'=> $arrow_colour,
        'absolutey' => 1,
      }));  

      if ($h ==8) {
        # vertical
        $composite->push($self->Rect({
          'x' => $f->reversed ^ $slicestrand == -1 ? $start : $end + 1 - ($stroke_width_pix / $ppbp),
          'y' => 0,
          'width' => ($stroke_width_pix / $ppbp),
          'height' => $h,
          'colour'=> $arrow_colour,
          'absolutey' => 1,
        }));  
      }
    }
    
    # render text
    if ($text_fits) {
      # SMJS Moved insert rendering inside if block to save having to do get_sequence_window calls all the time
      my ($seq, $inserts) =  $self->_get_sequence_window($f);

      # render inserts
      if (@{$inserts}) {
        foreach my $ins (@{$inserts}) {
          $composite->push($self->Rect({
            'x' => $ins->{pos}, 
            'y' => 0, 
            'width' => 1,
            'height' => $h, 
            'colour'=> $self->my_colour('read_insert'),
            'absolutey' => 1,
            'zindex' => 10,
          }));
        }
      }
      

      my $i = 0;
      foreach( split //, $seq ) {
        my $pos = $start + $i;
        my $consensus_seq = $consensus[$pos] ? $consensus[$pos]->seqname : '';
        #warn "[$_]";
        $composite->push( $self->Text({
          'x'         => $pos,
          'y'         => 0,
          'width'     => 1,
          'height'    => $font_h,
          'font'      => 'Tiny',
          'colour'    => $self->my_colour($consensus_seq eq $_ ? 'consensus_match' : 'consensus_mismatch'),
          'text'      => $_,
          'absolutey' => 1,
        }));
        $i++;
      }
    }
        
    $composite->y($self->{_yoffset} + $row_height * $row);
    $max_y = $composite->y if $composite->y > $max_y; # record max y extent
    
    # add it to the track
    $self->push($composite);
    $self->highlight($f, $composite, $ppbp, $h, 'highlight1');
    $nrendered++;
  }
    
  $self->{_yoffset} += $max_y + $h;

  my $features_bumped = scalar(@{$self->features}) - $nrendered;
  if( $features_bumped ) {
#    my $y_pos = $strand < 0
#              ? $y_offset
#              : 2 + $self->{'config'}->texthelper()->height($self->{'config'}->species_defs->ENSEMBL_STYLE->{'GRAPHIC_FONT'})
#              ;
    my $y_pos = 2 + $self->{'config'}->texthelper()->height($self->{'config'}->species_defs->ENSEMBL_STYLE->{'GRAPHIC_FONT'});
    $self->errorTrack( sprintf( q(%s features from '%s' not shown), $features_bumped, $self->my_config('name')), undef, $max_y );
  }
  
  return;
}

sub _read_type {
  my ($self, $f) = @_;
  my $type = '';
  
  if ($f->proper_pair) {
    $type = 'regular';
  } elsif ($f->paired) {
    if ($f->get_tag_values('UNMAPPED') or $f->get_tag_values('M_UNMAPPED')) {
      $type = 'singleton';
    } else {
      $type = 'chimera';
    }
  } else {
    $type = 'singleton'
  }
  
  return $type;
}

sub highlight {
## highlight a composite if its in the list of highlights
  my ($self, $f, $composite, $pix_per_bp, $h) = @_;

  return if (scalar($self->highlights()) == 0);

  ## Get highlights...
  my %highs = map { $_ => 1} $self->highlights();

  my $fkey = lc($f->qname);

  ## Are we going to highlight this item...
  if ($highs{$fkey}) {

    $self->unshift($self->Rect({
      'x'         => $composite->x() - 1/$pix_per_bp,
      'y'         => $composite->y() - 1,
      'width'     => $composite->width() + 2/$pix_per_bp,
      'height'    => $h + 2,
      'colour'    => $self->my_colour('highlight'),
      'dotted' => 1,
      'absolutey' => 1,
    }));
  }
}

sub _get_sequence_window {
## return just the sequence within the current window
  my ($self, $f, $s) = @_;
  
  my $slice = $self->{container};
  my $fend = $f->end;

  my $start = $f->start - $slice->start;
  my $end = $fend - $slice->start;

  my ($seq, $inserts) =  $self->_get_sequence($f, $s) ;

  if ($start < 0) {
    $seq = substr($seq, abs($start));
  }

  if ($end > $slice->length) {
    $seq = substr($seq, 0, $slice->end - $fend);
  }
  
  $inserts = [grep {$_->{pos} >= $start && $_->{pos} <= $end } @{$inserts || []}];
  
  return $seq, $inserts;
  
}

sub _get_sequence {
## build the sequence for the given feature based on the cigar string
  my ($self, $a, $s) = @_;
  
#  my $seq = $a->qdna;
  my $seq = $a->query->dna;
  my $cl = $a->cigar_str;
  my @inserts = () ;

  # D - delete
  # I - insert
  # S - soft clip : effectively we need to cut the sequence by that match  or shift it left by this amount

  if ($cl =~ /D|I|S|N/) {
    my @c1 = split /(M|D|I|S|N)/, $cl;
   
    my $s2;
    my $i = 0;
    my $pos = 0;
    my $spos = 0;

    while ($i < scalar(@c1)) {
      my $os = $c1[$i++];
      my $op = $c1[$i++];

      if ($os !~ /\d+/) {
        $os = 1;
        $i--;
      }

      if ($op eq 'M') {
        $s2 .= substr($seq, $pos, $os);
        $pos += $os;
      } elsif ($op eq 'D' || $op eq 'N') {
        $s2 .= '-'x$os;
      } elsif ($op eq 'I') {
        push @inserts, {
          pos => $s + $pos - $spos,
          s => substr($seq, $pos, $os)
        };
        $pos += $os;
      } elsif ($op eq 'S') {
        $pos += $os;

        # we need to count the positions shifted by S so the inserts are in the right place;
        $spos += $os;
      }

    }
    $seq = $s2;
  }

  #print STDERR $a->reversed . " " . $a->start . " " . $a->end . " " . $a->cigar_str . " " . $seq . "\n";
  return ($seq, \@inserts);
}


sub calc_coverage {
## calculate the coverage
  my ($self) = @_;
  
  my $features = $self->features;

  my $slice = $self->{'container'};
  my $START = $slice->start;
  my $ppbp = $self->scalex;
  my $slength = $slice->length;

  my $pcx = $slength * $ppbp;
  my $bpx = $slength / $pcx;

  my $sample_size  = $slength / $pcx;
  my $lbin = $pcx;

  if ($sample_size < 1) {
    $sample_size = 1;
    $lbin = $slength;
  }

  #print STDERR "sample_size =  " . $sample_size . "\n";

  my $coverage = $self->c_coverage($features, $sample_size, $lbin, $START);
     $coverage = [reverse @$coverage] if $slice->strand == -1;
  
  #print STDERR "Done coverage, ended with type " . ref($coverage) . "\n";
  return $coverage;
}

use Inline C => <<'END_OF_CALC_COV_C_CODE';

#include "bam.h"
AV * c_coverage(SV *self, SV *features_ref, double sample_size, int lbin, int START) {
  AV *ret_cov = newAV();
  int *coverage = calloc(lbin+1,sizeof(int));
  int i;
  AV* features;

  if (! SvROK(features_ref)) {
    croak("features_ref is not a reference");
    fflush(stderr);
  }

  features = (AV*)SvRV(features_ref);

  //fprintf(stderr,"calc coverage for %d features, lbin = %d\n",av_len(features)+1,lbin);
  //fflush(stderr);



  for (i=0; i<=av_len(features); i++) {
    SV** elem = av_fetch(features, i, 0);
    bam1_t *f;
    int fstart;
    int fend;
    int sbin;
    int ebin;
    int j;

    if (elem == NULL) {
      continue;
    }

    f = (bam1_t *)SvIV(SvRV(*elem));

    fstart = f->core.pos+1;
    fend = bam_calend(&f->core,bam1_cigar(f));

    sbin = (int)((fstart - START) / sample_size);
    ebin = (int)((fend - START) / sample_size);

    if (sbin < 0) sbin = 0;
    if (ebin > lbin) ebin = lbin;

    for (j = sbin; j <= ebin; j++) {
      coverage[j]++;
    }
  }

  av_extend(ret_cov, lbin);
  for (i = 0; i <= lbin; i++) {
    av_push(ret_cov,  newSViv(coverage[i]));
  }

  free(coverage);

  //fprintf(stderr, "Done c_coverage\n");
  //fflush(stderr);
  return ret_cov;
}

END_OF_CALC_COV_C_CODE

## calculate the coverage
#sub calc_coverage {
#  my ($self) = @_;
#  
#  my $features = $self->features;
#
#  my $slice = $self->{'container'};
#  my $START = $slice->start;
#  my $ppbp = $self->scalex;
#  my $slength = $slice->length;
#
#  my $pcx = $slength * $ppbp;
#  my $bpx = $slength / $pcx;
#
#  my $sample_size  = $slength / $pcx;
#  my $lbin = $pcx;
#
#  if ($sample_size < 1) {
#    $sample_size = 1;
#    $lbin = $slength;
#  }
#
#  my @coverage;
#
#  for (my $i = 0; $i <= $lbin; $i++) {
#    $coverage[$i] = 0;
#  }
#
#  foreach my $f (@$features) {
#    my $sbin = int(($f->start - $START) / $sample_size);
#    my $ebin = int(($f->end -$START) / $sample_size);
#
#    $sbin = 0 if ($sbin < 0);
#    $ebin = $lbin if($ebin > $lbin);
#
#    for (my $i = $sbin; $i <= $ebin; $i++) {
#      $coverage[$i]++;
#    }
#  }
#
#  print STDERR "Done coverage\n";
#  return \@coverage;
#
#
##  my $cov = $self->bam_adaptor->fetch_coverage($slice->seq_region_name, $slice->start, $slice->end, $lbin);
##  print STDERR "Done coverage\n";
##  return $cov;
#}

1;
