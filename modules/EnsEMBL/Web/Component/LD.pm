package EnsEMBL::Web::Component::LD;

# Puts together chunks of XHTML for LD-based displays

use EnsEMBL::Web::Component;
our @ISA = qw( EnsEMBL::Web::Component);
use POSIX qw(floor ceil);

use strict;
use warnings;
no warnings "uninitialized";

use Spreadsheet::WriteExcel;

# TEST SNPs  gives and ERROR 1065427
# 3858116 has TSC sources, 557122 hapmap (works), 2259958 (senza-hit), 625 multi-hit, lots of LD 2733052, 2422821, 12345
# Problem snp  	1800704 has no upstream, downstream seq,  slow one: 431235
# Variation object: has all the data (flanks, alleles) but no position
# VariationFeature: has position (but also short cut calls to allele etc.) 
#                   for contigview

#-----------------------------------------------------------------------------

=head2 focus

    Arg[1]      : panel, object
    Description : adds pair of values to panel if the paramater 'gene' or 'snp' is defined
    Return type : 1

=cut

sub focus {
  my ( $panel, $object ) = @_;
  my ( $info, $focus );
  if ( $object->param("gene") ) {
    $focus = "Gene";
    my $gene_id = $object->name;
    $info = ("Gene ". $gene_id);
    $info .= "  [<a href='geneview?gene=$gene_id'>View in GeneView</a>]";
  }

  elsif ( $object->param("snp") ) {
    $focus = "SNP";
    my $snp  = $object->__data->{'snp'}->[0];
    my $name = $snp->name;
    my $source = $snp->source;
    my $link_name  = $object->get_ExtURL_link($name, 'SNP', $name) if $source eq 'dbSNP';
    $info .= "$link_name ($source ". $snp->source_version.")";
    my $params = qq( [<a href="snpview?snp=$name;source=$source);
    $params .= ";c=".$object->param('c') if $object->param('c');
    $params .= ";pop=".$object->param('pop') if $object->param('pop');
  }
  else {
    return 1;
  }
  $panel->add_row( "Focus: $focus", $info );
  return 1;
}

#-----------------------------------------------------------------------------

=head2 prediction_method

   Arg[1]      : 
   Example     : $self->prediction_method
   Description : Returns information about the prediction method
   Return type : label, html

=cut

sub prediction_method {
 my($panel, $object) = @_;
 my $label = "Prediction method";
 my $info = 
 "<p>LD values were calculated by a pairwise
 estimation between SNPs genotyped in the same individuals and within a
 100kb window.  An established method was used to estimate the maximum 
 likelihood of the proportion that each possible haplotype contributed to the
 double heterozygote.</p>";

 $panel->add_row( $label, $info );
 return 1;
}

#-----------------------------------------------------------------------------

=head2 population_info

   Arg[1]      : population dbID
   Example     : $self->population_info($self->param("pop"))
   Description : Returns information about the population 
   Return type : label, html

=cut

sub population_info {
  my ( $panel, $object ) = @_;
  my $pop_id  = $object->current_pop_id;
  return () unless $pop_id;

  my $pop       = $object->pop_obj_from_id($pop_id);
  my $super_pop = $object->extra_pop($pop->{$pop_id}{PopObject}, "super");
  my $sub_pop   = $object->extra_pop($pop->{$pop_id}{PopObject}, "sub");

  my $info;
  $panel->add_row( "Population", print_pop_info($object, $pop, "Population"))  if $pop;
   $panel->add_row( "Super-population", print_pop_info($object, $super_pop, "Super-population"))  if $super_pop;
  #$panel->add_row ("Sub-population", print_pop_info($object, $sub_pop, "Sub-population")) if $sub_pop;

  return 1;
 }

#-------------------------------------------------------------------------

=head2 tagged_snp

    Arg[1]      : (optional) String
                  Label
    Example     : $vari_data->renderer->heterozygosity;
    Description : returns Variation heterozygosity in two_col_table format
    Return type : key/value pair of label/html

=cut

sub tagged_snp {
  my $object  = shift;
  my $snps = $object->__data->{'snp'};
  return 0 unless $snps && @$snps;
  my $snp_data  = $snps->[0]->tagged_snp;
  return unless %$snp_data;

  my $current_pop  = $object->current_pop_id;
  for my $pop_id (keys %$snp_data) {
    return "Yes" if $pop_id == $current_pop;
  }
  return "No";
}



#-----------------------------------------------------------------------------

# =head2 html_location

#    Arg[1]      : 
#    Example     : $self->html_location
#    Description : returns string with Genomic location as a link
#    Return type : string

# =cut

# sub html_location {
#   my ( $panel, $object ) = @_;
#   my $return   = sprintf '<a href="/%s/contigview?c=%s:%s;w=50">%s %s</a>',
#     $object->species, 
#       $object->seq_region_name, 
# 	$object->seq_region_start,
# 	  $object->seq_region_type_and_name, 
# 	    $object->thousandify( $object->seq_region_start );

#   $panel->add_row("Genomic region", $return || "No mapping position");
#   return 1;
# }

##############################################################################
# Use this if there is more than one mapping for SNP  

=head2 mappings

 Arg1        : panel
 Arg2        : data object 
 Example     :  $mapping_panel->add_components( qw(mappings EnsEMBL::Web::Component::LD::mappings) );
 Description : table showing Variation feature mappings to genomic locations
 Return type : 1

=cut

sub mappings {
  my ( $panel, $object ) = @_;
  my $view = "ldview";
  my $snp  = $object->__data->{'snp'};
  my %mappings = %{ $snp->[0]->variation_feature_mapping };
  return [] unless keys %mappings;
  my $source = $snp->[0]->source;

  my @table_header;
  foreach my $varif_id (keys %mappings) {
    my %chr_info;
    my $region = $mappings{$varif_id}{Chr};
    my $start  = $mappings{$varif_id}{start};
    my $end    = $mappings{$varif_id}{end};
    my $link   = "/@{[$object->species]}/contigview?l=$region:" .($start - 10) ."-" . ($end+10);
    my $strand = $mappings{$varif_id}{strand};
    $strand = " ($strand)&nbsp;" if $strand;
    if ($region) {
      $chr_info{chr} = "<nobr><a href= $link>$region: $start-$end</a>$strand </nobr>";
    } else {
      $chr_info{chr} = "unknown";
    }
    my $vari = $snp->[0]->name;
    my $choice = "<a href='$view?snp=$vari&c=$region:$start'>Choose this location</a>";

    my $display = $object->centrepoint eq $start ? "Current location":$choice;
    $chr_info{location} = $display;

    $panel->add_row(\%chr_info);
  }
  unshift (@table_header,{key =>'location', title => 'Location'});
  unshift (@table_header, {key =>'chr',title => 'Genomic location (strand)'});

  $panel->add_columns(@table_header);
  return 1;
}

# IMAGE CALLS ################################################################

=head2 ldview_image_menu

 Arg1     : panel
 Arg2     : data object
 Example  : $image_panel->add_components(qw(
      menu  EnsEMBL::Web::Component::LD::ldview_image_menu
      image EnsEMBL::Web::Component::LD::ldview_image
    ));
 Description : Creates a menu container for ldview and adds it to the panel
 Return type : 0

=cut

sub ldview_image_menu {
  my($panel, $object ) = @_;
  my $user_config = $object->user_config_hash( 'ldview' );
  $user_config->{'_databases'}     = $object->DBConnection;
  $user_config->{'_add_labels'}    = 'true';
  $user_config->{'Populations'} = ld_populations($object, 100000);

  my $pop = $object->param('pop') || $object->get_default_pop_id;
  $user_config->{'_ld_population'} = $pop;
  my $mc = $object->new_menu_container(
    'configname'  => 'ldview',
    'panel'       => 'ldview',
    'leftmenus'  => [qw(Features Options Population Export ImageSize)],
    'rightmenus' => [qw(Help)],
    'fields' => {
      'snp'          => $object->param('snp'),
      'gene'         => $object->param('gene'),
      'pop'          => $pop, 
      'w'            => $object->length,
      'c'            => $object->seq_region_name.':'.$object->centrepoint,  
      'source'       => $object->param('source') || "dbSNP",
      'h'            => $object->highlights_string,
    }
  );
  $panel->print( $mc->render_html );
  $panel->print( $mc->render_js );
  return 0;
}


=head2 ldview_image

 Arg1     : panel
 Arg2     : data object
 Arg[3]   : width (optional)
 Example  : $image_panel->add_components(qw(
      menu  EnsEMBL::Web::Component::LD::ldview_image_menu
      image EnsEMBL::Web::Component::LD::ldview_image
    ));
 Description : Creates a drawable container for ldview and adds it to the panel
 Return type : 0

=cut

sub ldview_image {
  my($panel, $object) = @_;
  my ($seq_region, $start, $end, $seq_type ) = ($object->seq_region_name, $object->seq_region_start, $object->seq_region_end, $object->seq_region_type);

  my $slice =
    $object->database('core')->get_SliceAdaptor()->fetch_by_region(
    $seq_type, $seq_region, $start, $end, 1
  );
  my $wuc = $object->user_config_hash( 'ldview' );

  $wuc->set( '_settings', 'width', $object->param('image_width'));
  $wuc->container_width($slice->length);

  # If you want to resize this image
  my $image = $object->new_image( $slice, $wuc, [$object->name] );
  $image->imagemap = 'yes';
  my $T = $image->render;
  $panel->print( $T );
  return 0;
}


=head2 ldview_noimage

 Arg1     : panel
 Arg2     : data object
 Example  :  $image_panel->add_components(qw(
      no_image EnsEMBL::Web::Component::LD::ldview_noimage
   ));
 Description : Adds an HTML string to the panel if the LD cannot be mapped uniquely
 Return type : 1

=cut

sub ldview_noimage {
  my ($panel, $object) = @_;
  $panel->print("<p>Unable to draw context as we cannot uniquely determine the SNP's location</p>");
  return 1;
}


# OPTIONS FORM CALLS ##############################################

sub options {
  my ( $panel, $object ) = @_;
  $panel->print("<p>Use the yellow drop down menus at the top of the image to configure display and data you wish to dump.  If no LD values are displayed, zoom out, choose another population or another region. </p>");
  my $html = qq(
   <div>
     @{[ $panel->form( 'options' )->render() ]}
  </div>);

  $panel->print( $html );
  return 1;
}


=head2 input_forms

   Arg1      : panel
   Arg2      : object
   Description : Returns form 
   Return type : form object

=cut
   #unless (%$data) {
    # $panel->print("<p>No pairwise LD data within $zoom kb of this $focus</p>");
    # return 1;
   #}
   #unless (ref $data eq 'HASH') {
     #$panel->print("<p class='red'>No linkage data in $zoom kb window </p>");
   #  return 1;
   #}


sub options_form {
  my ($panel, $object ) = @_;
  my $form = EnsEMBL::Web::Form->new('ldview', "/@{[$object->species]}/ldtableview", 'get' );

  my  @formats = ( {"value" => "astext",  "name" => "As text"},
	#	   {"value" => "asexcel", "name" => "In Excel format"},
		   {"value" => "ashtml",  "name" => "HTML format "}
		 );

  return $form unless @formats;
  $form->add_element( 'type' => 'Hidden', 'name' => '_format', 'value'=>'HTML' );
  $form->add_element(
    'class'     => 'radiocheck1col',
    'type'      => 'DropDown',
    'renderas'  => 'checkbox',
    'name'      => 'dump',
    'label'     => 'Dump format',
    'values'    => \@formats,
    'value'     => $object->param('dump') || 'ashtml'
  );

  my @cgi_params = @{$panel->get_params($object, {style =>"form"}) };
  foreach my $param ( @cgi_params) {
    $form->add_element (
      'type'      => 'Hidden',
      'name'      => $param->{'name'},
      'value'     => $param->{'value'},
      'id'        => "Other param",
		       );
  }
  $form->add_element(
    'type'      => 'Submit',
    'name'      => 'submit',
    'value'     => 'Dump',
		    );

  $form->add_attribute( 'onSubmit',
  qq(this.elements['_format'].value='HTML';this.target='_self';flag='';for(var i=0;i<this.elements['dump'].length;i++){if(this.elements['dump'][i].checked){flag=this.elements['dump'][i].value;}}if(flag=='astext'){this.elements['_format'].value='Text';this.target='_blank'}if(flag=='gz'){this.elements['_format'].value='Text';})
    );

  return $form;
}



###############################################################################
#               INTERNAL CALLS
###############################################################################


# Internal LD calls: Population Info  ---------------------------------------

=head2 print_pop_info 

  Arg[1]      : population object
  Arg[1]      : label (e.g. "Super-Population" or "Sub-Population")
  Example     : $self->print_pop_info($super_pop, "Super-Population")
  Description : Returns information about the population 
  Return type : label, html

=cut

sub print_pop_info {
  my ($object, $pop, $label ) = @_;
  #my $focus  = focus($object);
  my $count;
  my $return;

  foreach my $pop_id (keys %$pop) {
    my $display_pop = _pop_url($object,  $pop->{$pop_id}{Name}, 
				       $pop->{$pop_id}{PopLink});
    ######## TEMPORARY HACK FOR TRUNCATED POP DESCRIPTIONS IN DB ##
    my $description = $pop->{$pop_id}{Description} || "Unknown";
    $description =~s/<[^>]+>//g;
    $description =~s/<[^>]*$+//g;

    if ($label eq 'Population') {
      $return .= "<th>Name:</th><td>$display_pop</td></tr>";
      $return .= "<tr><th>Size:</th><td>".
	($pop->{$pop_id}{Size}|| "Unknown")."</td></tr> ";
      $return .= "<tr><th>Description:</th><td>".
	($description)."</td></tr>";

      if ($object->param('snp')) {
 	my $tagged = tagged_snp($object);
 	$return .= "<tr><th>SNP in tagged set for this population:</th>
                   <td>$tagged</td></tr>" if $tagged;
       }
    }
    else {
      $count++;
      $return .= qq(<td><span class="small">$display_pop</span></td>);
      if ($count ==4) {
	$count   = 0;
	$return .= "</tr><tr>";
      }
    }
  }
  return unless $return;
  $return = "<table><tr>$return</tr></table>";
  return $return;
}


=head2 _pop_url  ### ALSO IN SNP RENDERER

   Arg1      : Population name (to be displayed)
   Arg2      : dbSNP population ID (variable to be linked to)
   Example     : $self->_pop_url($pop_name, $pop_dbSNPID);
   Description : makes pop_name into a link
   Return type : string

=cut

sub _pop_url {
  my ($object, $pop_name, $pop_dbSNP) = @_;
  return $pop_name unless $pop_dbSNP;
  return $object->get_ExtURL_link( $pop_name, 'DBSNPPOP', $pop_dbSNP->[0] );
}


# Internal: Form  calls #################################################

=head2 ld_populations

   Arg[1]      : object
   Arg2        : slice width
   Example     : ld_populations($object)
   Description : data structure with population id and name of pops with LD info for this SNP
   Return type : hashref

=cut

sub ld_populations {
  my ( $object, $width ) = @_;
  my $pop_ids = $object->pops_for_slice($width); # slice width
  return {} unless @$pop_ids;

  my %pops;
  foreach (@$pop_ids) {
    my $data = $object->pop_obj_from_id($_);
    my $name = $data->{$_}{Name};
    $pops{$_} = $name;
  }
  return \%pops;
}

#------------------------------------------------------------------------------

1;

