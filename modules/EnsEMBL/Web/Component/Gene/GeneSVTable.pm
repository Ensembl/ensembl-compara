package EnsEMBL::Web::Component::Gene::GeneSVTable;

use strict;

use Bio::EnsEMBL::Variation::Utils::Constants;

use base qw(EnsEMBL::Web::Component::Gene);

sub _init {
  my $self = shift;
  $self->cacheable(1);
  $self->ajaxable(1);
}

sub content {
  my $self   = shift;
  my $hub    = $self->hub;
  my $object = $self->object;
	my $html;
	
	my $slice = $object->slice;
	
	
	#### Image configuration ####
	
	my $gene_slice = $slice;#$slice->expand(10e3, 10e3);
     $gene_slice = $gene_slice->invert if $object->seq_region_strand < 0;
     
  # Get the web_image_config
  my $image_config = $object->get_imageconfig('gene_sv_view');
  
  $image_config->set_parameters({
    container_width => $gene_slice->length,
    image_width     => $object->param('i_width') || $self->image_width || 800,
    slice_number    => '1|1',
  });
  
  $self->_attach_das($image_config);

	# Transcript track
  my $key  = $image_config->get_track_key('transcript', $object);
  my $node = $image_config->get_node(lc $key);
  $node->set('display', 'transcript_label') if $node && $node->get('display') eq 'off';

  my $image = $self->new_image($gene_slice, $image_config, [ $object->stable_id ]);
  
  #return if $self->_export_image($image);
  
  $image->imagemap         = 'yes';
  $image->{'panel_number'} = 'top';
  $image->set_button('drag', 'title' => 'Drag to select region');
  
  $html .= $image->render;
	
	
	#### Table configuration ####
	
	my $columns = [
     { key => 'id',          sort => 'string',        title => 'Name'   },
     { key => 'location',    sort => 'position_html', title => 'Chr:bp' },
		 { key => 'size',    		 sort => 'string',        title => 'Genomic size (bp)' },
     { key => 'class',       sort => 'string',        title => 'Class'  },
     { key => 'source',      sort => 'string',        title => 'Source Study' },
     { key => 'description', sort => 'string',        title => 'Study description', width => '50%' },
  ];
	
	
	# structural variation table
  $html .= $self->structural_variation_table($slice, $columns);
  
	# copy number variant probe table
  $html .= $self->cnv_probe_table($slice, $columns);
	
	return $html;
}


sub structural_variation_table{
  my $self     = shift;
  my $slice    = shift;
	my $columns  = shift;
  my $hub      = $self->hub;
  my $title    = 'Structural variants';
	my $table_id = 'sv';
	my $html;
  
  my $rows;
	
	foreach my $sv (@{$slice->get_all_StructuralVariations}) {
		my $name        = $sv->variation_name;
    my $description = $sv->source_description;
		my $ext_ref     = $sv->external_reference;
	 	my $sv_class    = $sv->class;
	  my $source      = $sv->source;
		my $study_url   = $sv->study_url;
	  
		# SV size (format the size with comma separations, e.g: 10000 to 10,000)
		my $sv_size = ($sv->end-$sv->start+1);
		my $int_length = length($sv_size);
		if ($int_length>3){
			my $nb = 0;
			my $int_string = '';
			while (length($sv_size)>3) {
				$sv_size =~ /(\d{3})$/;
				if ($int_string ne '') {	$int_string = ','.$int_string; }
				$int_string = $1.$int_string;
				$sv_size = substr($sv_size,0,(length($sv_size)-3));
			}	
			$sv_size = "$sv_size,$int_string";
		}	
		
	  # Add study information
	  if ($sv->study_name ne '') {
	  	$source .= ":".$sv->study_name;
			$source = sprintf ('<a rel="external" href="%s">%s</a>',$study_url,$source);
			$description .= $sv->study_description;
	  }
      
    if ($ext_ref =~ /pubmed\/(.+)/) {
			my $pubmed_id = $1;
			my $pubmed_link = $hub->get_ExtURL('PUBMED', $pubmed_id);
      $description =~ s/$pubmed_id/'<a href="'.$pubmed_link.'" target="_blank">'.$&.'<\/a>'/eg;
    }
			
    my $sv_link = $hub->url({
       		type    => 'StructuralVariation',
        	action  => 'Summary',
        	sv      => $name
       	});      

    my $loc_string = $sv->seq_region_name . ':' . $sv->seq_region_start . '-' . $sv->seq_region_end;
        
    my $loc_link = $hub->url({
        	type   => 'Location',
        	action => 'View',
        	r      => $loc_string,
      	});
      
    my %row = (
        	id          => qq{<a href="$sv_link">$name</a>},
        	location    => qq{<a href="$loc_link">$loc_string</a>},
					size        => $sv_size,
        	class       => $sv_class,
        	source      => $source,
        	description => $description,
      	);
	  
    push @$rows, \%row;
  }
  
	my $sv_table = $self->new_table($columns, $rows, { data_table => 1, sorting => [ 'location asc' ] });
	$html .= display_table_with_toggle_button($title,$table_id,1,$sv_table);
	return $html;
}


