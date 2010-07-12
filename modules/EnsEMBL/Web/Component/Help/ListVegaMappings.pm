#$Id$
package EnsEMBL::Web::Component::Help::ListVegaMappings;

use strict;
use warnings;

use base qw(EnsEMBL::Web::Component::Help);
use Bio::EnsEMBL::Registry;
no warnings "uninitialized";
use EnsEMBL::Web::Document::SpreadSheet;

sub _init {
  my $self = shift;
  $self->cacheable(1);
  $self->ajaxable(0);
  $self->configurable(0);
}

sub content {
  my $self           = shift;
  my $object         = $self->object;
  my $species        = $object->species;
  my $location       = $self->model->object('Location');
  my $chromosome     = $location->seq_region_name;
  my $ensembl_start  = $location->seq_region_start;
  my $alt_assemblies = $object->species_defs->ALTERNATIVE_ASSEMBLIES;
  my $referer        = $self->hub->parent;
  
  # get coordinates of other assemblies (Vega)  
  if ($alt_assemblies) {
    my $table = new EnsEMBL::Web::Document::SpreadSheet([], [], { data_table => 1, sorting => [ 'ensemblcoordinates asc' ] });

    $table->add_columns(
      { key => 'ensemblcoordinates', title => 'Ensembl coordinates',               align => 'left', sort => 'position'      },
      { key => 'length',             title => 'Length',                            align => 'left', sort => 'numeric'       },
      { key => 'targetcoordinates',  title => "$alt_assemblies->[0] coordinates",  align => 'left', sort => 'position_html' }
    );
    
    Bio::EnsEMBL::Registry->add_DNAAdaptor($species, 'vega', $species, 'vega');
    
    my $adaptor     = Bio::EnsEMBL::Registry->get_adaptor($species, 'vega', 'Slice');
    my $start       = $location->seq_region_start;
    my $end         = $location->seq_region_end;         
    my $vega_slices = $adaptor->fetch_by_region('chromosome', $chromosome, $start, $end, 1, 'GRCh37')->project('chromosome', $alt_assemblies->[0]);
    my $base_url    = $object->ExtURL->get_url('VEGA') . "$species/$referer->{'ENSEMBL_TYPE'}/$referer->{'ENSEMBL_ACTION'}";
    
    foreach my $segment (@$vega_slices) {
      my $s          = $segment->from_start + $ensembl_start - 1;
      my $slice      = $segment->to_Slice;
      my $mapped_url = "$base_url?r=" . $slice->seq_region_name. ':' . $slice->start. '-'.  $slice->end;
	    my $match_txt  = $slice->seq_region_name . ':' . $object->thousandify($slice->start) . '-' . $object->thousandify($slice->end);
      
	    $table->add_row({
        ensemblcoordinates => "$chromosome:$s-" . ($slice->length + $s - 1),
		    length             => $slice->length, 
		    targetcoordinates  => qq{<a href="$mapped_url" rel="external">$match_txt</a>}
      });
    }
    
    return sprintf '<input type="hidden" class="panel_type" value="Content" /><h2>Vega mappings</h2>%s', $table->render;  	
  }
}

1;
