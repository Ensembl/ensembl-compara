package EnsEMBL::Web::Component::Experiment::Filter;

use strict;

use base qw(EnsEMBL::Web::Component::Experiment);

sub caption       {'Exeriment'}
sub short_caption {'Exeriment'}

sub content {
  my $self    = shift;
  my $object  = $self->object;
  my $hub     = $self->hub;
  my $table   = $self->new_table(
    [
      { 'key' => 'count',         'title' => 'Number of experiments', 'align' => 'right', 'width' => '150px', 'sort' => 'numeric' },
      { 'key' => 'show',          'title' => '', 'sort' => 'none' },
      { 'key' => 'filter_value',  'title' => ''             },
      { 'key' => 'filter_type',   'title' => 'Filter type'  },
      { 'key' => 'desc',          'title' => 'Description'  },
    ],
    [],
    {'data_table' => 1}
  );

  my $grouped_feature_sets = $object->get_grouped_feature_sets;

  for my $filter_type (sort keys %$grouped_feature_sets) {
    my $filter_values = $grouped_feature_sets->{$filter_type};
    while (my ($filter_value, $grouped_feature_types) = each %$filter_values) {
      my $count       = scalar @{$grouped_feature_types->{'feature_sets'}};
      my $param       = $object->get_url_param_for_filter($filter_type);
      my $show_label  = $count ? $hub->param('ex') eq "$param-$filter_value" ? 'Displayed' : sprintf('<a href="%s">Show</a>', $hub->url({'ex' => "$param-$filter_value"})) : '';

      $table->add_row({
        'count'         => $count,
        'show'          => $show_label,
        'filter_value'  => $filter_value,
        'filter_type'   => $filter_type,
        'desc'          => $grouped_feature_types->{'description'}
      });
    }
  }

  return $table->render;
}

1;