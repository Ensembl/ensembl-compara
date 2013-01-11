package EnsEMBL::Web::Component::Variation::Summary;

use strict;

use base qw(EnsEMBL::Web::Component::Variation);

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
  my $vf                 = $hub->param('vf');
  my $variation_features = $variation->get_all_VariationFeatures;
  my ($feature_slice)    = map { $_->dbID == $vf ? $_->feature_Slice : () } @$variation_features; # get slice for variation feature
  my $failed             = $variation->failed_description ? $self->failed($feature_slice) : ''; ## First warn if variation has been failed

  my $summary_table      = $self->new_twocol(
    $self->variation_source,
    $self->alleles($feature_slice),
    $self->location,
    $feature_slice ? $self->co_located($feature_slice) : (),
    $self->validation_status,
    $self->clinical_significance,
    $self->synonyms,
    $self->hgvs,
    $self->sets
  );

  return sprintf qq{<div class="summary_panel">$failed%s</div>}, $summary_table->render;
}

sub failed {
  my ($self, $feature_slice) = @_;
  my @descs = @{$self->object->Obj->get_all_failed_descriptions};
  my %mappings = %{$self->object->variation_feature_mapping};
  my $count    = scalar keys %mappings;
  my $html;
  
  if ($feature_slice) {
    for (0..$#descs) {
      my $seq    = $feature_slice->seq || '-';
         $seq    =~ s/(.{60})/$1\n/g;
      $descs[$_] =~ s/reference allele/reference allele ($seq)/ if $descs[$_] =~ /match.+reference allele/ && $feature_slice;
    }
  }
 
  ## Do a bit of user-friendly munging
  foreach (@descs) {
    if ($_ eq 'Variation maps to more than one genomic location') {
      $_ = "Variation maps to $count genomic locations"; 
    }
  }
 
  if (scalar @descs > 1) {
    $html  = '<ul>';
    $html .= "<li>$_</li>" foreach @descs;
    $html .= '</ul>';
  } else {
    $html = "<p>$descs[0]</p>";
  }

  my $hub       = $self->hub;
  my $vf        = $hub->param('vf');
  my $id        = $self->object->name;
  my $params    = $hub->core_params;
  my @locations = ({ value => 'null', name => 'None selected' });
    
  # add locations for each mapping
  foreach (sort { $mappings{$a}{'Chr'} cmp $mappings{$b}{'Chr'} || $mappings{$a}{'start'} <=> $mappings{$b}{'start'}} keys %mappings) {
    my $region = $mappings{$_}{'Chr'}; 
    my $start  = $mappings{$_}{'start'};
    my $end    = $mappings{$_}{'end'};
    my $str    = $mappings{$_}{'strand'};
      
    push @locations, {
      value    => $_,
      name     => sprintf('%s (%s strand)', ($start == $end ? "$region:$start" : "$region:$start-$end"), ($str > 0 ? 'forward' : 'reverse')),
      selected => $vf == $_ ? ' selected' : ''
    };
  }
    
  # ignore vf and region as we want them to be overwritten
  my $core_params = join '', map $params->{$_} && $_ ne 'vf' && $_ ne 'r' ? qq(<input name="$_" value="$params->{$_}" type="hidden" />) : (), keys %$params;

  ## Don't show dropdown if we only have one location
  ## (Array has to be greater than 2 since we have a 'none selected' "location" as well)
  if (scalar(@locations) > 2) {

    my $options     = join '', map qq(<option value="$_->{'value'}"$_->{'selected'}>$_->{'name'}</option>), @locations;

    my $label = $vf ? 'Selected location' : 'Select a location';

    $html .= sprintf('<form action="%s" method="get"><b>%s</b>: %s<select name="vf" class="fselect">%s</select> <input value="Go" class="fbutton" type="submit"></form>',
                  $hub->url({ vf => undef, v => $id, source => $self->object->source }),
                  $label,
                  $core_params,
                  $options,
                );
  }
  
  return $self->_warning('This variation has been flagged as failed', $html, '50%');
}


