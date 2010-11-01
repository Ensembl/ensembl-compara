package EnsEMBL::Web::Component::Gene::GeneSNPTable;

use strict;

use Bio::EnsEMBL::Variation::ConsequenceType;

use base qw(EnsEMBL::Web::Component::Gene);

sub _init {
  my $self = shift;
  $self->cacheable(1);
  $self->ajaxable(1);
}

sub content {
  my $self        = shift;
  my $hub         = $self->hub;
  my $gene        = $self->configure($hub->param('context') || 100, $hub->get_imageconfig('genesnpview_transcript'));
  
  my @transcripts = sort { $a->stable_id cmp $b->stable_id } @{$gene->get_all_transcripts};
  
  # no sub-table selected, just show stats
  if(!defined($hub->param('sub_table'))) {
    my $table = $self->stats_table(\@transcripts);
    
    return $self->render_content($table)
  }
  
  else {
    my $table_rows = $self->variation_table(\@transcripts);
    my $table      = $table_rows ? $self->make_table($table_rows) : undef;
    
    return $self->render_content($table);
  }
}

sub make_table {
  my ($self, $table_rows) = @_;
  
  my $columns = [
    { key => 'ID',        sort => 'html'                                                   },
    { key => 'chr' ,      sort => 'position', title => 'Chr: bp'                           },
    { key => 'Alleles',   sort => 'string',   align => 'center'                            },
    { key => 'Ambiguity', sort => 'string',   align => 'center'                            },
    #{ key => 'HGVS',      sort => 'string',   title => 'HGVS name(s)',   align => 'center' },
    { key => 'class',     sort => 'string',   title => 'Class',          align => 'center' },
    { key => 'Source',    sort => 'string'                                                 },
    { key => 'status',    sort => 'string',   title => 'Validation',     align => 'center' },
    { key => 'snptype',   sort => 'string',   title => 'Type',                             },
    { key => 'aachange',  sort => 'string',   title => 'Amino Acid',     align => 'center' },
    { key => 'aacoord',   sort => 'position', title => 'AA co-ordinate', align => 'center' },
    { key => 'Transcript', sort => 'string'                                                },
  ];
  
  return $self->new_table($columns, $table_rows, { data_table => 1, sorting => [ 'chr asc' ], exportable => 0 });
}

sub render_content {
  my ($self, $tables) = @_;
  
  my $html;
  my $hub = $self->hub;
  
  my $stable_id = $self->object->stable_id;
  
  my $sub_table = $hub->param('sub_table');
  
  if(!defined($sub_table)) {
    $html .= qq{<a name="top"></a><h2>Summary of variations in $stable_id by consequence type</h2>};
  }
  
  else {
    my %labels = %Bio::EnsEMBL::Variation::ConsequenceType::CONSEQUENCE_LABELS;
    
    $html .= qq{
      <table style="width:100%;margin:0px;padding:0px;">
        <tr>
          <td>
            <h2><a href="#" class="toggle" rel="$sub_table">$labels{$sub_table} variants</a></h2>
          </td>
          <td style="vertical-align:middle;">
            <span style="float:right;"><a href="#top">[back to top]</a></span>
          </td>
        </tr>
      </table>
    };
  }
  
  $html .= $tables->render;
  
  #$html .= $self->_info(
  #  'Configuring the display',
  #  q{<p>The <strong>'Configure this page'</strong> link in the menu on the left hand side of this page can be used to customise the exon context and types of SNPs displayed in both the tables above and the variation image.
  #  <br /> Please note the default 'Context' settings will probably filter out some intronic SNPs.</p><br />}
  #) unless $sub_table;
  
  return $html;
}


