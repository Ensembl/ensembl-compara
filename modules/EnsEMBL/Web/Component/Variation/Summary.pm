# $Id$

package EnsEMBL::Web::Component::Variation::Summary;

use strict;

use base qw(EnsEMBL::Web::Component::Variation);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(0);
}

sub failed {
  my ($self, $feature_slice) = @_;
  my @descs = @{$self->object->Obj->get_all_failed_descriptions};
  my $html;
  
  if ($feature_slice) {
    for (0..$#descs) {
      my $seq    = $feature_slice->seq;
         $seq    =~ s/.{60}/$&\n/g;
      $descs[$_] =~ s/reference allele/$& ($seq)/ if $descs[$_] =~ /match.+reference allele/ && $feature_slice;
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
  my $name    = $object->name;
  my $source  = $object->source;
  my $version = $object->source_version;
  my $url     = $object->source_url;
  my @links;
  
  # Date version
  if ($version =~ /^(20\d{2})(\d{2})/) {
    $version = " ($2/$1)";
  } elsif ($version) {
    $version = " $version";
  }
  
  if ($source eq 'dbSNP') {
    @links = ($hub->get_ExtURL_link($name, 'DBSNP', $name), $hub->get_ExtURL_link("$source$version", 'DBSNP_HOME', $name));
  } elsif ($source =~ /SGRP/) {
    @links = ($name, $hub->get_ExtURL_link("$source$version", 'SGRP', $name));
  } elsif ($source =~ /COSMIC/) {
    @links = ($hub->get_ExtURL_link($name, 'COSMIC_ID', $name), $hub->get_ExtURL_link("$source$version", 'COSMIC', $name));
  } elsif ($source =~ /HGMD/) {
    # HACK - should get its link properly somehow
    foreach (@{$hub->get_adaptor('get_VariationAnnotationAdaptor', 'variation')->fetch_all_by_Variation($object->Obj)}) {
      next unless $_->source_name =~ /HGMD/;
      @links = ($hub->get_ExtURL_link($name, 'HGMD', { ID => $_->associated_gene, ACC => $name }), $hub->get_ExtURL_link($_->source_name . $version, 'HGMD-PUBLIC', ''));
      last;
    }
	} elsif ($source =~ /LSDB/) {
    @links = ($name, $hub->get_ExtURL_link($source . ($version ? " ($version)" : ''), $source, $name));
  } else {
    @links = ($name, $url ? qq{<a href="$url">$source$version</a>} : "$source $version");
  }
  
  return sprintf('
    <dl class="summary">
      <dt>Variation class</dt> 
      <dd>%s (%s source %s - %s)</dd>
    </dl>',
    uc $object->vari_class, @links, $object->source_description
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
        <dl class="summary">
          <dt>Co-located </dt>
          <dd>with $html</dd>
        </dl>
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

    $html .= "<b>$db</b> " . (join ', ', @urls) . '<br />';
  }

  $html ||= 'None currently in the database';
 
  return qq{
    <dl class="summary">
      <dt>Synonyms</dt>
      <dd>$html</dd>
    </dl>
  }; 
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
    
    $html = sprintf('
      <dt><a class="toggle closed" href="#variation_sets" rel="variation_sets" title="Click to toggle sets names">Present in</a></dt>
      <dd>This feature is present in %s sets - click the plus to show all sets</dd>
      <dd class="variation_sets"><div class="toggleable" style="display:none;font-weight:normal;">%s</div></dd>',
      $count_1000 ? sprintf('<b>1000 genomes</b> and <b>%s</b> other', $count - $count_1000) : "<b>$count</b>",
      sprintf('<ul><li>%s</li></ul>', join '</li><li>', @variation_sets)
    );
  }
  
  return qq{<dl class="summary">$html</dl>};
}

sub alleles {
  my ($self, $feature_slice) = @_;
  my $object   = $self->object;
  my $alleles  = $object->alleles;
  my $ancestor = $object->ancestor;
  my $html     = "<b>$alleles</b>";
     $html    .= sprintf ' (Ambiguity code: <strong>%s</strong>)', $alleles =~ /HGMD/ ? 'not available' : $object->Obj->ambig_code if lc $object->vari_class eq 'snp';

  # Check somatic mutation base matches reference
  if ($feature_slice) {
    my $sequence = $feature_slice->seq;
    my ($allele) = split /\//, $alleles;
    
    if ($allele =~ /^[ACGTN]+$/) {
      my $seq   = length $sequence == 1 ? 'base': 'sequence';
      $sequence =~ s/.{60}/$&<br\/>/g;
      $html    .= "<br /><em>Note</em>: The reference $seq for this mutation ($allele) does not match the Ensembl reference $seq ($sequence) at this location." if $sequence ne $allele;
    }
  }
  
  $html  = qq{<dl class="summary"><dt>Alleles</dt><dd>$html</dd></dl>};
  $html .= qq{<dl class="summary"><dt>Ancestral allele</dt><dd>$ancestor</dd></dl>} if $ancestor;
  
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
  
  if ($count > 1) {
    my $params = $hub->core_params;
    my @values;
    
    # create form
    my $form = $self->new_form({
      name   => 'select_loc',
      action => $hub->url({ vf => undef, v => $id, source => $object->source }), 
      method => 'get', 
      class  => 'nonstd check'
    });
    
    push @values, { value => 'null', name => 'None selected' }; # add default value
    
    # add values for each mapping
    foreach (sort { $mappings{$a}->{'Chr'} cmp $mappings{$b}->{'Chr'} || $mappings{$a}->{'start'} <=> $mappings{$b}->{'start'}} keys %mappings) {
      my $region = $mappings{$_}{'Chr'}; 
      my $start  = $mappings{$_}{'start'};
      my $end    = $mappings{$_}{'end'};
      my $str    = $mappings{$_}{'strand'};
      
      push @values, {
        value => $_,
        name  => sprintf('%s (%s strand)', ($start == $end ? "$region:$start" : "$region:$start-$end"), ($str > 0 ? 'forward' : 'reverse'))
      };
    }
    
    # add dropdown
    $form->add_element(
      type   => 'DropDown',
      select => 'select',
      name   => 'vf',
      values => \@values,
      value  => $vf,
    );
    
    # add submit
    $form->add_element(
      type  => 'Submit',
      value => 'Go',
    );
    
    # add hidden values for all other params
    foreach (grep defined $params->{$_}, keys %$params) {
      next if $_ eq 'vf' || $_ eq 'r'; # ignore vf and region as we want them to be overwritten
      
      $form->add_element(
        type  => 'Hidden',
        name  => $_,
        value => $params->{$_},
      );
    }
    
    $html = "This feature maps to $count genomic locations" . $form->render;                    # render to string
    $html =~ s/\<\/?(div|tr|th|td|table|tbody|fieldset)+.*?\>\n?//g;                            # strip off unwanted HTML layout tags from form
    $html =~ s/\<form.*?\>/$&.'<span style="font-weight: bold;">Selected location: <\/span>'/e; # insert text
  }    
  
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
        contigviewbottom => ($variation->is_somatic ? 'somatic_mutation_COSMIC=normal' : 'variation_feature_variation=normal') . ($variation->failed_description ? ',fail_all=normal' : '')
      })
    );
  }
  
  if ($count == 1) {
    $html .= "This feature maps to $location$location_link";
  } else {
    $html =~ s/<\/form>/$location_link<\/form>/;
  }
  
  return qq{<dl class="summary"><dt>Location</dt><dd>$html</dd></dl>};
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
    <dl class="summary">
      <dt>Validation status</dt>
      <dd>$stat</dd>
    </dl>
  };
}

