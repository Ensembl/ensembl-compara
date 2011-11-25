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

  return unless $error && $self->{'config'}->get_option('opt_empty_tracks') == 1;
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

  my ( $self, $features, $colour, $score, $display_summit, $display_pwm) = @_;
  my $length = $self->{'container'}->length;
  my $h = 8;
  foreach my $f (@$features ) {
    my $start = $f->start;  
    my $end   = $f->end;
    my $midpoint =  $f->summit;
    $start = 1 if $start < 1; 
    $end   = $length if $end > $length;  
    my $y = $self->_offset;
    $self->push($self->Rect({
      'x'         => $start -1,
      'y'         => $y,
      'height'    => $h,
      'width'     => $end - $start,
      'absolutey' => 1,          # in pix rather than bp
      'colour'    => $colour,
      'href'      => $self->block_features_zmenu($f, $score),
      'class'     => 'group',
    }));
    if ($display_pwm) { 
      my @loci = @{$f->get_underlying_structure}; 
      my $end  = pop @loci;
      my ($start, @mf_loci) = @loci;

      while ( my ($mf_start, $mf_end) = splice (@mf_loci, 0, 2) ){  
        my $mf_length = ($mf_end - $mf_start) +1;
        $self->push($self->Rect({
          'x'         => $mf_start -1,
          'y'         => $y,
          'height'    => $h,
          'width'     => $mf_length,
          'absolutey' => 1,          # in pix rather than bp
          'colour'    => 'black',
        }));
      }        
    }
    if ($length <= 20000 && $midpoint && $display_summit){
      $midpoint -= $self->{'container'}->start; 
      if ($midpoint > 0 && $midpoint < $length ){
        my $pix_per_bp = $self->scalex;
        # Upward pointing triangle
        my $triangle_end   =  $midpoint - 2/$pix_per_bp;
        my $triangle_start =  $midpoint + 2/$pix_per_bp;
        $self->push($self->Poly({
          'points'    => [ $triangle_start, $h+4+$y,
                           $midpoint, $h+$y,
                           $triangle_end, $h+4+$y  ],
          'colour'    => 'black',
          'absolutey' => 1,
        }));
        # Downward pointing triangle
        $self->push($self->Poly({
          'points'    => [ $triangle_start, $h-12+$y,
                           $midpoint,  $h-9+$y,
                           $triangle_end, $h-12+$y ], 

          'colour'    => 'black',
        'absolutey' => 1,
        }));
      }
    }
  }

  $self->_offset( $h+6 );
  return 1;
}

