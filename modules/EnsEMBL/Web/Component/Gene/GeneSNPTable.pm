package EnsEMBL::Web::Component::Gene::GeneSNPTable;

use strict;

use EnsEMBL::Web::Document::SpreadSheet;

use base qw(EnsEMBL::Web::Component::Gene);

sub _init {
  my $self = shift;
  $self->cacheable(1);
  $self->ajaxable(1);
}

sub caption {
  return;
}


sub content {
  my $self = shift;
  
  my $gene        = $self->configure_gene;
  my @transcripts = sort { $a->stable_id cmp $b->stable_id } @{$gene->get_all_transcripts};
  my %var_tables;
  
  foreach my $transcript (@transcripts) {
    my $tsid       = $transcript->stable_id;
    my $table_rows = $self->variation_table($transcript);    
    my $table      = new EnsEMBL::Web::Document::SpreadSheet([], [], { margin => '1em 0px', data_table => 1, sorting => [ 'chr asc' ] });

    $table->add_columns(
      { key => 'ID',        sort => 'html'                                                   },
      { key => 'snptype',   sort => 'string',   title => 'Type',                             },
      { key => 'chr' ,      sort => 'position', title => 'Chr: bp'                           },
      { key => 'Alleles',   sort => 'string',   align => 'center'                            },
      { key => 'Ambiguity', sort => 'string',   align => 'center'                            },
      #{ key => 'HGVS',      sort => 'string',   title => 'HGVS name(s)',   align => 'center' },
      { key => 'aachange',  sort => 'string',   title => 'Amino Acid',     align => 'center' },
      { key => 'aacoord',   sort => 'position', title => 'AA co-ordinate', align => 'center' },
      { key => 'class',     sort => 'string',   title => 'Class',          align => 'center' },
      { key => 'Source',    sort => 'string'                                                 },
      { key => 'status',    sort => 'string',   title => 'Validation',     align => 'center' }
   );
 
    if ($table_rows) {
      $table->add_rows(@$table_rows);
      $var_tables{$tsid} = $table->render;
    }
  }

  my $html;
  
  $html .= "<h2>Variations in $_:</h2>$var_tables{$_}" for keys %var_tables;
  $html .= $self->_info(
    'Configuring the display',
    q{<p>The <strong>'Configure this page'</strong> link in the menu on the left hand side of this page can be used to customise the exon context and types of SNPs displayed in both the tables above and the variation image.
    <br /> Please note the default 'Context' settings will probably filter out some intronic SNPs.</p><br />}
  );
  
  return $html;
}

sub variation_table {
  my ($self, $object) = @_;
  
  my %snps = %{$object->__data->{'transformed'}{'snps'}||[]};
 
  return unless %snps;
  
  my $gene_snps         = $object->__data->{'transformed'}{'gene_snps'} || [];
  my $tr_start          = $object->__data->{'transformed'}{'start'};
  my $tr_end            = $object->__data->{'transformed'}{'end'};
  my $extent            = $object->__data->{'transformed'}{'extent'};
  my $cdna_coding_start = $object->Obj->cdna_coding_start;
  my @rows;
  
  foreach (@$gene_snps) {
    my ($snp, $chr, $start, $end) = @$_;
    my $raw_id               = $snp->dbID;
    my $validation           = $snp->get_all_validation_states || [];
    my $variation_name       = $snp->variation_name;
    my $transcript_variation = $snps{$raw_id};
    #my @hgvs = @{$snp->get_all_hgvs_notations($object->param('hgvs') eq 'transcript' ? ($object->transcript, 'c') : ($object->gene, 'g'))};
    #s/ENS(...)?[TG]\d+\://g for @hgvs;
    #my $hgvs = join ", ", @hgvs;
    
    if ($transcript_variation && $end >= $tr_start - $extent && $start <= $tr_end + $extent) {
      my $url = $object->_url({ type => 'Variation', action => 'Summary', v => $variation_name, vf => $raw_id, source => $snp->source }); 
      
      my $row = {
        ID        => qq{<a href="$url">$variation_name</a>},
        class     => $snp->var_class eq 'in-del' ? ($start > $end ? 'insertion' : 'deletion') : $snp->var_class,
        Alleles   => $snp->allele_string,
        Ambiguity => $snp->ambig_code,
        #HGVS      => ($hgvs || '-'),
        status    => (join(', ',  @$validation) || '-'),
        chr       => "$chr:$start" . ($start == $end ? '' : "-$end"),
        Source    => (join ', ', @{$snp->get_all_sources||[]}) || '-',
        snptype   => (join ', ', @{$transcript_variation->consequence_type||[]}), $transcript_variation->translation_start ? (
          aachange => $transcript_variation->pep_allele_string,
          aacoord  => sprintf('%s (%s)', $transcript_variation->translation_start, (($transcript_variation->cdna_start - $cdna_coding_start) % 3 + 1)),
        ) : ( 
          aachange => '-',
          aacoord  => '-'
        )
      };

      push @rows, $row;
    }
  }

  return \@rows;
}

sub configure_gene {
  my $self = shift;
  
  my $object        = $self->object;
  my $context       = $object->param('context') || 100;
  my $extent        = $context eq 'FULL' ? 1000 : $context;
  my $master_config = $object->get_imageconfig( "genesnpview_transcript" );
  
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

  foreach my $trans_obj (@{$object->get_all_transcripts}) {
    $trans_obj->__data->{'transformed'}{'extent'}    = $extent;
    $trans_obj->__data->{'transformed'}{'gene_snps'} = \@snps2;
  }

  return $object;
}

1;


