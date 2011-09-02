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

sub _configure_Gene_table {
  my ($self, $feature_type, $feature_set) = @_;
  my $info = $self->SUPER::_configure_Gene_table($feature_type, $feature_set);
  $info->{'header'} = 'Genes associated with phenotype '.$self->hub->param('name');
  return $info; 
}

sub _configure_Variation_table {
  my ($self, $feature_type, $feature_set) = @_;
  my $rows = [];

  my $header = 'Variants associated with phenotype '.$self->hub->param('name');
  my $table_style = {'sorting' => ['p-values asc']};

  my $column_order = [qw(loc names)];
  my $column_info = {
    'names'   => {'title' => 'Name(s)', 'sort' => 'html'},
    'loc'     => {'title' => 'Genomic location (strand)' => 'position_html'},
  };


  my ($data, $extras) = @$feature_set;
  foreach my $feature ($self->_sort_features_by_coords($data)) {
    my $row = {
              'loc'     => {'value' => $self->_var_location_link($feature), 'style' => $self->cell_style},
              'names'   => {'value' => $self->_variation_link($feature, $feature_type), 'style' => $self->cell_style},
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
            action  => 'View',
            r       => $coords,
            v       => $f->{'label'},
            contigviewbottom => $f->{'somatic'} ? 'somatic_mutation_COSMIC=normal' 
                                                  : 'variation_feature_variation=normal',
            __clear => 1
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
    __clear     => 1
  };

  my $names = sprintf('<a href="%s">%s</a>', $self->hub->url($params), $f->{'label'});
  return $names;
}

1;
