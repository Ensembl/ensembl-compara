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
  my $summary; #            = $self->variation_class;
    $summary            .= $self->variation_source;
    $summary            .= $self->alleles($feature_slice);
    $summary            .= $self->location;
    $summary            .= $self->validation_status;
    $summary            .= $self->co_located($feature_slice) if $feature_slice;
    $summary            .= $self->variation_sets;
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

sub variation_class {
  my $self    = shift;
  my $hub     = $self->hub;
  my $object  = $self->object;
  return sprintf('
    <dt>Class</dt> 
    <dd>%s</dd>',
    uc $object->vari_class
  );
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
  
  # Date version
  if ($version =~ /^(20\d{2})(\d{2})/) {
    $version = " ($2/$1)";
  } elsif ($version) {
    $version = " $version";
  }
  
  if ($source eq 'dbSNP') {
    $source_link = $hub->get_ExtURL_link("$source$version", 'DBSNP', $name);
  } elsif ($source =~ /SGRP/) {
    $source_link = $hub->get_ExtURL_link("$source$version", 'SGRP', $name);
  } elsif ($source =~ /COSMIC/) {
    $source_link = $hub->get_ExtURL_link("$source$version", 'COSMIC', $name);
  } elsif ($source =~ /HGMD/) {
    # HACK - should get its link properly somehow
    foreach (@{$hub->get_adaptor('get_VariationAnnotationAdaptor', 'variation')->fetch_all_by_Variation($object->Obj)}) {
      next unless $_->source_name =~ /HGMD/;
      $source_link = $hub->get_ExtURL_link($_->source_name . $version, 'HGMD-PUBLIC', '');
      last;
    }
  } elsif ($source =~ /LSDB/) {
    $source_link = $hub->get_ExtURL_link($source . ($version ? " ($version)" : ''), $source, $name);
  } else {
    $source_link = $url ? qq{<a href="$url">$source$version</a>} : "$source $version";
  }
 
  ## parse description for links
  my $description = $object->source_description;
  $description =~ s/(\w+) \[(http:\/\/[\w\.\/]+)\]/<a href="$2">$1<\/a>/; 

  warn ">>> URL $1 = $2";

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
  
  my $html = '<ul>';
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
    $html .= "<li><strong>$db</strong> " . (join ', ', @urls) . '</li>';
  }

  $html .= '</ul>';
 
  # Large text display
  if ($count) { # Collapsed div display 
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
    return qq{
      <dt>Synonyms</dt>
      <dd>None currently in the database</dd>
    }; 
  }
}

sub variation_sets {
  my $self           = shift;
  my @variation_sets = sort @{$self->object->get_variation_set_string};
  my $count          = scalar @variation_sets; 
  
  return unless $count;
  
  my $html;
  
  # Large text display
  if ($count < 6) {
    $html = sprintf '<dt>Present in</dt><dd>%s</dd>', join ',', @variation_sets
  } else { # Collapsed div display 
    my $count_1000 = scalar grep { /1000 genomes/i } @variation_sets;
    my $show       = $self->hub->get_cookies('toggle_variation_sets') eq 'open';
    
    $html = sprintf('
      <dt><a class="toggle %s set_cookie" href="#" rel="variation_sets" title="Click to toggle sets names">Present in</a></dt>
      <dd>This feature is present in %s sets - click the plus to show all sets</dd>
      <dd class="variation_sets"><div class="toggleable" style="font-weight:normal;%s">%s</div></dd>',
      $show ? 'open' : 'closed',
      $count_1000 ? sprintf('<b>1000 genomes</b> and <b>%s</b> other', $count - $count_1000) : "<b>$count</b>",
      $show ? '' : 'display:none',
      sprintf('<ul><li>%s</li></ul>', join '</li><li>', @variation_sets)
    );
  }
  
  return $html;
}

sub alleles {
  my ($self, $feature_slice) = @_;
  my $object   = $self->object;

  my @alleles  = split('/', $object->alleles);
  my $ref_allele = shift @alleles;
  my $alt_string = 'Alternative';
  $alt_string .= 's' if (scalar @alleles > 1);
  $alt_string .= ': <strong>'.join(', ', @alleles).'</strong>';
  my $ancestor = $object->ancestor;
  my $ambiguity;
  if (lc $object->vari_class eq 'snp') {
    $ambiguity = $object->alleles =~ /HGMD/ ? 'not available' : $object->Obj->ambig_code;
  }

  my $html      = sprintf 'Reference: <strong>%s</strong> | %s | Ancestral: <strong>%s</strong> | Ambiguity code: <strong>%s</strong>',
                  $ref_allele, $alt_string, $ancestor, $ambiguity;

 # my $html     = "<b>$alleles</b>";
 #    $html    .= sprintf ' (Ambiguity code: <strong>%s</strong>)', $alleles =~ /HGMD/ ? 'not available' : $object->Obj->ambig_code if lc $object->vari_class eq 'snp';

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
  
  $html  = qq{<dt>Alleles</dt><dd>$html</dd>};
  #$html .= qq{<dt>Ancestral allele</dt><dd>$ancestor</dd>} if $ancestor;
  
  return $html;
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
    my $region    = $mappings{$vf}{'Chr'}; 
    my $start     = $mappings{$vf}{'start'};
    my $end       = $mappings{$vf}{'end'};
       $location  = ($start == $end ? "$region:$start" : "$region:$start-$end") . ' (' . ($mappings{$vf}{'strand'} > 0 ? 'forward' : 'reverse') . ' strand)';
    
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
    foreach (sort { $mappings{$a}->{'Chr'} cmp $mappings{$b}{'Chr'} || $mappings{$a}{'start'} <=> $mappings{$b}{'start'}} keys %mappings) {
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
    $html = "This feature maps to $location$location_link";
  }
  
  return qq{<dt>Location</dt><dd>$html</dd>};
}

sub validation_status {
  my $self   = shift;
  my $hub    = $self->hub;
  my $object = $self->object;
  my $status = $object->status;
  my $stat;
  
  if (scalar @$status) {
    my $snp_name = $object->name;
    my (@status_list, $hapmap);

    foreach (@$status) {
      if ($_ eq 'hapmap') {
        $hapmap = '<b>HapMap variant</b>', $hub->get_ExtURL_link($snp_name, 'HAPMAP', $snp_name);
      } elsif ($_ ne 'failed') {
        push @status_list, $_ eq 'freq' ? 'frequency' : $_;
      }
    }

    $stat = join ', ', @status_list;
    
    if ($stat eq 'observed' || $stat eq 'non-polymorphic') {
      $stat = '<b>' . ucfirst $stat . '</b> ';
    } elsif ($stat) {
      $stat = "Proven by <b>$stat</b> ";
    }

    $stat .= $hapmap;
    $stat  = 'Undefined' unless $stat =~ /^\w/;
  } else {
    $stat = 'Unknown';
  }
  
  return qq{
    <dt>Validation status</dt>
    <dd>$stat</dd>
  };
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
  if ($count) {
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
  } else {
    $html = qq{<dt>HGVS names</dt><dd><h5>None</h5></dd>};
  }
  
  return $html;
}

1;
