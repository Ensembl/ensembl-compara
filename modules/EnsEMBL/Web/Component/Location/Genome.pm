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

our $feature_display_name = {
  'Xref'                => 'External Reference',
  'DnaAlignFeature'     => 'Sequence Feature',
  'ProteinAlignFeature' => 'Protein Feature',
};

our $column_info = {
  'names'   => {'title' => 'Ensembl ID'},
  'loc'     => {'title' => 'Genomic location (strand)'},
  'extname' => {'title' => 'External names'},
  'length'  => {'title' => 'Length'},
  'lrg'     => {'title' => 'Name'},
};

sub content {
  my $self         = shift;
  my $hub          = $self->hub;
  my $species      = $hub->species;
  my $species_defs = $hub->species_defs;
  my ($html, $total_features, $mapped_features, $unmapped_features);
  my $features = {};
 
  ## Get features to draw
  my $object = $self->builder->create_objects('Feature', 'lazy') if $hub->param('id');
  if ($object) {
    $features = $object->convert_to_drawing_parameters;
  }

  my $chromosomes  = $species_defs->ENSEMBL_CHROMOSOMES || [];
  my %chromosome = map {$_ => 1} @$chromosomes;
  while (my ($type, $set) = each (%$features)) {
    foreach my $feature (@{$set->[0]}) {
      if ($chromosome{$feature->{'region'}}) {
        $mapped_features++;
      }
      else {
        $unmapped_features++;
      }
      $total_features++;
    }
  }

  if ($hub->param('id') && $total_features < 1) {
    my $ids = join(', ', $hub->param('id'));
    return $self->_warning('Not found', sprintf('No mapping of %s found', $ids || 'unknown feature'));
  }

  ## Add in userdata tracks
  my $user_features = $self->create_user_features;
  while (my ($key, $data) = each (%$user_features)) {
    while (my ($analysis, $track) = each (%$data)) {
      foreach my $feature (@{$track->{'features'}}) {
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
    my $image    = $self->new_karyotype_image;
    my $config   = $hub->get_imageconfig('Vkaryotype'); ## Form with hidden elements for click-through

    ## Create pointers to be drawn
    my $pointers = [];

    if ($mapped_features) {
      ## Title for image - a bit messy, but we want it to be human-readable!
      my $title = 'Location';
      $title .= 's' if $mapped_features > 1;
      $title .= ' of ';
      my $data_type = $hub->param('ftype');
      my (%names, $data_name, @other_names, $name_string);
      ## De-camelcase names
      foreach (keys %$features) {
        my $pretty = $feature_display_name->{$_} || $self->decamel($_);
        if ($_ eq $data_type) {
          $data_name = $pretty;
        }
        else {
          push @other_names, $pretty;
        }
        $names{$_} = $pretty.'s';
      }
      my $feature_names;

      if (scalar @other_names < 1) {
          $title .= $data_name;
      } else {
        my $last_name = pop(@other_names);
        if (scalar @other_names > 0) {
          $name_string = join ', ', @other_names;
          $name_string .= ' and '.$last_name;
        }
        $title .= "$name_string$last_name associated with $data_name";
      }
     
      ## Deal with pointer colours
      my %used_colour;
      my %pointer_default = (
        DnaAlignFeature     => [ 'red', 'rharrow' ],
        ProteinAlignFeature => [ 'red', 'rharrow' ],
        RegulatoryFactor    => [ 'red', 'rharrow' ],
        ProbeFeature        => [ 'red', 'rharrow' ],
        Xref                => [ 'red', 'rharrow' ],
        Gene                => [ 'blue','lharrow' ],
        Domain              => [ 'blue','lharrow' ], 
      );
      
      $html .= "<h2>$title</h2>";        

      ## Create pointers for Ensembl features
      while (my ($feat_type, $set) = each (%$features)) {          
        my $defaults    = $pointer_default{$set->[2]};
        my $pointer_ref = $image->add_pointers($hub, {
          config_name  => 'Vkaryotype',
          features     => $set->[0],
          feature_type => $feat_type,
          color        => $hub->param('colour') || $defaults->[0],
          style        => $hub->param('style')  || $defaults->[1],            
        });
          
        push @$pointers, $pointer_ref;
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
  while (my ($feat_type, $feature_set) = each (%$features)) {
    my $method = '_configure_'.$feat_type.'_table';
    if ($self->can($method)) {
      my ($header, $column_order, $rows) = $self->$method($feat_type, $feature_set);
      my $columns = [];
      my $table_style = {};
      my $cell_style = $self->cell_style;
      my $col;

      foreach $col (@$column_order) {
        push @$columns, {'key' => $col, 'title' => $column_info->{$col}{'title'}, 'style' => $cell_style};
      }

      my $extras = $feature_set->[1];
      foreach $col (@$extras) {
        push @$columns, {'key' => 'extra_'.lc($col), 'title' => $col, 'style' => $cell_style}; 
      }

      $table_style->{'margin'}      = '1em 0px';
      my $table = $self->new_table($columns, $rows, $table_style);
      $html .= '<h2 style="margin-top:1em">'.$header.'</h2>';
      $html .= $table->render;
    }
  }

  ## User table
  if (keys %$user_features) {
    my ($header, $column_order, $rows) = $self->configure_UserData_table('UserData', $user_features);
    my $columns = [];
    my $table_style = {};
    my $cell_style = $self->cell_style;
    my $col;

    foreach $col (@$column_order) {
      push @$columns, {'key' => $col, 'title' => $column_info->{$col}{'title'}, 'style' => $cell_style};
    }

    $table_style->{'margin'}      = '1em 0px';
    my $table = $self->new_table($columns, $rows, $table_style);
    $html .= '<h2 style="margin-top:1em">'.$header.'</h2>';
    $html .= $table->render;
  }

  unless (keys %$features || keys %$user_features) {
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
    $header       = "Domain $domain_id maps to $count $plural. The gene information is shown below:";
  }

  my $column_order = [qw(names loc extname)];

  my ($data, $extras) = @$feature_set;
  foreach my $feature ($self->_sort_features_by_coords($data)) {
    my ($loc_link);

    my $row = {
              'extname' => {'value' => $feature->{'extname'}, 'style' => $self->cell_style},
              'names'   => {'value' => $self->_names_link($feature, $feature_type), 'style' => $self->cell_style},
              'loc'     => {'value' => $self->_location_link($feature), 'style' => $self->cell_style},
              };

    my $i = 0;
    foreach my $col (@$extras) {
      $row->{'extra_'.lc($col)} = {'value' => $feature->{'extra'}[$i], 'style' => $self->cell_style};
      $i++;
    }
    push @$rows, $row;
  }

  return ($header, $column_order, $rows); 
}

sub _configure_Transcript_table {
  my ($self, $feature_type, $feature_set) = @_;
  my ($header, $column_order, $rows) = $self->_configure_Gene_table($feature_type, $feature_set);
  ## Override default header
  $header = 'Transcript Information';
  return ($header, $column_order, $rows);
}

sub _configure_ProbeFeature_table {
  my ($self, $feature_type, $feature_set) = @_;
  my $rows = [];
  
  my $column_order = [qw(loc length names)];

  my $header = 'OligoProbe Information';
 
  my ($data, $extras) = @$feature_set;
  foreach my $feature ($self->_sort_features_by_coords($data)) {
    my ($loc_link);

    my $row = {
              'loc'     => {'value' => $self->_location_link($feature), 'style' => $self->cell_style},
              'length'  => {'value' => $feature->{'length'},            'style' => $self->cell_style}, 
              'names'   => {'value' => $feature->{'label'},             'style' => $self->cell_style},
              };

    my $i = 0;
    foreach my $col (@$extras) {
      $row->{'extra_'.lc($col)} = {'value' => $feature->{'extra'}[$i], 'style' => $self->cell_style};
      $i++;
    }
    push @$rows, $row;
  }

  return ($header, $column_order, $rows); 
}

sub _configure_RegulatoryFeature_table {
  my ($self, $feature_type, $feature_set) = @_;
  my ($header, $column_order, $rows) = $self->_configure_ProbeFeature_table($feature_type, $feature_set);
  ## Override default header
  my $rf_id     = $self->hub->param('id');
  my $ids       = join(', ', $rf_id);
  my $count     = scalar @{$feature_set->[0]};
  my $plural    = $count > 1 ? 'Factors' : 'Factor';
  $header = "Regulatory Features associated with Regulatory $plural $ids";
  return ($header, $column_order, $rows);
}

sub _configure_Xref_table {
  my ($self, $feature_type, $feature_set) = @_;
  my ($header, $column_order, $rows) = $self->_configure_ProbeFeature_table($feature_type, $feature_set);
  ## Override default header
  $header = 'External References';
  return ($header, $column_order, $rows);
}

sub _configure_DnaAlignFeature_table {
  my ($self, $feature_type, $feature_set) = @_;
  my ($header, $column_order, $rows) = $self->_configure_ProbeFeature_table($feature_type, $feature_set);
  ## Override default header
  $header = 'Sequence Feature Information';
  return ($header, $column_order, $rows);
}

sub _configure_ProteinAlignFeature_table {
  my ($self, $feature_type, $feature_set) = @_;
  my ($header, $column_order, $rows) = $self->_configure_ProbeFeature_table($feature_type, $feature_set);
  ## Override default header
  $header = 'Protein Feature Information';
  return ($header, $column_order, $rows);
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
            action  => 'View',
            r       => $coords, 
            h       => $f->{'label'},
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
    __clear     => 1
  };

  my $names = sprintf('<a href="%s">%s</a>', $self->hub->url($params), $f->{'label'});
  return $names;
}

1;
