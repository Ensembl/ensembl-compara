package Bio::EnsEMBL::GlyphSet_wiggle_and_block;

use strict;
use base qw(Bio::EnsEMBL::GlyphSet);

sub draw_error {
  my($self, $string ) = @_;
}
sub render_compact        { return $_[0]->_render();         }
sub render_tiling     { return $_[0]->_render('wiggle'); }
sub render_tiling_feature { return $_[0]->_render('both');   }

sub render_text {
  my ($self, $wiggle) = @_;
  
  my $container = $self->{'container'};
  my $feature_type = $self->my_config('caption');
  
  my $method = $self->can('export_feature') ? 'export_feature' : '_render_text';
  my $export;
  
  if ($wiggle ne 'wiggle') {
    my $element_features = $self->can('element_features') ?  $self->element_features : [];
    my $strand = $self->strand;
    my $strand_flag = $self->my_config('strand');
    my $length = $container->length;
    
    my @features = sort { $a->[1] <=> $b->[1] } map { ($strand_flag ne 'b' || $strand == $_->{'strand'}) && $_->{'start'} <= $length && $_->{'end'} >= 1 ? [ $_, $_->{'start'} ] : () } @$element_features;
     
    foreach (@features) {
      my $f = $_->[0];
      
      $export .= $self->$method($f, $feature_type, undef, {
        'seqname' => $f->{'hseqname'}, 
        'start'   => $f->{'start'} + ($f->{'hstrand'} > 0 ? $f->{'hstart'} : $f->{'hend'}),
        'end'     => $f->{'end'} + ($f->{'hstrand'} > 0 ? $f->{'hstart'} : $f->{'hend'}),
        'strand'  => '.',
        'frame'   => '.'
      });
    }
  }
  
  if ($wiggle) {
    my $score_features = $self->can('score_features') ? $self->score_features : [];
    my $name = $container->seq_region_name;
    
    foreach my $f (@$score_features) {
      my $pos = $f->seq_region_pos;
      
      $export .= $self->$method($f, $feature_type, undef, { 'seqname' => $name, 'start' => $pos, 'end' => $pos });
    }
  }
  
  return $export;
}

sub _render { ## Show both map and features
  my $self = shift;
  
  return $self->render_text(@_) if $self->{'text_export'};
  
## Check to see if we draw anything because of size!

  my $max_length    = $self->my_config( 'threshold' ) || 10000;
  my $slice_length  = $self->{'container'}->length;
  my $wiggle_name   = $self->my_config('wiggle_name') || $self->my_config('label') ;

  if($slice_length > $max_length*1010) {
    my $height = $self->errorTrack("$wiggle_name only displayed for less than $max_length Kb");
    $self->_offset($height+4);
    return 1;
  }

## Now we try and draw the features
  my $error = $self->draw_features( @_ );

  return unless $error && $self->{'config'}->get_parameter('opt_empty_tracks')==1;
  my $height = $self->errorTrack( "No $error in this region", 0, $self->_offset );
  $self->_offset($height + 4);
  return 1;
}

sub draw_block_features {

  ### Predicted features
  ### Draws the predicted features track
  ### Arg1: arrayref of Feature objects
  ### Arg2: colour of the track
  ### Returns 1

  my ( $self, $features, $colour, $score ) = @_;
  my $length = $self->{'container'}->length;

  my $h = 10;
  foreach my $f (@$features ) {
    my $start = $f->start;
    my $end   = $f->end;
    $start = 1 if $start < 1;
    $end   = $length if $end > $length;
    $self->push($self->Rect({
      'y'         => $self->_offset,
      'height'    => $h,
      'x'         => $start -1,
      'width'     => $end - $start,
      'absolutey' => 1,          # in pix rather than bp
      'colour'    => $colour,
      'href'     => $self->block_features_zmenu($f, $score),
    }));
  }
  $self->_offset( $h+3 );
  return 1;
}

