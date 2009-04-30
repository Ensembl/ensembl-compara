package EnsEMBL::Web::Component::LD;

### Description: This class consists of methods which output chunks
### of XHTML for LD based displays.
### The page is based on a slice created round a gene or SNP

### This object is called from a Configuration object e.g.
### from package {{EnsEMBL::Web::Configuration::Location}}

### For each component to be displayed, you need to create
### an appropriate panel object and then add the component.
### See {{EnsEMBL::Web::Configuration::Location}}

### Args : Except where indicated, all methods take the same two arguments
### a {{EnsEMBL::Web::Document::Panel}} object and a
### {{EnsEMBL::Web::Proxy::Object}} object (data).

### Returns : In general components return true on completion.
### If true is returned and the components are chained (see notes in
### {{Ensembl::Web::Configuration}}) then the subsequence components are ignored.
### if false is returned any subsequent components are executed.
### Note: Variation objects have all the data (flanks, alleles) but no position
### Note: VariationFeature objects have position (but also short cut
### calls to allele etc.)  for contigview



# TEST SNPs -------------------------------------------------------------
# ERROR 1065427
# 3858116 has TSC sources, 557122 hapmap (works), 2259958 (senza-hit), 625 multi-hit, lots of LD 2733052, 2422821, 12345
# Problem snp  	1800704 has no upstream, downstream seq,  slow one: 431235


use strict;
use warnings;
no warnings "uninitialized";

use EnsEMBL::Web::Component;
use EnsEMBL::Web::Form;
#use Spreadsheet::WriteExcel;
our @ISA = qw( EnsEMBL::Web::Component);
use POSIX qw(floor ceil);



## Info panel functions ################################################

sub focus {

  ### Information_panel
  ### Purpose : outputs focus of page e.g.. gene, SNP (rs5050)or slice
  ### Description : adds pair of values (type of focus e.g gene or snp and the ID) to panel if the paramater "gene" or "snp" is defined

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
  }
  else {
    return 1;
  }
  $panel->add_row( "Focus: $focus", $info );
  return 1;
}

#-----------------------------------------------------------------------------

sub prediction_method {

  ### Information_panel
  ### Purpose: standard blurb about calculation of LD
  ### Description : Adds text information about the prediction method

  my($panel, $object) = @_;
  my $label = "Prediction method";
  my $info =
    qq(<p>LD values were calculated by a pairwise
 estimation between SNPs genotyped in the same individuals and within a
 100kb window.  An established
 <a HREF="http://cvs.sanger.ac.uk/cgi-bin/viewvc.cgi/ensembl-variation/scripts/import/calc_genotypes.pl?view=markup&root=ensembl">method</a> was used to estimate the maximum
 likelihood of the proportion that each possible haplotype contributed to the
 double heterozygote.</p>);

  $panel->add_row( $label, $info );
  return 1;
}

#-----------------------------------------------------------------------------

sub population_info {

  ### Information_panel
  ### Purpose    : outputs name, size, description of population and
  ### super/sub population info if exists
  ### Description : Returns information about the population.  Calls helper function print_pop_info to get population data (name, size, description, whether the SNP is tagged)

  my ( $panel, $object ) = @_;
  my $pop_names  = $object->current_pop_name;

  unless (@$pop_names) {
    if  ( @{$object->pops_for_slice(100000)} ) {
      $panel->add_row("Population", "Please select a population from the yellow drop down menu below.");
      return ;
    }
    else {
      $panel->add_row("Population", "There is no LD data for this species.");
      return ;
    }
  }
  foreach my $name (sort {$a cmp $b} @$pop_names) {
    my $pop       = $object->pop_obj_from_name($name);
    my $super_pop = $object->extra_pop($pop->{$name}{PopObject}, "super");
    my $sub_pop   = $object->extra_pop($pop->{$name}{PopObject}, "sub");
    my $html = print_pop_info($object, $pop, "Population");
    $html   .= print_pop_info($object, $super_pop, "Super-population");
    $panel->add_row( "Population", "<table>$html</table>");
  }
  return 1;
}



sub mappings {

  ### Use this if there is more than one mapping for SNP
  ### Description : table showing Variation feature mappings to genomic locations. May only display when a SNP maps to more than one location

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
      $chr_info{chr} = "&nbsp;<a href= $link>$region: $start-$end</a>$strand";
    } else {
      $chr_info{chr} = "unknown";
    }
    my $vari = $snp->[0]->name;
    my $choice = "<a href='$view?snp=$vari;c=$region:$start;w=10000'>Choose this location</a>";

    my $display = $choice;
    if ( int($object->centrepoint +0.5) eq $start ) {
      $display =  "Current location" if $object->seq_region_name eq $region ;
    }
    $chr_info{location} = $display;

    $panel->add_row(\%chr_info);
  }
  unshift (@table_header,{key =>'location', title => 'Location'});
  unshift (@table_header, {key =>'chr',title => 'Genomic location (strand)'});

  $panel->add_columns(@table_header);
  return 1;
}

