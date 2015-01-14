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
  my $chromosome     = $location->seq_region_name;
  my $ensembl_start  = $location->seq_region_start;
  my $current_assembly  = $hub->species_defs->ASSEMBLY_VERSION;
  my $alt_assembly      = $hub->param('alt_assembly');
  my $alt_assemblies    = $hub->species_defs->ASSEMBLY_MAPPINGS || [];
  my $referer           = $hub->referer;
  
  # get coordinates of other assembly 
  if ($alt_assembly && scalar(@$alt_assemblies)) {
    my $table = $self->new_table([], [], { data_table => 1, sorting => [ 'ensemblcoordinates asc' ] });

    $table->add_columns(
      { key => 'ensemblcoordinates', title => "$current_assembly coordinates",               align => 'left', sort => 'position'      },
      { key => 'length',             title => 'Length',                            align => 'left', sort => 'numeric'       },
      { key => 'targetcoordinates',  title => "$alt_assembly coordinates",  align => 'left', sort => 'position_html' }
    );
   
    if (my @mappings = @{$hub->species_defs->get_config($hub->species, 'ASSEMBLY_MAPPINGS')||[]}) {
      my $mapping;
      foreach (@mappings) {
        $mapping = $_;
        last if $mapping eq sprintf('chromosome:%s#chromosome:%s', $current_assembly, $alt_assembly);
      }
      if ($mapping) {
        my $segments = $location->slice->project('chromosome', $alt_assembly);
             
        my $base_url    = 'http://'.$hub->species_defs->SWITCH_ARCHIVE_URL;
    
        foreach my $segment (@$segments) {
          my $s          = $segment->from_start + $ensembl_start - 1;
          my $slice      = $segment->to_Slice;
          my $mapped_url = "$base_url/$species/Location/View?r=" . $slice->seq_region_name. ':' . $slice->start. '-'.  $slice->end;
	        my $match_txt  = $slice->seq_region_name . ':' . $hub->thousandify($slice->start) . '-' . $hub->thousandify($slice->end);
      
	        $table->add_row({
            ensemblcoordinates => "$chromosome:$s-" . ($slice->length + $s - 1),
		        length             => $slice->length, 
		        targetcoordinates  => qq{<a href="$mapped_url" rel="external">$match_txt</a>}
          });
        }
      }
    }
    
    return sprintf '<input type="hidden" class="panel_type" value="Content" /><h2>Coordinate mappings</h2>%s', $table->render;  	
  }
}

1;
