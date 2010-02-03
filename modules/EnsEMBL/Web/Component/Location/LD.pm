package EnsEMBL::Web::Component::Location::LD;

use strict;
use warnings;
no warnings "uninitialized";

use base qw(EnsEMBL::Web::Component::Location);

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  1 );
}

sub content {
  my $self = shift;
  my $model = $self->model;
  my $obj = $self->object;
  my $html = '<dl class="summary">';

  if ($obj->param('pop1')){
    my $focus = $self->focus($model);  
    if ($focus) {
      $html .= qq( <dt>Focus: </dt><dd>$focus</dd>); 
    }
    $html .= $self->prediction_method($obj);
 
    my $pop_html .= $self->population_info($obj);
    $html .= qq( <dt>Populations: </dt><dd>$pop_html</dd>);
  } else {
     $html .= $self->_info('No Population Selected', '<p>You must select a population(s) using the "Select populations" link from menu on the left hand side of this page.</p>'
  );

  }

  $html .= "</dl><br />";
  return $html;
}

#-----------------------------------------------------------------------------

sub focus {
  ### Information_panel
  ### Purpose : outputs focus of page e.g.. gene, SNP (rs5050)or slice
  ### Description : adds pair of values (type of focus e.g gene or snp and the ID) to panel if the paramater "gene" or "snp" is defined

  my ( $self, $model ) = @_;
  my $obj = $model->object;
  my $hub = $model->hub;

  my ( $info, $focus );
  if ( $obj->param('v') && $obj->param('focus')) {
    my $snp = $obj->core_objects->variation;
    my $name = $snp->name; 
    my $source = $snp->source;
    my $link_name  = $obj->get_ExtURL_link($name, 'DBSNP', $name) if $source eq 'dbSNP'; 
    my $var_url =  $obj->_url({ 'type' => 'Variation', 'action' => 'Summary', 'v' => $obj->param('v'), 'vf' => $obj->param('vf') });
    $info .= "Variant $link_name ($source ". $snp->adaptor->get_source_version($source).")";
    $info .= " <a href=$var_url>[View variation]</a>"; 
  } elsif ( $hub->core_param('g') ) {
    my $gene_id = $hub->core_param('g');
    my $url = $obj->_url({ 'type' => 'Gene', 'action' => 'Summary', 'g' => $obj->param('g') });
    $info .= "Gene <a href=$url>$gene_id</a>";
  } elsif ($hub->core_param('r')){
    my $location = $hub->core_param('r');
    my $url = $obj->_url({ 'type' => 'Location', 'action' => 'View', 'r' => $obj->param('r') });
    $info .= "Location <a href=$url>$location</a>";
  } else {
    return 1;
  }
  return $info;
}

#-----------------------------------------------------------------------------

sub prediction_method {

  ### Information_panel
  ### Purpose: standard blurb about calculation of LD
  ### Description : Adds text information about the prediction method

  my($self, $object) = @_;
  my $label = "Prediction method";
  my $info =
    "<p>LD values were calculated by a pairwise
 estimation between SNPs genotyped in the same individuals and within a
 100kb window.  An established method was used to estimate the maximum
 likelihood of the proportion that each possible haplotype contributed to the
 double heterozygote.</p>";
 
  my $html .= qq( <dt>$label: </dt><dd>$info</dd>);
  return $html;
}

#-----------------------------------------------------------------------------

sub population_info {

  ### Information_panel
  ### Purpose    : outputs name, size, description of population and
  ### super/sub population info if exists
  ### Description : Returns information about the population.  Calls helper function print_pop_info to get population data (name, size, description, whether the SNP is tagged)

  my ( $self, $object ) = @_;
  my $pop_names  = $object->current_pop_name; 
  my $pop_html;

  unless (@$pop_names) {
    if  ( @{$object->pops_for_slice(100000)} ) {
      $pop_html = qq("Population", "Please select a population from the 'Configure this page' link in the left hand menu.");
      return  $pop_html;
    }
    else {
      $pop_html = qq("Population", "There is no LD data for this species.");
      return $pop_html;
    }
  }
  foreach my $name (sort {$a cmp $b} @$pop_names) { 
    my $pop       = $object->pop_obj_from_name($name); 
    my $super_pop = $object->extra_pop($pop->{$name}{PopObject}, "super"); 
    my $sub_pop   = $object->extra_pop($pop->{$name}{PopObject}, "sub");
    my $html = $self->print_pop_info($object, $pop, "Population");
    $html   .= $self->print_pop_info($object, $super_pop, "Super-population");
    $pop_html .= qq(<table>$html</table>);
  }
  return $pop_html;
}

#-----------------------------------------------------------------------------

sub print_pop_info {

  ### Internal_call
  ###Arg1      : population object
  ### Arg2      : label (e.g. "Super-Population" or "Sub-Population")
  ### Example     :   print_pop_info($super_pop, "Super-Population").
  ### Description : Returns information about the population: name, size, description and whether it is a tagged SNP
  ### Returns HTML string with population data

  my ($self, $object, $pop, $label ) = @_;
  my $count;
  my $return;

  foreach my $pop_name (keys %$pop) {
    my $display_pop = _pop_url($object,  $pop->{$pop_name}{Name},
               $pop->{$pop_name}{PopLink});
    
    my $description = $pop->{$pop_name}{Description} || "unknown";
    $description =~ s/\.\s+.*|\.\,.*/\./; # descriptions are v. long. Stop after 1st "."
  
    my $size = $pop->{$pop_name}{Size}|| "unknown"; 
    $return .= "<th>$label: </th><td>$display_pop &nbsp;[size: $size]</td></tr>";
    $return .= "<tr><th>Description:</th><td>".
      ($description)."</td>";

    if ($object->param('v') && $label eq 'Population') {
      my $tagged = $self->tagged_snp($object, $pop->{$pop_name}{Name});
      $return .= "<tr><th>SNP in tagged set for this population:<br /></th>
                   <td>$tagged</td>" if $tagged;
    }
  }
  $return .= "<br />";
  return unless $return;
  $return = "<tr>$return</tr>";
  return $return;
}

#-----------------------------------------------------------------------------

sub tagged_snp {

  ### Arg1 : object
  ### Arg2 : population name (string)
  ### Description : Gets the {{EnsEMBL::Web::Object::SNP}} object off the
  ### proxy object and checks if SNP is tagged in the current population.
  ### Returns 0 if no SNP.
  ### Returns "Yes" if SNP is tagged in the population name supplied, else
  ### returns no

  my ($self, $object, $pop_name)  = @_;
  my $var = $object->core_objects->variation;
  my $snp = $self->new_object('Variation', $var, $object->__data);
  
  my $snp_data  = $snp->tagged_snp;
  return unless keys %$snp_data;

  for my $pop_id (keys %$snp_data) {
    return "Yes" if $pop_id eq $pop_name;
  }
  return "No";
}

#-----------------------------------------------------------------------------
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
