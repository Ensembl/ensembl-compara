package EnsEMBL::Web::Component::StructuralVariation::Summary;

use strict;

use base qw(EnsEMBL::Web::Component::StructuralVariation);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(0);
}

sub content {
  my $self                = shift;
  my $hub                 = $self->hub;
  my $object              = $self->object;
	my $sv_obj              = $object->Obj;
  my $name                = $object->name;
  my $class               = $object->class;
  my $source              = $object->source;
  my $source_description  = $object->source_description;
  my $study_name          = $object->study_name;
  my $study_description   = $object->study_description;
  my $study_url           = $object->study_url;
	my $states              = $object->validation_status;
  $name = "$class ($name)";
	
	
  my $source_link = $source;
	my $allele_types;
	if ($source eq 'DGVa') {
	 $source_link = $hub->get_ExtURL_link($source, 'DGVA', $source);
	 $allele_types = $self->get_allele_types($object);
 	}
	elsif ($source =~ /affy/i ) {
		$source_link = $hub->get_ExtURL_link($source, 'AFFYMETRIX', $source);
	}
	elsif ($source =~ /illumina/i) {
		$source_link = $hub->get_ExtURL_link($source, 'ILLUMINA', $source);
	}
	
  $source_description = add_pubmed_link($source_description, $hub);
  
	$source = "$source_link - $source_description";
 	
	# Study line display
	my $study_line = '';
  if ($study_name ne '') {
		$study_description = add_pubmed_link($study_description, $hub);
    $study_line = sprintf ('<a href="%s">%s</a>',$study_url,$study_name);
  	$study_line = "<dt>Study</dt><dd>$study_line - $study_description</dd>";
  }
 
  # Location
  my %mappings = %{$object->variation_feature_mapping};
  my $count    = scalar keys %mappings;
  
  return '<dl class="summary"><dt>Location</dt><dd>This feature has not been mapped.</dd></dl>' unless $count;
  
  my $svf = $hub->param('svf');
  my $id  = $object->name;
  my ($location_link,$location_content,$location,$region,$start,$end);
 
 
 	if ($count > 1) {
    my $params = $hub->core_params;
    my @values;
    
    # create form
    my $form = $self->new_form({
      name   => 'select_loc',
      action => $hub->url({ svf => undef, sv => $name, source => $object->source }), 
      method => 'get', 
      class  => 'nonstd check'
    });
    
    push @values, { value => 'null', name => 'None selected' }; # add default value
    
    # add values for each mapping
    foreach (sort { $mappings{$a}->{'Chr'} cmp $mappings{$b}->{'Chr'} || $mappings{$a}->{'start'} <=> $mappings{$b}->{'start'}} keys %mappings) {
      $region = $mappings{$_}{'Chr'}; 
      $start  = $mappings{$_}{'start'};
      $end    = $mappings{$_}{'end'};
      my $str = $mappings{$_}{'strand'};
      
      push @values, {
        value => $_,
        name  => sprintf('%s (%s strand)', ($start == $end ? "$region:$start" : "$region:$start-$end"), ($str > 0 ? 'forward' : 'reverse'))
      };
    }
    
    # add dropdown
    $form->add_element(
      type   => 'DropDown',
      select => 'select',
      name   => 'svf',
      values => \@values,
      value  => $svf,
    );
    
    # add submit
    $form->add_element(
      type  => 'Submit',
      value => 'Go',
    );
    
    # add hidden values for all other params
    foreach (grep defined $params->{$_}, keys %$params) {
      next if $_ eq 'svf' || $_ eq 'r'; # ignore svf and region as we want them to be overwritten
      
      $form->add_element(
        type  => 'Hidden',
        name  => $_,
        value => $params->{$_},
      );
    }
    
    $location_content = "This feature maps to $count genomic locations" . $form->render;                    # render to string
    $location_content =~ s/\<\/?(div|tr|th|td|table|tbody|fieldset)+.*?\>\n?//g;                            # strip off unwanted HTML layout tags from form
    $location_content =~ s/\<form.*?\>/$&.'<span style="font-weight: bold;">Selected location: <\/span>'/e; # insert text
  }    
  
  if ($svf) {
    $region   = $mappings{$svf}{'Chr'}; 
    $start    = $mappings{$svf}{'start'};
    $end      = $mappings{$svf}{'end'};
    $location = ($start == $end ? "$region:$start" : "$region:$start-$end") . ' (' . ($mappings{$svf}{'strand'} > 0 ? 'forward' : 'reverse') . ' strand)';
    
    $location_link = sprintf(
      ' | <a href="%s">View in location tab</a>',
      $hub->url({
        type              => 'Location',
        action            => 'View',
        r                 => $region . ':' . ($start - 500) . '-' . ($end + 500),
        sv                => $id,
        svf               => $svf,
        contigviewbottom  => 'variation_feature_structural=normal'
			})
    );
  }
	
	
  if ($count == 1) {
    $location_content .= "This feature maps to $location$location_link";
		my $current_svf = $mappings{$svf};
		$location_content .= $self->get_outer_coordinates($current_svf);
		$location_content .= $self->get_inner_coordinates($current_svf);
  } else {
    $location_content =~ s/<\/form>/$location_link<\/form>/;
  }
 
 
	# SV size (format the size with comma separations, e.g: 10000 to 10,000)
	my $genomic_size = '';
	if ($count == 1 || $svf) {
		my $sv_size = ($mappings{$svf}{end}-$mappings{$svf}{start}+1);
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
		$genomic_size = qq{<dt>Genomic size</dt>\n<dd>$sv_size bp</dd>\n};
	}
	
	# Validation status
	my $vstates = '';
	if ($states) {
		$vstates = qq{<dt>Validation status</dt><dd>$states</dd>};
	}
	
  my $html = qq{
    <dl class="summary">
      <dt>Variation class</dt>
      <dd>$name</dd>
			$allele_types
      <dt>Source</dt>
      <dd>$source</dd>
	    $study_line
      <dt>Location</dt>
      <dd>$location_content</dd>
			$genomic_size
			$vstates
    </dl>
  };
	
  return $html;
}


