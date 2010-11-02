# $Id$

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
  my $self             = shift;
  my $hub              = $self->hub;
  my $consequence_type = $hub->param('sub_table');
  my $gene             = $self->configure($consequence_type, $hub->param('context') || 5000, $hub->get_imageconfig('genesnpview_transcript'));
  my @transcripts      = sort { $a->stable_id cmp $b->stable_id } @{$gene->get_all_transcripts};
  
  if ($consequence_type) {
    my $table_rows = $self->variation_table($consequence_type, \@transcripts);
    my $table      = $table_rows ? $self->make_table($table_rows, $consequence_type) : undef;
    return $self->render_content($table, $consequence_type);
  } else {
    my $table = $self->stats_table(\@transcripts); # no sub-table selected, just show stats
    return $self->render_content($table);
  }
}

sub make_table {
  my ($self, $table_rows, $consequence_type) = @_;
  
  my $columns = [
    { key => 'ID',         sort => 'html'                                                   },
    { key => 'chr' ,       sort => 'position', title => 'Chr: bp'                           },
    { key => 'Alleles',    sort => 'string',                              align => 'center' },
    { key => 'Ambiguity',  sort => 'string',                              align => 'center' },
    { key => 'class',      sort => 'string',   title => 'Class',          align => 'center' },
    { key => 'Source',     sort => 'string'                                                 },
    { key => 'status',     sort => 'string',   title => 'Validation',     align => 'center' },
    { key => 'snptype',    sort => 'string',   title => 'Type',                             },
    { key => 'aachange',   sort => 'string',   title => 'Amino Acid',     align => 'center' },
    { key => 'aacoord',    sort => 'position', title => 'AA co-ordinate', align => 'center' },
    { key => 'Transcript', sort => 'string'                                                 },
  ];
  
  return $self->new_table($columns, $table_rows, { data_table => 1, sorting => [ 'chr asc' ], exportable => 0, id => "${consequence_type}_table" });
}

sub render_content {
  my ($self, $table, $consequence_type) = @_;
  my $stable_id = $self->object->stable_id;
  my $html;
  
  if ($consequence_type) {
    my $label = $Bio::EnsEMBL::Variation::ConsequenceType::CONSEQUENCE_LABELS{$consequence_type} || 'All';
    
    $html = qq{
      <h2 style="float:left"><a href="#" class="toggle open" rel="$consequence_type">$label variants</a></h2>
      <span style="float:right;"><a href="#$self->{'id'}_top">[back to top]</a></span>
      <p class="invisible">.</p>
    };
  } else {
    $html = qq{<a id="$self->{'id'}_top"></a><h2>Summary of variations in $stable_id by consequence type</h2>};
  }
  
  $html .= sprintf '<div class="toggleable">%s</div>', $table->render;
  
  return $html;
}

sub stats_table {
  my ($self, $transcripts) = @_;
  
  my $columns = [
    { key => 'count', title => 'Number of variants', sort => 'position',      width => '20%', align => 'right'  },
    { key => 'view',  title => '',                   sort => 'none',          width => '5%',  align => 'center' },
    { key => 'type',  title => 'Type',               sort => 'position_html', width => '20%'                    },
    { key => 'desc',  title => 'Description',        sort => 'none',          width => '55%'                    },
  ];
  
  my %counts;
  my %total_counts;
  
  foreach my $tr (@$transcripts) {
    my $tr_stable_id = $tr->stable_id;
    my %tvs          = %{$tr->__data->{'transformed'}{'snps'} || {}};
    
    foreach my $vf_id (keys %tvs) {
      my $tv = $tvs{$vf_id};
      
      foreach my $con (@{$tv->consequence_type}) {
        my $key = "${tr_stable_id}_$vf_id";
        
        $counts{$con}{$key} = 1 if $con;
        $total_counts{$key} = 1;
      }
    }
  }
  
  my %ranks        = %Bio::EnsEMBL::Variation::ConsequenceType::CONSEQUENCE_TYPES;
  my %descriptions = %Bio::EnsEMBL::Variation::ConsequenceType::CONSEQUENCE_DESCRIPTIONS;
  my %labels       = %Bio::EnsEMBL::Variation::ConsequenceType::CONSEQUENCE_LABELS;
  my @rows;
  
  # ignore REGULATORY_REGION and INTERGENIC
  delete $descriptions{$_} for qw(REGULATORY_REGION INTERGENIC WITHIN_MATURE_miRNA);
  
  foreach my $con (keys %descriptions) {
    if (defined $counts{$con}) {
      my $url = $self->ajax_url . ";sub_table=$con;update_panel=1";
      
      my $view_html = qq{
        <a href="$url" class="ajax_add toggle closed" rel="$con">
          <span class="closed">Show</span><span class="open">Hide</span>
          <input type="hidden" class="url" value="$url" />
        </a>
      };
      
      push @rows, {
        type  => qq{<span class="hidden">$ranks{$con}</span>$labels{$con}},
        desc  => $descriptions{$con},
        count => scalar(keys %{$counts{$con}}),
        view  => $view_html
      };
    } else {
      push @rows, {
        type  => qq{<span class="hidden">$ranks{$con}</span>$labels{$con}},
        desc  => $descriptions{$con},
        count => 0,
        view  => '-'
      };
    }
  }
  
  # add the row for ALL variations
  my $url = $self->ajax_url . ';sub_table=ALL;update_panel=1';
  
  # create a hidden span to add so that ALL is always last in the table
  my $hidden_span = qq{<span class="hidden">-</span>};
  
  my $view_html = qq{
    <a href="$url" class="ajax_add toggle closed" rel="ALL">
      <span class="closed">Show</span><span class="open">Hide</span>
      <input type="hidden" class="url" value="$url" />
    </a>
  };
  
  my $total   = scalar keys %total_counts;
  my $warning = $total > 10000 ? qq{<span style="color:red;">(WARNING: page may not load for large genes!)</span>} : '';
  
  push @rows, {
    type  => $hidden_span . 'ALL',
    view  => $view_html,
    desc  => "All variations $warning",
    count => $hidden_span . $total,
  };
  
  return $self->new_table($columns, \@rows, { data_table => 'no_col_toggle', sorting => [ 'type asc' ], exportable => 0 });
}

