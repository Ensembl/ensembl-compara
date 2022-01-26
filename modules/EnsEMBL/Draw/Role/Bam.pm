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

package EnsEMBL::Draw::Role::Bam;

### Module for drawing data in BAM or CRAM format (either user-attached,
### or internally configured via an ini file or database record
### Note: uses Inline C for faster handling of these huge files

### Note also that because of the file size, we do not use standard
### ensembl-io parsers with an IOWrapper module, but instead use an 
### adaptor and then munge the data here

use strict;

use Role::Tiny;

use Bio::EnsEMBL::DBSQL::DataFileAdaptor;
use Bio::EnsEMBL::IO::Adaptor::HTSAdaptor;
use EnsEMBL::Web::File::Utils::IO qw(file_exists);
use EnsEMBL::Web::Constants;

sub my_empty_label {
  return 'No data found for this region';
}

############# RENDERING ########################

sub render_coverage_with_reads {
### Standard rendering style 
  my $self = shift;
  $self->_render({'coverage' => 1, 'reads' => 1});
}

sub render_unlimited {
### 'External' rendering style
### Coverage and reads
  my $self = shift;
  $self->{'my_config'}->set('depth', 500);
  $self->_render({'coverage' => 1, 'reads' => 1});
}

sub render_histogram {
### 'External' rendering style
### Coverage only - no reads
  my $self = shift;
  $self->_render({'coverage' => 1, 'reads' => 0});
}

sub render_text {
### Text export
  my $self = shift;
  warn 'No text render implemented for bam';
  return '';
}

sub _render_coverage {
### Draw the coverage subtrack, using Style modules
  my $self = shift;

  ## Process the data using Inline C
  my @coverage = @{$self->calc_coverage};

  my $max = (sort {$b <=> $a} @coverage)[0];
  return if $max == 0; ## nothing to show

  ## Some useful stuff, mainly to do with rendering differently at different scales
  my $slice         = $self->{'container'};
  my $slice_start   = $slice->start;
  my $smax          = 100; ## Cutoff for values
  my $scale         = 3;
  my $pix_per_bp    = $self->scalex;

  ## Set some defaults for this graph
  my $default_colour = $self->my_colour('consensus');
  $self->{'my_config'}->set('axis_colour', $default_colour);
  $self->{'my_config'}->set('height', int($smax/$scale));
  $self->{'my_config'}->set('no_guidelines', 1);
  $self->{'my_config'}->set('baseline_zero', 1);
  $self->{'my_config'}->set('subtitle_y', -4);

  ## Do we want to show the consensus base? (ACTG)
  my $consensus;
  if ($pix_per_bp > 1) {
    $consensus = $self->consensus_features;
    $self->{'my_config'}->set('overlay_label', 1);
    $self->{'my_config'}->set('hide_subtitle', 1);
  }
  elsif ($pix_per_bp < 1) {
    ## Graph won't draw without this. Because reasons.
    $self->{'my_config'}->set('absolutex', 1);
  }

  my ($min_score,$max_score);
  my $viewLimits = $self->my_config('viewLimits');
  if ($viewLimits) {
    ($min_score,$max_score) = split ":",$viewLimits;
    $max = $max_score;
  }

  ## Munge into a format suitable for the Style module
  my $name = $self->{'my_config'}->get('short_name') || $self->{'my_config'}->get('name');
  my $data = {'features' => [], 
              'metadata' => {
                             'name'      => $name,
                             'colour'    => $default_colour,
                             'max_score' => $max, 
                             'min_score' => $min_score || 0
                             }
              };

  my %config                = %{$self->track_style_config};
  $config{'pix_per_score'}  = $smax / ($scale * $max); 
  $config{'line_score'}     = 0;

  foreach my $i (0..$#coverage) {
    my $cvrg = $coverage[$i];
    my $cons = $consensus->{$slice_start + $i};

    my ($colour, $label);
    if ($pix_per_bp < 1 || !$cons) {
      $colour =  $default_colour;
    } else {
      $label  = $cons;
      $colour = $self->my_colour(lc($cons));
    }

    my $start = $i + 1;

    my $title = 'Coverage' .
                  "; Location: ".sprintf('%s:%s-%s',  $slice->seq_region_name, 
                                                      $start + $slice_start, 
                                                      $start + $slice_start) .
                  "; Score: $cvrg";

    my $hash = {
                  'start'   => $start,
                  'end'     => $start,
                  'score'   => $cvrg,
                  'label'   => $label,
                  'colour'  => $colour,
                  'title'   => $title,
                };
    
    push @{$data->{'features'}}, $hash;
  }
  #use Data::Dumper; warn Dumper($data);

  ## Draw coverage track
  my $style_class = 'EnsEMBL::Draw::Style::Graph::Bar';
  if ($self->dynamic_use($style_class)) {
    my $style = $style_class->new(\%config, [$data]);
    $self->push($style->create_glyphs);
  }

  ## This is clunky, but it's the only way we can make the new code
  ## work in a nice backwards-compatible way right now!
  ## Get label position, which is set in Style::Graph
  $self->{'label_y_offset'} = $self->{'my_config'}->get('label_y_offset');

  ## Everything went OK, so no error to return
  return 0;
}

