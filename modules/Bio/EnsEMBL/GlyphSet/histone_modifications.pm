package Bio::EnsEMBL::GlyphSet::histone_modifications;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_simple;
use Bio::EnsEMBL::Utils::Eprof qw(eprof_start eprof_end eprof_dump); 
@ISA = qw(Bio::EnsEMBL::GlyphSet_simple);
use Data::Dumper;

sub my_label { return "Histone modification"; }


sub init {
  my ($self) = @_;
  $self->bumped( $self->my_config( 'compact' ) ? 'no' : 'yes' );

  if ($self->my_config('compact')) {
    $self->init_collapse;    # do just blue track
    
  }
  else {
    $self->init_expand; # do both tracks
    $self->init_collapse; # do both tracks
  }
  return 1;
}

sub features { #init_compact {
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
  if( $pf_adaptor ) {
    my $features = $pf_adaptor->fetch_all_by_Slice($self->{'container'});
    return $features;
  } 
  else {
    warn("Funcgen database must be attached to core database to " .
	    "retrieve funcgen information" );
    return [];
  }
}


sub zmenu {
  my ($self, $f ) = @_;
  my $pos =  $f->start."-".$f->end;
  my $score = sprintf("%.3f", $f->score());
  my %zmenu = ( 
  	       caption               => ($f->display_label || ''),
  	       "03:bp:   $pos"       => '',
  	       "04:type:        ".($f->type->name() || '-') => '',
  	       "05:description: ".($f->type->description() || '-') => '',
  	       "09:score: ".$score => '',
 	      );

   return \%zmenu;
 }

sub init_expand {

  ### Returns arrayref of features

  my ($self) = @_;
  my $slice = $self->{'container'};
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

  my $configuration = {length => $slice->seq_region_length, 
		       offset => 0,  };

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
      $configuration->{'features'} = \@draw_features;
      $self->RENDER_signalmap($configuration);       # render these on track
    }
  }
  return 1;
}


sub RENDER_signalmap {
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
        'height'    => $textheight_i,
	'width'     => $res_i[2],
        'font'      => $fontname_i,
        'ptsize'    => $fontsize_i,
        'halign'    => 'right',
        'valign'    => 'top',
	'colour'    => 'red',
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
    # keep within the window we're drawing
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
  } # END loop over features

  $configuration->{'offset'} += $row_height +9;
  return 1;
}   # END RENDER_signalmap


1;
