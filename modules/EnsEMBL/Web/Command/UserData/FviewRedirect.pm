package EnsEMBL::Web::Command::UserData::FviewRedirect;

### Redirects from the 'FeatureView' form to either Location/Chromosome or Location/Genome

use strict;
use warnings;

use EnsEMBL::Web::Builder;

use base qw(EnsEMBL::Web::Command::UserData);

sub process {
  my $self = shift;
  my $hub = $self->hub;

  my @input_ids = split /\n|\r/, $hub->param('id');
  my @output_ids;
  foreach (@input_ids) {
    my @A = split(/\t|\s+|, /, $_);
    push @output_ids, @A;
  }

  ## This bit is basically replicating the old featureview URL-based functionality!
  my $builder = new EnsEMBL::Web::Builder({hub => $hub});
  my $features = [];
  $hub->param('id', @output_ids);
  my $object = $builder->create_objects('Feature', 'lazy');
  if ($object && $object->can('convert_to_drawing_parameters')) {
    $features = $object->convert_to_drawing_parameters;
  }

  ## Write out features as BED file
  my $desc = $hub->param('name') || 'Selected '.$hub->param('ftype').'s';
  my $content = sprintf('track name=%s description="%s" useScore=1 color=%s style=%s', $hub->param('ftype'), $desc, $hub->param('colour'), $hub->param('style'));
  $content .= "\n";

  while (my ($type, $feat) = each (%{$features||{}})) {
    foreach my $f (@{$feat->[0]||[]}) {
      my @A = ($f->{'region'}, $f->{'start'}, $f->{'end'}, $f->{'label'}, '.', $f->{'strand'});
      $content .= join('  ', @A);
      $content .= "\n";
    }
  }

  $hub->param('text', $content);
  $hub->param('format', 'BED');
  $hub->param('name', $desc);

  ## Upload munged data
  $self->upload('text');

  my $url = '/'.$hub->param('species').'/Location/Genome';
  my $params = {'reload' => 1};
  
  $self->ajax_redirect($url, $params, undef, 'page'); 
}

1;
