=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2022] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::ZMenu::SegFeature;

use strict;

use base qw(EnsEMBL::Web::ZMenu::RegulationBase);

sub content {
  my ($self) = @_;

  my $hub     = $self->hub;
  my $r       = $hub->param('r');
  my $s       = $hub->param('click_start');
  my $e       = $hub->param('click_end');

  my $pos = int(($s+$e)/2);
  my $chr = $r;
  $chr =~ s/:.*$//;

  if ($hub->param('seg_name')) {
    $self->content_from_file($hub,$chr,$pos);
  } else {
    $self->content_from_db($hub,$chr,$pos);
  }
}

sub content_from_db {
  my ($self,$hub,$chr,$pos) = @_;

  my $object            = $self->object;
  my $dbid              = $hub->param('dbid');

  my $fgh = $hub->database('funcgen');
  my $fsa = $fgh->get_FeatureSetAdaptor();
  my $cta = $fgh->get_EpigenomeAdaptor;
  my $sa = $hub->database('core')->get_SliceAdaptor();
  return unless $fsa and $cta and $sa;
  my $slice = $sa->fetch_by_region('toplevel',$chr,$pos,$pos+1);
  my $cell_line = $hub->param('cl');
  my $fs = $fsa->fetch_by_dbID($dbid);
  my $features = $fs->get_Features_by_Slice($slice);
  return undef unless $features and @$features;
  my $seg_feat = $features->[0];
  my $cell_line         = $hub->param('cl');
  $self->caption('Regulatory Segment - ' . $cell_line);
  my $type = $seg_feat->feature_type->name;
  $self->add_entry ({ type   => 'Type', label  => $type });
  $self->add_entry({
    type       => 'Location',
    label_html => sprintf("%s:%d",$chr,$pos),
    link       => $hub->url({
      type   => 'Location',
      action => 'View',
      r      => sprintf("%s:%d-%d",$chr,$pos-1000,$pos+1000)
    })
  });
}

sub content_from_file {
  my ($self, $hub) = @_;

  my $click_data = $self->click_data;

  return unless $click_data;
  $click_data->{'display'}  = 'text';
  $click_data->{'strand'}   = $hub->param('fake_click_strand');

  my $strand = $hub->param('fake_click_strand') || 1;
  my $glyphset = 'EnsEMBL::Draw::GlyphSet::fg_segmentation_features';
  my $slice    = $click_data->{'container'};

  if ($self->dynamic_use($glyphset)) {
    $glyphset = $glyphset->new($click_data);

    my $colour_lookup = $self->_types_by_colour;

    my $data = $glyphset->get_data;
    foreach my $track (@$data) {
      next unless $track->{'features'};

      my $caption = 'Regulatory Segment';
      $caption .= ' - '.$hub->param('celltype');
      $self->caption($caption);

      foreach (@{$track->{'features'}}) {
        my $chr   = $_->{'seq_region'};
        my $pos   = int(($_->{'start'} + $_->{'end'})/2);
        $_->{'label'} =~ /_(\w+)_/;
        my $name = ucfirst($1);
        my $type  = $colour_lookup->{'#'.$_->{'colour'}} || $name;

        $self->add_entry ({ type => 'Type', label => $type });
        $self->add_entry({
                          type       => 'Location',
                          label_html => sprintf("%s:%d",$chr,$pos),
                          link       => $hub->url({
                                                    type   => 'Location',
                                                    action => 'View',
                                                    r      => sprintf("%s:%d-%d",$chr,$pos-1000,$pos+1000)
                                                  })
                            });
      }
    }
  }

}

sub _types_by_colour {
  my $self = shift;
  my $colours = $self->hub->species_defs->all_colours('fg_regulatory_features');
  my $colourmap = new EnsEMBL::Draw::Utils::ColourMap;
  my $lookup  = {};
  foreach my $col (keys %$colours) {
    my $raw_col = $colours->{$col}{'default'};
    my $hexcol = lc $colourmap->hex_by_name($raw_col);
    $lookup->{$hexcol} = $colours->{$col}{'text'};
  }
  return $lookup;
}

1;
