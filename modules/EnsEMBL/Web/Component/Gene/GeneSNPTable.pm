package EnsEMBL::Web::Component::Gene::GeneSNPTable;

use strict;

use EnsEMBL::Web::Document::SpreadSheet;

use base qw(EnsEMBL::Web::Component::Gene);

sub _init {
  my $self = shift;
  $self->cacheable(1);
  $self->ajaxable(1);
}

sub content {
  my $self        = shift;
  my $object      = $self->object;
  my $gene        = $self->configure($object->param('context') || 100, $object->get_imageconfig('genesnpview_transcript'));
  my @transcripts = sort { $a->stable_id cmp $b->stable_id } @{$gene->get_all_transcripts};
  my $tables      = {};
  
  my $table_rows = $self->variation_table(\@transcripts);
  
  my $table = $self->make_table($table_rows) if $table_rows;
  
  return $self->render_content($table);
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
    { key => 'Transcript', sort => 'string'},
  ];
  
  return new EnsEMBL::Web::Document::SpreadSheet($columns, $table_rows, { data_table => 1, sorting => [ 'chr asc' ] });
}

sub render_content {
  my ($self, $tables) = @_;
  
  my $html;
  
  $html .= '<h2>Variations in '.$self->object->stable_id.'</h2>'.$tables->render;
  #$html .= sprintf '<h2>Variations in %s:</h2>%s', $_, $tables->{$_}->render for keys %$tables;
  $html .= $self->_info(
    'Configuring the display',
    q{<p>The <strong>'Configure this page'</strong> link in the menu on the left hand side of this page can be used to customise the exon context and types of SNPs displayed in both the tables above and the variation image.
    <br /> Please note the default 'Context' settings will probably filter out some intronic SNPs.</p><br />}
  );
  
  return $html;
}

sub variation_table {
  my ($self, $transcripts, $slice) = @_;
  
  my @rows;
  
  foreach my $transcript(@$transcripts) {  
    my %snps = %{$transcript->__data->{'transformed'}{'snps'}||{}};
   
    return unless %snps;
    
    my $object            = $self->object;
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
      
      if ($transcript_variation && $end >= $tr_start - $extent && $start <= $tr_end + $extent) {
        my $validation        = $snp->get_all_validation_states || [];
        my $variation_name    = $snp->variation_name;
        my $var_class         = $snp->var_class;
        my $translation_start = $transcript_variation->translation_start;
        
        my ($aachange, $aacoord) = $translation_start ? 
          ($transcript_variation->pep_allele_string, sprintf('%s (%s)', $transcript_variation->translation_start, (($transcript_variation->cdna_start - $cdna_coding_start) % 3 + 1))) : 
          ('-', '-');
        
        my $url = $object->_url({
          type   => 'Variation',
          action => 'Summary',
          v      => $variation_name,
          vf     => $raw_id,
          source => $snp->source 
        });
        
        my $trans_url = $object->_url({
          type => 'Transcript',
          action => 'Summary',
          t => $transcript->stable_id,
        });
        
        # break up allele string if too long
        my $as = $snp->allele_string;
        $as =~ s/(.{30})/$1\n/g;
        
        my $row = {
          ID        => qq{<a href="$url">$variation_name</a>},
          class     => $var_class eq 'in-del' ? ($start > $end ? 'insertion' : 'deletion') : $var_class,
          Alleles   => qq{<span style="font-family:Courier New,Courier,monospace;">$as</span>},
          Ambiguity => $snp->ambig_code,
          #HGVS      => $self->get_hgvs($snp, $transcript->Obj, $gene) || '-',
          status    => (join(', ',  @$validation) || '-'),
          chr       => "$chr:$start" . ($start == $end ? '' : "-$end"),
          Source    => (join ', ', @{$snp->get_all_sources||[]}) || '-',
          snptype   => (join ', ', @{$transcript_variation->consequence_type||[]}),
          Transcript => '<a href="'.$trans_url.'">'.$transcript->stable_id.'</a>',
          aachange  => $aachange,
          aacoord   => $aacoord,
          '_raw_id' => $raw_id
        };
        
        # add HGVS if LRG
        if($transcript->stable_id =~ /^LRG/) {
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

  my $transcript_slice = $object->__data->{'slices'}{'transcripts'}[1];
  my ($count_snps, $snps, $context_count) = $object->getVariationsOnSlice($transcript_slice, $object->__data->{'slices'}{'transcripts'}[2]);
  
  $object->store_TransformedTranscripts; ## Stores in $transcript_object->__data->{'transformed'}{'exons'|'coding_start'|'coding_end'}
  $object->store_TransformedSNPS;        ## Stores in $transcript_object->__data->{'transformed'}{'snps'}

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
