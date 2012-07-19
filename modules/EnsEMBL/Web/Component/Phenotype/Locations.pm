# $Id$

package EnsEMBL::Web::Component::Phenotype::Locations;

### Module to replace Karyoview

use strict;

use HTML::Entities qw(encode_entities);

use EnsEMBL::Web::Controller::SSI;

use base qw(EnsEMBL::Web::Component::Location::Genome);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(1);
}

sub content {
  my $self = shift;
  ## Accept both parameters for now, to avoid breaking links from elsewhere in code
  my $id   = $self->hub->param('ph') || $self->hub->param('id');
  my $features = {};

  ## Get features to draw
  if ($id) {
    my $object = $self->object;
    if ($object && $object->can('convert_to_drawing_parameters')) {
      $features = $object->convert_to_drawing_parameters;
    }
  }
  my $html = $self->_render_features($id, $features);
  return $html;
}

sub _configure_Gene_table {
  my ($self, $feature_type, $feature_set) = @_;
  my $info = $self->SUPER::_configure_Gene_table($feature_type, $feature_set);
  $info->{'header'} = 'Genes associated with phenotype '.$self->object->get_phenotype_desc;
  return $info; 
}

sub _configure_Variation_table {
  my ($self, $feature_type, $feature_set) = @_;
  my $rows = [];

  my $header = 'Variants associated with phenotype '.$self->object->get_phenotype_desc;
  my $table_style = {'sorting' => ['p-values desc']};

  my $column_order = [qw(loc names)];
  my $column_info = {
    'names'   => {'title' => 'Name(s)', 'sort' => 'html'},
    'loc'     => {'title' => 'Genomic location (strand)', 'sort' => 'position_html'},
  };


  my ($data, $extras) = @$feature_set;
  foreach my $feature ($self->_sort_features_by_coords($data)) {
    my $row = {
              'loc'     => {'value' => $self->_var_location_link($feature)},
              'names'   => {'value' => $self->_variation_link($feature, $feature_type)},
              'options' => {'class' => $feature->{'html_id'}},
              };

    $self->add_extras($row, $feature, $extras);
    push @$rows, $row;
  }
  return {'header' => $header, 'column_order' => $column_order, 'rows' => $rows,
          'column_info' => $column_info, 'table_style' => $table_style};
}
    
sub _var_location_link {
  my ($self, $f) = @_;
  return 'Unmapped' unless $f->{'region'};
  my $coords = $f->{'region'}.':'.$f->{'start'}.'-'.$f->{'end'};
  my $link = sprintf(
          '<a href="%s">%s:%d-%d(%d)</a>',
          $self->hub->url({
            type    => 'Location',
            action  => 'View',
            r       => $coords,
            v       => $f->{'label'},
            ph      => $self->hub->param('ph'),
            contigviewbottom => $f->{'somatic'} ? 'somatic_mutation_COSMIC=normal' 
                                                  : 'variation_feature_variation=normal',
            __clear => 1,
          }),
          $f->{'region'}, $f->{'start'}, $f->{'end'},
          $f->{'strand'}
  );
  return $link;
}

sub _variation_link {
  my ($self, $f, $type) = @_;
  my $params = {
    'type'      => 'Variation',
    'action'    => 'Phenotype',
    'v'         => $f->{'label'},
    ph          => $self->hub->param('ph'),
    __clear     => 1
  };

  my $names = sprintf('<a href="%s">%s</a>', $self->hub->url($params), $f->{'label'});
  return $names;
}

1;
