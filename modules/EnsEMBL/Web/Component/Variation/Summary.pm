# $Id$

package EnsEMBL::Web::Component::Variation::Summary;

use strict;

use base qw(EnsEMBL::Web::Component::Variation);
use EnsEMBL::Web::Form;

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(0);
}

sub content {
  my $self               = shift;
  my $hub                = $self->hub;
  my $object             = $self->object;
  my $variation          = $object->Obj;
  my $name               = $object->name; 
  my $source             = $object->source;
  my $source_description = $object->source_description; 
  my $source_url         = $object->source_url;
  my $class              = uc $object->vari_class;
  my $is_somatic         = $variation->is_somatic;
  my $vaa                = $variation->adaptor->db->get_VariationAnnotationAdaptor;
  my $variation_features = $variation->get_all_VariationFeatures;
  my $display_name       = $object->name; 
  
  if ($source eq 'dbSNP') {
    my $version = $object->source_version; 
    $display_name = $hub->get_ExtURL_link($name, 'DBSNP', $name);
    $name       = $hub->get_ExtURL_link("$source $version", 'DBSNP_HOME', $name); 
    $name       = "$class ($display_name source $name - $source_description)"; 
  } elsif ($source =~ /SGRP/) {
    $name = $hub->get_ExtURL_link($source, 'SGRP', $name);
    $name = "$class ($display_name source $name - $source_description)";
  } elsif ($source =~ /COSMIC/) {
    $name = $hub->get_ExtURL_link($source, 'COSMIC', $name);
    $display_name = $hub->get_ExtURL_link($display_name, 'COSMIC_ID', $display_name);
    $name = "$class ($display_name source $name - $source_description)";
  } elsif ($source =~ /HGMD/) { # HACK - should get its link properly somehow
    foreach my $va (@{$vaa->fetch_all_by_Variation($variation)}) {
      next unless $va->source_name =~ /HGMD/;
      
      my $source_link = $hub->get_ExtURL_link($va->source_name, 'HGMD', { ID => $va->associated_gene, ACC => $name });
      $name = "$class ($display_name source $source_link $source_description)";
    }
  } else {
    $name = defined $source_url ? qq{<a href="$source_url">$source</a>} : $source;
    $name = "$class ($display_name source $name - $source_description)";
  }

  my $html;
  
  ## First warn if variation has been failed
  if ($variation->failed_description) {
    $html .= $self->_warning('This variation has been flagged as failed', '<p>' . $variation->failed_description . '</p>');
  }
  
  $html .= qq{
    <dl class="summary">
      <dt> Variation class </dt> 
      <dd>$name</dd>
  };
 
  ## Add synonyms
  my %synonyms = %{$object->dblinks};
  my $info;
  
  foreach my $db (keys %synonyms) {
    my @ids = @{$synonyms{$db}};
    my @urls;

    if ($db =~ /dbsnp rs/i) { # Glovar stuff
      @urls = map { $hub->get_ExtURL_link($_, 'SNP', $_) } @ids;
    } elsif ($db =~ /dbsnp/i) {
      foreach (@ids) {
        next if /^ss/; # don't display SSIDs - these are useless
        push @urls , $hub->get_ExtURL_link($_, 'SNP', $_);
      }
      
      next unless @urls;
    } elsif ($db =~ /HGVbase|TSC/) {
      next;
    } elsif ($db =~ /Uniprot/) { 
      push @urls , $hub->get_ExtURL_link($_, 'UNIPROT_VARIATION', $_) for @ids;
    } elsif ($db =~ /HGMD/) { # HACK - should get its link properly somehow
      foreach (@ids) {
        foreach my $va (@{$vaa->fetch_all_by_Variation($variation)}) {
          next unless $va->source_name =~ /HGMD/;
          push @urls, $hub->get_ExtURL_link($_, 'HGMD', { ID => $va->associated_gene, ACC => $_ });
        }
      }
    } else {
      @urls = @ids;
    }

    # Do wrapping
    for (my $counter = 7; $counter < $#urls; $counter +=7) {
      my @front   = splice (@urls, 0, $counter);
      $front[-1] .= '</tr><tr><td></td>';
      @urls       = (@front, @urls);
    }

    $info .= "<b>$db</b> " . (join ', ', @urls) . '<br />';
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
  my $feature_slice;
  
  foreach my $vf (@$variation_features) {
    $feature_slice = $vf->feature_Slice if $vf->dbID == $hub->core_param('vf');
  }  
  
  my $label      = 'Alleles';
  my $alleles    = $object->alleles;
  my $vari_class = $object->vari_class || 'Unknown';
  my $allele_html;

  if ($vari_class ne 'snp') {
    $allele_html = "<b>$alleles</b> (Type: <strong>$vari_class</strong>)";
  } else {
    my $ambig_code = $variation->ambig_code;
    $allele_html = "<b>$alleles</b> (Ambiguity code: <strong>$ambig_code</strong>)";
  }
  
  my $ancestor  = $object->ancestor;
  $allele_html .= "<br /><em>Ancestral allele</em>: $ancestor" if $ancestor;

  # Check somatic mutation base matches reference
  if ($is_somatic && $feature_slice) {
    my $ref_base = $feature_slice->seq;
    my ($a1, $a2) = split //, $alleles;
    
    $allele_html .= "<br /><em>Note</em>: The reference base for this mutation ($a1) does not match the Ensembl reference base ($ref_base)." if $ref_base ne $a1;
  }
  
  $html .= "
      <dt>Alleles</dt>
      <dd>$allele_html</dd>
    </dl>
  ";

  # First add co-located variation info if count == 1
  if ($feature_slice) {
    my $vfa = $hub->get_adaptor('get_VariationFeatureAdaptor', 'variation');
    my @variations;
    
    if ($is_somatic) { 
      @variations = @{$vfa->fetch_all_by_Slice($feature_slice)};  
    } else {
      @variations = @{$vfa->fetch_all_somatic_by_Slice($feature_slice)};
    }
    
    if (@variations) {
      my $variation_string = $is_somatic ? 'with variation ' : 'with somatic mutation ';
      
      foreach my $v (@variations) {
        my $name           = $v->variation_name; 
        my $link           = $hub->url({ v => $name, vf => $v->dbID });
        my $variation      = qq{<a href="$link">$name</a>};
        $variation_string .= ", $variation";
      }
      
      $variation_string =~ s/,\s+//;  

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

  $html  .= '<dl class="summary">';
  
  if ($count < 1) {
    $html .= '<dt>Location</dt><dd>This feature has not been mapped.</dd></dl>';
  }
  else {
    my @values;
    my $selected_vf;
    my $loc_html;
    
    # selected_vf is used to construct a link to location view
    # when count is one we just want the VF ID (the only one)
    if ($count == 1) {
      $selected_vf = $variation_features->[0]->dbID;
    }
    
    else {
      
      # add default value
      push @values, {value => 'null', name => 'None selected'};
      
      # get selected VF from the params
      $selected_vf = $self->hub->core_param('vf');
      
      # add values for each mapping
      foreach my $varif_id (sort
      {
        $mappings{$a}->{'Chr'} cmp $mappings{$b}->{'Chr'} ||
        $mappings{$a}->{'start'} <=> $mappings{$b}->{'start'}
      } keys %mappings) {
        
        my $region          = $mappings{$varif_id}{'Chr'}; 
        my $start           = $mappings{$varif_id}{'start'};
        my $end             = $mappings{$varif_id}{'end'};
        my $str             = $mappings{$varif_id}{'strand'};
        my $display_region  = $region . ':' . ($start - 500) . '-' . ($end + 500);
        my $location_string =
          ($start == $end ? "$region:$start" : "$region:$start-$end").
          ' ('.($str > 0 ? "forward" : "reverse").' strand)';
        
        push @values, {value => $varif_id, name => $location_string};
      }
      
      # create form
      my $url = $hub->url({ vf => undef, v => $id, source => $source, });
      my $form  = new EnsEMBL::Web::Form('select_loc', $url, 'get', 'nonstd check');
      
      # add dropdown
      $form->add_element(
        type         => 'DropDown',
        select       => 'select',
        name         => 'vf',
        values       => \@values,
        value        => $selected_vf, # default to selected_vf
      );
      
      # add submit
      $form->add_element(
        type         => 'Submit',
        value        => 'Go',
      );
      
      # add hidden values for all other params
      my %params = %{$self->hub->core_params};
      foreach my $param(keys %params) {
        
        # ignore vf and region as we want them to be overwritten
        next if $param eq 'vf' or $param eq 'r';
        
        $form->add_element(
          type => 'Hidden',
          name => $param,
          value => $params{$param},
        ) if defined $params{$param};
      }
      
      # render to string
      $loc_html = 'This feature maps to '.$count.' genomic locations'.$form->render;
      
      # strip off unwanted HTML layout tags from form
      $loc_html =~ s/\<\/?(div|tr|th|td|table|tbody|fieldset)+.*?\>\n?//g;
      
      # insert text
      $loc_html =~ s/\<form.*?\>/$&.'<span style="font-weight: bold;">Selected location: <\/span>'/e;
    }
    
    # construct location view link and other strings
    my ($location_string, $location_string_long, $location_link_html);
    
    if(defined($selected_vf)) {
      my $region          = $mappings{$selected_vf}{'Chr'}; 
      my $start           = $mappings{$selected_vf}{'start'};
      my $end             = $mappings{$selected_vf}{'end'};
      my $str             = $mappings{$selected_vf}{'strand'};
      my $display_region  = $region . ':' . ($start - 500) . '-' . ($end + 500);
      
      $location_string = ($start == $end ? "$region:$start" : "$region:$start-$end");
      $location_string_long = $location_string.' ('.($str > 0 ? "forward" : "reverse").' strand)';
      
      # turn on somatic or normal variation track
      my $track_name = $is_somatic ? 'somatic_mutation_COSMIC' : 'variation_feature_variation';
      
      my $location_link = $hub->url({ type =>'Location', action => 'View', r => $display_region, v => $id, source => $source, vf => $selected_vf, contigviewbottom => $track_name.'=normal' });
      $location_link_html = qq( | <a href="$location_link">View in location tab</a>);
    }
    
    # finish off html
    if($count == 1) {
      $loc_html = 'This feature maps to '.$location_string_long.$location_link_html;
    }
    else {
      #insert location link
      $loc_html =~ s/\<\/form\>/$location_link_html.$&/e;
    }
    
    # add to main $html
    $html .= '<dt>Location</dt><dd>'.$loc_html.'</dd></dl>';
  }

  return qq{<div class="summary_panel">$html</div>};
}

1;
