package Bio::EnsEMBL::GlyphSet::histone_modifications;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet;
use Sanger::Graphics::Glyph::Text;
use Sanger::Graphics::Glyph::Rect;
use Bio::EnsEMBL::Utils::Eprof qw(eprof_start eprof_end eprof_dump); 
@ISA = qw(Bio::EnsEMBL::GlyphSet);
use Data::Dumper;

sub init_label {

  ### Returns (string) the label for the track

  my $self = shift;
  my $HELP_LINK = $self->check();
  $self->init_label_text( "Histone mod.",$HELP_LINK );
  $self->bumped( $self->{'config'}->get($HELP_LINK, 'compact') ? 'no' : 'yes' );
  return;
}


sub _init {
  my ($self) = @_;
  $self->bumped( $self->my_config( 'compact' ) ? 'no' : 'yes' );

  my $slice = $self->{'container'};
  my $max_length     = $self->{'config'}->get( $self->check(), 'threshold' )  || 500;
  my $slice_length  = $slice->length;
  if($slice_length > $max_length*1010) {
    my $height = $self->errorTrack('Tiling array data only displayed for less than '.$max_length.'Kb');
    $self->_offset($height+4);
    return;
  }

  my $db = $slice->adaptor->db->get_db_adaptor('funcgen');
  if(!$db) {
    warn('Cannot connect to funcgen db');
    return [];
  }
  my $exp_adaptor  = $db->get_ExperimentAdaptor;

  if (!$exp_adaptor) {
    warn ("Cannot get get adaptors: $exp_adaptor");
    return [];
  }

  my $vanalysis = $db->get_AnalysisAdaptor->fetch_by_logic_name("VSN_GLOG");# normalisation method
  my $sanger_analysis = $db->get_AnalysisAdaptor->fetch_by_logic_name("SangerPCR");# normalisation method

  # get_all_experiment_names method takes one arg: a displayable flag
  my %drawn_pf_flag;
  my %drawn_wiggle_flag;

  foreach my $name (@{ $exp_adaptor->get_all_experiment_names(1) || [] } ) {
    my $experiment = $exp_adaptor->fetch_by_name($name);
    my $experiment_id = $experiment->dbID;
    my $analysis = $experiment_id > 1 ? $sanger_analysis : $vanalysis;

    if ($self->my_config('compact')) {
      $drawn_wiggle_flag{1} = 1;
      $drawn_pf_flag{ $self->pred_features($experiment_id)} = 1;    # do just blue track    
      next if $drawn_pf_flag{1};

      $drawn_wiggle_flag{ $self->wiggle_plot($experiment_id, $analysis) } = 1;
      $self->errorTrack( "No predicted features in this region", 0, $self->_offset ) if $self->{'config'}->get('_settings','opt_empty_tracks')==1;
      $self->render_space_glyph();
      next;
    }

    $drawn_wiggle_flag{$self->wiggle_plot($experiment_id, $analysis)} = 1; # do both tracks
    $drawn_pf_flag {$self->pred_features($experiment_id)} = 1; # do both tracks
  }

  return if $drawn_pf_flag{1} && $drawn_wiggle_flag{1};

  # If both wiggle and predicted features tracks aren't drawn in expanded mode..
  my $error;
  if (!$drawn_pf_flag{1}  && !$drawn_wiggle_flag{1}) {
    $error = "predicted features or tiling array data";
  }
  elsif (!$drawn_pf_flag{1}) {
    $error = "predicted features";
  }
  elsif (!$drawn_wiggle_flag{1}) {
    $error = "tiling array data";
  }
  
  my $height = $self->errorTrack( "No $error in this region", 0, $self->_offset ) if $self->{'config'}->get('_settings','opt_empty_tracks')==1;
  $self->_offset($height + 4);

  return 1;
}

sub wiggle_plot {

  ### Wiggle plot
  ### Description: gets data for the 'wiggle plot' and passes to
  ### {{render_wiggle_plot}} for drawing
  ### Returns 1

  my ($self, $experiment_id, $analysis) = @_;
  my $slice = $self->{'container'};

  my $db = $slice->adaptor->db->get_db_adaptor('funcgen');
  if(!$db) {
    warn('Cannot connect to funcgen db');
    return [];
  }
  my $exp_chip_adaptor  = $db->get_ExperimentalChipAdaptor;
  my $oligo_feature_adaptor = $db->get_OligoFeatureAdaptor;

  if (!$exp_chip_adaptor or !$oligo_feature_adaptor) {
    warn ("Cannot get get adaptors: $exp_chip_adaptor, $oligo_feature_adaptor");
    return [];
  }

  my $drawn_wiggle_flag = 0;
  my $configuration = {length => $slice->length, 
		       analysis => $analysis};

  my @experiment_chip_sets = @{$exp_chip_adaptor->fetch_contigsets_by_experiment_dbID($experiment_id) || []};

  foreach my $set ( @experiment_chip_sets ) {
    # returns arrayref with ExperimentalChips in that set (first element is set name)
    $configuration->{'features'} = ();
    $configuration->{'track_name'} = shift @$set;

    #get features for slice and experimtenal chip set
    my @oligo_features = @{$oligo_feature_adaptor->fetch_all_by_Slice_ExperimentalChips($slice, $set) || [] };

    my @draw_features;
    foreach my $oligo_feature ( @oligo_features ){
      # restrict features to experimental chips
      my $score =  $oligo_feature->get_result_by_Analysis_ExperimentalChips($analysis, $set);
      my $start  = $oligo_feature->start; #50mer probe
      my $end    = $oligo_feature->end;
      push @draw_features, {'score' => $score,
			    'start' => $start,
			    'end'   => $end,
			   };
    }
    next unless @draw_features;
    $drawn_wiggle_flag = 1;
    $configuration->{'features'} = \@draw_features;
    $self->render_wiggle_plot($configuration);       # render these on track
  }
  return $drawn_wiggle_flag;
}


