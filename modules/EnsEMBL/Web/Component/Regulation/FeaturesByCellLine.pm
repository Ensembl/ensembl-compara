package EnsEMBL::Web::Component::Regulation::FeaturesByCellLine;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Regulation);


sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  1 );
}

sub content {
  my $self = shift;
  my $object = $self->object; 

  my $Configs;

  my $context      = $object->param( 'context' ) || 200;
  my $object_slice = $object->get_bound_context_slice($context);
     $object_slice = $object_slice->invert if $object_slice->strand < 1;

  my $wuc = $object->get_imageconfig( 'regulation_view' );
  $wuc->set_parameters({
    'container_width'   => $object_slice->length,
    'image_width',      => $self->image_width || 800,
    'slice_number',     => '1|1',
    'opt_highlight'    => $object->param('opt_highlight')
  });
  my @containers_and_configs = ( $object_slice, $wuc);


  my $all_evidence_features = $object->get_all_cell_line_features();
  if ( $all_evidence_features) {
    $wuc->{'evidence'}->{'data'}->{'all_features'} = $all_evidence_features;
  }
  my $configured_tracks = $object->get_configured_tracks;
  
  # Get MultiCell data 
  my $multi_data = $object->get_multicell_evidence_data($object_slice);
  my $wuc_multi = $object->get_imageconfig( 'reg_detail_by_cell_line' );
  $wuc_multi->set_parameters({
      'container_width'   => $object_slice->length,
      'image_width',      => $self->image_width || 800,
      'opt_highlight'    => $object->param('opt_highlight'),
      'opt_empty_tracks'  => $object->param('opt_empty_tracks')
    });
  $wuc_multi->modify_configs(
    [ 'fg_regulatory_features_funcgen_reg_feats' ],
    {qw(display on )}
  );
  $wuc_multi->{'evidence'}->{'data'}->{'all_features'} = $all_evidence_features;
  $wuc_multi->{'data_by_cell_line'} = $multi_data;
  $wuc_multi->{'configured_tracks'} = $configured_tracks;
  $wuc_multi->{'reg_feature'} = 1;  
  push @containers_and_configs, $object_slice, $wuc_multi;


  # Add cell line specific data and configs  
  my %cell_lines =  %{$object->species_defs->databases->{'DATABASE_FUNCGEN'}->{'tables'}{'cell_type'}{'ids'}};
  my $data_all_cell_lines = $object->get_evidence_data($object_slice,);

  my $number_of_cell_lines = scalar (keys %cell_lines);
  my $count =1;  
  foreach my $cell_line (sort keys %cell_lines) { 
    $cell_line =~s/\:\w*//;
    my $wuc_cell_line = $object->get_imageconfig( 'reg_detail_by_cell_line' );
    $wuc_cell_line->set_parameters({
      'container_width'   => $object_slice->length,
      'image_width',      => $self->image_width || 800,
      'opt_highlight'     => $object->param('opt_highlight'),
      'opt_empty_tracks'  => $object->param('opt_empty_tracks')
    });
    $wuc_cell_line->modify_configs(
      [ 'fg_regulatory_features_funcgen_reg_feats_'. $cell_line ],
      {qw(display on )} 
    );
    my %data_by_cell_line;
    $data_by_cell_line{$cell_line} = $data_all_cell_lines->{$cell_line} || {}; 
    if ($count == $number_of_cell_lines){
      $data_by_cell_line{$cell_line}{'last_cell_line'} =1;
    }    
    # do we have a reg_feature for this cell line?
    foreach my $reg_obj (@{$object->fetch_all_objs_by_slice($object_slice)}){
      if ( $reg_obj->feature_set->cell_type->name =~/$cell_line/){
        $wuc_cell_line->{'reg_feature'} = 1;
      }
    }

    $wuc_cell_line->{'data_by_cell_line'} = \%data_by_cell_line;
    $wuc_cell_line->{'evidence'}->{'data'}->{'all_features'} = $all_evidence_features;
    $wuc_cell_line->{'configured_tracks'} = $configured_tracks; 
    push @containers_and_configs, $object_slice, $wuc_cell_line;    
    $count++;
  }

  # Add config to draw legends and bottom ruler
  my $wuc_regulation_bottom = $object->get_imageconfig( 'regulation_view_bottom' );
  $wuc_regulation_bottom->set_parameters({
      'container_width'   => $object_slice->length,
      'image_width',      => $self->image_width || 800,
      'opt_highlight'    => $object->param('opt_highlight')
    });
  $wuc_regulation_bottom->{'fg_regulatory_features_legend_features'}->{'fg_regulatory_features'} = {'priority' =>1020, 'legend' => [] };
  push @containers_and_configs, $object_slice, $wuc_regulation_bottom; 

  my $image    = $self->new_image(
    [ @containers_and_configs,],
    [$object->stable_id],
  );

  $image->imagemap           = 'yes';
  $image->{'panel_number'} = 'top';
  $image->set_button( 'drag', 'title' => 'Drag to select region' );
  return if $self->_export_image( $image );

return $image->render;
}

1;