sub _render_reads {
### Draw the reads subtrack, using Style modules
  my $self = shift;

  ## Establish defaults
  my $max_depth   = $self->my_config('depth') || 50;
  my $pix_per_bp  = $self->scalex; # pixels per base pair
  my $slice       = $self->{'container'};
  my $slicestart  = $slice->start;
  my $sliceend    = $slice->end;
  my $slicelength = $slice->length;
  my $slicestrand = $slice->strand;
  my $read_colour = $self->my_colour('read');
  $self->{'my_config'}->set('insert_colour', $self->my_colour('read_insert'));

  my $fs = [ map { $_->[1] } sort { $a->[0] <=> $b->[0] } map { [$_->start, $_] } 
            @{$self->get_data->[0]{'features'}} ];

  my $features = pre_filter_depth($fs, $max_depth, $pix_per_bp, $slice->start, $slice->end);
  $features = [reverse @$features] if $slice->strand == -1;

  ## Do some text scaling calculations, so we know if it's worth fetching the data
  my($font, $fontsize) = $self->get_font_details( $self->can('fixed') ? 'fixed' : 'innertext' );
  my($tmp1, $tmp2, $font_w, $font_h) = $self->get_text_width(0, 'X', '', 'font' => $font, 'ptsize' => $fontsize);
  my $text_fits = $font_w * $slice->length <= int($slice->length * $pix_per_bp);

  ## Now set some positioning
  my $y_start = $self->{'my_config'}->get('height');
  $y_start += $text_fits ? 10 : 2;
  $self->{'my_config'}->set('y_start', $y_start);
  $self->{'my_config'}->set('height', 1);
  $self->{'my_config'}->set('bumped', 1);
  $self->{'my_config'}->set('vspacing', 0);

  my $total_count = scalar @$fs;
  my $drawn_count = scalar @$features;
  my $data = {'features' => [], 'metadata' => {'not_drawn' => $total_count - $drawn_count}};

  foreach my $f (@$features) {
    my $fstart  = $f->start;
    my $fend    = $f->end;
    my $strand  = $f->reversed ? -1 : 1;

    next unless $fstart and $fend and $strand == $self->strand;
    ## Munge coordinates
    my $start  = $slicestrand == -1 ? $sliceend - $fend   + 1 : $fstart - $slicestart;
    my $end    = $slicestrand == -1 ? $sliceend - $fstart + 1 : $fend   - $slicestart;

    ## Build the feature hash  
    my $fhash = {
                'start'     => $start,
                'end'       => $end + 1,
                'strand'    => $strand,
                'colour'    => $read_colour,
                'title'     => $self->_feature_title($f),
                'arrow'     => {},
                'inserts'   => [],
                'consensus' => [],
    };

    ## Work out details of arrow, if any
    if (($strand == -1 and $fstart >= $slicestart) or ($strand == 1 and $fend <= $sliceend)) {
      $fhash->{'arrow'}{'colour'}     = $self->my_colour('type_' . $self->_read_type($f));
      $fhash->{'arrow'}{'position'}   = $f->reversed ^ ($slicestrand == -1) ? 'start' : 'end';
    }

    ## Are we at a high enough scale to show text?
    if ($text_fits) {
      $self->{'my_config'}->set('height', 8);
      $self->{'my_config'}->set('vspacing', 4);
      $self->{'my_config'}->set('y_offset', -10);

      my $consensus       = $self->consensus_features;
      my ($seq, $inserts) = $self->_get_sequence_window($f);

      # render inserts
      if (@{$inserts}) {
        $fhash->{'insert_colour'} = $self->my_colour('read_insert');
        foreach my $ins (@{$inserts}) {
          push @{$fhash->{'inserts'}}, $ins->{'pos'};
        }
      }

      my $i = 0;
      foreach( split //, $seq ) {
        my $drawn_start   = $slicestart + $i;
        $drawn_start     += $start if $start > 0; 
        my $consensus_seq = $consensus->{$drawn_start} || '';
        my $cons_colour   = $self->my_colour($consensus_seq eq $_ ? 'consensus_match' : 'consensus_mismatch');
        push @{$fhash->{'consensus'}}, [$i, $_, $cons_colour];
        $i++;
      }
    }

    push @{$data->{'features'}}, $fhash;
  }

  ## Draw read track
  my %config      = %{$self->track_style_config};
  my $style_class = 'EnsEMBL::Draw::Style::Feature::Read';
  if ($self->dynamic_use($style_class)) {
    my $style = $style_class->new(\%config, [$data]);
    $self->push($style->create_glyphs);
  }

  ## Everything went OK, so no error to return
  return 0;
}

