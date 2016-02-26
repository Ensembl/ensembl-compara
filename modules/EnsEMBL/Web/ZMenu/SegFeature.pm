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
  my $fgh = $hub->database('funcgen');
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
  my $ct = $cta->fetch_by_dbID($hub->param('celldbid'));
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
