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

### MODULE AT RISK OF DELETION ##
# This module is unused in the core Ensembl code, and is at risk of
# deletion. If you have use for this module, please contact the
# Ensembl team.
### MODULE AT RISK OF DELETION ##

package EnsEMBL::Draw::GlyphSet::histone_modifications;

### STATUS: Unknown - maybe not in use any more?

use strict;

use base qw(EnsEMBL::Draw::GlyphSet_wiggle_and_block);
use EnsEMBL::Web::Utils::Tombstone qw(tombstone);

sub new {
  my $self = shift;
  tombstone('2015-04-16','ds23');
  $self->SUPER::new(@_);
}

sub wiggle_subtitle { $_[0]->my_colour('score','text'); }

sub get_block_features {

  ### block_features

  my ( $self, $db ) = @_;
  unless ( $self->{'block_features'} ) {  
    my $data_set_adaptor = $db->get_DataSetAdaptor(); 
    if (!$data_set_adaptor) {
      warn ("Cannot get get adaptors: $data_set_adaptor");
      return [];
    }
    #my $features = $feature_adaptor->fetch_all_displayable_by_feature_type_class('HISTONE') || [] ;
    ### Hack to display features for release 51
    my $features = $data_set_adaptor->fetch_by_name('Vienna MEFf H3K4me3');
    my @feat = ($features);
    $self->{'block_features'} = \@feat;
  }

  my $colour = "blue";
  return ( $self->{'block_features'}, $colour);
}


sub draw_features {
  ### Description: gets features for block features and passes to draw_block_features
  ### Draws wiggles if wiggle flag is 1
  ### Returns 1 if draws blocks. Returns 0 if no blocks drawn

  my ($self, $wiggle)= @_;
  my $db =  $self->dbadaptor( 'mus_musculus', 'FUNCGEN' );
  my ($block_features, $colour) = $self->get_block_features($db);
  my $drawn_flag = 0;
  my $drawn_wiggle_flag = $wiggle ? 0: "wiggle";
  my $slice = $self->{'container'};
  my $wiggle_colour = "contigblue1";
  foreach my $feature ( @$block_features ) {
    # render wiggle if wiggle
    if ($wiggle) {
      #foreach my $result_set  (  @{ $feature->get_displayable_supporting_sets() } ){
	    foreach my $result_set  (  @{ $feature->get_supporting_sets() } ){

		    next if $result_set->set_type ne 'result';
        
	      #get features for slice and experimtenal chip set
	     # my @features = @{ $result_set->get_displayable_ResultFeatures_by_Slice($slice) };
        my @features = @{ $result_set->get_ResultFeatures_by_Slice($slice) };

	      next unless @features;
	      $drawn_wiggle_flag = "wiggle";
	      @features   = sort { $a->score <=> $b->score  } @features;
	      my ($min_score, $max_score) = ($features[0]->score || 0, $features[-1]->score|| 0);
        #	$self->render_wiggle_plot(\@features, $wiggle_colour, $min_score, $max_score, $result_set->display_label);
        $self->draw_wiggle_plot(
          \@features,                      ## Features array
          { 'min_score' => $min_score, 'max_score' => $max_score }
        );
      }
      $self->draw_space_glyph() if $drawn_wiggle_flag;
    }

    # Block features
  # foreach my $fset ( @{ $feature->get_displayable_product_FeatureSet() }){
      my $fset = $feature->get_displayable_product_FeatureSet;
      my $display_label = $fset->display_label();
      #my $features = $fset->get_AnnotatedFeatures_by_Slice($slice ) ;
      my $features = $fset->get_Features_by_Slice($slice ) ;
      next unless @$features;
      $drawn_flag = "block_features";
      $self->draw_track_name($display_label, $colour);
      $self->draw_block_features( $features, $colour );
   # }
   }

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
    "06:analysis:    ".($f->analysis->display_label() || '-')  => '',
    "09:score: ".$score => '',
  );
  return \%zmenu || {};
}


1;
### Contact: Fiona Cunningham fc1@sanger.ac.uk