sub variation_source {
  my $self    = shift;
  my $hub     = $self->hub;
  my $object  = $self->object;
  my $name    = $object->name;
  my $source  = $object->source;
  my $version = $object->source_version;
  my $url     = $object->source_url;
  my ($source_link, $sname);
  
  # Date version
  if ($version =~ /^(20\d{2})(\d{2})/) {
    $version = "$2/$1";
  }
  
  ## parse description for links
  (my $description = $object->source_description) =~ s/(\w+) \[(http:\/\/[\w\.\/]+)\]/<a href="$2" class="constant">$1<\/a>/; 
  
  # Source link
  if ($source eq 'dbSNP') {
    $sname       = 'DBSNP';
    $source_link = $hub->get_ExtURL_link("View in $source", $sname, $name);
  } elsif ($source =~ /SGRP/) {
    $source_link = $hub->get_ExtURL_link("View in $source", 'SGRP', $name);
  } elsif ($source =~ /COSMIC/) {
    $sname       = 'COSMIC';
    my $cname = ($name =~ /^COSM(\d+)/) ? $1 : $name;
    $source_link = $hub->get_ExtURL_link("View in $source", "${sname}_ID", $cname);
  } elsif ($source =~ /HGMD/) {
    $version =~ /(\d{4})(\d+)/;
    $version = "$1.$2";
    my $va          = ($hub->get_adaptor('get_VariationAnnotationAdaptor', 'variation')->fetch_all_by_Variation($object->Obj))->[0];
    my $asso_gene   = $va->associated_gene;
       $source_link = $hub->get_ExtURL_link("View in $source", 'HGMD', { ID => $asso_gene, ACC => $name });
  } elsif ($source =~ /ESP/) {
    if ($name =~ /^TMP_ESP_(\d+)_(\d+)/) {
      $source_link = $hub->get_ExtURL_link("View in $source", $source, { CHR => $1 , START => $2, END => $2});
    }
    else {
      $source_link = $hub->get_ExtURL_link("View in $source", "${source}_HOME");
    }
  } elsif ($source =~ /LSDB/) {
    $version = ($version) ? " ($version)" : '';
    $source_link = $hub->get_ExtURL_link("View in $source", $source, $name);
  } else {
    $source_link = $url ? qq{<a href="$url" class="constant">View in $source</a>} : "$source $version";
  }
  
  $version = ($version) ? " (release $version)" : '';
  
  return ['Original source', sprintf('<p>%s%s | %s</p>', $description, $version, $source_link)];
}


sub co_located {
  my ($self, $feature_slice) = @_;
  my $hub        = $self->hub;
  my $adaptor    = $hub->get_adaptor('get_VariationFeatureAdaptor', 'variation');
  $adaptor->db->include_failed_variations(1);
  my @variations = (@{$adaptor->fetch_all_by_Slice($feature_slice)}, @{$adaptor->fetch_all_somatic_by_Slice($feature_slice)});

  if (@variations) {
    my $name  = $self->object->name;
    my $start = $feature_slice->start;
    my $end   = $feature_slice->end;
    my %by_source;
    
    foreach (@variations) {
      my $v_name = $_->variation_name; 
      
      next if $v_name eq $name;
      
      my $v_start = $_->start + $start - 1;
      my $v_end   = $_->end   + $start - 1;
      
      next unless $v_start == $start && $v_end == $end; 
      
      my $link      = $hub->url({ v => $v_name, vf => $_->dbID });
      my $alleles   = ' ('.$_->allele_string.')' if $_->allele_string =~ /\//;
      my $variation = qq{<a href="$link">$v_name</a>$alleles};
      
      push @{$by_source{$_->source}}, $variation;
    }
    
    if (scalar keys %by_source) {
      my $html;
      foreach (keys %by_source) {
        $html .= " <b>$_</b> ";
        $html .= join ', ', @{$by_source{$_}};
      }

      return ['Co-located', "with $html"];
    }
  }
  
  return ();
}