sub draw_wiggle_plot {
  ### Wiggle plot
  ### Args: array_ref of features in score order, colour, min score for features, max_score for features, display label
  ### Description: draws wiggle plot using the score of the features
  ### Returns 1

  my( $self, $features, $parameters, $colours ) = @_; 


  my $METHOD_ID      = $self->my_config( 'method_link_species_set_id' );
  my $zmenu = {
      'type'   => 'Location',
      'action' => 'Align',
      'align'  => $METHOD_ID,
  };

  my $slice           = $self->{'container'};
  my $row_height      = $self->my_config('height') || 60;
  my $offset          = $self->_offset();

  my $P_MAX           = $parameters->{'max_score'} > 0 ? $parameters->{'max_score'} : 0; 
  my $N_MIN           = $parameters->{'min_score'} < 0 ? $parameters->{'min_score'} : 0;  

  my $pix_per_score   = ($P_MAX-$N_MIN) ? $row_height / ( $P_MAX-$N_MIN ) : 0;
  my $red_line_offset = $P_MAX * $pix_per_score;

  my $colour          = $parameters->{'score_colour'}|| $self->my_colour('score')|| 'blue';
  my $axis_colour     = $parameters->{'axis_colour'} || $self->my_colour('axis') || 'red';
  my $label           = $parameters->{'description'} || $self->my_colour('score','text');
  my $name            = $self->my_config('short_name') || $self->my_config('name');
     $label =~ s/\[\[name\]\]/$name/;

  # Draw the axis ------------------------------------------------
  $self->push( $self->Line({ # horzi line
    'x'         => 0,
    'y'         => $offset + $red_line_offset,
    'width'     => $slice->length,
    'height'    => 0,
    'absolutey' => 1,
    'colour'    => $axis_colour,
    'dotted'    => 1,
  }),$self->Line({ # vertical line
    'x'         => 0,
    'y'         => $offset,
    'width'     => 0,
    'height'    => $row_height,
    'absolutey' => 1,
    'absolutex' => 1,
    'colour'    => $axis_colour,
    'dotted'    => 1,
  }));


  # Draw max and min score ---------------------------------------------
  my $display_max_score = sprintf("%.2f", $P_MAX); 
  my( $fontname_i, $fontsize_i ) = $self->get_font_details( 'innertext' );
  my @res_i = $self->get_text_width(
    0, $display_max_score, '', 'font'=>$fontname_i, 'ptsize' => $fontsize_i );
  my $textheight_i = $res_i[3];
  my $pix_per_bp = $self->scalex;
  my $axis_label_flag = $parameters->{'axis_label'} ? "off": "on"; 
  
  if ($axis_label_flag eq 'on'){ 
    $self->push( $self->Text({ 
      'text'          => $display_max_score,
      'width'         => $res_i[2],
      'textwidth'     => $res_i[2],
      'font'          => $fontname_i,
      'ptsize'        => $fontsize_i,
      'halign'        => 'right',
      'valign'        => 'top',
      'colour'        => $axis_colour,
      'height'        => $textheight_i,
      'y'             => $offset,
      'x'             => -4 - $res_i[2],
      'absolutey'     => 1,
      'absolutex'     => 1,
      'absolutewidth' => 1,
    }));

    if ($parameters->{'min_score'} <= 0) {
      my $display_min_score = sprintf("%.2f", $N_MIN); 
      my @res_min = $self->get_text_width(
        0, $display_min_score, '', 'font'=>$fontname_i, 'ptsize' => $fontsize_i );

      $self->push($self->Text({
        'text'          => $display_min_score,
        'height'        => $textheight_i,
        'width'         => $res_min[2],
        'textwidth'     => $res_min[2],
        'font'          => $fontname_i,
        'ptsize'        => $fontsize_i,
        'halign'        => 'right',
        'valign'        => 'bottom',
        'colour'        => $axis_colour,
        'y'             => $offset + $row_height - $textheight_i,
        'x'             => -4 - $res_min[2],
       'absolutey'     => 1,
       'absolutex'     => 1,
       'absolutewidth' => 1,
      }));
    }
  }


  # Draw wiggly plot -------------------------------------------------
  ## Check to see if we have multiple data sets to draw on one axis 
  if ( ref($features->[0]) eq 'ARRAY' ){
    foreach my $feature_set ( @$features){
      $colour = shift @$colours; 
      $self->draw_wiggle_points($feature_set, $slice, $parameters, $offset, $pix_per_score, $colour, $red_line_offset);
    }
  }   
  else {
    $self->draw_wiggle_points($features, $slice,$parameters, $offset, $pix_per_score, $colour, $red_line_offset);  
  }
  $offset = $self->_offset($row_height);


  # Add line of text -------------------------------------------
  my @res_analysis = $self->get_text_width( 0,  $label, '', 'font'=>$fontname_i, 'ptsize' => $fontsize_i ); 
  
  $self->push( $self->Text({
    'text'      => $label,
    'width'     => $res_analysis[2],
    'font'      => $fontname_i,
    'ptsize'    => $fontsize_i,
    'halign'    => 'left',
    'valign'    => 'bottom',
    'colour'    => $colour,
    'y'         => $offset,
    'height'    => $textheight_i,
    'x'         => 1,
    'absolutey' => 1,
    'absolutex' => 1,
  }) ); 
  $self->_offset($textheight_i);  #update offset
  return 1;
}

