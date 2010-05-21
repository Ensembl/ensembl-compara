package EnsEMBL::Web::Component::Help::ListVegaMappings;

use strict;
use warnings;

use base qw(EnsEMBL::Web::Component::Help);

no warnings "uninitialized";

sub _init {
  my $self = shift;
  $self->cacheable(1);
  $self->ajaxable(0);
  $self->configurable(0);
}

sub content {
  my $self    = shift;
  my $object  = $self->object;

  my $panel_name = $object->param('panel_name');
  my $species = $object->species;
  my $chromosome = $self->hub->core_objects->location->seq_region_name;
  my $ensembl_start_location=$self->hub->core_objects->location->start;
  
  # get coordinates of other assemblies (Vega)  
  if (my $alt_assemblies= $self->hub->species_defs->ALTERNATIVE_ASSEMBLIES) {
    my $url;
    my $table = new EnsEMBL::Web::Document::SpreadSheet([], [], { margin => '1em 0px', data_table => 1, sorting => [ 'ensemblcoordinates asc' ]});

    $table->add_columns(
      { key => 'ensemblcoordinates'  , title => 'Ensembl coordinates'                  , align => 'left', sort => 'position'},
      { key => 'length'           , title => 'Length'                            , align => 'left', sort => 'numeric'},
      { key => 'targetcoordinates', title => @$alt_assemblies[0]." coordinates" , align => 'left', sort => 'position_html'}
    );

    ## set dnadb to 'vega' so that the assembly mapping is retrieved from there		 
    my $reg = "Bio::EnsEMBL::Registry";
    my $vega_dnadb = $reg->get_DNAAdaptor($species, "vega");
    $reg->add_DNAAdaptor($species, "vega", $species, "vega");
    ## get a Vega slice to do the projection
    my $vega_sa = Bio::EnsEMBL::Registry->get_adaptor($species, "vega", "Slice");
    my $start_location = $object->hub->core_objects->location->start;
    my $end_location = $object->hub->core_objects->location->end;         
    my $start_slice = $vega_sa->fetch_by_region( 'chromosome', $chromosome,$start_location,$end_location,1,"GRCh37" );
    my $V_slices = $start_slice->project('chromosome', @$alt_assemblies[0]);
    
    foreach my $segment (@$V_slices) {
      my $ensembl_start = $segment->from_start+$ensembl_start_location-1;

      my $slice = $segment->to_Slice;
      my $mapped_url = $object->ExtURL->get_url('VEGA').$species . "/". $object->param('type')."/".$object->param('action')."?r=".$slice->seq_region_name. ":". $slice->start. "-".  $slice->end;
	    my $match_txt=$slice->seq_region_name.":".$object->thousandify($slice->start)."-". $object->thousandify($slice->end);
      
      my $ensembl_end_location=$self->hub->core_objects->location->end;
	    my $row = { ensemblcoordinates   => $chromosome.":".$ensembl_start."-".($slice->length+$ensembl_start-1),
		              length            => $slice->length, 
		              targetcoordinates =>"<a href=\"".$mapped_url."\" rel=\"external\">".$match_txt."</a>" };
	    $table->add_rows($row);
    }
    return qq{<div class="js_panel"><input type="hidden" class="panel_type" value="Content" /><h2>Vega mappings </h2>}.$table->render;  	
  }
}

1;