sub synonyms {
  my $self     = shift;
  my $hub      = $self->hub;
  my $object   = $self->object;
  my $synonyms = $object->dblinks;
  my ($count, $count_sources, @synonyms_list);
 
  foreach my $db (sort { lc $a cmp lc $b } keys %$synonyms) {
    my @ids = @{$synonyms->{$db}};
    my @urls;

    if ($db =~ /dbsnp rs/i) { # Glovar stuff
      @urls = map $hub->get_ExtURL_link($_, 'SNP', $_), @ids;
    } elsif ($db =~ /dbsnp/i) {
      foreach (@ids) {
        next if /^ss/; # don't display SSIDs - these are useless
        
        push @urls, $hub->get_ExtURL_link($_, 'SNP', $_);
      }
      
      next unless @urls;
    } elsif ($db =~ /HGVbase|TSC/) {
      next;
    } elsif ($db =~ /Affy|Illumina/){ ##moving genotyping chip data to sets
      next;
    } elsif ($db =~ /Uniprot/) { 
      push @urls, $hub->get_ExtURL_link($_, 'UNIPROT_VARIATION', $_) for @ids;
    } elsif ($db =~ /HGMD/) {
      # HACK - should get its link properly somehow
      my @annotations = grep $_->source_name =~ /HGMD/, @{$hub->get_adaptor('get_VariationAnnotationAdaptor', 'variation')->fetch_all_by_Variation($object->Obj)};
      
      foreach my $id (@ids) {
        push @urls, $hub->get_ExtURL_link($id, 'HGMD', { ID => $_->associated_gene, ACC => $id }) for @annotations;
      }
    } elsif ($db =~ /LSDB/) {
      push @urls , $hub->get_ExtURL_link($_, $db, $_) for @ids;
    } else {
      @urls = @ids;
    }
    
    $count += scalar @urls;
    
    push @synonyms_list, "<strong>$db</strong> " . (join ', ', @urls);
  }
  
  $count_sources = scalar @synonyms_list;
 
  # Large text display
  if ($count_sources > 1) { # Collapsed div display 
    my $show = $self->hub->get_cookie_value('toggle_variation_synonyms') eq 'open';

    return [
      sprintf('<a class="toggle %s set_cookie" href="#" rel="variation_synonyms" title="Click to toggle sets names">Synonyms</a>', $show ? 'open' : 'closed'),
      sprintf('<p>This variation has <strong>%s</strong> synonyms - click the plus to show</p><div class="variation_synonyms twocol-cell"><div class="toggleable" style="font-weight:normal;%s"><ul>%s</ul></div></div>',
        $count,
        $show ? '' : 'display:none',
        join('', map "<li>$_</li>", @synonyms_list)
      )
    ];

  } else {
    return ['Synonyms', $count_sources ? $synonyms_list[0] : 'None currently in the database'];
  }
}

sub alleles {
  my ($self, $feature_slice) = @_;
  my $object     = $self->object;
  my $variation  = $object->Obj;
  my $alleles    = $object->alleles;
  my @l_alleles  = split '/', $alleles;
  my $c_alleles  = scalar @l_alleles;
  my $alt_string = $c_alleles > 2 ? 's' : '';
  my $ancestor   = $object->ancestor;
     $ancestor   = " | Ancestral: <strong>$ancestor</strong>" if $ancestor;
  my $ambiguity  = $variation->ambig_code;
     $ambiguity  = 'not available' if $object->source =~ /HGMD/;
     $ambiguity  = " | Ambiguity code: <strong>$ambiguity</strong>" if $ambiguity;
  my $freq       = sprintf '%.2f', $variation->minor_allele_frequency;
     $freq       = '&lt; 0.01' if $freq eq '0.00'; # Frequency lower than 1%
  my $maf        = $variation->minor_allele;
     $maf        = " | MAF: <strong>$freq</strong> ($maf)" if $maf;
  my $html;   
     
  # Check allele string size (for display issues)
  my $large_allele = 0;
  my $display_alleles;
  if (length($alleles) > 50) {
    foreach my $string_allele (@l_alleles) {
      $display_alleles .= '/' if ($display_alleles);
      $display_alleles .= substr($string_allele,0,50);
      if (length($string_allele) > 50) {
        $large_allele += 1;
        $display_alleles .= '...';
      }
    }
    if ($large_allele != 1) {
      $display_alleles = substr($alleles,0,50).'...';
      $large_allele = 1;
    }
    
    $alleles = join("/<br />", @l_alleles);
    my $show = $self->hub->get_cookie_value('toggle_Alleles') eq 'open';
    $html = sprintf('Reference/Alternative%s: 
      <a class="toggle %s set_cookie" href="#" rel="Alleles" style="font-weight:bold;font-size:1.2em" title="Click to toggle alleles">%s</a>
      <small>Click the plus to show all of the alleles</small>%s
      <div class="Alleles"><div class="toggleable" style="font-weight:normal;%s">%s</div></div>',
      $alt_string,
      $show ? 'open' : 'closed',
      $display_alleles, "$ancestor$ambiguity$maf",
      $show ? '' : 'display:none',
      "<pre>$alleles</pre>");
  }
  else {
    $html = qq{Reference/Alternative$alt_string: <span style="font-weight:bold;font-size:1.2em">$alleles</span>$ancestor$ambiguity$maf};
  }

  # Check somatic mutation base matches reference
  if ($feature_slice) {
    my $sequence = $feature_slice->seq;
    my ($allele) = split /\//, $object->alleles;
    
    if ($allele =~ /^[ACGTN]+$/) {
      my $seq   = length $sequence == 1 ? 'base': 'sequence';
      $sequence =~ s/(.{60})/$1<br \/>/g;
      
      if ($sequence ne $allele) {
        $html .= '<br />' if ($large_allele == 0);
        if (length $sequence < 50) {
          $html .= "<em>Note</em>: The reference $seq for this mutation ($allele) does not match the Ensembl reference $seq ($sequence) at this location.";
        }
        else {
          $allele = substr($allele,0,50).'...' if (length $allele > 50);
          my $show2 = $self->hub->get_cookie_value('toggle_Sequence') eq 'open';
          $html  .= sprintf('<em>Note</em>: The reference %s for this mutation (%s) does not match the Ensembl reference %s at this location.
                             <a class="toggle %s set_cookie" href="#" rel="Sequence" title="Click to toggle Sequence"></a><small>Click the plus to show all of the sequence</small>
                             <div class="Sequence"><div class="toggleable" style="font-weight:normal;%s">%s</div></div>',
                            $seq,
                            $allele,
                            $seq,
                            $show2 ? 'open' : 'closed',
                            $show2 ? '' : 'display:none',
                            "<pre>$sequence</pre>"
                           );
        }
      }
    }
  }
  
  return [ 'Alleles', qq(<div class="twocol-cell">$html</div>) ];
}

