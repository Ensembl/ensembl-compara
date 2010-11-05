# $Id$

package EnsEMBL::Web::ZMenu::Regulation;

use strict;

use base qw(EnsEMBL::Web::ZMenu);

sub content {
  my $self = shift;
  my $hub  = $self->hub;
  my $rf   = $hub->param('rf');
 
  return unless $rf; 
  
  my $object              = $self->object;
  my $cell_line           = $hub->param('cl');
  my $funcgen_db          = $hub->database('funcgen');
  my $reg_feature_adaptor = $funcgen_db->get_RegulatoryFeatureAdaptor; 
  my $reg_objs            = $reg_feature_adaptor->fetch_all_by_stable_ID($rf);
  my $core_reg_obj;
  
  foreach my $rf (@$reg_objs) {
    if ($cell_line) {
      $core_reg_obj = $rf if $rf->feature_set->cell_type->name =~ /$cell_line/i;
    } elsif ($rf->feature_set->cell_type->name =~ /multi/i) {
      $core_reg_obj = $rf;
    }
  }

  my $cell_line_specific_reg_object = $self->new_object('Regulation', $core_reg_obj, $object->__data);
  my %motif_features      = %{$cell_line_specific_reg_object->get_motif_features};
  
  $self->caption('Regulatory Feature');
  
  $self->add_entry({
    type  => 'Stable ID',
    label => $object->stable_id,
    link  => $object->get_details_page_url
  });
  
  $self->add_entry({
    type  => 'Type',
    label => $object->feature_type->name
  });
  
  $self->add_entry({
    type  => 'Core bp',
    label => $object->location_string,
    link  => $object->get_location_url
  });

  unless ($cell_line_specific_reg_object->bound_start == $object->seq_region_start && $cell_line_specific_reg_object->bound_end == $object->seq_region_end) {
    $self->add_entry({
      type  => 'Bounds bp',
      label => $cell_line_specific_reg_object->bound_location_string,
      link  => $cell_line_specific_reg_object->get_bound_location_url
    });
  }
  
  $self->add_entry({
    type  => 'Attributes',
    label => $cell_line_specific_reg_object->get_attribute_list
  });

  if ($cell_line_specific_reg_object->Obj->is_projected){
    my $projected_html = "NOTE: This feature has been projected by the <a href='/info/docs/funcgen/index.html'>RegulatoryBuild</a>";
    $self->add_entry({
    label_html => $projected_html
    });
  }

  if (scalar (keys %motif_features) >> 0  ){
    # get region clicked on
    my $nearest_feature =1;
    my $nearest         = 1e12; # Arbitrary large number
    my ($left, $right, $min, @feat);
    my $click_start = $hub->param('click_start');
    my $click_end = $hub->param('click_end');

    foreach my $motif (keys %motif_features ){
      my $motif_id = $motif;
      ($left, $right) = split /\:/, $motif; 
      $left  -= $click_start;
      $right  = $click_end - $right;

      # If both are 0 or positive, feature is inside the click region.
      # If both are negative, click is inside the feature.
      if (($left >= 0 && $right >= 0) || ($left < 0 && $right < 0)) {
        push @feat, $motif_id;
        $nearest_feature = undef;
      } elsif ($nearest_feature) {
        $min = [ sort { $a <=> $b } abs($left), abs($right) ]->[0];

        if ($min < $nearest) {
          $nearest_feature = $motif_id;
          $nearest = $min;
        }
      }
    }

    # Return the nearest feature if it's inside two click widths
    push @feat, $nearest_feature if $nearest_feature && $nearest < 2 * ($click_end - $click_start);

    $self->add_entry ({
    label_html => undef,
    });
    $self->add_subheader('<span align="center">PWM Information</span>');
  
    my $pwm_table = '<table cellpadding="0" cellspacing="0" style="border:0; padding:0px; margin:0px;">
                     <tr><th>Name</th><th>ID</th><th>Score</th></tr>';
 
    foreach my $motif (sort keys %motif_features){
      my ($name, $score, $binding_matrix_name) = @{$motif_features{$motif}};
      my $bm_link = $self->hub->get_ExtURL_link($binding_matrix_name, 'JASPAR', $binding_matrix_name);
      my $style;
      if (scalar @feat == 1 && $feat[0] eq $motif ){
        $style = 'style="background-color: #BBCCFF"';
      }
      $pwm_table .= sprintf( '<tr><td %s>%s</td><td %s>%s</td><td %s>%s</td></tr>',
        $style,
        $name,
        $style,
        $bm_link,
        $style,
        $score
      );
    } 

    $pwm_table .= "</table>";
    $self->add_entry({
      label_html => $pwm_table
    });
  }
}


1;