sub draw_wiggle_plot {
  ### Wiggle plot
  ### Args: array_ref of features in score order, colour, min score for features, max_score for features, display label
  ### Description: draws wiggle plot using the score of the features
  ### Returns 1

  my( $self, $features, $parameters, $colours, $labels ) = @_; 


  my $METHOD_ID      = $self->my_config( 'method_link_species_set_id' );
  my $zmenu = {
      'type'   => 'Location',
      'action' => 'Align',
      'align'  => $METHOD_ID,
  };

  my $slice           = $self->{'container'};
  my $row_height      = $self->{'height'} || $self->my_config('height') || 60;
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
  my $axis_style = 1;
  if ($parameters->{'graph_type'} eq 'line') { $axis_style = 0; }

  # Draw the labels ----------------------------------------------
  ## Only done if we have multiple data sets
  if ($labels){
    my $header_label = shift @$labels;

    my $y = $self->_offset;
    my $y_offset  =  0;
    my( $fontname_i, $fontsize_i ) = $self->get_font_details( 'innertext' );
    my @res_analysis = $self->get_text_width(
    0, 'Legend', '', 'font'=>$fontname_i, 'ptsize' => $fontsize_i );
    if($header_label eq 'CTCF'){
      $y += 15; 
      $colour = shift @$colours;
    }else {
      $self->push( $self->Text({
        'text'      => $header_label,
        'height'    => $res_analysis[3],
        'width'     => $res_analysis[2],
        'font'      => $fontname_i,
        'ptsize'    => $fontsize_i,
        'halign'    => 'left',
        'valign'    => 'bottom',
        'colour'    => 'black',
        'y'         => $y,
        'x'         => -118,
        'absolutey' => 1,
        'absolutex' => 1,
      }));
    }
    my $legend_alt_text;  
    my $max = scalar @$labels -1;
    my %seen;
    for( my $i = 0; $i <= $max; $i++){ 
      my $name = $labels->[$i];
      my $colour = $colours->[$i];
      unless (exists $seen{$name}){  
        $legend_alt_text .= $name.':'.$colour .',';
        $seen{$name} = 1;
      }
    }
    $legend_alt_text =~s/,$//;
    # add colour key legend  
    $y += 13;
    $self->push( $self->Rect({
      'width'     => $res_analysis[2] +15,
      'height'    => $res_analysis[3] +2,
      'y'         => $y,
      'x'         => -109,
      'absolutey' => 1,
      'absolutex' => 1,
      'title'     => "$header_label; [$legend_alt_text ]",
      'absolutewidth' => $res_analysis[2] +15,
      'class'         =>  'coloured',
      'bordercolour'  => '#336699',
      'colour'    => 'white',
    }));
    $self->push( $self->Text({
      'text'      => 'Legend',
      'height'    => $res_analysis[3],
      'font'      => $fontname_i,
      'ptsize'    => $fontsize_i,
      'halign'    => 'left',
      'valign'    => 'bottom',
      'colour'    => '#336699',
      'y'         => $y,
      'x'         => -108,
      'absolutey' => 1,
      'absolutex' => 1,
    }));
    my $triangle_start =  -113 + $res_analysis[2] +6;
    my $triangle_end =   -113 + $res_analysis[2] +12;
    $self->push ( $self->Poly({
      'points'    => [ $triangle_start, $y+4,
                       -113 + $res_analysis[2] +9, $y+9, 
                       $triangle_end, $y+4,
                         ],
      'colour'    => '#336699',
      'absolutex' => 1,
      'absolutey' => 1,
    }));  
    $y_offset += 12;
    $offset += 15;
    $self->_offset($y_offset); #unless $no_offset;        
  }
  unless ($parameters->{'no_axis'}) {
    # Draw the axis ------------------------------------------------
    $self->push( $self->Line({ # horzi line
      'x'         => 0,
      'y'         => $offset + $red_line_offset,
      'width'     => $slice->length,
      'height'    => 0,
      'absolutey' => 1,
      'colour'    => $axis_colour,
      'dotted'    => $axis_style,
    }),$self->Line({ # vertical line
      'x'         => 0,
      'y'         => $offset,
      'width'     => 0,
      'height'    => $row_height,
      'absolutey' => 1,
      'absolutex' => 1,
      'colour'    => $axis_colour,
      'dotted'    => $axis_style,
    }));
  }

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
      if ($parameters->{'graph_type'} eq 'line') {
        $self->draw_wiggle_points_as_line($feature_set, $slice, $parameters, $offset, $pix_per_score, $colour, $red_line_offset);
      } else{ 
        $self->draw_wiggle_points($feature_set, $slice, $parameters, $offset, $pix_per_score, $colour, $red_line_offset);
      }
    }
  }   
  else {
    $self->draw_wiggle_points($features, $slice, $parameters, $offset, $pix_per_score, $colour, $red_line_offset);  
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
  my $hrefs = $parameters->{'hrefs'};
  foreach my $f (@$features) { 
    my $href = '';
    if (ref($f) ne 'HASH' && $f->can('id')){
      $href = $hrefs->{$f->id};
    }
    my ($START, $END, $score, $min_score);

    if (ref($f) eq 'HASH'){ # Data is from a Funcgen result set collection, windowsize > 0
      my $start = $f->{'start'};
      my $end = $f->{'end'};
      $START = $start < 1 ? 1 : $start;
      $END   = $end   > $slice->length  ? $slice->length : $end;
      $score = $f->{'score'};
    } else {
      $START = $f->start < 1 ? 1 : $f->start; 
      $END   = $f->end   > $slice->length  ? $slice->length : $f->end;  

      if ($f->isa("Bio::EnsEMBL::Variation::ReadCoverageCollection")){
        $score = $f->read_coverage_max;
        $min_score = $f->read_coverage_min;
      } else {
        if ($f->can('score')){
          $score = $f->score || 0;
        } elsif($f->can('scores')) {
          $score = $f->scores->[0];
        }
      }
    }

    my ($y, $height);
    if ($parameters->{'graph_type'} eq 'points') {
      $y = -$score * $pix_per_score;
      $height = 0; 
    }
    else {
      $y = $score < 0 ? 0 : -$score * $pix_per_score;
      $height = $score;
    }
    $height *= $pix_per_score;
    my $this_colour = $colour;

    # alter colour if the intron supporting feature has a name of non_canonical
    if (ref($f) ne 'HASH' && $f->can('display_id') && $f->display_id =~ /non canonical$/ && $f->analysis->logic_name =~ /_intron$/) {
      $this_colour = $parameters->{'non_can_score_colour'} ||  $colour;
    }
 
    my $dets = {
      'y'         => $offset + $red_line_offset + $y,
      'height'    => abs( $height ),
      'x'         => $START-1,
      'width'     => $END - $START+1,
      'absolutey' => 1,
      'title'     => sprintf("%.2f", $score),
      'colour'    => $this_colour,
    };
    $dets->{'href'} = $href if $href;
    $self->push($self->Rect($dets));
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

sub draw_wiggle_points_as_line {
  my ($self, $features, $slice, $parameters, $offset, $pix_per_score, $colour, $red_line_offset) = @_;
  my $slice = $self->{'container'};
  my $Config          = $self->{'config'}; 
  my $vclen           = $slice->length(); 
  my $im_width        = $Config->image_width();
  my $window_size     = 10;
  unless(ref($features->[0]) eq 'HASH') {$window_size = $features->[0]->window_size;}

  if($window_size == 0){
    my @temp = @{$features};
     @temp = sort { $a->start <=> $b->start } @temp;
    $features = \@temp;
  }
 

  my $previous_f = $features->[0]; 
  my $previous_x = ($previous_f->{'end'} + $previous_f->{'start'}) / 2;
  my $previous_score = $previous_f->{'score'};

  if ($window_size == 0 ){
    $previous_score = $previous_f->scores->[0];
    $previous_x = ($previous_f->end + $previous_f->start)/2;
  }
  my $previous_y = $previous_score < 0 ? 0 : -$previous_score * $pix_per_score;
  $previous_y = $offset + $red_line_offset + $previous_y;


  for ( my $i = 1; $i <= @$features; $i++) {    
    my $f = $features->[$i];
    my $current_x = ($f->{'end'} + $f->{'start'}) / 2; 
    my $current_score = $f->{'score'}; 
    if ($window_size == 0){
      next if (ref($f) eq 'HASH');
      $current_score = $f->scores->[0];
      $current_x = ($f->end + $f->start)/2; 
    }
    my $current_y =  $current_score < 0 ? 0 : -$current_score * $pix_per_score;

    my $width = 1 - (($current_x - $previous_x) +1); 
    next if ($width >= 1);
    my $y_coord = $offset + $red_line_offset + $current_y;
    my $height = 1 - ($y_coord - $previous_y);    

    next unless ($current_x <= $vclen ); 
    $self->push($self->Line({
        'x'            => $current_x,
        'y'            => $y_coord,
        'width'        => $width,
        'height'       => $height,
        'colour'       => $colour,
        'absolutey'    => 1,
      }));
  
    $previous_x = $current_x;
    $previous_y = $y_coord;
    $previous_f = $f;
    $previous_score = $current_score;  
  }
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
    'x'         => $x,
    'y'         => $y,
    'text'      => $name,
    'height'    => $res_analysis[3],
    'width'     => $res_analysis[2],
    'halign'    => 'left',
    'valign'    => 'bottom',
    'font'      => $fontname_i,
    'ptsize'    => $fontsize_i,
    'colour'    => $colour,
    'absolutey' => 1,
    'absolutex' => 1,
  }));

  $self->_offset($res_analysis[3]) unless $no_offset; 
  return 1;
}

sub display_no_data_error{
 my ($self, $error_string) = @_;
  my $height = $self->errorTrack( $error_string, 0, $self->_offset );
  $self->_offset($height + 4); 
}

sub draw_separating_line {
  my ($self) = @_;
  my $Config = $self->{'config'};
  my $im_width        = $Config->image_width();

  # Set up a separating line...
  my $rect = $self->Rect({
    'x'             => -125,
    'y'             => $self->_offset +5,
    'width'         => $im_width,
    'height'        => 2,
    'colour'        => 'grey40',
    'absolutey'     => 1,
    'absolutex'     => 1,
    'absolutewidth' =>1,
  });
  $self->push($rect);
  $self->_offset(8);
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