sub stats_table {
  my ($self, $transcripts) = @_;
  my $hub = $self->hub;
  
  my $columns = [
    { key => 'count', title => 'Number of variants', sort => 'position', align => 'right'},
    { key => 'view', title => '', sort => 'position', width => '5%', align => 'center', sort => 'none'},
    { key => 'type', title => 'Type', sort => 'position_html'},
    { key => 'desc', title => 'Description', sort => 'none'},
  ];
  
  my %counts;
  my %total_counts;
  
  foreach my $tr(@$transcripts) {
    my $tr_stable_id = $tr->stable_id;
    
    my %tvs = %{$tr->__data->{'transformed'}{'snps'}||{}};
    
    foreach my $vf_id(keys %tvs) {
      my $tv = $tvs{$vf_id};
      
      foreach my $con(@{$tv->consequence_type}) {
        my $key = $tr_stable_id.'_'.$vf_id;
        
        $counts{$con}{$key} = 1 if defined($con);
        $total_counts{$key} = 1;
      }
    }
  }
  
  my @rows;
  my %ranks = %Bio::EnsEMBL::Variation::ConsequenceType::CONSEQUENCE_TYPES;
  my %descriptions = %Bio::EnsEMBL::Variation::ConsequenceType::CONSEQUENCE_DESCRIPTIONS;
  my %labels = %Bio::EnsEMBL::Variation::ConsequenceType::CONSEQUENCE_LABELS;
  
  # ignore REGULATORY_REGION and INTERGENIC
  delete $descriptions{'REGULATORY_REGION'};
  delete $descriptions{'INTERGENIC'};
  delete $descriptions{'WITHIN_MATURE_miRNA'};
  
  foreach my $con(keys %descriptions) {
    if(defined($counts{$con})) {
      my $url = $self->ajax_url . ";sub_table=$con;update_panel=1";
      
      my $onclick_a = qq{document.getElementById("$con\_hide").style.display="";document.getElementById("$con\_show").style.display="none"};
      my $onclick_b = qq{document.getElementById("$con\_hide").style.display="none";document.getElementById("$con\_show").style.display=""};
      
      my $view_html = qq{
        <span id="$con\_show">
          <a href="$url" class="ajax_add" rel="$con" onclick='$onclick_a'>
            View
            <input type="hidden" class="url" value="$url" />
          </a>
        </span>
        <span id="$con\_hide" style="display:none">
          <a href="#" class="toggle" rel="$con" onclick='$onclick_b'>Hide</a>
        </span>
      };
      
      push @rows, {
        type => qq{<span class="hidden">$ranks{$con}</span>$labels{$con}},
        desc => $descriptions{$con},
        count => (scalar keys %{$counts{$con}}),
        view => $view_html
      };
    }
    
    else {
      push @rows, {
        type => qq{<span class="hidden">$ranks{$con}</span>$labels{$con}},
        desc => $descriptions{$con},
        count => 0,
        view => "-"
      };
    }
  }
  
  # add the row for ALL variations
  my $url = $self->ajax_url . ';sub_table=ALL;update_panel=1';
  
  # create a hidden span to add so that ALL is always last in the table
  my $hidden_span = qq{<span class="hidden">-</span>};
  
  my $onclick_a = qq{document.getElementById("ALL_hide").style.display="";document.getElementById("ALL_show").style.display="none";};
  my $onclick_b = qq{document.getElementById("ALL_hide").style.display="none";document.getElementById("ALL_show").style.display="";};
  
  my $view_html = qq{
    <span id="ALL\_show">
      <a href="$url" class="ajax_add" rel="ALL" onclick='$onclick_a'>
        View
        <input type="hidden" class="url" value="$url" />
      </a>
    </span>
    <span id="ALL_hide" style="display:none">
      <a href="#" class="toggle" rel="ALL" onclick='$onclick_b'>Hide</a>
    </span>
  };
  
  my $total = scalar keys %total_counts;
  
  my $warning = ($total > 10000 ? qq{<span style='color:red;'>(WARNING: page may not load for large genes!)</span>} : "");
  
  push @rows, {
    type => $hidden_span.'ALL',
    view => $view_html,
    desc => qq{All variations $warning},
    count => $hidden_span.$total,
  };
  
  return $self->new_table($columns, \@rows, { data_table => 1, sorting => [ 'type asc'], exportable => 0 });
}


