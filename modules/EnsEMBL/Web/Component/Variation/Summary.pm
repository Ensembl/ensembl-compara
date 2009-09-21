# $Id$

package EnsEMBL::Web::Component::Variation::Summary;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Variation);
use CGI qw(escapeHTML);

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  0 );
}

sub content {
  my $self = shift;
  my $object = $self->object;

  ## Add feature type and source
  my $name = $object->name; 
  my $source = $object->source; 
  my $class  =  uc($object->vari_class);
   
  if ($source eq 'dbSNP'){
    $name      = $object->get_ExtURL_link($source, 'SNP', $name); 
    $name = "$class (source $name)"; 
  } elsif ($source =~ /SGRP/){
    $name      = $object->get_ExtURL_link($source, 'SGRP', $name);
    $name = "$class (source $name)";
  } else {
    $name = "$class (source $source)";
  }

  my $html  = '';
  $html .= qq(<dl class="summary">
     <dt> Variation class </dt> 
     <dd>$name</dd>
  );

  ## First check that the variation status is not failed
  if ($object->Obj->failed_description){
   my $failed_text = "<p>" . $object->Obj->failed_description . "</p>";
   $html .= "<br />". $self->_info(
   'This variation was not mapped',
   $failed_text
   );
   return $html; 
  }
 
  ## Add synonyms
  my %synonyms = %{$object->dblinks};
  my $info;
    foreach my $db (keys %synonyms) {
    my @ids =  @{ $synonyms{$db} } ;
    my @urls;

     
    if ($db =~ /dbsnp rs/i) {  # Glovar stuff
      @urls  = map {  $object->get_ExtURL_link( $_, 'SNP', $_)  } @ids;
    }
    elsif ($db =~ /dbsnp/i) {
      foreach (@ids) {
  next if $_ =~/^ss/; # don't display SSIDs - these are useless
  push @urls , $object->get_ExtURL_link( $_, 'DBSNPSS', $_ );
      }
      next unless @urls;
    } elsif( $db =~/HGVbase|TSC/){
      next;
    }elsif ($db =~/Uniprot/){ 
      foreach (@ids) {
        push @urls , $object->get_ExtURL_link( $_, 'UNIPROT_VARIATION', $_ );
      }
    }  else {
      @urls = @ids;
    }

    # Do wrapping
    for (my $counter = 7; $counter < $#urls; $counter +=7) {
      my @front = splice (@urls, 0, $counter);
      $front[-1] .= "</tr><tr><td></td>";
      @urls = (@front, @urls);
    }

    $info .= "<b>$db</b> ". (join ", ", @urls ). "<br />";
  }

  $info ||= "None currently in the database";
 
  $html .= qq(<dt>Synonyms</dt>
     <dd>$info</dd>); 

  ## Add Alleles
   my $label = 'Alleles';
   my $alleles = $object->alleles;
   my $vari_class = $object->vari_class || "Unknown";
   my $allele_html;

   if ($vari_class ne 'snp') {
     $allele_html = qq(<b>$alleles</b> (Type: <strong>$vari_class</strong>));
   }
   else {
     my $ambig_code = $object->vari->ambig_code;
     $allele_html = qq(<b>$alleles</b> (Ambiguity code: <strong>$ambig_code</strong>));
   }
   my $ancestor  = $object->ancestor;
   $allele_html .= qq(<br /><em>Ancestral allele</em>: $ancestor) if $ancestor;

    $html .= qq(<dt>Alleles</dt>
     <dd>$allele_html</dd>);
    $html .="</dl>";
    

  ## Add location information
  my $location; 
  my $strand = "(forward strand)";
  my %mappings = %{ $object->variation_feature_mapping };
  my $count = scalar (keys %mappings);
  $html  .= qq( <dl class="summary">);
  my $id = $object->name;
  my $action = $object->action;

  if ($count < 1) {
   $html .= qq(<dt>Location</dt><dd>This feature has not been mapped.</dd></dl>);
  } else {
    my @locations;
    my $select_html;
    if ($count >1){ $select_html = "<br />Please select a location to display information relating to $id in that genomic region.";}
    $html .= qq(<dt>Location</dt><dd><p class="toggle_text" id="locations_text"> This feature maps to $count genomic location(s). $select_html </p>
    <table class="toggle_table" id="locations">);

    foreach my $varif_id (keys %mappings) {
     my %chr_info;
     my $region = $mappings{$varif_id}{Chr}; 
     my $start  = $mappings{$varif_id}{start};
     my $end    = $mappings{$varif_id}{end};
     my $display_region = $region .':' . ($start -500) .'-'. ($end +500); 
     my $link = $object->_url({'type'=>'Location', 'action'=>'View', 'v' => $id, 'source' => $source, 'vf' => $varif_id, 'contigviewbottom' => 'variation_feature_variation=normal' });  
     my $str = $mappings{$varif_id}{strand};
     if ($str <= 0 ) {$strand ="(reverse strand)";}
     else {$strand = "(forward strand)"; }
     my $location_string; 
     if ($start == $end ) { $location_string =  $region.":".$start;}
     else { $location_string = $region.":".$start."-".$end; }
     my $location; 
     if ($varif_id eq $object->core_objects->{'parameters'}{'vf'} ){
       $location = $location_string;
     } else {
       my $link = $object->_url({'v' => $id, 'source' => $source, 'vf' => $varif_id,});
       $location = qq(<a href="$link">$location_string</a>);
     }
     my $location_link = $object->_url({'type'=>'Location', 'action'=>'View', 'r' => $display_region, 'v' => $id, 'source' => $source, 'vf' => $varif_id, 'contigviewbottom' => 'variation_feature_variation=normal'});

     my $location_link_html = qq(<a href="$location_link">Jump to region in detail</a>);
      $html.= sprintf( '
        <tr%s>
          <td><strong>%s</strong> %s</td>
          <td>%s</td> 
        </tr>',
       $varif_id eq $object->core_objects->{'parameters'}{'vf'} ? ' class="active"' : '',
       $location,
       $strand,
       $location_link_html,   
      );
    }
   $html .= "</table></dd>";
  }


  return $html;
}

1;