sub location {
  my $self     = shift;
  my $object   = $self->object;
  my %mappings = %{$object->variation_feature_mapping};
  my $count    = scalar keys %mappings;
  
  return ['Location', 'This variation has not been mapped'] unless $count;
  
  my $hub = $self->hub;
  my $vf  = $hub->param('vf');
  my $id  = $object->name;
  my (@rows, $location, $location_link);
  
  if ($vf) {
    my $variation = $object->Obj;
    my $type     = $mappings{$vf}{'Type'};
    my $region   = $mappings{$vf}{'Chr'}; 
    my $start    = $mappings{$vf}{'start'};
    my $end      = $mappings{$vf}{'end'};

    $location = ucfirst(lc $type).' <b>'.($start == $end ? "$region:$start" : "$region:$start-$end") . '</b> (' . ($mappings{$vf}{'strand'} > 0 ? 'forward' : 'reverse') . ' strand)';
    
    $location_link = sprintf(
      ' | <a href="%s" class="constant">View in location tab</a>',
      $hub->url({
        type             => 'Location',
        action           => 'View',
        r                => $region . ':' . ($start - 50) . '-' . ($end + 50),
        v                => $id,
        vf               => $vf,
        source           => $object->source,
        contigviewbottom => ($variation->is_somatic ? 'somatic_mutation_COSMIC=normal' : 'variation_feature_variation=normal') . ($variation->failed_description ? ',variation_set_fail_all=normal' : '') . ',seq=normal'
      })
    );
  }
  else {
    $location = "This variation maps to $count genomic locations; <b>None selected</b>";
  }
  
  return [ 'Location', "$location$location_link" ];
}


