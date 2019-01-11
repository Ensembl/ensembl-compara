=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2018] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::JSONServer::TrackHubData;

### Convert a parsed trackhub into JSON that can be used by the new interface

use strict;
use warnings;

use JSON;

use EnsEMBL::Web::Utils::TrackHub;

use parent qw(EnsEMBL::Web::JSONServer);

our $final = {};

sub json_data {
  my $self = shift;
  my $hub  = $self->hub;

  # TODO - replace with dynamic parameter
  my $record_id = 'url_093244c7b96971052ab900101f8636ff_94481512';

  my ($type, $code, $id) = split('_', $record_id);
  $code .= '_'.$id;

  my $record;
  foreach my $m (grep $_, $hub->user, $hub->session) {
    $record = $m->get_record_data({'type' => $type, 'code' => $code});
    last if ($record && keys %$record);
  }
  my $url = $record->{'url'};
  warn ">>> URL $url";

  my $trackhub  = EnsEMBL::Web::File::Utils::TrackHub->new('hub' => $self->hub, 'url' => $url);
  my $hub_info = $trackhub->get_hub({'parse_tracks' => 1}); ## Do we have data for this species?
  $self->{'th_default_count'} = 0;

  my $node;
  my $assemblies = $hub->species_defs->get_config($hub->param('species'), 'TRACKHUB_ASSEMBLY_ALIASES');
  $assemblies ||= [];
  $assemblies = [ $assemblies ] unless ref($assemblies) eq 'ARRAY';
  foreach (qw(UCSC_GOLDEN_PATH ASSEMBLY_VERSION)) {
    my $assembly = $self->hub->species_defs->get_config($hub->param('species'), $_);
    next unless $assembly;
    push @$assemblies,$assembly;
  }
  foreach my $assembly (@$assemblies) {
    $node = $hub_info->{'genomes'}{$assembly}{'tree'};
    $node = $node->root if $node;
    last if $node;
  }


  #$self->_add_trackhub_node($node) if $node;

  use Data::Dumper;
  $Data::Dumper::Sortkeys = 1;
  $Data::Dumper::Maxdepth = 2;
  warn Dumper($node);

  $final->{data}->{evidence}->{'name'}    = 'evidence';
  $final->{data}->{evidence}->{'label'}   = 'Evidence';
  $final->{data}->{evidence}->{'data'}    = {};
  $final->{data}->{evidence}->{'subtabs'} = 1;

  $final->{data}->{epigenome}->{'name'}   = 'epigenome';
  $final->{data}->{epigenome}->{'label'}  = 'Epigenome';
  $final->{data}->{epigenome}->{'data'}   = {};
  $final->{data}->{epigenome}->{'listType'} = 'alphabetRibbon';

  $final->{dimensions} = ['epigenome', 'evidence'];
  return $final;
}

sub _add_trackhub_node {
  my ($self, $node) = @_;
}

1;

