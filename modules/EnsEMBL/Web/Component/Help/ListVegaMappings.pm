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

package EnsEMBL::Web::Component::Help::ListVegaMappings;

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
  my $alt_assemblies = $hub->species_defs->ALTERNATIVE_ASSEMBLIES;
  my $referer        = $hub->referer;
  
  # get coordinates of other assemblies (Vega)  
  if ($alt_assemblies) {
    my $table = $self->new_table([], [], { data_table => 1, sorting => [ 'ensemblcoordinates asc' ] });

    $table->add_columns(
      { key => 'ensemblcoordinates', title => 'Ensembl coordinates',               align => 'left', sort => 'position'      },
      { key => 'length',             title => 'Length',                            align => 'left', sort => 'numeric'       },
      { key => 'targetcoordinates',  title => "$alt_assemblies->[0] coordinates",  align => 'left', sort => 'position_html' }
    );
    
    my $reg        = 'Bio::EnsEMBL::Registry';
    my $orig_group = $reg->get_DNAAdaptor($species, 'vega')->group;
    
    $reg->add_DNAAdaptor($species, 'vega', $species, 'vega');
    
    my $start       = $location->seq_region_start;
    my $end         = $location->seq_region_end;
        
    my $e_assembly = $hub->get_adaptor('get_CoordSystemAdaptor')
                         ->fetch_by_name('chromosome')->version;
             
    my $vega_slices = $hub->get_adaptor('get_SliceAdaptor', 'vega')->fetch_by_region('chromosome', $chromosome, $start, $end, 1,$e_assembly)->project('chromosome', $alt_assemblies->[0]);
    my $base_url    = $hub->ExtURL->get_url('VEGA') . "$species/$referer->{'ENSEMBL_TYPE'}/$referer->{'ENSEMBL_ACTION'}";
    
    foreach my $segment (@$vega_slices) {
      my $s          = $segment->from_start + $ensembl_start - 1;
      my $slice      = $segment->to_Slice;
      my $mapped_url = "$base_url?r=" . $slice->seq_region_name. ':' . $slice->start. '-'.  $slice->end;
	    my $match_txt  = $slice->seq_region_name . ':' . $hub->thousandify($slice->start) . '-' . $hub->thousandify($slice->end);
      
	    $table->add_row({
        ensemblcoordinates => "$chromosome:$s-" . ($slice->length + $s - 1),
		    length             => $slice->length, 
		    targetcoordinates  => qq{<a href="$mapped_url" rel="external">$match_txt</a>}
      });
    }
    
    $reg->add_DNAAdaptor($species, 'vega', $species, $orig_group); # set dnadb back to the original group
    
    return sprintf '<input type="hidden" class="panel_type" value="Content" /><h2>Vega mappings</h2>%s', $table->render;  	
  }
}

1;