# IMAGE CALLS ################################################################

sub ldview_image_menu {

  ### Image_panel
  ### Example  : $image_panel->add_components(qw(
  ###    menu  EnsEMBL::Web::Component::LD::ldview_image_menu
  ###    image EnsEMBL::Web::Component::LD::ldview_image    ));
  ### Description : Creates a menu container for ldview and adds it to the panel
  ### Returns 0

  my($panel, $object ) = @_;
  my $image_config = $object->image_config_hash( 'LD_population' );
  $image_config->{'Populations'}    = $object->pops_for_slice(100000);

  return 0;
}

#-----------------------------------------------------------------------------

sub ldview_image {

  ### Image_panel
  ### Description : Gets the slice, creates the user config
  ### Creates the image, imagemap and renders the image
  ### Returns 0

  my($panel, $object) = @_;
  my ($seq_region, $start, $end, $seq_type ) = ($object->seq_region_name, $object->seq_region_start, $object->seq_region_end, $object->seq_region_type);

  my $slice =
    $object->database('core')->get_SliceAdaptor()->fetch_by_region(
    $seq_type, $seq_region, $start, $end, 1
  );


  my ($count_snps, $snps) = $object->getVariationsOnSlice();
  my ($genotyped_count, $genotyped_snps) = $object->get_genotyped_VariationsOnSlice();

  my $wuc_ldview = $object->image_config_hash( 'ldview' );
  $wuc_ldview->set( '_settings', 'width', $object->param('image_width'));
  $wuc_ldview->container_width($slice->length);
  $wuc_ldview->{'_databases'}     = $object->DBConnection;
  $wuc_ldview->{'_add_labels'}    = 'true';
  $wuc_ldview->{'snps'}           = $snps;
  $wuc_ldview->{'genotyped_snps'} = $genotyped_snps;

  # Do images for first section
  my @containers_and_configs = ( $slice, $wuc_ldview );

  # Do images for each population
  foreach my $pop_name ( sort { $a cmp $b } @{ $object->current_pop_name } ) {
    my $pop_obj = $object->pop_obj_from_name($pop_name);
    next unless $pop_obj->{$pop_name}; # i.e. skip name if not a valid pop name

    my $wuc_pop = $object->image_config_hash( "LD_population_$pop_name", 'LD_population' );
    $wuc_pop->set( '_settings', 'width', $object->param('image_width'));
    $wuc_pop->container_width($slice->length);
    $wuc_pop->{'_databases'}     = $object->DBConnection;
    $wuc_pop->{'_add_labels'}    = 'true';
    $wuc_pop->{'_ld_population'} = [$pop_name];
    $wuc_pop->{'text'} = $pop_name;
    $wuc_pop->{'snps'} = $snps;


    push @containers_and_configs, $slice, $wuc_pop;
  }
  my $image    = $object->new_image([ @containers_and_configs, ],
				     $object->highlights, );

  $image->imagemap = 'yes';
  $panel->print( $image->render );

  return 0;
}


#-------------------------------------------------------------------------
sub ldview_noimage {

  ### Image_panel
  ### Description : Adds an HTML string to the panel if the LD cannot be mapped uniquely

  my ($panel, $object) = @_;
  $panel->print("<p>Unable to draw context as we cannot uniquely determine the SNP's location</p>");
  return 1;
}


# OPTIONS FORM CALLS ##############################################

sub options {

  ### Dumping_form
  ### Description: Adds text to the page instructing user how to navigate round page

  my ( $panel, $object ) = @_;
  $panel->print("<p>Use the yellow drop down menus at the top of the image to configure display and data you wish to dump.  If no LD values are displayed, zoom out, choose another population or another region. </p>");
  my $html = qq(
   <div>
     @{[ $panel->form( 'options' )->render() ]}
  </div>);

  $panel->print( $html );
  return 1;
}


