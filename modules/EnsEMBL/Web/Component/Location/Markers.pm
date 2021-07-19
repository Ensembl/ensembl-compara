=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2021] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Component::Location::Markers;

use strict;
use warnings;
no warnings "uninitialized";

use base qw(EnsEMBL::Web::Component);

sub _init {
  my $self = shift;
  $self->ajaxable(0);
}

sub content {
  my $self = shift;
  
  my $location = $self->object;
  my $hub = $self->hub;
  my $threshold = 1000100 * ($hub->species_defs->ENSEMBL_GENOME_SIZE||1);
		
  return $self->_warning('Region too large', '<p>The region selected is too large to display in this view</p>') if $location->length > $threshold;
    
  my @found_mf = $location->sorted_marker_features($location->Obj->{'slice'});
  my ($html, %mfs);
  
  foreach my $mf (@found_mf) {
    my $name = $mf->marker->display_MarkerSynonym->name;
    my $sr_name = $mf->seq_region_name;
    my $cs = $mf->coord_system_name;
    
    push @{$mfs{$name}->{$sr_name}}, {
      'cs'    => $cs,
      'mf'    => $mf,
      'start' => $mf->seq_region_start,
      'end'   => $mf->seq_region_end
    };
  }
 
  my $c = scalar keys %mfs; 
  $html = qq(
      <h3>$c mapped markers found:</h3>
      <table class="margin-bottom">
  );
  
  foreach my $name (sort keys %mfs) {
    my ($link, $r);
    
    foreach my $chr (keys %{$mfs{$name}}) {
      $link .= "<td><strong>$mfs{$name}->{$chr}[0]{'cs'} $chr:</strong></td>";
      
      foreach my $det (@{$mfs{$name}->{$chr}}) {
	$link .= "<td>$det->{'start'}-$det->{'end'}</td>";
	$r = "$chr:$det->{'start'}-$det->{'end'}";
      }
    }
    
    my $url = $hub->url({ type => 'Marker', action => 'Details',  m => $name, r => $r });
    
    $html .= qq{<tr><td><a href="$url">$name</a></td>$link</tr>};
  }
  
  $html .= '</table>';
  return $html;
}

1;