sub _render {
### Wrapper around the individual subtrack renderers, with lots of
### error/timeout handling to cope with the large size of BAM files
  my ($self, $options) = @_;

  ## check threshold
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
    ## Creating the adaptor checks if the file exists
    my $adaptor = $self->bam_adaptor;
    die if $self->{'file_error'};
    # try to render
    my $features = $self->get_data->[0]{'features'};
    if (!scalar(@$features)) {
      $self->no_features;
    } else {
      #warn "Rendering coverage";
      $self->_render_coverage if $options->{coverage};
      #warn "Done rendering coverage";
      #warn "Rendering reads";
      $self->_render_reads if $options->{reads};
      #warn "Done rendering reads";
    }
    alarm 0;
  };

  if ($@) {
    my $error_message;
    if ($@ eq "alarm\n") {
      $error_message = " could not be rendered within the specified time limit (${timeout} sec)";
    } elsif ($self->{'file_error'}) {
      my $custom_error = $self->{'my_config'}->get('on_error');
      if ($custom_error) {     
        my %messages = EnsEMBL::Web::Constants::ERROR_MESSAGES;
        my $message  = $messages{$custom_error};
        $error_message = $message->[1];
      }
      else {
        $error_message = $self->{'file_error'};
      }
    } else {
      $error_message = 'could not retrieve BAM file';
      warn "######## BAM ERROR: $@"; # propagate unexpected errors
    }
    $self->reset;
    return $self->errorTrack($self->error_track_name . ': ' . $error_message);
  }
}

sub reset {
### Delete glyphs and reset parameters if the calls time out
  my ($self) = @_;
  $self->{'glyphs'} = [];
  foreach (qw(x y width minx miny maxx maxy bumped)) {
      delete $self->{$_};
  }
}

############# DATA ACCESS & PROCESSING ########################

sub get_data {
## get the alignment features
  my $self = shift;

  unless ( $self->{_cache}->{data} ) {    
    my $adaptor = $self->bam_adaptor;
    if ($self->{'file_error'}) {
      $self->{_cache}->{_bam_adaptor} = undef;
      $self->errorTrack(sprintf 'Could not read file %s', $self->my_config('caption'));
      return [];
    }

    my $slice = $self->{'container'};
    
    ## Allow for seq region synonyms
    my $seq_region_names = [$slice->seq_region_name];
    if ($self->{'config'}->hub->species_defs->USE_SEQREGION_SYNONYMS) {
      push @$seq_region_names, map {$_->name} @{ $slice->get_all_synonyms };
    }

    my $data;
    foreach my $seq_region_name (@$seq_region_names) {
      $data = $adaptor->fetch_alignments_filtered($seq_region_name, $slice->start, $slice->end) || [];
      last if @$data;
    }

    $self->{_cache}->{data} = $data;
    $self->{_cache}->{_bam_adaptor} = undef;
  }

  ## Return data in standard format expected by other modules
  return [{'features' => $self->{_cache}->{data},
            'metadata' => {'zmenu_caption' => 'Aligned reads'},
          }];
} 

