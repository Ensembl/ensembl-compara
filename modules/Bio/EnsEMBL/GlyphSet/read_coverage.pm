package Bio::EnsEMBL::GlyphSet::read_coverage;

use strict;

use base qw(Bio::EnsEMBL::GlyphSet);

sub my_helplink { return "read_coverage_collection"; }

sub _init {
  my ($self) = @_; 
  my $Config = $self->{'config'};
  my $key = $self->{'my_config'}->key; 
  my @key_info = split (/_/, $key);
  my $sample = pop @key_info; 
  my $slice = $self->{'container'};
  my ($coverage_level, $coverage_obj) = $self->read_coverage($sample, $slice);
  my @coverage_levels = sort { $a <=> $b } @$coverage_level;
  my $max_coverage   = $coverage_levels[-1];
  my $min_coverage   = $coverage_levels[0] || $coverage_levels[1];

  unless (@$coverage_obj && @coverage_levels) {
    $self->push($self->Space({
      'x'         => 1,
      'y'         => 0,
      'height'    => 1,
      'width'     => 1,
      'absolutey' => 1,
    }) );
    return;
  }
  my $A = $self->my_config('type') eq 'bottom' ? 0 : 1;

  my %draw_coverage = (
    $coverage_levels[0] => [0, "grey70"],
    $coverage_levels[1] => [1, "grey40"],
  );

  # Drawing stuff
  my $fontname      = $Config->species_defs->ENSEMBL_STYLE->{'GRAPHIC_FONT'};
  my($font_w_bp, $font_h_bp) = $Config->texthelper->px2bp($fontname);

  foreach my $coverage ( sort { $a->start <=> $b->start } @$coverage_obj ) { 
    my $level = $coverage->level; 
    my $y =  $draw_coverage{$level}[0];
    my $z = 2+$y;# -19+$y;
       $y =  1 - $y if $A;
       $y *= 2;
    my $h = 3 - $y;
       $y = 0;
    # Draw ------------------------------------------------
    my $width = $font_w_bp * length( $level );
    my $offset = $self->{'container'}->strand > 0 ? $self->{'container'}->start - 1 :  $self->{'container'}->end + 1;
    my $start = $coverage->start();  
    my $end   = $coverage->end(); #  + $offset;
    my $offset_start = $start + $offset;
    my $offset_end = $end + $offset;
    my $pos   = "$offset_start-$offset_end";
    if ($start <= 0) {$start = 0;}
    my $display_level = $level == $max_coverage ? ">".($level-1) : $level;
    my $bglyph = $self->Rect({
      'x'         => $start,
      'y'         => 8-$h,
      'height'    => $h,                            #$y,
      'width'     => $end-$start+1,
      'colour'    => $draw_coverage{$level}->[1],
      'absolutey' => 1,
      'href'      => $self->_url({'action' => 'coverage', 'pos' => $pos, 'sp' => $sample, 'disp_level' => $display_level}),
    });
    $self->push ($bglyph);
  }  
} 

sub read_coverage {
  my ($self, $sample, $slice) = @_;

  my $vdb =  $self->dbadaptor( $self->species, 'VARIATION' );  
  my $individual_adaptor = $vdb->get_IndividualAdaptor();  
  my $sample_objs = $individual_adaptor->fetch_all_by_name($sample);
  return ([],[]) unless @$sample_objs;
  my $sample_obj = $sample_objs->[0]; 

  my $sample_slice = $slice->get_by_strain($sample); 

  my $rc_adaptor = $vdb->get_ReadCoverageAdaptor();
  my $coverage_level = $rc_adaptor->get_coverage_levels;
  my $coverage_obj = $rc_adaptor->fetch_all_by_Slice_Sample_depth($sample_slice, $sample_obj);
  return ($coverage_level, $coverage_obj);
}

1;
### Contact Bethan Pritchard bp1@sanger.ac.uk

=head
 ### Code for wiggle plot display if we decide to switch to this
sub draw_features {
  my ($self, $wiggle)= @_; 
 
  my $features = $self->rcc_features;
  return 0 unless scalar @$features;

  if ( $wiggle ){
    my $min_score = $features->[0]->y_axis_min;
    my $max_score = $features->[0]->y_axis_max;
    $self->draw_wiggle_plot(
      $features,
      { 'min_score' => $min_score, 'max_score' => $max_score, 'axis_label' => 'off', } 
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
=cut