# Method to add a pubmed link to the expression "PMID:xxxxxxx"
# in the source or study description, if it is present.
sub add_pubmed_link{
	my $s_description = shift;
	my $hub = shift;
	if($s_description =~/PMID/){ 
		my @temp = split('\s', $s_description);
    foreach (@temp ){
			if ($_ =~/PMID/){
      	my $pubmed_id = $_; 
        my $id = $pubmed_id;  
        $id =~s/PMID\://; 
        my $pubmed_url = $hub->get_ExtURL_link($pubmed_id, 'PUBMED', $id); 
        $s_description =~s/$_/$pubmed_url/;
			}
		}
 	}
	return $s_description;
}

# Returns the list of the allele types (supporting evidence classes) with the associate colour
sub get_allele_types {
	my $self   = shift;
	my $object = $self->object;#shift;
	
	my $ssvs = $object->supporting_sv;
	my @allele_types;
	my $html;
	
	foreach my $ssv (@$ssvs) {
		my $SO_term = $ssv->class_SO_term;
		if (!grep {$ssv->class_SO_term eq $_} @allele_types) {
			push (@allele_types, $SO_term);
			my $colour = $object->get_class_colour($SO_term);
			my $class  = $ssv->var_class;
			$html .= qq{<td style="width:5px"></td>} if (defined($html));
			$html .= qq{
									<td style="vertical-align:middle">
										<table style="border-spacing:0px"><tr><td style="background-color:$colour;width:7px;height:7px"></td></tr></table>
									</td>
									<td style="padding-left:2px">$class</td>
								 };
		}
	}
	if (defined($html)) {
		$html = qq{<dt>Allele type(s)</dt><dd><table style="border-spacing:0px"><tr>$html</tr></table></dd>\n};
	}
	return $html;
}


sub get_outer_coordinates {
	my $self   = shift;
	my $svf    = shift;
	
	my $region      = $svf->{'Chr'};
	my $outer_start = defined($svf->{'outer_start'}) ? $svf->{'outer_start'} : $svf->{'start'};
	my $outer_end   = defined($svf->{'outer_end'}) ? $svf->{'outer_end'} : $svf->{'end'};
	
	if ($outer_start == $svf->{'start'} and $outer_end == $svf->{'end'}) {
		return '';
	}
	else {
		return qq{<br />Outer coordinates: $region:$outer_start-$outer_end};
	}
}

sub get_inner_coordinates {
	my $self   = shift;
	my $svf    = shift;
	
	my $region      = $svf->{'Chr'};
	my $inner_start = defined($svf->{'inner_start'}) ? $svf->{'inner_start'} : $svf->{'start'};
	my $inner_end   = defined($svf->{'inner_end'}) ? $svf->{'inner_end'} : $svf->{'end'};
	
	if ($inner_start == $svf->{'start'} and $inner_end == $svf->{'end'}) {
		return '';
	}
	else {
		return qq{<br />Inner coordinates: $region:$inner_start-$inner_end};
	}
}
1;
