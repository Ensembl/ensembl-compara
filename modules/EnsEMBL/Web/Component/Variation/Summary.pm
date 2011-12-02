# $Id$

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
  my $summary;
    $summary            .= $self->variation_source;
    $summary            .= $self->alleles($feature_slice);
    $summary            .= $self->location;
    $summary            .= $self->co_located($feature_slice) if $feature_slice;
    $summary            .= $self->validation_status;
    $summary            .= $self->synonyms;
    $summary            .= $self->hgvs;
  
  return qq{
    <div class="summary_panel">
      $failed
      <dl class="summary">
        $summary
      </dl>
    </div>
  };
}

sub failed {
  my ($self, $feature_slice) = @_;
  my @descs = @{$self->object->Obj->get_all_failed_descriptions};
  my $html;
  
  if ($feature_slice) {
    for (0..$#descs) {
      my $seq    = $feature_slice->seq || '-';
         $seq    =~ s/(.{60})/$1\n/g;
      $descs[$_] =~ s/reference allele/reference allele ($seq)/ if $descs[$_] =~ /match.+reference allele/ && $feature_slice;
    }
  }
  
  if (scalar @descs > 1) {
    $html  = '<p><ul>';
    $html .= "<li>$_</li>" foreach @descs;
    $html .= '</ul></p>';
  } else {
    $html = $descs[0];
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
  my $source_link;
  my $home_link;
  my $sname;
  
  # Date version
  if ($version =~ /^(20\d{2})(\d{2})/) {
    $version = " ($2/$1)";
  } elsif ($version) {
    $version = " $version";
  }
  
  ## parse description for links
  my $description = $object->source_description;
  $description =~ s/(\w+) \[(http:\/\/[\w\.\/]+)\]/<a href="$2">$1<\/a>/; 
  
  # Source link
  if ($source eq 'dbSNP') {
    $sname = 'DBSNP';
    $source_link = $hub->get_ExtURL_link("$source$version", $sname, $name);
    $home_link = $hub->get_ExtURL_link($source, $sname.'_HOME', $name);
    $description =~ s/$sname/$home_link/i;
  } elsif ($source =~ /SGRP/) {
    $source_link = $hub->get_ExtURL_link("$source$version", 'SGRP', $name);
  } elsif ($source =~ /COSMIC/) {
    $sname = 'COSMIC';
    $source_link = $hub->get_ExtURL_link("$source$version", $sname.'_ID', $name);
    $home_link = $hub->get_ExtURL_link($source, $sname, $name);
    $description =~ s/$sname/$home_link/i;
  } elsif ($source =~ /HGMD/) {
    my $va = ($hub->get_adaptor('get_VariationAnnotationAdaptor', 'variation')->fetch_all_by_Variation($object->Obj))->[0];
    my $asso_gene = $va->associated_gene;
    $sname = 'HGMD-PUBLIC';
    $source_link = $hub->get_ExtURL_link("$source$version", 'HGMD', { ID => $asso_gene, ACC => $name });
    $home_link = $hub->get_ExtURL_link($source, $sname, $name);
    $description =~ s/$sname/$home_link/i;
  } elsif ($source =~ /LSDB/) {
    $source_link = $hub->get_ExtURL_link($source . ($version ? " ($version)" : ''), $source, $name);
  } else {
    $source_link = $url ? qq{<a href="$url">$source$version</a>} : "$source $version";
  }

  return sprintf('
    <dt>Source</dt> 
    <dd>%s - %s</dd>',
    $source_link, $description
  );
}


sub co_located {
  my ($self, $feature_slice) = @_;
  my $hub        = $self->hub;
  my $adaptor    = $hub->get_adaptor('get_VariationFeatureAdaptor', 'variation');
  my @variations = (@{$adaptor->fetch_all_by_Slice($feature_slice)}, @{$adaptor->fetch_all_somatic_by_Slice($feature_slice)});
  my $html;
  
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
      my $variation = qq{<a href="$link">$v_name</a>};
      
      push @{$by_source{$_->source}}, $variation;
    }
    
    if (scalar keys %by_source) {
      foreach (keys %by_source) {
        $html .= " <b>$_</b> ";
        $html .= join ', ', @{$by_source{$_}};
      }

      $html = qq{
        <dt>Co-located</dt>
        <dd>with $html</dd>
      };
    }
  }
  
  return $html;
}