sub validation_status {
  my $self           = shift;
  my $hub            = $self->hub;
  my $object         = $self->object;
  my $status         = $object->status;
  my @variation_sets = sort @{$object->get_variation_set_string};
  my (@status_list, %main_status);
  
  if (scalar @$status) {
    my $snp_name = $object->name;
    
    foreach (@$status) {
      my $st;
      
      if ($_ eq 'hapmap') {
        $st = 'HapMap', $hub->get_ExtURL_link($snp_name, 'HAPMAP', $snp_name);
        $main_status{'HapMap'} = 1;
        next;
      } elsif ($_ =~ /1000Genome/i) {
        $st = '1000 Genomes';
        $main_status{'1000 Genomes'} = 1;
        next;
      } elsif ($_ ne 'failed') {
        $st = $_ eq 'freq' ? 'frequency' : $_;
      }
      
      push @status_list, $st;
    }
  }
  
  my $status_count = scalar @status_list;
  
  if ( !$main_status{'1000 Genomes'}) {
    foreach my $vs (@variation_sets) {
      if ($vs =~ /1000 Genomes/i && !$main_status{'1000 Genomes'}) {
        $main_status{'1000 Genomes'} = 1;
        $status_count ++;
      }
    }
  }
  
  return unless $status_count;
  
  my $html;
  
  if ($main_status{'HapMap'} || $main_status{'1000 Genomes'}) {
    my $show = $self->hub->get_cookie_value('toggle_status') eq 'open';
    my $showed_line;
    
    foreach my $st (sort keys %main_status) {
      $showed_line .= ', ' if $showed_line;
      $showed_line .= "<b>$st</b>";
      $status_count --;
    }
    
    $showed_line .= ' and also ' . join ', ', sort @status_list if $status_count > 0;
    $html        .= $showed_line;
  } else {
    $html .= join ', ', sort @status_list;
  }
  
  return ['Validation status', $html];
}

sub clinical_significance {
  my $self   = shift;
  my $object = $self->object;
  my $hub    = $self->hub; 
  my ($clin_sign,$colour) = $object->clinical_significance;
  my $c_link = $hub->get_ExtURL_link("View explanation", "DBSNP_CLIN", '');
  return $clin_sign ? [
    {'title' => 'Clinical significance', 'inner_text' => 'Clinical significance'},
    qq{<p><span style="color:$colour">$clin_sign</span> (from dbSNP) | $c_link</p>}
  ] : ();
}

sub hgvs {
  my $self      = shift;
  my $object    = $self->object;
  my $hgvs_urls = $object->get_hgvs_names_url(1);
  my $count     = 0;
  my $total     = scalar keys %$hgvs_urls;
  my $html;
 
  # Loop over and format the URLs
  foreach my $allele (keys %$hgvs_urls) {
    $html  .= sprintf '<p>%s</p>', join('<br />', $total > 1 ? "<b>Variant allele $allele</b>" : (), @{$hgvs_urls->{$allele}});
    $count += scalar @{$hgvs_urls->{$allele}};
  }

  # Wrap the html
  if ($count > 1) {
    my $show = $self->hub->get_cookie_value('toggle_HGVS_names') eq 'open';

    return [
      sprintf('<a class="toggle %s set_cookie" href="#" rel="HGVS_names" title="Click to toggle HGVS names">HGVS names</a>', $show ? 'open' : 'closed'),
      sprintf(qq(<div class="twocol-cell">
        <p>This variation has <strong>%s</strong> HGVS names - click the plus to show</p>
        <div class="HGVS_names"><div class="toggleable"%s>$html</div></div>
      </div>), $count, $show ? '' : ' style="display:none"')
    ];
  } elsif ($count == 1) {
    return ['HGVS name', $html];
  }

  return ['HGVS name', 'None'];
}

sub sets{

  my $self           = shift;
  my $hub            = $self->hub;
  my $object         = $self->object;
  my $status         = $object->status;
  my @variation_sets = sort @{$object->get_variation_set_string};

  my @genotyping_sets_list;

  foreach my $vs (@variation_sets){
    next unless $vs =~/Affy|Illumina/;  ## only showing genotyping chip sets
    push @genotyping_sets_list,  $vs;
  }

  my $count = scalar @genotyping_sets_list;  
  
  if ($count > 3) {
    my $show = $self->hub->get_cookie_value('toggle_variation_sets') eq 'open';
  
    return [
      sprintf('<a class="toggle %s set_cookie" href="#" rel="variation_sets" title="Click to toggle sets names">Genotyping chips</a>', $show ? 'open' : 'closed'),
      sprintf('<p>This variation has assays on <strong>%s</strong> chips - click the plus to show</p><div class="variation_sets twocol-cell"><div class="toggleable" style="font-weight:normal;%s"><ul>%s</ul></div></div>',
        $count,
        $show ? '' : 'display:none',
        join('', map "<li>$_</li>", @genotyping_sets_list)
      )
    ];
  }
  else {
    return scalar @genotyping_sets_list
      ? ['Genotyping chips', sprintf('This variation has assays on: %s', join(', ', @genotyping_sets_list))]
      : ()
    ;
  }
}


1;
