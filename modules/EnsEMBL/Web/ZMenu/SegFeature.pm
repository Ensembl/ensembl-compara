=head1 LICENSE

Copyright [1999-2016] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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
  my $hub     = $self->hub;
  if($hub->param('celldbid')) {
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
  my $cta = $fgh->get_CellTypeAdaptor;
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
  my ($self,$hub,$chr,$pos) = @_;

  my $fgh = $hub->database('funcgen');
  my $cta = $fgh->get_CellTypeAdaptor;
  my $ct = $cta->fetch_by_dbID($hub->param('celldbid'));
  my $rsa = $fgh->get_ResultSetAdaptor;
  my $rs = $rsa->fetch_by_dbID($hub->param('dbid'));
  return unless $rs;
  my $bigbed_file = $rs->dbfile_path;
  my @parts = split(m!/!, $bigbed_file);
  my $path  = join("/", $self->hub->species_defs->DATAFILE_BASE_PATH,
                          @parts[-6..-1]);
  # Yuk! There has to be a better way than use colours
  my $rgb;
  my $bba = $self->{'_cache'}->{'bigbed_parser'}->{$path}
              ||= Bio::EnsEMBL::IO::Parser::open_as('bigbed', $path);
  $bba->fetch_rows($chr,$pos,$pos+1,sub {
    my @row = @_;
    my @col = split(',',$row[8]);
    $rgb = sprintf("#%02x%02x%02x",@col);
  });
  return undef unless $rgb;
  my $colours = $self->hub->species_defs->all_colours('fg_regulatory_features');
  my $colourmap = new EnsEMBL::Draw::Utils::ColourMap;
  my $type = "Unclassified";
  foreach my $col (keys %$colours) {
    my $raw_col = $colours->{$col}{'default'};
    my $hexcol = lc $colourmap->hex_by_name($raw_col);
    next unless $hexcol eq $rgb;
    $type = $colours->{$col}{'text'};
  }
  my $cta = $fgh->get_CellTypeAdaptor;
  my $cell_line = '';
  $cell_line = $ct->name if $ct;
  $self->caption('Regulatory Segment - ' . $cell_line);
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

1;