sub hgvs {
  my $self          = shift;
  my $object        = $self->object;
  
  my $hgvs_urls = $object->get_hgvs_names_url;
  my $html = "";
  my $count = 0;
  # Loop over and format the URLs
  foreach my $allele (keys(%{$hgvs_urls})) {
    $html .= ($count ? "<br />" : "") . "<b>Variant allele $allele</b>" if (scalar(keys(%{$hgvs_urls})) > 1);
    $html .= join("<br />",@{$hgvs_urls->{$allele}});
    $count += scalar(@{$hgvs_urls->{$allele}});
  }
  
  # Wrap the html
  if ($count) {
    my $several = ($count > 1) ? 's' : '';
    $html = qq{
      <dt><a class="toggle closed" href="#HGVS_names" rel="HGVS_names" title="Click to toggle HGVS names">HGVS names</a></dt>
      <dd>This feature has $count HGVS name$several - click the plus to show</dd>
      <dd class="HGVS_names"><div class="toggleable" style="display:none;font-weight:normal;">$html</div></dd>
    };
  }
  else {
    $html = qq{<dt>HGVS names</dt><dd><h5>None</h5></dd>};
  }
  
  return qq{<dl class="summary">$html</dl>};
}

sub content {
  my $self               = shift;
  my $hub                = $self->hub;
  my $object             = $self->object;
  my $variation          = $object->Obj;
  my $vf                 = $hub->param('vf');
  my $variation_features = $variation->get_all_VariationFeatures;
  my ($feature_slice)    = map { $_->dbID == $vf ? $_->feature_Slice : () } @$variation_features; # get slice for variation feature
  my $html;
  
  $html .= $self->failed($feature_slice) if $variation->failed_description; ## First warn if variation has been failed
  $html .= $self->variation_class;
  $html .= $self->co_located($feature_slice) if $feature_slice;
  $html .= $self->synonyms;
  $html .= $self->variation_sets;
  $html .= $self->alleles;
  $html .= $self->location;
  $html .= $self->validation_status;
  $html .= $self->hgvs;
  
  return qq{<div class="summary_panel">$html</div>};
}

1;
