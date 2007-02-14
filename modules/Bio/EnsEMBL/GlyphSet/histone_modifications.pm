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


  my $dataset_adaptor            = $db->get_DataSetAdaptor();
  if (!$dataset_adaptor) {
    warn ("Cannot get get adaptors: $dataset_adaptor");
    return [];
  }

  my %drawn_flag;
  foreach my $dataset  (@{  $dataset_adaptor->fetch_all_displayable() || [] } ){

    if ($self->my_config('compact')) {
      $drawn_flag{ 'wiggle' } = 1;
      $drawn_flag{ 'predicted_features' } = 1 if $self->pred_features($dataset);    # do just blue track    
      next if $drawn_flag{ 'predicted_features' };

      $drawn_flag{ 'wiggle' } = 1 if  $self->wiggle_plot($dataset);
      $self->render_space_glyph();
      next;
    }

    $drawn_flag{ 'predicted_features' } = 1 if $self->pred_features($dataset);    # do just blue track    
    $drawn_flag{ 'wiggle' } = 1 if $self->wiggle_plot($dataset) ;
  } # end foreach dataset


  return if $drawn_flag{'wiggle'} && $drawn_flag{'predicted_features'};

  # If both wiggle and predicted features tracks aren't drawn in expanded mode..
  my $error;
  if (!$drawn_flag{'predicted_features'}  && !$drawn_flag{'wiggle'}) {
    $error = "predicted features or tiling array data";
  }
  elsif (!$drawn_flag{'predicted_features'}) {
    $error = "predicted features";
  }
  elsif (!$drawn_flag{'wiggle'}) {
    $error = "tiling array data";
  }

  my $height = $self->errorTrack( "No $error in this region", 0, $self->_offset ) if $self->{'config'}->get('_settings','opt_empty_tracks')==1;
  $self->_offset($height + 4);
  return 1;
}



sub wiggle_plot {

  ### Wiggle plot
  ### Description: draws wiggle plot using the score of the features
  ### Returns 1 if draws wiggles. Returns 0 if no wiggles drawn

  my( $self, $dataset ) = @_;

  my $drawn_wiggle_flag = 0;
  my $slice = $self->{'container'};

  foreach my $result_set  (  @{ $dataset->get_displayable_ResultSets() } ){   

    #get features for slice and experimtenal chip set
    my @features = @{ $result_set->get_displayable_ResultFeatures_by_Slice($slice) };
    next unless @features;

    $drawn_wiggle_flag = 1;
    @features   = sort { $a->score <=> $b->score  } @features;
    my ($min_score, $max_score) = ($features[0]->score || 0, $features[-1]->score|| 0);

    my $row_height = 60;
    my $colour     = "contigblue1";
    my $offset     = $self->_offset();
    my $P_MAX = $max_score > 0 ? $max_score : 0;
    my $N_MIN = $min_score < 0 ? $min_score : 0;
    my $pix_per_score   = ($P_MAX-$N_MIN) ? $row_height / ( $P_MAX-$N_MIN ) : 0;
    my $red_line_offset = $P_MAX * $pix_per_score;


    # Draw the axis ------------------------------------------------
    $self->push( new Sanger::Graphics::Glyph::Line({ # horzi line
    'x'         => 0,
    'y'         => $offset + $red_line_offset,
    'width'     => $slice->length,
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
    'text'          => $display_max_score,
    'width'         => $res_i[2],
    'textwidth'     => $res_i[2],
    'font'          => $fontname_i,
    'ptsize'        => $fontsize_i,
    'halign'        => 'right',
    'valign'        => 'top',
    'colour'        => 'red',
    'height'        => $textheight_i,
    'y'             => $offset,
    'x'             => -4 - $res_i[2],
    'absolutey'     => 1,
    'absolutex'     => 1,
    'absolutewidth' => 1,
    }) );

    if ($min_score < 0) {
      my $display_min_score = sprintf("%.2f", $N_MIN); 
      my @res_min = $self->get_text_width( 0, $display_min_score, '', 
					   'font'=>$fontname_i, 
					   'ptsize' => $fontsize_i );

      $self->push(new Sanger::Graphics::Glyph::Text({
      'text'          => $display_min_score,
      'height'        => $textheight_i,
      'width'         => $res_min[2],
      'textwidth'     => $res_min[2],
      'font'          => $fontname_i,
      'ptsize'        => $fontsize_i,
      'halign'        => 'right',
      'valign'        => 'bottom',
      'colour'        => 'red',
      'y'             => $offset + $row_height - $textheight_i,
      'x'             => -4 - $res_min[2],
      'absolutey'     => 1,
      'absolutex'     => 1,
      'absolutewidth' => 1,
						    }));
    }


    # Draw wiggly plot -------------------------------------------------
    foreach my $f (@features) {
      my $START = $f->start < 1 ? 1 : $f->start;
      my $END   = $f->end   > $slice->length  ? $slice->length : $f->end;
      my $score = $f->score || 0;
     # warn(join('*', $f, $START, $END, $score));
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
    my @res_analysis = $self->get_text_width( 0,  $result_set->display_label(),
					      '', 'font'=>$fontname_i, 
					      'ptsize' => $fontsize_i );

    $self->push( new Sanger::Graphics::Glyph::Text({
    'text'      => $result_set->display_label(),
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
  } # foreach $result_set

  return $drawn_wiggle_flag;
}


sub pred_features {
  my ($self, $dataset) = @_;
  my $colour = "blue";
  my $drawn_flag = 0;
  foreach my $fset ( @{ $dataset->get_displayable_FeatureSets() }){
    my $display_label = $fset->display_label();
    my $features = $fset->get_PredictedFeatures_by_Slice($self->{'container'} ) ;
    next unless @$features;
    $drawn_flag = 1;
    $self->render_predicted_features( $features, $colour );
    $self->render_track_name($display_label, $colour);
  }

  $self->render_space_glyph();
  return $drawn_flag;
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
    "05:description: ".($f->feature_type->description() || '-') => '',
    "06:analysis:    ".($f->analysis->display_label() || '-')  => '',
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
