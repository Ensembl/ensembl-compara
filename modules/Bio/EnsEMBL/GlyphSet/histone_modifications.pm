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

  if ($self->my_config('compact')) {
    $self->init_compact;    # do just blue track    
  }
  else {
    $self->init_expand(); # do both tracks
    $self->init_compact(); # do both tracks
    $self->render_space_glyph();
  }
  return 1;
}

sub init_expand {

  ### Wiggle plot
  ### Description: gets data for the 'wiggle plot' and passes to
  ### {{render_signalmap}} for drawing
  ### Returns 1

  my ($self) = @_;
  my $slice = $self->{'container'};
  my $type = $self->check();
  my $max_length     = $self->{'config'}->get( $type, 'threshold' )  || 500;
  my $slice_length  = $slice->length;
  if($slice_length > $max_length*1010) {
    my $height = $self->errorTrack('Tiling array data not displayed for more than '.$max_length.'Kb');
    $self->_offset($height+4);
    return;
  }

  my $adaptor = $slice->adaptor();
  if(!$adaptor) {
    warn('Cannot get prediction features without attached adaptor');
    return [];
  }

  my $db = $slice->adaptor->db->get_db_adaptor('funcgen');
  if(!$db) {
    warn('Cannot connect to funcgen db');
    return [];
  }
  my $exp_adaptor  = $db->get_ExperimentAdaptor;
  my $exp_chip_adaptor  = $db->get_ExperimentalChipAdaptor;
  my $oligo_feature_adaptor = $db->get_OligoFeatureAdaptor;

  if (!$exp_adaptor or !$exp_chip_adaptor or !$oligo_feature_adaptor) {
    warn ("Cannot get get adaptors: $exp_chip_adaptor, $exp_adaptor, $oligo_feature_adaptor");
    return [];
  }

  my @results;
  my $analysis = $db->get_AnalysisAdaptor->fetch_by_logic_name("VSN_GLOG");# normalisation method

  my $configuration = {length => $slice->length, 
		       analysis => $analysis};

  my $drawn_flag = 0;
  # get_all_experiment_names method takes one arg: a displayable flag
  foreach my $name (@{ $exp_adaptor->get_all_experiment_names(1) || [] } ) {
    my $experiment = $exp_adaptor->fetch_by_name($name);

    # The wiggley tracks should be displayed for each contiguous set of  
    # each experiment. They need separating on experiment (and contig set).
    my @experiment_chip_sets = @{$exp_chip_adaptor->fetch_contigsets_by_experiment_dbID($experiment->dbID()) || []};

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
      $drawn_flag = 1;
      $configuration->{'features'} = \@draw_features;
      $self->render_signalmap($configuration);       # render these on track
    }
  }
  unless ($drawn_flag) {
   my $height = $self->errorTrack( "No tiling array data in this region", 0, $self->_offset ) if $self->{'config'}->get('_settings','opt_empty_tracks')==1;
   $self->_offset($height + 4);
  }
  return 1;
}


sub render_signalmap {

  ### Wiggle plot
  ### Arg1 : configuration hashref with arrayref of feature objects (hashref)
  ### Description: draws wiggle plot using the score of the features
  ### Returns 1

  my( $self, $configuration ) = @_;

  my $row_height = 60;
  my $colour     = "contigblue1";
  my $offset     = $configuration->{'offset'};
  my @features   = sort { $a->{score} <=> $b->{score}  } @{$configuration->{'features'}};
  my ($min_score, $max_score) = ($features[0]->{'score'} || 0, $features[-1]->{'score'}|| 0);

  my $pix_per_score   = ($max_score-$min_score) ? $row_height / ( $max_score-$min_score ) : 0;
  my $red_line_offset = $max_score * $pix_per_score;

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
  my $display_max_score = sprintf("%.2f", $max_score); 
  my( $fontname_i, $fontsize_i ) = $self->get_font_details( 'innertext' );
  my @res_i = $self->get_text_width( 0, $display_max_score, '', 
				     'font'=>$fontname_i, 
				     'ptsize' => $fontsize_i );
  my $textheight_i = $res_i[3];
  my $pix_per_bp = $self->{'config'}->transform->{'scalex'};

  $self->push( new Sanger::Graphics::Glyph::Text({
	'text'      => $display_max_score,
	'width'     => $res_i[2],
        'font'      => $fontname_i,
        'ptsize'    => $fontsize_i,
        'halign'    => 'right',
        'valign'    => 'top',
	'colour'    => 'red',
        'height'    => $textheight_i,
 	'y'         => $offset,
	'x'         => -3 - $res_i[2],
	'absolutey' => 1,
	'absolutex' => 1,
    }) );

  if ($min_score < 0) {
    my $display_min_score = sprintf("%.2f", $min_score); 
    my @res_min = $self->get_text_width( 0, $display_min_score, '', 
				     'font'=>$fontname_i, 
				     'ptsize' => $fontsize_i );

	$self->push( new Sanger::Graphics::Glyph::Text({
	    'text'       => $display_min_score,
            'height'     => $textheight_i,
	    'width'      => $res_min[2],
            'font'       => $fontname_i,
            'ptsize'     => $fontsize_i,
            'halign'     => 'right',
            'valign'     => 'bottom',
	    'colour'     => 'red',
	    'y'          => $offset + $row_height - $textheight_i,
	    'x'          => -4 - $res_min[2],
	    'absolutey' => 1,
	    'absolutex' => 1,
	}) );
      }


  # Draw wiggly plot -------------------------------------------------
  foreach my $f (@features) {
    my $START = $f->{'start'} < 1 ? 1 : $f->{'start'};
    my $END   = $f->{'end'}   > $configuration->{'length'}  ? $configuration->{'length'} : $f->{'end'};
    my $score = $f->{'score'} || 0;
    #	warn(join('*', 'F', $START, $END, $score));
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



sub init_compact {

  ### Predicted features
  ### Gets data for the predicted features track

  my ($self) = @_;

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

  my $features = $pf_adaptor->fetch_all_by_Slice($self->{'container'});
  if (@$features) {
    my $colour = "blue";
    $self->render_predicted_features( $features, $colour );
    $self->render_track_name($features->[0]->type->name, $colour);
  }
  elsif ( $self->my_config('compact') ) {
    $self->init_expand();
    $self->errorTrack( "No predicted features in this region", 0, $self->_offset ) if $self->{'config'}->get('_settings','opt_empty_tracks')==1;
    $self->render_space_glyph();
  }
  return 1;
}


sub render_predicted_features {

  ### Predicted features
  ### Draws the predicted features track
  ### Arg1: arrayref of Feature objects
  ### Arg2: colour of the track

  my ( $self, $features, $colour ) = @_;

  foreach my $f (@$features ) {
    my $Glyph = new Sanger::Graphics::Glyph::Rect({
	'y'         => $self->_offset,
        'height'    => 10,
	'x'         => $f->start -1,
        'width'     => $f->end - $f->start,
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
  my $slice_start   = $self->{'container'}->start + 1;
  my $pos =  ($slice_start + $f->start)."-".($f->end+$slice_start);
  my $score = sprintf("%.3f", $f->score());
  my %zmenu = ( 
  	       caption               => ($f->display_label || ''),
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
