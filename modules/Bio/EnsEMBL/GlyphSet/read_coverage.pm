package Bio::EnsEMBL::GlyphSet::read_coverage;
use strict;
use base qw(Bio::EnsEMBL::GlyphSet_wiggle_and_block);

sub my_helplink { return "read_coverage_collection"; }

sub draw_features {

  ### Description: gets features for block features and passes to render_block_features
  ### Draws wiggles if wiggle flag is 1
  ### Returns 1 if draws blocks. Returns 0 if no blocks drawn

  my ($self, $wiggle)= @_; 

  my $drawn_flag = 0;
  my $drawn_wiggle_flag = $wiggle ? 0: "wiggle";
  my $wiggle_colour = "steelblue";
  my $features = $self->rcc_features;
  return 0 unless scalar @$features;

  if ( $wiggle ){
    $self->draw_space_glyph() if $drawn_wiggle_flag;
    my $min_score = $features->[0]->y_axis_min;
    my $max_score = $features->[0]->y_axis_max;
  
    $self->draw_wiggle_plot(
      $features,
      { 'min_score' => $min_score, 'max_score' => $max_score } 
    );
  }

 return 1;
}

sub rcc_features {
  my $self = shift;
  my $key = $self->{'my_config'}->key;
  my @key_info = split (/_/, $key);
  my $sample_id = pop @key_info;
  my $vdb =  $self->dbadaptor( $self->species, 'VARIATION' );
  my $collection = $vdb->get_ReadCoverageCollectionAdaptor();

  return $collection->fetch_all_by_Slice_SampleId( 
    $self->{'container'},
    $sample_id,
    $self->image_width
  ) || [];
}  

1;
### Contact: Bethan Pritchard bp1@sanger.ac.uk