sub options_form {

  ### Dumping_form
  ### Description :  Creates a new form to dump LD data in different formats
  ### (html, text, excel and haploview)
  ### Returns        $form

  my ($panel, $object ) = @_;
  my $form = EnsEMBL::Web::Form->new('ldview_form', "/@{[$object->species]}/ldtableview", 'get' );

  my  @formats = ( {"value" => "astext",       "name" => "As text"},
		   {"value" => "asexcel",      "name" => "In Excel format"},
		   {"value" => "ashtml",       "name" => "HTML format "},
		   {"value" => "ashaploview",  "name" => 'For upload into Haploview software (may take a while)'}
		 );

  return $form unless @formats;
  $form->add_element( 'type' => 'Hidden',
		      'name' => '_format',
		      'value'=>'HTML' );
  $form->add_element(
    'class'     => 'radiocheck1col',
    'type'      => 'DropDown',
    'renderas'  => 'checkbox',
    'name'      => 'dump',
    'label'     => 'Dump format',
    'values'    => \@formats,
    'value'     => $object->param('dump') || 'ashtml',
  );

  my %pop_values;
  my $view_config = $object->get_viewconfig();

  # Read in all in viewconfig stuff
  foreach ($view_config->options) {
    next unless $_ =~ /opt_pop_/;
    $pop_values{$_} = $view_config->get("$_");
  }

  my @cgi_params = @{$panel->get_params($object, {style =>"form"}) };

  foreach my $param ( @cgi_params) {
    if ($param->{'name'} =~ /opt_pop_/) {
      $pop_values{ $param->{'name'} } = $param->{'value'};
    }
     else {
       next if $param->{'name'} =~/opt_/;
       $form->add_element (
 			  'type'      => 'Hidden',
 			  'name'      => $param->{'name'},
 			  'value'     => $param->{'value'},
 			  'id'        => "Other param",
 			 );
     }
  }

  my $populations;
  map { $populations .= "$_:$pop_values{$_}|"; } (keys %pop_values);

  $form->add_element (
		      'type'      => 'Hidden',
		      'name'      => "bottom",
		      'value'     => $populations,
		     );


 $form->add_element(
    'type'      => 'Submit',
    'name'      => 'submit',
    'value'     => 'Dump',
		    );

## TODO - Important! Replace this inline javascript
=pod
  $form->add_attribute( 'onSubmit',
  qq(this.elements['_format'].value='HTML';this.target='_self';
      flag='';
    for(var i=0;i<this.elements['dump'].length;i++){
     if(this.elements['dump'][i].checked){
       flag=this.elements['dump'][i].value;
    }
    }
if(flag=='astext'){this.elements['_format'].value='Text';this.target='_blank';}
if(flag=='asexcel'){this.elements['_format'].value='Excel';this.target='_blank';}
if(flag=='gz'){this.elements['_format'].value='Text';}
)
    );
=cut

  return $form;
}

#if(flag=='ashaploview'){this.elements['_format'].value='HTML';}





###############################################################################
#               INTERNAL CALLS
###############################################################################

sub tagged_snp {

  ### Arg1 : object
  ### Arg2 : population name (string)
  ### Description : Gets the {{EnsEMBL::Web::Object::SNP}} object off the
  ### proxy object and checks if SNP is tagged in the current population.
  ### Returns 0 if no SNP.
  ### Returns "Yes" if SNP is tagged in the population name supplied, else
  ### returns no

  my ($object, $pop_name)  = @_;
  my $snp = $object->__data->{'snp'}->[0];
  return 0 unless $snp && @$snp;
  my $snp_data  = $snp->tagged_snp;
  return unless keys %$snp_data;

  for my $pop_id (keys %$snp_data) {
    return "Yes" if $pop_id eq $pop_name;
  }
  return "No";
}



# Internal LD calls: Population Info  ---------------------------------------

sub print_pop_info {

  ### Internal_call
  ###Arg1      : population object
  ### Arg2      : label (e.g. "Super-Population" or "Sub-Population")
  ### Example     :   print_pop_info($super_pop, "Super-Population").
  ### Description : Returns information about the population: name, size, description and whether it is a tagged SNP
  ### Returns HTML string with population data

  my ($object, $pop, $label ) = @_;
  my $count;
  my $return;

  foreach my $pop_name (keys %$pop) {
    my $display_pop = _pop_url($object,  $pop->{$pop_name}{Name},
				       $pop->{$pop_name}{PopLink});

    my $description = $pop->{$pop_name}{Description} || "unknown";
    $description =~ s/\.\s+.*//; # descriptions are v. long. Stop after 1st "."

    my $size = $pop->{$pop_name}{Size}|| "unknown";
    $return .= "<th>$label: </th><td>$display_pop &nbsp;[size: $size]</td></tr>";
    $return .= "<tr><th>Description:</th><td>".
      ($description)."</td>";

    if ($object->param('snp') && $label eq 'Population') {
      my $tagged = tagged_snp($object, $pop->{$pop_name}{Name} );
      $return .= "<tr><th>SNP in tagged set for this population:<br /></th>
                   <td>$tagged</td>" if $tagged;
    }
  }
  return unless $return;
  $return = "<tr>$return</tr>";
  return $return;
}


sub _pop_url {

  ### Internal_call
  ### Arg 1       : Proxy object
  ### Arg 2       : Population name (to be displayed)
  ### Arg 3       : dbSNP population ID (variable to be linked to)
  ### Example     : _pop_url($pop_name, $pop_dbSNPID);
  ### Description : makes pop_name into a link
  ### Returns HTML string of link to population in dbSNP

  my ($object, $pop_name, $pop_dbSNP) = @_;
  return $pop_name unless $pop_dbSNP;
  return $object->get_ExtURL_link( $pop_name, 'DBSNPPOP', $pop_dbSNP->[0] );
}


#------------------------------------------------------------------------------

1;
