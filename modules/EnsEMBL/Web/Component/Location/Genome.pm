# $Id$

package EnsEMBL::Web::Component::Location::Genome;

### Module to replace Karyoview

use strict;

use HTML::Entities qw(encode_entities);

use EnsEMBL::Web::Controller::SSI;

use base qw(EnsEMBL::Web::Component::Location);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(1);
}

sub content {
  my $self = shift;
  my $id   = $self->hub->param('id'); 
  my $features = {};

  #configure two Vega tracks in one
  my $config = $self->hub->get_imageconfig('Vkaryotype');
  if ($config->get_node('Vannotation_status_left') & $config->get_node('Vannotation_status_right')) {
    $config->get_node('Vannotation_status_left')->set('display', $config->get_node('Vannotation_status_right')->get('display'));
  }

  ## Get features to draw
  if ($id) {
    my $object = $self->builder->create_objects('Feature', 'lazy');
    if ($object && $object->can('convert_to_drawing_parameters')) {
      $features = $object->convert_to_drawing_parameters;
    }
  }
  my $html = $self->_render_features($id, $features, $config);
  return $html;
}

sub _render_features {
  my ($self, $id, $features, $image_config) = @_;
  my $hub          = $self->hub;
  my $species      = $hub->species;
  my $species_defs = $hub->species_defs;
  my ($html, $total_features, $mapped_features, $unmapped_features, $has_internal_data, $has_userdata);

  my $chromosomes  = $species_defs->ENSEMBL_CHROMOSOMES || [];
  my %chromosome = map {$_ => 1} @$chromosomes;
  while (my ($type, $set) = each (%$features)) {
    foreach my $feature (@{$set->[0]}) {
      $has_internal_data++;
      if ($chromosome{$feature->{'region'}}) {
        $mapped_features++;
      }
      else {
        $unmapped_features++;
      }
      $total_features++;
    }
  }

  if ($id && $total_features < 1) {
    my $ids = join(', ', $id);
    return $self->_warning('Not found', sprintf('No mapping of %s found', $ids || 'unknown feature'));
  }

  ## Add in userdata tracks
  my $user_features = $image_config ? $image_config->create_user_features : {};
  while (my ($key, $data) = each (%$user_features)) {
    while (my ($analysis, $track) = each (%$data)) {
      foreach my $feature (@{$track->{'features'}}) {
        $has_userdata++;
        if ($chromosome{$feature->{'chr'}}) {
          $mapped_features++;
        }
        else {
          $unmapped_features++;
        }
        $total_features++;
      }
    }
  }

  ## Draw features on karyotype, if any
  if (scalar @$chromosomes && $species_defs->MAX_CHR_LENGTH) {
    my $image = $self->new_karyotype_image($image_config);

    ## Map some user-friendly display names
    my $feature_display_name = {
      'Xref'                => 'External Reference',
      'ProbeFeature'        => 'Oligoprobe',
      'DnaAlignFeature'     => 'Sequence Feature',
      'ProteinAlignFeature' => 'Protein Feature',
    };
    my ($xref_type, $xref_name);
    while (my ($type, $feature_set) = each (%$features)) {    
      if ($type eq 'Xref') {
        my $sample = $feature_set->[0][0];
        $xref_type = $sample->{'label'};
        $xref_name = $sample->{'extname'};
        $xref_name =~ s/ \[#\]//;
        $xref_name =~ s/^ //;
      }
    }

    ## Create pointers to be drawn
    my $pointers = [];
    my ($legend_info, $has_gradient);

    if ($mapped_features) {

      ## Title for image - a bit messy, but we want it to be human-readable!
      my $title;
      if ($has_internal_data) { 
        $title = 'Location';
        $title .= 's' if $mapped_features > 1;
        $title .= ' of ';
        my ($data_type, $assoc_name);
        my $ftype = $hub->param('ftype');
        if (grep (/$ftype/, keys %$features)) {
          $data_type = $ftype;
        }
        else {
          my @A = sort keys %$features;
          $data_type = $A[0];
          $assoc_name = $hub->param('name');
          unless ($assoc_name) {
            $assoc_name = $xref_type.' ';
            $assoc_name .= $id;
            $assoc_name .= " ($xref_name)";
          }
        }

        my %names;
        ## De-camelcase names
        foreach (sort keys %$features) {
          my $pretty = $feature_display_name->{$_} || $self->decamel($_);
          $pretty .= 's' if $mapped_features > 1;
          $names{$_} = $pretty;
        }

        my @feat_names = sort values %names;
        my $last_name = pop(@feat_names);
        if (scalar @feat_names > 0) {
          $title .= join ', ', @feat_names;
          $title .= ' and ';
        }
        $title .= $last_name;
        $title .= " associated with $assoc_name" if $assoc_name;
      }
      else {
        $title = 'Location of your feature';
        $title .= 's' if $has_userdata > 1;
      }
      $html .= "<h3>$title</h3>";        
     
      ## Create pointers for Ensembl features
      while (my ($feat_type, $set) = each (%$features)) {          
        my $defaults    = $self->pointer_default($feat_type);
        my $colour      = $hub->param('colour') || $defaults->[1];
        my $gradient    = $defaults->[2];
        my $pointer_ref = $image->add_pointers($hub, {
          config_name  => 'Vkaryotype',
          features     => $set->[0],
          feature_type => $feat_type,
          color        => $colour,
          style        => $hub->param('style')  || $defaults->[0],            
          gradient     => $gradient,
        });
        $legend_info->{$feat_type} = {'colour' => $colour, 'gradient' => $gradient};  
        push @$pointers, $pointer_ref;
        $has_gradient++ if $gradient;
      }

      ## Create pointers for userdata
      if (keys %$user_features) {
        push @$pointers, $self->create_user_pointers($image, $user_features);
      } 

    }

    $image->image_name = @$pointers ? "feature-$species" : "karyotype-$species";
    $image->imagemap   = @$pointers ? 'yes' : 'no';
      
    $image->set_button('drag', 'title' => 'Click on a chromosome');
    $image->caption  = 'Click on the image above to jump to a chromosome, or click and drag to select a region';
    $image->imagemap = 'yes';
    $image->karyotype($hub, $self->object, $pointers, 'Vkaryotype');
      
    return if $self->_export_image($image,'no_text');
      
    $html .= $image->render;
 
    ## Add colour key if required
    if ($self->html_format && (scalar(keys %$legend_info) > 1 || $has_gradient)) { 
      $html .= '<h3>Key</h3>';

      my $columns = [
        {'key' => 'ftype',  'title' => 'Feature type'},
        {'key' => 'colour', 'title' => 'Colour'},
      ];
      my $rows;

      foreach my $type (sort keys %$legend_info) {
        my $type_name = $feature_display_name->{$type} || $type;
        my $colour    = $legend_info->{$type}{'colour'};
        my @gradient  = @{$legend_info->{$type}{'gradient'}||[]};
        my $swatch_style = 'width:30px;height:20px;border:2px solid #999;text-align:center;padding:4px 0 0 0;'; 
        my $swatch;
        if ($colour eq 'gradient' && @gradient) {
          $gradient[0] = '20';
          my @colour_scale = $hub->colourmap->build_linear_gradient(@gradient);
          my $i = 1;
          foreach my $step (@colour_scale) {                
            my $label;
            if ($i == 1) {
              $label = sprintf("%.1f", $i);
            } 
            elsif ($i == scalar @colour_scale) {
              $label = '>'.$i/2;
            }
            else {
              $label = $i % 3 ? '' : sprintf("%.1f", ($i/3 + 2));
            }
            $swatch .= qq{<div style="background:#$step;color:#fff;float:left;$swatch_style">$label</div>};
            $i++;
          }
          $swatch .= '<br /><div style="clear:both;margin-left:120px">Less significant -log(p-values) &lt;-------------------------&gt; More significant -log(p-values)</div>';
        }
        else { 
          $swatch = qq{<span style="background-color:$colour;display:block;$swatch_style" title="$colour"></span>};
        }
        push @$rows, {
              'ftype'  => {'value' => $type_name, 'style' => $self->cell_style},
              'colour' => {'value' => $swatch,    'style' => $self->cell_style},
        };
      }
      my $legend = $self->new_table($columns, $rows); 
      $html .= $legend->render;
    }
      
    if ($unmapped_features > 0) {
      my $message;
      if ($mapped_features) {
        my $do    = $unmapped_features > 1 ? 'features do' : 'feature does';
        my $have  = $unmapped_features > 1 ? 'have' : 'has';
        $message = "$unmapped_features $do not map to chromosomal coordinates and therefore $have not been drawn.";
      }
      else {
        $message = 'No features map to chromosomal coordinates.'
      }
      $html .= $self->_info('Undrawn features', "<p>$message</p>");
    }

  } elsif (!scalar @$chromosomes) {
    $html .= $self->_info('Unassembled genome', '<p>This genome has yet to be assembled into chromosomes</p>');
  }

  ## Create HTML tables for features, if any
  my $default_column_info = {
    'names'   => {'title' => 'Ensembl ID'},
    'loc'     => {'title' => 'Genomic location (strand)', 'sort' => 'position_html'},
    'extname' => {'title' => 'External names'},
    'length'  => {'title' => 'Length', 'sort' => 'numeric'},
    'lrg'     => {'title' => 'Name'},
    'xref'    => {'title' => 'Name(s)'},
  };

  while (my ($feat_type, $feature_set) = each (%$features)) {
    my $method = '_configure_'.$feat_type.'_table';
    if ($self->can($method)) {
      my $table_info = $self->$method($feat_type, $feature_set);
      my $column_info = $table_info->{'custom_columns'} || $default_column_info;
      my $columns = [];
      my $col;
      my $cell_style = $self->cell_style;
      my $table_style = $table_info->{'table_style'} || {};

      foreach $col (@{$table_info->{'column_order'}||[]}) {
        push @$columns, {'key' => $col, 'title' => $column_info->{$col}{'title'}, 'style' => $cell_style};
      }

      ## Add "extra" columns (unique to particular table types)
      my $extras = $feature_set->[1];
      foreach $col (@$extras) {
        push @$columns, {
                    'key'   => $col->{'key'}, 
                    'title' => $col->{'title'}, 
                    'sort'  => $col->{'sort'}, 
                    'style' => $cell_style,
                    }; 
      }
      $table_style->{'margin'}      = '1em 0px';
      $table_style->{'data_table'}  = 1;
      my $table = $self->new_table($columns, $table_info->{'rows'}, $table_style);
      $html .= '<h3 style="margin-top:1em">'.$table_info->{'header'}.'</h3>';
      $html .= $table->render;
    }
  }

  ## User table
  if (keys %$user_features) {
    my $table_info  = $self->configure_UserData_table($image_config);
    my $column_info = $default_column_info;
    my $columns     = [];
    my $table_style = $table_info->{'table_style'} || {};
    my $cell_style  = $self->cell_style;
    my $col;

    foreach $col (@{$table_info->{'column_order'}||[]}) {
      push @$columns, {'key' => $col, 'title' => $column_info->{$col}{'title'}, 'style' => $cell_style};
    }

    $table_style->{'margin'}      = '1em 0px';
    my $table = $self->new_table($columns, $table_info->{'rows'}, $table_style);
    $html .= '<h3 style="margin-top:1em">'.$table_info->{'header'}.'</h3>';
    $html .= $table->render;
  }

  unless (keys %$features) {
    $html .= EnsEMBL::Web::Controller::SSI::template_INCLUDE($self, "/ssi/species/stats_$species.html");
  }

  ## Done!
  return $html;
}

sub _configure_Gene_table {
  my ($self, $feature_type, $feature_set) = @_;
  my $rows = [];
 
  my $header = 'Gene Information';
  if ($self->hub->param('ftype') eq 'Domain') {
    ## Override default header
    my $domain_id = $self->hub->param('id');
    my $count     = scalar @{$feature_set->[0]};
    my $plural    = $count > 1 ? 'genes' : 'gene';
    $header       = "Domain $domain_id maps to $count $plural:";
  }

  my $column_order = [qw(names loc extname)];

  my ($data, $extras) = @$feature_set;
  foreach my $feature ($self->_sort_features_by_coords($data)) {
    my $row = {
              'extname' => {'value' => $feature->{'extname'}, 'style' => $self->cell_style},
              'names'   => {'value' => $self->_names_link($feature, $feature_type), 'style' => $self->cell_style},
              'loc'     => {'value' => $self->_location_link($feature), 'style' => $self->cell_style},
              };
    $self->add_extras($row, $feature, $extras);
    push @$rows, $row;
  }

  return {'header' => $header, 'column_order' => $column_order, 'rows' => $rows}; 
}

sub _configure_Transcript_table {
  my ($self, $feature_type, $feature_set) = @_;
  my $info = $self->_configure_Gene_table($feature_type, $feature_set);
  ## Override default header
  $info->{'header'} = 'Transcript Information';
  return $info; 
}

sub _configure_ProbeFeature_table {
  my ($self, $feature_type, $feature_set) = @_;
  my $rows = [];
  
  my $column_order = [qw(loc length names)];

  my $header = 'Oligoprobe Information';
 
  my ($data, $extras) = @$feature_set;
  foreach my $feature ($self->_sort_features_by_coords($data)) {
    my $row = {
              'loc'     => {'value' => $self->_location_link($feature), 'style' => $self->cell_style},
              'length'  => {'value' => $feature->{'length'},            'style' => $self->cell_style}, 
              'names'   => {'value' => $feature->{'label'},             'style' => $self->cell_style},
              };
    $self->add_extras($row, $feature, $extras);
    push @$rows, $row;
  }

  return {'header' => $header, 'column_order' => $column_order, 'rows' => $rows}; 
}

sub _configure_RegulatoryFeature_table {
  my ($self, $feature_type, $feature_set) = @_;
  my $info = $self->_configure_ProbeFeature_table($feature_type, $feature_set);
  ## Override default header
  my $rf_id     = $self->hub->param('id');
  my $ids       = join(', ', $rf_id);
  my $count     = scalar @{$feature_set->[0]};
  my $plural    = $count > 1 ? 'Factors' : 'Factor';
  $info->{'header'} = "Regulatory Features associated with Regulatory $plural $ids";
  return $info;
}

sub _configure_Xref_table {
  my ($self, $feature_type, $feature_set) = @_;
  my $rows = [];
  
  my $column_order = [qw(loc length xref)];

  my $header = 'External References';
 
  my ($data, $extras) = @$feature_set;
  foreach my $feature ($self->_sort_features_by_coords($data)) {
    my $row = {
              'loc'     => {'value' => $self->_location_link($feature), 'style' => $self->cell_style},
              'length'  => {'value' => $feature->{'length'},            'style' => $self->cell_style}, 
              'xref'    => {'value' => $feature->{'label'},             'style' => $self->cell_style},
              };
    $self->add_extras($row, $feature, $extras);
    push @$rows, $row;
  }

  return {'header' => $header, 'column_order' => $column_order, 'rows' => $rows}; 
}

sub _configure_DnaAlignFeature_table {
  my ($self, $feature_type, $feature_set) = @_;
  my $info = $self->_configure_Xref_table($feature_type, $feature_set);
  ## Override default header
  $info->{'header'} = 'Sequence Feature Information';
  return $info; 
}

sub _configure_ProteinAlignFeature_table {
  my ($self, $feature_type, $feature_set) = @_;
  my $info = $self->_configure_Xref_table($feature_type, $feature_set);
  ## Override default header
  $info->{'header'} = 'Protein Feature Information';
  return $info; 
}

sub add_extras {
  my ($self, $row, $feature, $extras) = @_;
  foreach my $col (@$extras) {
    my $key = $col->{'key'};
    $row->{$key} = {'value' => $feature->{'extra'}{$key}, 'style' => $self->cell_style};
  }
}

sub _sort_features_by_coords {
  my ($self, $data) = @_;

  my @sorted =  map  { $_->[0] }
                sort { $a->[1] <=> $b->[1] || $a->[2] cmp $b->[2] || $a->[3] <=> $b->[3] }
                map  { [ $_, $_->{'region'} =~ /^(\d+)/ ? $1 : 1e20, $_->{'region'}, $_->{'start'} ] }
                @$data;

  return @sorted;
}

sub _location_link {
  my ($self, $f) = @_;
  return 'Unmapped' unless $f->{'region'};
  my $coords = $f->{'region'}.':'.$f->{'start'}.'-'.$f->{'end'};
  my $link = sprintf(
          '<a href="%s">%s:%d-%d(%d)</a>',
          $self->hub->url({
            type    => 'Location',
            action  => 'View',
            r       => $coords, 
            h       => $f->{'label'},
            ph      => $self->hub->param('ph'),
            __clear => 1
          }),
          $f->{'region'}, $f->{'start'}, $f->{'end'},
          $f->{'strand'}
  );
  return $link;
}

sub _names_link {
  my ($self, $f, $type) = @_;
  my $coords    = $f->{'region'}.':'.$f->{'start'}.'-'.$f->{'end'};
  my $obj_param = $type eq 'Transcript' ? 't' : 'g';
  my $params = {
    'type'      => $type, 
    'action'    => 'Summary',
    $obj_param  => $f->{'label'},
    'r'         => $coords, 
    'ph'        => $self->hub->param('ph'),
    __clear     => 1
  };

  my $names = sprintf('<a href="%s">%s</a>', $self->hub->url($params), $f->{'label'});
  return $names;
}

1;