sub synonyms {
  my $self     = shift;
  my $hub      = $self->hub;
  my $object   = $self->object;
  my $synonyms = $object->dblinks;
  my $count;
  my $count_sources;
   my @synonyms_list;
  my $html;
 
  foreach my $db (sort { lc $a cmp lc $b } keys %$synonyms) {
    my @ids = @{$synonyms->{$db}};
    my @urls;

    if ($db =~ /dbsnp rs/i) { # Glovar stuff
      @urls = map { $hub->get_ExtURL_link($_, 'SNP', $_) } @ids;
    } elsif ($db =~ /dbsnp/i) {
      foreach (@ids) {
        next if /^ss/; # don't display SSIDs - these are useless
        push @urls, $hub->get_ExtURL_link($_, 'SNP', $_);
      }
      
      next unless @urls;
    } elsif ($db =~ /HGVbase|TSC/) {
      next;
    } elsif ($db =~ /Uniprot/) { 
      push @urls , $hub->get_ExtURL_link($_, 'UNIPROT_VARIATION', $_) for @ids;
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
    $count += scalar(@urls);
    my $syn = "<strong>$db</strong> " . (join ', ', @urls);
    push(@synonyms_list,$syn);
  }
  
  $count_sources = scalar(@synonyms_list);
 
  # Large text display
  if ($count_sources > 1) { # Collapsed div display 
    $html = "<ul><li>".join('</li><li>',@synonyms_list)."</li></ul>";
    my $show       = $self->hub->get_cookies('toggle_variation_synonyms') eq 'open';
    
    return sprintf('
      <dt><a class="toggle %s set_cookie" href="#" rel="variation_synonyms" title="Click to toggle sets names">Synonyms</a></dt>
      <dd>This feature has <strong>%s</strong> synonyms - click the plus to show</dd>
      <dd class="variation_synonyms"><div class="toggleable" style="font-weight:normal;%s">%s</div></dd>',
      $show ? 'open' : 'closed',
      $count,
      $show ? '' : 'display:none',
      $html
    );
  }
  else {
    $html = ($count_sources) ? $synonyms_list[0] : 'None currently in the database';
    return qq{
      <dt>Synonyms</dt>
      <dd>$html</dd>
    }; 
  }
}


sub alleles {
  my ($self, $feature_slice) = @_;
  my $object   = $self->object;

  # Ref/Alt
  my $alleles = $object->alleles;
  my $c_alleles  = scalar (split('/', $alleles));
  my $alt_string;
  $alt_string = 's' if ($c_alleles > 2);
  
  # Ancestral
  my $ancestor = $object->ancestor;
  $ancestor = qq{ | Ancestral: <strong>$ancestor</strong>} if ($ancestor);
  
  # Ambiguity
  my $ambiguity = $object->Obj->ambig_code;
  if ($object->source =~ /HGMD/) {
    $ambiguity = 'not available';
  }
  $ambiguity = qq{ | Ambiguity code: <strong>$ambiguity</strong>} if ($ambiguity);
  
  # MAF
  my $maf = $object->Obj->minor_allele;
  my $freq = sprintf("%.2f", $object->Obj->minor_allele_frequency);
  $freq = "&lt; 0.01" if ($freq eq '0.00'); # Frequency lower than 1%
  $maf = " | MAF: <strong>$freq</strong> ($maf)" if ($maf);
  
  my $html = sprintf 'Reference/Alternative%s: <span style="font-weight:bold;font-size:1.2em">%s</span>%s%s%s',
                      $alt_string, $alleles, $ancestor, $ambiguity, $maf;

  # Check somatic mutation base matches reference
  if ($feature_slice) {
    my $sequence = $feature_slice->seq;
    my ($allele) = split /\//, $object->alleles;
    
    if ($allele =~ /^[ACGTN]+$/) {
      my $seq   = length $sequence == 1 ? 'base': 'sequence';
      $sequence =~ s/(.{60})/$1<br \/>/g;
      $html    .= "<br /><em>Note</em>: The reference $seq for this mutation ($allele) does not match the Ensembl reference $seq ($sequence) at this location." if $sequence ne $allele;
    }
  }
  
  return qq{<dt>Alleles</dt><dd>$html</dd>};
}


sub location {
  my $self     = shift;
  my $object   = $self->object;
  my %mappings = %{$object->variation_feature_mapping};
  my $count    = scalar keys %mappings;
  
  return '<dl class="summary"><dt>Location</dt><dd>This feature has not been mapped.</dd></dl>' unless $count;
  
  my $hub = $self->hub;
  my $vf  = $hub->param('vf');
  my $id  = $object->name;
  my ($html, $location, $location_link);
  
  if ($vf) {
    my $variation = $object->Obj;
    my $type     = $mappings{$vf}{'Type'};
    my $region   = $mappings{$vf}{'Chr'}; 
    my $start    = $mappings{$vf}{'start'};
    my $end      = $mappings{$vf}{'end'};
       $location = ucfirst(lc $type).' <b>'.($start == $end ? "$region:$start" : "$region:$start-$end") . '</b> (' . ($mappings{$vf}{'strand'} > 0 ? 'forward' : 'reverse') . ' strand)';
    
    $location_link = sprintf(
      ' | <a href="%s">View in location tab</a>',
      $hub->url({
        type             => 'Location',
        action           => 'View',
        r                => $region . ':' . ($start - 500) . '-' . ($end + 500),
        v                => $id,
        vf               => $vf,
        source           => $object->source,
        contigviewbottom => ($variation->is_somatic ? 'somatic_mutation_COSMIC=normal' : 'variation_feature_variation=normal') . ($variation->failed_description ? ',variation_set_fail_all=normal' : '')
      })
    );
  }
  
  if ($count > 1) {
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
    my $core_params = join '', map $params->{$_} && $_ ne 'vf' && $_ ne 'r' ? qq{<input name="$_" value="$params->{$_}" type="hidden" />} : (), keys %$params;
    my $options     = join '', map qq{<option value="$_->{'value'}"$_->{'selected'}>$_->{'name'}</option>}, @locations;
    
    $html = sprintf('
        This feature maps to %s genomic locations
      </dd>
      <dt>Selected location</dt>
      <dd>
        <form action="%s" method="get">
          %s
          <select name="vf" class="fselect">
            %s
          </select>
          <input value="Go" class="fbutton" type="submit">
          %s
        </form>
      </dd>',
      $count,
      $hub->url({ vf => undef, v => $id, source => $object->source }),
      $core_params,
      $options,
      $location_link
    );
  } else {
    $html = "$location$location_link";
  }
  
  return qq{<dt>Location</dt><dd>$html</dd>};
}


sub validation_status {
  my $self   = shift;
  my $hub    = $self->hub;
  my $object = $self->object;
  my $status = $object->status;

  my @variation_sets = sort @{$self->object->get_variation_set_string};
  
  my @status_list;
  my %main_status;
  my $html;
  
  if (scalar @$status) {
    my $snp_name = $object->name;
    foreach (@$status) {
       my $st;
      if ($_ eq 'hapmap') {
        $st = 'HapMap', $hub->get_ExtURL_link($snp_name, 'HAPMAP', $snp_name);
        $main_status{'HapMap'} = 1;
        next;
      }
      elsif ( $_ =~ /1000Genome/i) {
        $st = '1000 Genomes';
        $main_status{'1000 Genomes'} = 1;
        next;
      }
      elsif ($_ ne 'failed') {
        $st = $_ eq 'freq' ? 'frequency' : $_;
      }
      push (@status_list, $st);
    }
  }
  
  if (!$main_status{'HapMap'} && !$main_status{'1000 Genomes'}) {
    foreach my $vs (@variation_sets) {
      if ($vs =~ /1000 Genomes/i && !$main_status{'1000 Genomes'}) {
        $main_status{'1000 Genomes'} = 1;
      }
      elsif ($vs =~ /hapmap/i && !$main_status{'HapMap'}) {
        $main_status{'HapMap'} = 1;
      }
    }
  }
  
  my $status_count = scalar @status_list;
  
  my $html = qq{This variation is validated by };
  
  
  return unless ($status_count);
  
  my $status_data;
  if ($main_status{'HapMap'} || $main_status{'1000 Genomes'}) {
    my $show = $self->hub->get_cookies('toggle_status') eq 'open';
    
    my $showed_line;
    foreach my $st (sort(keys(%main_status))) {
      $showed_line .= ', ' if ($showed_line);
      $showed_line .= "<b>$st</b>";
      $status_count --;
    }
    if ($status_count > 0) {
      $showed_line .= " and also ".join ', ', sort(@status_list);
    }
    
    $html .= $showed_line;
  }
  else {
    $html .= join ', ', sort(@status_list);
  }
  return qq{ <dt>Validation status</dt><dd>$html</dd>};
}


sub hgvs {
  my $self      = shift;
  my $object    = $self->object;
  my $hgvs_urls = $object->get_hgvs_names_url;
  my $count     = 0;
  my $total     = scalar keys %$hgvs_urls;
  my $html;
  
  # Loop over and format the URLs
  foreach my $allele (keys %$hgvs_urls) {
    $html  .= ($count ? '<br />' : '') . "<b>Variant allele $allele</b><br />" if $total > 1;
    $html  .= join '<br />', @{$hgvs_urls->{$allele}}, $total > 1 ? '' : ();
    $count += scalar @{$hgvs_urls->{$allele}};
  }
  
  # Wrap the html
  if ($count > 1) {
    my $show = $self->hub->get_cookies('toggle_HGVS_names') eq 'open';
    my $s    = $count > 1 ? 's' : '';
    
    $html = sprintf('
      <dt><a class="toggle %s set_cookie" href="#" rel="HGVS_names" title="Click to toggle HGVS names">HGVS names</a></dt>
      <dd>This feature has %s HGVS name%s - click the plus to show</dd>
      <dd class="HGVS_names"><div class="toggleable" style="font-weight:normal;%s">%s</div></dd>',
      $show ? 'open' : 'closed',
      $count, $s,
      $show ? '' : 'display:none',
      $html
    );
  } elsif ($count == 1){
    $html = qq{<dt>HGVS name</dt><dd>$html</dd>};  
  } else {
    $html = qq{<dt>HGVS name</dt><dd>None</dd>};
  }
  
  return $html;
}

1;
