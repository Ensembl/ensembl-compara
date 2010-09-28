# $Id$

package EnsEMBL::Web::Component::Info::News;

use strict;

use base qw(EnsEMBL::Web::Component);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(0);
}

sub content {
  my $self    = shift;
  my $builder = $self->builder;

  ## Fetch some news items
  $builder->create_data_object_of_type('News');

  my $stories = $builder->object('News')->get_stories;

  ## Output stories
  my $html;

  foreach my $story (@$stories) {
    $html .= '<h2>' . $story->title   . '</h2>';
    $html .= '<p>'  . $story->content . '</p>';
  }

  return $html;
}

1;