sub cnv_probe_table{
  my $self     = shift;
  my $slice    = shift;
	my $columns  = shift;
  my $hub      = $self->hub;
  my $title    = 'Copy number variants probes';
	my $table_id = 'cnv';
	my $html;
  
  my $rows;
	
	foreach my $sv (@{$slice->get_all_CopyNumberVariantProbes}) {
		my $name = $sv->variation_name;
    my $description = $sv->source_description;
    my $ext_ref  = $sv->external_reference;
	 	my $sv_class = $sv->class;
	  my $source   = $sv->source;
	  
	  # Add study information
	  if ($sv->study_name ne '') {
	  	$source .= ":".$sv->study_name;
			$description .= $sv->study_description;
	  }
    if ($ext_ref =~ /pubmed\/(.+)/) {
			my $pubmed_id = $1;
			my $pubmed_link = $hub->get_ExtURL('PUBMED', $pubmed_id);
      $description =~ s/$pubmed_id/'<a href="'.$pubmed_link.'" target="_blank">'.$&.'<\/a>'/eg;
    }
			
		# SV size (format the size with comma separations, e.g: 10000 to 10,000)
		my $sv_size = ($sv->end-$sv->start+1);
		my $int_length = length($sv_size);
		if ($int_length>3){
			my $nb = 0;
			my $int_string = '';
			while (length($sv_size)>3) {
				$sv_size =~ /(\d{3})$/;
				if ($int_string ne '') {	$int_string = ','.$int_string; }
				$int_string = $1.$int_string;
				$sv_size = substr($sv_size,0,(length($sv_size)-3));
			}	
			$sv_size = "$sv_size,$int_string";
		}	
			
    my $sv_link = $hub->url({
       		type    => 'StructuralVariation',
        	action  => 'Summary',
        	sv      => $name
      	});      

    my $loc_string = $sv->seq_region_name . ':' . $sv->seq_region_start . '-' . $sv->seq_region_end;
        
    my $loc_link = $hub->url({
        	type   => 'Location',
        	action => 'View',
        	r      => $loc_string,
      	});
      
    my %row = (
        	id          => qq{<a href="$sv_link">$name</a>},
        	location    => qq{<a href="$loc_link">$loc_string</a>},
					size        => $sv_size,
        	class       => $sv_class,
        	source      => $source,
        	description => $description,
      	);
	  
    push @$rows, \%row;
  }
  
	my $cnv_table = $self->new_table($columns, $rows, { data_table => 1, sorting => [ 'location asc' ] });
	$html .= display_table_with_toggle_button($title,$table_id,0,$cnv_table);
	return $html;
}


sub display_table_with_toggle_button {
	my $title = shift;
	my $id    = shift;
	my $state = shift;
	my $table = shift;
	
	my $is_show = 'show';
	my $is_open = 'open';
	if ($state==0) {
		$is_show = 'hide';
		$is_open = 'closed';
	}
	
	$table->add_option('data_table', "toggle_table $is_show");
  $table->add_option('id', $id.'_table');
	my $html = qq{
  	<div>
    	<h2 style="float:left">$title</h2>
      <span class="toggle_button" id="$id"><em class="$is_open" style="margin:5px"></em></span>
      <p class="invisible">.</p>
    </div>\n
	};
	$html .= $table->render;	
	$html .= qq{<br />};
		
	return $html;
}
1;