sub variation_table {
  my ($self, $transcripts, $slice) = @_;
  
  my @rows;
  
  my $hub = $self->hub;
  
  my $selected_type = $hub->param('sub_table');
  my $selected_transcript = $hub->param('t');
  
  # create some URLs - quicker than calling the url method for every variation
  my $base_url = $hub->url({
    type   => 'Variation',
    action => 'Sumary',
    vf     => undef,
    v      => undef,
    source => undef,
  });
  
    
  my $base_trans_url = $hub->url({
    type => 'Transcript',
    action => 'Summary',
    t => undef,
  });
  
  my $base_type_url = $hub->url({
    sub_table => undef,
    t => $selected_transcript,
  });
  
  my %labels = %Bio::EnsEMBL::Variation::ConsequenceType::CONSEQUENCE_LABELS;
  
  foreach my $transcript(@$transcripts) {
    my $transcript_stable_id = $transcript->stable_id;
    
    if(defined($selected_transcript)) {
      next unless $transcript_stable_id eq $selected_transcript;
    }
    
    my %snps = %{$transcript->__data->{'transformed'}{'snps'}||{}};
   
    return unless %snps;
    
    my $gene_snps         = $transcript->__data->{'transformed'}{'gene_snps'} || [];
    my $tr_start          = $transcript->__data->{'transformed'}{'start'};
    my $tr_end            = $transcript->__data->{'transformed'}{'end'};
    my $extent            = $transcript->__data->{'transformed'}{'extent'};
    my $cdna_coding_start = $transcript->Obj->cdna_coding_start;
    my $gene              = $transcript->gene;
    
    foreach (@$gene_snps) {      
      my ($snp, $chr, $start, $end) = @$_;
      my $raw_id               = $snp->dbID;
      my $transcript_variation = $snps{$raw_id};
      
      my $skip = 1;
      if($selected_type eq 'ALL') {
        $skip = 0;
      }
      elsif($transcript_variation) {
        foreach my $con(@{$transcript_variation->consequence_type}) {
          $skip = 0 if $con eq $selected_type;
        }
      }
      next if $skip;
      
      if ($transcript_variation && $end >= $tr_start - $extent && $start <= $tr_end + $extent) {
        my $validation        = $snp->get_all_validation_states || [];
        my $variation_name    = $snp->variation_name;
        my $var_class         = $snp->var_class;
        my $translation_start = $transcript_variation->translation_start;
        my $source            = $snp->source;
        
        # store the transcript variation so that HGVS doesn't try and calculate it again
        $snp->{'transcriptVariations'} = [$transcript_variation];
        
        my ($aachange, $aacoord) = $translation_start ? 
          ($transcript_variation->pep_allele_string, sprintf('%s (%s)', $transcript_variation->translation_start, (($transcript_variation->cdna_start - $cdna_coding_start) % 3 + 1))) : 
          ('-', '-');
        
        my $url = $base_url.';v='.$variation_name.';vf='.$raw_id.';source='.$source;
        my $trans_url = $base_trans_url.';t='.$transcript_stable_id;
        
        # break up allele string if too long
        my $as = $snp->allele_string;
        $as =~ s/(.{20})/$1\n/g;
        
        # sort out consequence type string
        my $type;
        $type .= "$labels{$_}, " foreach @{$transcript_variation->consequence_type || []};
        $type =~ s/\, $//g;
        $type ||= '-';
        
        my $row = {
          ID        => qq{<a href="$url">$variation_name</a>},
          class     => $var_class eq 'in-del' ? ($start > $end ? 'insertion' : 'deletion') : $var_class,
          Alleles   => qq{<span style="font-family:Courier New,Courier,monospace;">$as</span>},
          Ambiguity => $snp->ambig_code,
          status    => (join(', ',  @$validation) || '-'),
          chr       => "$chr:$start" . ($start == $end ? '' : "-$end"),
          Source    => $source, #(join ', ', @{$snp->get_all_sources||[]}) || '-',
          snptype   => $type,
          Transcript => '<a href="'.$trans_url.'">'.$transcript_stable_id.'</a>',
          aachange  => $aachange,
          aacoord   => $aacoord,
          '_raw_id' => $raw_id
        };
        
        # add HGVS if LRG
        if($transcript_stable_id =~ /^LRG/) {
          $row->{'HGVS'} = $self->get_hgvs($snp, $transcript->Obj, $slice) || '-';
        }
        
        push @rows, $row;
      }
    }
  }

  return \@rows;
}

