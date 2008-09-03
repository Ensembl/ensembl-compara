package Bio::EnsEMBL::GlyphSet::ctcf;
use strict;
use base qw(Bio::EnsEMBL::GlyphSet_wiggle_and_block);

sub my_helplink { return "ctcf"; }

sub get_block_features {
  ### block_features
  my ( $self, $db ) = @_; 
  unless ( $self->{'block_features'} ) {
    my $feature_adaptor = $db->get_DataSetAdaptor(); 
    if (!$feature_adaptor) {
      warn ("Cannot get get adaptors: $feature_adaptor");
      return [];
    }
     #warn "Adapt $feature_adaptor"; 
     my $features = $feature_adaptor->fetch_all_displayable_by_feature_type_class('Insulator') || [] ;  warn "FEATS $features";
    $self->{'block_features'} = $features; 
  }

  my $colour = "dodgerblue4";
  return ( $self->{'block_features'}, $colour);
}


sub draw_features {

  ### Description: gets features for block features and passes to render_block_features
  ### Draws wiggles if wiggle flag is 1
  ### Returns 1 if draws blocks. Returns 0 if no blocks drawn

  my ($self, $db, $wiggle)= @_; 
  my ($block_features, $colour) = $self->get_block_features($db);
  my $drawn_flag = 0;
  my $drawn_wiggle_flag = $wiggle ? 0: "wiggle"; warn $wiggle;
  my $slice = $self->{'container'};
  my $wiggle_colour = "steelblue";
  foreach my $feature ( @$block_features ) {

    # render wiggle if wiggle
   if ($wiggle) { 
	foreach my $result_set  (  @{ $feature->get_displayable_supporting_sets() } ){ 
	 
	 #get features for slice and experimental chip set
	 my @features = @{ $result_set->get_displayable_ResultFeatures_by_Slice($slice) }; 
	 next unless @features; 	
	 $drawn_wiggle_flag = "wiggle";
	 @features   = sort { $a->score <=> $b->score  } @features;
	 my ($min_score, $max_score) = ($features[0]->score || 0, $features[-1]->score|| 0); 
	 $self->render_wiggle_plot(\@features, $wiggle_colour, $min_score, $max_score, $result_set->display_label);
   }
      $self->render_space_glyph() if $drawn_wiggle_flag;
  }

    # Block feature 
   my $fset = $feature->get_displayable_product_FeatureSet();   
      my $display_label = $fset->display_label();
      my $features = $fset->get_Features_by_Slice($slice ) ;
      next unless @$features;
      $drawn_flag = "block_features";
      $self->render_block_features( $features, $colour );
     $self->render_track_name($display_label, $colour);
  }

  $self->render_space_glyph() if $drawn_flag;
  my $error = $self->draw_error_tracks($drawn_flag, $drawn_wiggle_flag);
  return $error;
}

sub draw_error_tracks {
  my ($self, $drawn_blocks, $drawn_wiggle) = @_;
  return 0 if $drawn_blocks && $drawn_wiggle;

  # Error messages ---------------------
  my $wiggle_name   =  $self->my_config('wiggle_name');
  my $block_name =  $self->my_config('block_name') ||  $self->my_config('label');
  # If both wiggle and predicted features tracks aren't drawn in expanded mode..
  my $error;
  if (!$drawn_blocks  && !$drawn_wiggle) {
    $error = "$block_name or $wiggle_name";
  }
  elsif (!$drawn_blocks) {
    $error = $block_name;
  }
  elsif (!$drawn_wiggle) {
    $error = $wiggle_name;
  }
  return $error;
}

sub block_features_zmenu {

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
    "06:analysis:    ".($f->analysis->logic_name() || '-')  => '',
    "09:score: ".$score => '',
  );
  return \%zmenu || {};
}


1;
### Contact: Bethan Pritchard bp1@sanger.ac.uk