sub draw_wiggle_points { 
  my ($self, $features, $slice, $parameters, $offset, $pix_per_score, $colour, $red_line_offset) = @_; 

  foreach my $f (@$features) {
    my $START = $f->start < 1 ? 1 : $f->start; 
    my $END   = $f->end   > $slice->length  ? $slice->length : $f->end; 
    my ($score, $min_score);
    if ($f->isa("Bio::EnsEMBL::Variation::ReadCoverageCollection")){
      $score = $f->read_coverage_max;
      $min_score = $f->read_coverage_min;
    } else {
      $score = $f->score || 0;
    }
    my $y = $score < 0 ? 0 : -$score * $pix_per_score;
    #my $y = -$score * $pix_per_score;
    my $height;
    if (my $graph_type = $parameters->{'graph_type'}) {
      $height = $graph_type eq 'points' ? 20 : 0; 
    }
    else {
      $height = $score;
    }
    $height *= $pix_per_score;

    # warn(join('*', $f, $START, $END, $score));
    $self->push($self->Rect({
      'y'         => $offset + $red_line_offset + $y,
      'height'    => abs( $height ),
      'x'         => $START-1,
      'width'     => $END - $START+1,
      'absolutey' => 1,
      'title'     => sprintf("%.2f", $score),
      'colour'    => $colour,
    }));
    if ($min_score){
      my $y = $score < 0 ? 0 : -$min_score * $pix_per_score;
      $self->push($self->Rect({

        'y'         => $offset + $red_line_offset + $y,
        'height'    => abs( $min_score * $pix_per_score ),
        'x'         => $START-1,
        'width'     => $END - $START+1,
        'absolutey' => 1,
        'title'     => sprintf("%.2f", $score),
        'colour'    => 'steelblue',
      }));
    }
  }
return 1;
} 

sub draw_track_name {

  ### Predicted features
  ### Draws the name of the predicted features track
  ### Arg1: arrayref of Feature objects
  ### Arg2: colour of the track
  ### Returns 1

  my ( $self, $name, $colour, $x_offset, $y_offset, $no_offset   ) = @_;
  my $x = $x_offset || 1;
  my $y = $self->_offset;
  if ($y_offset) {$y += $y_offset;}
  my( $fontname_i, $fontsize_i ) = $self->get_font_details( 'innertext' );
  my @res_analysis = $self->get_text_width(
    0, $name, '', 'font'=>$fontname_i, 'ptsize' => $fontsize_i );

  $self->push( $self->Text({
    'text'      => $name,
    'height'    => $res_analysis[3],
    'width'     => $res_analysis[2],
    'font'      => $fontname_i,
    'ptsize'    => $fontsize_i,
    'halign'    => 'left',
    'valign'    => 'bottom',
    'colour'    => $colour,
    'y'         => $y,
    'x'         => $x,
    'absolutey' => 1,
    'absolutex' => 1,
  }));

  $self->_offset($res_analysis[3]) unless $no_offset; 
  return 1;
}

sub draw_space_glyph {

  ### Draws a an empty glyph as a spacer
  ### Arg1 : (optional) integer for space height,
  ### Returns 1

  my ($self, $space) = @_;
  $space ||= 9;

  $self->push( $self->Space({
    'height'    => $space,
    'width'     => 1,
    'y'         => $self->_offset,
    'x'         => 0,
    'absolutey' => 1,  # puts in pix rather than bp
    'absolutex' => 1,
  }));
  $self->_offset($space);
  return 1;
}


sub _offset {

  ### Arg1 : (optional) number to add to offset
  ### Description: Getter/setter for offset
  ### Returns : integer

  my ($self, $offset) = @_;
  $self->{'offset'} += $offset if $offset;
  return $self->{'offset'} || 0;
}


1;
### Contact: Fiona Cunningham fc1@sanger.ac.uk