sub consensus_features {
  my $self = shift;

  unless ($self->{_cache}->{consensus_features}) {

    my $adaptor = $self->bam_adaptor;
    if ($self->{'file_error'}) {
      $self->{_cache}->{_bam_adaptor} = undef;
      return {};
    }

    my $slice = $self->{'container'};
    
    ## Allow for seq region synonyms
    my $seq_region_names = [$slice->seq_region_name];
    if ($self->{'config'}->hub->species_defs->USE_SEQREGION_SYNONYMS) {
      push @$seq_region_names, map {$_->name} @{ $slice->get_all_synonyms };
    }

    my $consensus;
    foreach my $seq_region_name (@$seq_region_names) {
      $consensus = $adaptor->fetch_consensus($seq_region_name, $slice->start, $slice->end) || [];
      last if @$consensus;
    }    

    my $cons_lookup = {};
    foreach (@$consensus) {
      $cons_lookup->{$_->{'x'}} = $_->{'bp'};
    }
    $self->{_cache}->{consensus_features} = $cons_lookup;
    $self->{_cache}->{_bam_adaptor} = undef;
  }
  return $self->{_cache}->{consensus_features}; 
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

  return ($seq, \@inserts);
}

sub _feature_title {
  ## generate zmenu info for the feature
  my ($self, $f) = @_;
  my $slice  = $self->{'container'};
  my $seq_id = $slice->seq_region_name();

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

sub bam_adaptor {
## get a bam adaptor
  my $self = shift;
  return $self->{_cache}->{_bam_adaptor} if $self->{_cache}->{_bam_adaptor};

  my $url = $self->my_config('url');
  my $check = {};

  if ($url) { ## remote bam file
    if ($url =~ /\#\#\#CHR\#\#\#/) {
      my $region = $self->{'container'}->seq_region_name;
      $url =~ s/\#\#\#CHR\#\#\#/$region/g;
    }
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
      $url = $df->path;
      #$check = EnsEMBL::Web::File::Utils::IO::file_exists($url, {'nice' => 1});
    }
  }
  $self->{_cache}->{_bam_adaptor} ||= Bio::EnsEMBL::IO::Adaptor::HTSAdaptor->new($url);

=pod
  if ($check->{'error'}) {
    $self->{'file_error'} = $check->{'error'}[0];
  }
=cut
  return $self->{_cache}->{_bam_adaptor};
}

############## Here we do the heavy lifting! ##################################

# Calculate a machine-unique name for the C for safe copyability
use Digest::MD5 qw(md5_hex);
our $cbuild_dir;
BEGIN {
  $cbuild_dir = $SiteDefs::ENSEMBL_CBUILD_DIR;
  mkdir $cbuild_dir unless -e $cbuild_dir;
};

use Inline C => Config => INC => "-I$SiteDefs::HTSLIB_DIR/htslib",
                          LIBS => "-L$SiteDefs::HTSLIB_DIR -lhts",
                          DIRECTORY => $cbuild_dir;

use Inline C => <<'END_OF_C_CODE';

#include "sam.h"

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
        int fend = bam_endpos(f);

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

sub calc_coverage {
## calculate the coverage
  my ($self) = @_;

  my $features    = $self->get_data->[0]{'features'};

  my $slice       = $self->{'container'};
  my $START       = $slice->start;
  my $pix_per_bp  = $self->scalex;
  my $slength     = $slice->length;

  my $pcx = $slength * $pix_per_bp;
  my $bpx = $slength / $pcx;

  my $sample_size = $slength / $pcx;
  my $lbin = $pcx;

  if ($sample_size < 1) {
    $sample_size = 1;
    $lbin = $slength;
  }

  #warn "sample_size = $sample_size";

  my $coverage = $self->c_coverage($features, $sample_size, $lbin, $START, $self->strand);
     $coverage = [reverse @$coverage] if $slice->strand == -1;

  return $coverage;
}

use Inline C => <<'END_OF_CALC_COV_C_CODE';

#include "sam.h"
AV * c_coverage(SV *self, SV *features_ref, double sample_size, int lbin, int START, int STRAND) {
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

    if ((bam_is_rev(f) && STRAND == 1) || (!bam_is_rev(f) && STRAND == -1)) {
      continue;
    }

    fstart = f->core.pos+1;
    fend = bam_endpos(f);

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

1;
