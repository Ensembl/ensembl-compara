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

package EnsEMBL::Web::ZMenu::Oligo;

use strict;

use base qw(EnsEMBL::Web::ZMenu);

sub content {
  my $self         = shift;
  my $hub          = $self->hub;
  my $id           = $hub->param('id');
  my $db           = $hub->param('fdb') || $hub->param('db') || 'core';
  my $object_type  = $hub->param('ftype');
  my $array_name   = $hub->param('array');
  my $vendor       = $hub->param('vendor');
  my $db_adaptor   = $hub->database(lc $db);
  my $adaptor_name = "get_${object_type}Adaptor";
  my $feat_adap    = $db_adaptor->$adaptor_name; 
  my $type         = 'Individual probes:';
  my $features     = [];

  # details of each probe within the probe set on the array that are found within the slice
  my ($r_name, $r_start, $r_end) = $hub->param('r') =~ /^([^:]+):(\d+)-(\d+)$/;
  my %probes;
  
  if ($hub->param('ptype') ne 'probe') {
    $features = $feat_adap->can('fetch_all_by_hit_name') ? $feat_adap->fetch_all_by_hit_name($id) : 
          $feat_adap->can('fetch_all_by_probeset_name') ? $feat_adap->fetch_all_by_probeset_name($id) : [];
  }
  
  if (scalar @$features == 0 && $feat_adap->can('fetch_all_by_Probe')) {
    my $probe_obj = $db_adaptor->get_ProbeAdaptor->fetch_by_array_probe_probeset_name($hub->param('array'), $id);
    
    $features = $feat_adap->fetch_all_by_Probe($probe_obj);
    
    $self->caption("Probe: $id");
  } else {
    $self->caption("Probe set: $id");
  }
  
  $self->add_entry({ 
    label => 'View all probe hits',
    link  => $hub->url({
      type   => 'Location',
      action => 'Genome',
      id     => $id,
      fdb    => 'funcgen',
      ftype  => $object_type,
      ptype  => $hub->param('ptype'),
      array  => $array_name,
      vendor => $vendor,
      db     => 'core'
    })
  });

  foreach (@$features){ 
    my $op         = $_->probe; 
    my $of_name    = $_->probe->get_probename($array_name);
    my $of_sr_name = $_->seq_region_name;
    
    next if $of_sr_name ne $r_name;
    
    my $of_start = $_->seq_region_start;
    my $of_end   = $_->seq_region_end;
    
    next if ($of_start > $r_end) || ($of_end < $r_start);
    
    $probes{$of_name}{'chr'}   = $of_sr_name;
    $probes{$of_name}{'start'} = $of_start;
    $probes{$of_name}{'end'}   = $of_end;
    $probes{$of_name}{'loc'}   = $self->thousandify($of_start) . 'bp-' . $self->thousandify($of_end) . 'bp';
  }
  
  foreach my $probe (sort {
    $probes{$a}->{'chr'}   <=> $probes{$b}->{'chr'}   ||
    $probes{$a}->{'start'} <=> $probes{$b}->{'start'} ||
    $probes{$a}->{'stop'}  <=> $probes{$b}->{'stop'}
  } keys %probes) {
    $self->add_entry({
      type  => $type,
      label => "$probe ($probes{$probe}->{'loc'})",
    });
    
    $type = ' ';
  }
}

1;