sub configure {
  my ($self, $context, $master_config) = @_;
  
  my $hub = $self->hub;
  
  my $object = $self->object;
  my $extent = $context eq 'FULL' ? 1000 : $context;
  
  $master_config->set_parameters({
    image_width     => 800,
    container_width => 100,
    slice_number    => '1|1',
    context         => $context
  });

  $object->get_gene_slices(
    $master_config,
    [ 'context',     'normal', '100%'  ],
    [ 'gene',        'normal', '33%'   ],
    [ 'transcripts', 'munged', $extent ]
  );
  
  $object->store_TransformedTranscripts; ## Stores in $transcript_object->__data->{'transformed'}{'exons'|'coding_start'|'coding_end'}
  $object->store_TransformedSNPS();      ## Stores in $transcript_object->__data->{'transformed'}{'snps'}
  
  if(defined($hub->param('sub_table'))) {
    my $transcript_slice = $object->__data->{'slices'}{'transcripts'}[1];
    my ($count_snps, $snps, $context_count) = $object->getVariationsOnSlice($transcript_slice, $object->__data->{'slices'}{'transcripts'}[2]);
    
    ## Map SNPs for the last SNP display  
    my @snps2 = map {
      [ 
        $_->[2], $transcript_slice->seq_region_name,
        $transcript_slice->strand > 0 ?
          ( $transcript_slice->start + $_->[2]->start - 1, $transcript_slice->start + $_->[2]->end   - 1 ) :
          ( $transcript_slice->end   - $_->[2]->end   + 1, $transcript_slice->end   - $_->[2]->start + 1 )
      ]
    } @$snps;
  
    foreach (@{$object->get_all_transcripts}) {
      $_->__data->{'transformed'}{'extent'}    = $extent;
      $_->__data->{'transformed'}{'gene_snps'} = \@snps2;
    }
  }

  return $object;
}


sub get_hgvs {
  my ($self, $vf, $trans, $slice) = @_;
  
  my %cdna_hgvs = %{$vf->get_all_hgvs_notations($trans, 'c')};
  my %pep_hgvs = %{$vf->get_all_hgvs_notations($trans, 'p')};

  # group by allele
  my %by_allele;
  
  # get genomic ones if given a slice
  if(defined($slice)) {
    my %genomic_hgvs = %{$vf->get_all_hgvs_notations($slice, 'g', $vf->seq_region_name)};
    push @{$by_allele{$_}}, $genomic_hgvs{$_} foreach keys %genomic_hgvs;
  }

  push @{$by_allele{$_}}, $cdna_hgvs{$_} foreach keys %cdna_hgvs;
  push @{$by_allele{$_}}, $pep_hgvs{$_} foreach keys %pep_hgvs;
  
  my $allele_count = scalar keys %by_allele;

  my @temp = ();
  foreach my $a(keys %by_allele) {
    foreach my $h(@{$by_allele{$a}}) {
      $h =~ s/(.{35})/$1\n/g if length($h) > 50; #wordwrap
      push @temp, $h.($allele_count > 1 ? " <b>($a)</b>" : "");
    }
  }

  return join ", ", @temp;
}

1;
