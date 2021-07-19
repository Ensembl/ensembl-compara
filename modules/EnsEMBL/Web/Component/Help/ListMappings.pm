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

package EnsEMBL::Web::Component::Help::ListMappings;

use strict;

use base qw(EnsEMBL::Web::Component::Help);

sub _init {
  my $self = shift;
  $self->cacheable(1);
  $self->ajaxable(0);
  $self->configurable(0);
}

sub content {
  my $self           = shift;
  my $hub            = $self->hub;
  my $species        = $hub->species;
  my $location       = $self->builder->object('Location');
  return unless $location;
  my $chromosome     = $location->seq_region_name;
  my $ensembl_start  = $location->seq_region_start;
  my $current_assembly  = $hub->species_defs->ASSEMBLY_VERSION;
  my $alt_assembly      = $hub->param('alt_assembly');
  my $alt_assemblies    = $hub->species_defs->ASSEMBLY_MAPPINGS || [];
  my $referer           = $hub->referer;
  my ($html, $table);
  
  # get coordinates of other assembly 
  if ($alt_assembly && scalar(@$alt_assemblies)) {
    $html .= '<input type="hidden" class="panel_type" value="Content" /><h2>Coordinate mappings</h2>';
    if (my @mappings = @{$hub->species_defs->get_config($hub->species, 'ASSEMBLY_MAPPINGS')||[]}) {

      my $mapping;
      foreach (@mappings) {
        $mapping = $_;
        last if $mapping eq sprintf('chromosome:%s#chromosome:%s', $current_assembly, $alt_assembly);
      }
      if ($mapping) {

        my $segments = $location->slice->project('chromosome', $alt_assembly);

        if (scalar @$segments) {
             

          $table = $self->new_table([], [], { data_table => 1, sorting => [ 'ensemblcoordinates asc' ] });

          $table->add_columns(
            { key => 'coords', title => "$current_assembly coordinates", align => 'left', sort => 'position'},
            { key => 'length',             title => 'Length', align => 'left', sort => 'numeric'},
            { key => 'target',  title => "$alt_assembly coordinates",  align => 'left', sort => 'position_html'}
          );

          my $base_url  = '//'.$hub->species_defs->SWITCH_ARCHIVE_URL;
          my $title     = 'Go to '.$hub->species_defs->SWITCH_ARCHIVE_URL; 
    
          foreach my $segment (@$segments) {
            my $s          = $segment->from_start + $ensembl_start - 1;
            my $slice      = $segment->to_Slice;
            my $mapped_url = "$base_url/$species/Location/View?r=" . $slice->seq_region_name. ':' . $slice->start. '-'.  $slice->end;
	          my $match_txt  = $slice->seq_region_name . ':' . $hub->thousandify($slice->start) . '-' . $hub->thousandify($slice->end);
      
	          $table->add_row({
              coords => "$chromosome:$s-" . ($slice->length + $s - 1),
		          length => $slice->length, 
		          target => qq{<a href="$mapped_url" title="$title" rel="external">$match_txt</a>}
            });
          }
        }
      }
    }
  }
  if ($table) {
    $html .= $table->render;  	
  }
  else {
    $html .= '<p>No mappings in this region - please try another location.</p>';
  }
  return $html; 
}

1;