sub variation_table {
  my ($self, $consequence_type, $transcripts, $slice) = @_;
  my $hub                 = $self->hub;
  my $selected_transcript = $hub->param('t');
  my @rows;
  
  # create some URLs - quicker than calling the url method for every variation
  my $base_url = $hub->url({
    type   => 'Variation',
    action => 'Sumary',
    vf     => undef,
    v      => undef,
    source => undef,
  });
  
  my $base_trans_url = $hub->url({
    type   => 'Transcript',
    action => 'Summary',
    t      => undef,
  });
  
  my $base_type_url = $hub->url({
    sub_table => undef,
    t         => $selected_transcript,
  });
  
  my %labels = %Bio::EnsEMBL::Variation::ConsequenceType::CONSEQUENCE_LABELS;
  
  foreach my $transcript (@$transcripts) {
    my $transcript_stable_id = $transcript->stable_id;
    
    next if $selected_transcript && $transcript_stable_id ne $selected_transcript;
    
    my %snps = %{$transcript->__data->{'transformed'}{'snps'} || {}};
   
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
      
      if ($consequence_type eq 'ALL') {
        $skip = 0;
      } elsif ($transcript_variation) {
        foreach my $con (@{$transcript_variation->consequence_type}) {
          if ($con eq $consequence_type) {
            $skip = 0;
            last;
          }
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
        
        my $url       = "$base_url;v=$variation_name;vf=$raw_id;source=$source";
        my $trans_url = "$base_trans_url;t=$transcript_stable_id";
        
        # break up allele string if too long
        my $as = $snp->allele_string;
        $as    =~ s/(.{20})/$1\n/g;
        
        # sort out consequence type string
        my $type = join ', ', map $labels{$_}, @{$transcript_variation->consequence_type || []};
        $type  ||= '-';
        
        my $row = {
          ID         => qq{<a href="$url">$variation_name</a>},
          class      => $var_class eq 'in-del' ? ($start > $end ? 'insertion' : 'deletion') : $var_class,
          Alleles    => qq{<span style="font-family:Courier New,Courier,monospace;">$as</span>},
          Ambiguity  => $snp->ambig_code,
          status     => (join(', ',  @$validation) || '-'),
          chr        => "$chr:$start" . ($start == $end ? '' : "-$end"),
          Source     => $source,
          snptype    => $type,
          Transcript => qq{<a href="$trans_url">$transcript_stable_id</a>},
          aachange   => $aachange,
          aacoord    => $aacoord,
        };
        
        # add HGVS if LRG
        $row->{'HGVS'} = $self->get_hgvs($snp, $transcript->Obj, $slice) || '-' if $transcript_stable_id =~ /^LRG/;
        
        push @rows, $row;
      }
    }
  }

  return \@rows;
}

sub configure {
  my ($self, $consequence_type, $context, $master_config) = @_;
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
  $object->store_TransformedSNPS;        ## Stores in $transcript_object->__data->{'transformed'}{'snps'}
  
  if ($consequence_type) {
    my $transcript_slice = $object->__data->{'slices'}{'transcripts'}[1];
    my ($count_snps, $snps, $context_count) = $object->getVariationsOnSlice($transcript_slice, $object->__data->{'slices'}{'transcripts'}[2]);
    
    ## Map SNPs for the last SNP display  
    my @snps2 = map {[ 
      $_->[2], $transcript_slice->seq_region_name,
      $transcript_slice->strand > 0 ?
        ( $transcript_slice->start + $_->[2]->start - 1, $transcript_slice->start + $_->[2]->end   - 1 ) :
        ( $transcript_slice->end   - $_->[2]->end   + 1, $transcript_slice->end   - $_->[2]->start + 1 )
    ]} @$snps;
  
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
  my %pep_hgvs  = %{$vf->get_all_hgvs_notations($trans, 'p')};

  # group by allele
  my %by_allele;
  
  # get genomic ones if given a slice
  if ($slice) {
    my %genomic_hgvs = %{$vf->get_all_hgvs_notations($slice, 'g', $vf->seq_region_name)};
    push @{$by_allele{$_}}, $genomic_hgvs{$_} for keys %genomic_hgvs;
  }

  push @{$by_allele{$_}}, $cdna_hgvs{$_} for keys %cdna_hgvs;
  push @{$by_allele{$_}}, $pep_hgvs{$_}  for keys %pep_hgvs;
  
  my $allele_count = scalar keys %by_allele;
  my @temp;
  
  foreach my $a (keys %by_allele) {
    foreach my $h (@{$by_allele{$a}}) {
      $h =~ s/(.{35})/$1\n/g if length $h > 50; # wordwrap
      push @temp, $h . ($allele_count > 1 ? " <b>($a)</b>" : '');
    }
  }

  return join ', ', @temp;
}

1;