sub render_wiggle_plot {

  ### Wiggle plot
  ### Arg1 : configuration hashref with arrayref of feature objects (hashref)
  ### Description: draws wiggle plot using the score of the features
  ### Returns 1

  my( $self, $configuration ) = @_;

  my $row_height = 60;
  my $colour     = "contigblue1";
  my $offset     = $self->_offset();
  my @features   = sort { $a->{score} <=> $b->{score}  } @{$configuration->{'features'}};
  my ($min_score, $max_score) = ($features[0]->{'score'} || 0, $features[-1]->{'score'}|| 0);

  my $P_MAX = $max_score > 0 ? $max_score : 0;
  my $N_MIN = $min_score < 0 ? $min_score : 0;
  my $pix_per_score   = ($P_MAX-$N_MIN) ? $row_height / ( $P_MAX-$N_MIN ) : 0;
  my $red_line_offset = $P_MAX * $pix_per_score;

  # Draw the axis ------------------------------------------------
    $self->push( new Sanger::Graphics::Glyph::Line({ # horzi line
    'x'         => 0,
    'y'         => $offset + $red_line_offset,
    'width'     => $configuration->{'length'},
    'height'    => 0,
    'absolutey' => 1,
    'colour'    => 'red',
    'dotted'    => 1,
    }));

  $self->push( new Sanger::Graphics::Glyph::Line({ # vertical line
    'x'         => 0,
        'y'         => $offset,
    'width'     => 0,
    'height'    => $row_height,
    'absolutey' => 1,
    'absolutex' => 1,
    'colour'    => 'red',
    'dotted'    => 1,
    }));


  # Draw max and min score ---------------------------------------------
  my $display_max_score = sprintf("%.2f", $P_MAX); 
  my( $fontname_i, $fontsize_i ) = $self->get_font_details( 'innertext' );
  my @res_i = $self->get_text_width( 0, $display_max_score, '', 
                     'font'=>$fontname_i, 
                     'ptsize' => $fontsize_i );
  my $textheight_i = $res_i[3];
  my $pix_per_bp = $self->{'config'}->transform->{'scalex'};

  $self->push( new Sanger::Graphics::Glyph::Text({
    'text'      => $display_max_score,
    'width'     => $res_i[2],
    'textwidth'     => $res_i[2],
        'font'      => $fontname_i,
        'ptsize'    => $fontsize_i,
        'halign'    => 'right',
        'valign'    => 'top',
    'colour'    => 'red',
        'height'    => $textheight_i,
     'y'         => $offset,
    'x'         => -4 - $res_i[2],
    'absolutey' => 1,
    'absolutex' => 1,
    'absolutewidth' => 1,
    }) );

  if ($min_score < 0) {
    my $display_min_score = sprintf("%.2f", $N_MIN); 
    my @res_min = $self->get_text_width( 0, $display_min_score, '', 
                     'font'=>$fontname_i, 
                     'ptsize' => $fontsize_i );

    $self->push(new Sanger::Graphics::Glyph::Text({
      'text'       => $display_min_score,
      'height'     => $textheight_i,
      'width'      => $res_min[2],
      'textwidth'  => $res_min[2],
      'font'       => $fontname_i,
      'ptsize'     => $fontsize_i,
      'halign'     => 'right',
      'valign'     => 'bottom',
      'colour'     => 'red',
      'y'          => $offset + $row_height - $textheight_i,
      'x'          => -4 - $res_min[2],
      'absolutey'  => 1,
      'absolutex'  => 1,
      'absolutewidth' => 1,
     }));
  }


  # Draw wiggly plot -------------------------------------------------
  foreach my $f (@features) {
    my $START = $f->{'start'} < 1 ? 1 : $f->{'start'};
    my $END   = $f->{'end'}   > $configuration->{'length'}  ? $configuration->{'length'} : $f->{'end'};
    my $score = $f->{'score'} || 0;
    #    warn(join('*', 'F', $START, $END, $score));
    my $y = $score < 0 ? 0 : -$score * $pix_per_score;

    my $Glyph = new Sanger::Graphics::Glyph::Rect({
      'y'         => $offset + $red_line_offset + $y,
      'height'    => abs( $score * $pix_per_score ),
      'x'         => $START-1,
      'width'     => $END - $START,
      'absolutey' => 1,
      'title'     => sprintf("%.2f", $score),
      'colour'    => $colour,
    });
    $self->push( $Glyph );
  }

  $offset = $self->_offset($row_height);


  # Add line of text -------------------------------------------
  my @res_analysis = $self->get_text_width( 0, $configuration->{'track_name'},
                        '', 'font'=>$fontname_i, 
                        'ptsize' => $fontsize_i );

  $self->push( new Sanger::Graphics::Glyph::Text({
    'text'      => $configuration->{'track_name'},
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
  $self->render_space_glyph(5);
  return 1;
}



sub pred_features {

  ### Predicted features
  ### Gets data for the predicted features track
  ### Returns 1 if draws features, 0 if no features

  my ($self, $experiment_id) = @_;

  my $adaptor = $self->{'container'}->adaptor();
  if(!$adaptor) {
    warn('Cannot get histone modifications without attached adaptor');
    return [];
  }

  my $db = $adaptor->db->get_db_adaptor('funcgen');
  if (!$db) {
    warn ("Cannot connect to funcgen");
    return [];
  }
  my $pf_adaptor = $db->get_PredictedFeatureAdaptor();

  unless ($pf_adaptor) {
    warn("Funcgen database must be attached to core database to " .
     "retrieve funcgen information" );
    return 1;
  }

  my $features = $pf_adaptor->fetch_all_by_Slice_experiment_id($self->{'container'}, $experiment_id);
  return 0 unless @$features;

  my $colour = "blue";
  $self->render_predicted_features( $features, $colour );
  $self->render_track_name($features->[0]->type->name, $colour);
  $self->render_space_glyph();
  return 1;
}


sub render_predicted_features {

  ### Predicted features
  ### Draws the predicted features track
  ### Arg1: arrayref of Feature objects
  ### Arg2: colour of the track

  my ( $self, $features, $colour ) = @_;
  my $length = $self->{'container'}->length;

  foreach my $f (@$features ) {
    my $start = $f->start;
    my $end   = $f->end;
    $start = 1 if $start < 1;
    $end   = $length if $end > $length;
    my $Glyph = new Sanger::Graphics::Glyph::Rect({
      'y'         => $self->_offset,
      'height'    => 10,
      'x'         => $start -1,
      'width'     => $end - $start,
      'absolutey' => 1,          # in pix rather than bp
      'colour'    => $colour,
      'zmenu'     => $self->predicted_features_zmenu($f),
    });
    $self->push( $Glyph );
  }
  $self->_offset(10);
  return 1;
}


sub predicted_features_zmenu {

  ### Predicted features
  ### Creates zmenu for predicted features track
  ### Arg1: arrayref of Feature objects

  my ($self, $f ) = @_;
  my $offset = $self->{'container'}->strand > 0 ? $self->{'container'}->start - 1 :  $self->{'container'}->end + 1;
  my $pos =  ($offset + $f->start )."-".($f->end+$offset);
  my $score = sprintf("%.3f", $f->score());
  my %zmenu = ( 
    'caption'               => ($f->display_label || ''),
    "03:bp:   $pos"       => '',
    "04:type:        ".($f->type->name() || '-') => '',
    "05:description: ".($f->type->description() || '-') => '',
    "06:analysis: ".($f->analysis->logic_name() || "-") => '',
    "09:score: ".$score => '',
  );
  return \%zmenu || {};
}


sub render_track_name {

  ### Predicted features
  ### Draws the name of the predicted features track
  ### Arg1: arrayref of Feature objects
  ### Arg2: colour of the track

  my ( $self, $name, $colour ) = @_;
  my( $fontname_i, $fontsize_i ) = $self->get_font_details( 'innertext' );
  my @res_analysis = $self->get_text_width( 0, $name,
                        '', 'font'=>$fontname_i, 
                        'ptsize' => $fontsize_i );

  $self->push( new Sanger::Graphics::Glyph::Text({
    'text'      => $name,
    'height'    => $res_analysis[3],
    'width'     => $res_analysis[2],
    'font'      => $fontname_i,
    'ptsize'    => $fontsize_i,
    'halign'    => 'left',
    'valign'    => 'bottom',
    'colour'    => $colour,
    'y'         => $self->_offset,
    'x'         => 1,
    'absolutey' => 1,
    'absolutex' => 1,
    }) );

  $self->_offset($res_analysis[3]);
  return 1;
}


sub render_space_glyph {

  ### Draws a an empty glyph as a spacer
  ### Arg1 : (optional) integer for space height,

  my ($self, $space) = @_;
  $space ||= 9;
  $self->push( new Sanger::Graphics::Glyph::Space({
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
