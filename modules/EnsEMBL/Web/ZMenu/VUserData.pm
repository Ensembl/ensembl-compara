=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

package EnsEMBL::Web::ZMenu::VUserData;

use strict;

use EnsEMBL::Web::Text::FeatureParser;

use base qw(EnsEMBL::Web::ZMenu);

sub content {
  my $self = shift;
  my $hub = $self->hub;

  my $click_data = $self->click_data;

  return unless $click_data;

  my @features;

  my $track_config  = $click_data->{'my_config'};
  my $parser        = EnsEMBL::Web::Text::FeatureParser->new($hub->species_defs);
  my $container     = $click_data->{'container'};
  $parser->filter($container->seq_region_name, $container->start, $container->end);

  my $sub_type     = $track_config->get('sub_type');

  my %args = ('hub' => $hub);

  if ($sub_type eq 'url') {
    $args{'file'} = $track_config->get('url');
    $args{'input_drivers'} = ['URL'];
  }
  else {
    $args{'file'} = $track_config->get('file');
    if ($args{'file'} !~ /\//) { ## TmpFile upload
      $args{'prefix'} = 'user_upload';
    }
  }

  my $file = EnsEMBL::Web::File::User->new(%args);
  my $format = $track_config->get('format');

  my $response = $file->read;

  if (my $data = $response->{'content'}) {
    $parser->parse($data, $format);

    while (my ($key, $T) = each (%{$parser->{'tracks'}})) {
      $_->map($container) for @{$T->{'features'}};
      push @features, @{$T->{'features'}};
    }
  }

  $self->{'feature_count'} = scalar @features;

  if (scalar @features) {
    my $plural  = scalar @features > 1 ? 's' : '';

    foreach my $f (@features) {
      $self->new_feature;

      my $id      = $f->id || $format; 
      $self->caption("Feature: $id");

      my $r = $f->seqname.':'.$f->start.'-'.$f->end;
      $self->add_entry({
        type  => "Location", 
        label => $r,
        link  => $hub->url({
                          'type'    => 'Location',
                          'action'  => 'View',
                          'r'       => $r,
                        }),
      });
      if ($f->score) {
        $self->add_entry({
          type  => "Score", 
          label => $f->score,
        });
      }
    }
  }
}

1;
