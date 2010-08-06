# $Id$

package EnsEMBL::Web::Component::Variation::Summary;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Variation);

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  0 );
}

sub content {
  my $self = shift;
  my $object = $self->object;

  ## Add feature type and source
  my $name               = $object->name; 
  my $source             = $object->source;
  my $source_description = $object->source_description; 
  my $class              = uc $object->vari_class;
   
  if ($source eq 'dbSNP') {
    my $version = $object->source_version; 
    
    $name = $object->get_ExtURL_link($source .' '. $version, 'DBSNP', $name); 
    $name = "$class (source $name - $source_description)"; 
  } elsif ($source =~ /SGRP/) {
    $name = $object->get_ExtURL_link($source, 'SGRP', $name);
    $name = "$class (source $name - $source_description)";
  } elsif ($source =~ /COSMIC/) {
    $name = $object->get_ExtURL_link($source, 'COSMIC', $name);
    $name = "$class (source $name - $source_description)";
  } elsif ($source =~ /HGMD/) { # HACK - should get its link properly somehow
    # get a va adaptor
    my $vaa = $object->vari->adaptor->db->get_VariationAnnotationAdaptor();
    foreach my $va(@{$vaa->fetch_all_by_Variation($object->vari)}) {
      next unless $va->source_name =~ /HGMD/;
      my $source_link =  $object->get_ExtURL_link($va->source_name, 'HGMD', {'ID' => $va->associated_gene, 'ACC' => $name });
      $name = 
        $class.' (source '. $source_link. ' '.$source_description.')';
    }
  }
  else {
    if(defined($object->source_url)) {
      $name = '<a href="'.$object->source_url.'">'.$source.'</a>';
    }
    else {
      $name = $source;
    }
    $name = "$class (source $name - $source_description)";
  }

  my $html = qq{
    <dl class="summary">
      <dt> Variation class </dt> 
      <dd>$name</dd>
  };

  ## First check that the variation status is not failed
  if ($object->Obj->failed_description) {
    $html .= '<br />' . $self->_info('This variation was not mapped', '<p>' . $object->Obj->failed_description . '</p>');
    return $html; 
  }
 
  ## Add synonyms
  my %synonyms = %{$object->dblinks};
  my $info;
  
  foreach my $db (keys %synonyms) {
    my @ids =  @{$synonyms{$db}};
    my @urls;

    if ($db =~ /dbsnp rs/i) { # Glovar stuff
      @urls  = map { $object->get_ExtURL_link( $_, 'SNP', $_) } @ids;
    } elsif ($db =~ /dbsnp/i) {
      foreach (@ids) {
        next if $_ =~ /^ss/; # don't display SSIDs - these are useless
        push @urls , $object->get_ExtURL_link($_, 'SNP', $_);
      }
      
      next unless @urls;
    } elsif ($db =~/HGVbase|TSC/) {
      next;
    } elsif ($db =~/Uniprot/) { 
      foreach (@ids) {
        push @urls , $object->get_ExtURL_link($_, 'UNIPROT_VARIATION', $_);
      }
    } elsif ($db =~ /HGMD/) { # HACK - should get its link properly somehow
      foreach (@ids) {
        # get a va adaptor
        my $vaa = $object->vari->adaptor->db->get_VariationAnnotationAdaptor();
        foreach my $va(@{$vaa->fetch_all_by_Variation($object->vari)}) {
          next unless $va->source_name =~ /HGMD/;
          push @urls, 
              $object->get_ExtURL_link($_, 'HGMD', {'ID' => $va->associated_gene, 'ACC' => $_ });
        }
      }
    } else {
      @urls = @ids;
    }

    # Do wrapping
    for (my $counter = 7; $counter < $#urls; $counter +=7) {
      my @front = splice (@urls, 0, $counter);
      $front[-1] .= '</tr><tr><td></td>';
      @urls = (@front, @urls);
    }

    $info .= "<b>$db</b> ". (join ', ', @urls) . '<br />';
  }

  $info ||= 'None currently in the database';
 
  $html .= "
    <dt>Synonyms</dt>
    <dd>$info</dd>
  "; 

  ## Add variation sets
  my $variation_sets = $object->get_formatted_variation_set_string;
  
  if ($variation_sets) {
    $html .= '<dt>Present in</dt>';
    $html .= "<dd>$variation_sets</dd>";
  }

  ## Add Alleles
  # get slice for variation feature 
  my @vfs = @{$self->object->Obj->get_all_VariationFeatures};
  my $feature_slice;
  foreach my $vf (@vfs){
    if ($vf->dbID == $self->hub->core_param('vf')){
      $feature_slice = $vf->feature_Slice;
    } 
  }  
  

  my $label = 'Alleles';
  my $alleles = $object->alleles;
  my $vari_class = $object->vari_class || "Unknown";
  my $allele_html;

  if ($vari_class ne 'snp') {
    $allele_html = "<b>$alleles</b> (Type: <strong>$vari_class</strong>)";
  } else {
    my $ambig_code = $object->vari->ambig_code;
    $allele_html = "<b>$alleles</b> (Ambiguity code: <strong>$ambig_code</strong>)";
  }
  
  my $ancestor  = $object->ancestor;
  $allele_html .= "<br /><em>Ancestral allele</em>: $ancestor" if $ancestor;

  # Check somatic mutation base matches reference
  if ($self->object->Obj->is_somatic){
    my $ref_base = $feature_slice->seq();
    my ($a1, $a2) = split(//,$alleles);
    if ($ref_base ne $a1){
       $allele_html .= "<br /><em>Note</em>: The reference base for this mutation ($a1) does not match the Ensembl reference base ($ref_base).";
    }
  }

   $html .= "
      <dt>Alleles</dt>
      <dd>$allele_html</dd>
    </dl>
  ";

  # First add co-located variation info if count == 1
  if ($feature_slice){
    my $vfa = $self->object->database('variation')->get_VariationFeatureAdaptor;
    my @variations;
    if ($self->object->Obj->is_somatic){ 
      @variations = @{$vfa->fetch_all_by_Slice($feature_slice)};  
    } else {
      @variations = @{$vfa->fetch_all_somatic_by_Slice($feature_slice)};
    }
    
    if (@variations) {
      my $variation_string = $self->object->Obj->is_somatic ? 'with variation ' : 'with somatic mutation '  ; 
      foreach my $v (@variations){
        my $name = $v->variation_name; 
        my $link = $object->_url({ v => $name, vf => $v->dbID,});
        my $variation = qq(<a href="$link">$name</a>);  
        $variation_string .= ', '.$variation;
      }
      $variation_string =~s/,\s+//;  

      $html .= "
      <dl class='summary'>
        <dt>Co-located </dt>
        <dd>$variation_string</dd>
      </dl>";    
    }
  }


  ## Add location information
  my $location; 
  my $strand   = '(forward strand)';
  my %mappings = %{$object->variation_feature_mapping};
  my $count    = scalar keys %mappings;
  my $id       = $object->name;
  my $action   = $object->action;

  $html  .= '<dl class="summary">';
  
  if ($count < 1) {
    $html .= '<dt>Location</dt><dd>This feature has not been mapped.</dd></dl>';
  } else {

    # First add co-located variation info if count == 1
    if ($count ==1){
      my $vf = $self->object->Obj->get_all_VariationFeatures->[0]; 
      my $slice = $vf->slice; 
      if ($self->object->Obj->is_somatic){
      } 
    }

    my $hide = $self->hub->get_cookies('ENSEMBL_locations') eq 'close';
    my @locations;
    my $select_html;
    
    $select_html = "<br />Please select a location to display information relating to $id in that genomic region. " if $count > 1;
    
    $html .= sprintf(qq{
          <dt class="toggle_button" title="Click to toggle genomic locations"><span>Location</span><em class="%s"></em></dt>
          <dd>This feature maps to $count genomic location%s. $select_html</dd>
          <dd class="toggle_info"%s>Click the plus to show genomic locations</dd>
        </dl>
        <table class="toggle_table" id="locations"%s>
      },
      $hide ? 'closed' : 'open',
      $count > 1 ? 's' : '',
      $hide ? '' : ' style="display:none"',
      $hide ? ' style="display:none"' : ''
    );

    foreach my $varif_id (sort {$mappings{$a}->{'Chr'} cmp $mappings{$b}->{'Chr'} || $mappings{$a}->{'start'} <=> $mappings{$b}->{'start'}} keys %mappings) {
      my $region          = $mappings{$varif_id}{'Chr'}; 
      my $start           = $mappings{$varif_id}{'start'};
      my $end             = $mappings{$varif_id}{'end'};
      my $str             = $mappings{$varif_id}{'strand'};
      my $display_region  = $region . ':' . ($start - 500) . '-' . ($end + 500); 
      my $track_name      = $self->object->Obj->is_somatic ? 'somatic_mutation_COSMIC' : 'variation_feature_variation';  
      my $link            = $object->_url({ type => 'Location', action=> 'View', v => $id, source => $source, vf => $varif_id, contigviewbottom => $track_name.'=normal' });  
      my $location_string = $start == $end ? "$region:$start" : "$region:$start-$end"; 
      my $location;
      
      $strand = $str <= 0 ? '(reverse strand)' : '(forward strand)';
      
      if ($varif_id eq $self->hub->core_param('vf')) {
        $location = $location_string;
      } else {
        my $link = $object->_url({ v => $id, source => $source, vf => $varif_id,});
        $location = qq(<a href="$link">$location_string</a>);
      }
      
      my $location_link      = $object->_url({ type =>'Location', action => 'View', r => $display_region, v => $id, source => $source, vf => $varif_id, contigviewbottom => $track_name.'=normal' });
      my $location_link_html = qq(<a href="$location_link">Jump to region in detail</a>);
      
      $html .= sprintf('
        <tr%s>
          <td><strong>%s</strong> %s</td>
          <td>%s</td> 
        </tr>',
        $varif_id eq $self->hub->core_param('vf') ? ' class="active"' : '',
        $location,
        $strand,
        $location_link_html
      );
    }
    
    $html .= '</table>';
  }

  return qq{<div class="summary_panel">$html</div>};
}

1;
