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

package EnsEMBL::Draw::GlyphSet::ctcf;

### Draw CTCF regulatory features track
### (See matrices for TFBS - transcription factor binding sites)

use strict;

use base qw(EnsEMBL::Draw::GlyphSet_wiggle_and_block);

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
     my $features = $feature_adaptor->fetch_all_displayable_by_feature_type_class('Insulator') || [] ;  
    $self->{'block_features'} = $features; 
  }

  return $self->{'block_features'};
}


sub draw_features {
  ### Description: gets features for block features and passes to render_block_features
  ### Draws wiggles if wiggle flag is 1
  ### Returns 1 if draws blocks. Returns 0 if no blocks drawn

  my ($self, $wiggle)= @_;  
  my $db =  $self->dbadaptor( 'homo sapiens', 'FUNCGEN' );  
  my $block_features = $self->get_block_features($db);
  my $drawn_flag = 0;
  my $drawn_wiggle_flag = $wiggle ? 0: "wiggle"; 
  my $slice = $self->{'container'};
  foreach my $feature ( @$block_features ) {
    my $label = $feature->get_displayable_product_FeatureSet->display_label; 
    my $fset_cell_line = $feature->get_displayable_product_FeatureSet->cell_type->name;
    next unless $fset_cell_line =~/IMR90/;
    my $colour = $self->my_colour($fset_cell_line) || 'steelblue';
    # render wiggle if wiggle
    if( $wiggle ) { 
      my $max_bins = $self->{'config'}->image_width();
      foreach my $result_set  ( @{ $feature->get_displayable_supporting_sets() } ){
        my $rfs =  $result_set->get_ResultFeatures_by_Slice($slice, undef, undef, $max_bins);
        next unless @$rfs;
        $drawn_wiggle_flag = "wiggle";

        my $wsize = $rfs->[0]->window_size; 
        my $start = 1 - $wsize;#Do this here so we minimize the number of calcs done in the loop
        my $end   = 0;
        my $score;
        my @features = @$rfs;
        @features   = sort { $a->scores->[0] <=> $b->scores->[0]  } @features;
        my ($min_score, $max_score) = @{$features[0]->get_min_max_scores()};
        if ($wsize ==0){
          $min_score = $features[0]->scores->[0];
          $max_score = $features[-1]->scores->[0];
        } else {
          @features = ();
          foreach my $rf (@$rfs){
            for my $x(0..$#{$rf->scores}){
              $start += $wsize;
              $end += $wsize;
              $score = $rf->scores->[$x];
              my $f = { 'start' => $start, 'end' => $end, 'score' => $score };
              push (@features, $f);
            }
          }
        }

        # render wiggle plot        
        $self->draw_wiggle_plot(
          \@features,                      ## Features array
          { 'min_score' => $min_score, 'max_score' => $max_score },
          [$colour],
          ['CTCF', $label],
        );
      }
      $self->draw_space_glyph() if $drawn_wiggle_flag;
    }

    # Block feature 
    if( !$wiggle || $wiggle eq 'both' ) { 
       my $fset = $feature->get_displayable_product_FeatureSet();   
       my $display_label = $fset->display_label();
       my $features = $fset->get_Features_by_Slice($slice ) ;
       next unless @$features;
       $drawn_flag = "block_features";
       $self->draw_block_features( $features, $colour );
       $self->draw_track_name($display_label, $colour);
    }
  }

  $self->draw_space_glyph() if $drawn_flag;
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


sub render_text {
  my ($self, $wiggle) = @_;
  
  my $container = $self->{'container'};
  my $feature_type = $self->my_config('caption');
  my ($features) = $self->get_block_features($self->dbadaptor('homo sapiens', 'FUNCGEN'));
  my ($start, $end) = ($container->start, $container->end);
  my $export;
  
  foreach (@$features) {
    if ($wiggle) {
      foreach my $result_set (@{$_->get_displayable_supporting_sets}) { 
        foreach (@{$result_set->get_displayable_ResultFeatures_by_Slice($container)}) {
          my $strand = $_->strand;
          my $add = $strand > 0 ? $start : $end;
          
          $export .= $self->_render_text($_->slice, $feature_type, undef, {
            'start'  => $_->start + $add,
            'end'    => $_->end + $add,
            'strand' => $strand,
            'score'  => $_->score
          });
        }
      }
    }
    
    if ($wiggle ne 'wiggle') {
      my $fset = $_->get_displayable_product_FeatureSet;
      
      foreach (@{$fset->get_Features_by_Slice($container)}) {
        $export .= $self->_render_text($_, $feature_type);
      }
    }
  }
  
  return $export;
}


1;
