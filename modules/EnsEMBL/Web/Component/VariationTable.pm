package EnsEMBL::Web::Component::VariationTable;

use strict;
use Bio::EnsEMBL::Variation::Utils::Constants;

use base qw(EnsEMBL::Web::Component);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(1);
}

sub content {
  my $self = shift;
  my $hub = $self->hub;
  my $object_type = $self->hub->type;
  my $consequence_type = $hub->param('sub_table');
  my $icontext = $hub->param('context') || 100;
  my $gene_object = $self->configure($icontext, $consequence_type);
  my ($count, $msg, $html);

  my @transcripts      = sort { $a->stable_id cmp $b->stable_id } @{$gene_object->get_all_transcripts};

  if ($object_type eq 'Transcript'){
    my @temp;
    foreach (@transcripts){ 
      push (@temp, $_) if $_->stable_id eq $hub->param('t');
    }
    @transcripts = @temp;
  }
 
  $count += scalar @{$_->__data->{'transformed'}{'gene_snps'}} for @transcripts;

  if ($icontext) {
    if ($icontext eq 'FULL') {
      $msg = "The <b>full</b> intronic sequence around this $object_type is used.";
    } else {
      $msg = "Currently <b>$icontext"."bp</b> of intronic sequence is included either side of the exons.";
    }

    $msg .= '<br />';
  }

  if ($consequence_type || $count < 25) {
    $consequence_type ||= 'ALL';

    my $table_rows = $self->variation_table($consequence_type, \@transcripts);
    my $table      = $table_rows ? $self->make_table($table_rows, $consequence_type) : undef;

    $html = $self->render_content($table, $consequence_type);
  } else {
    $html  = $self->_hint('snp_table', 'Configuring the page', qq{<p>${msg}To extend or reduce the intronic sequence, use the "<strong>Configure this page - Intron Context</strong>" link on the left.</p>});
    $html .= $self->render_content($self->stats_table(\@transcripts, $gene_object)); # no sub-table selected, just show stats
  }
  
  return $html;
}

sub make_table {
  my ($self, $table_rows, $consequence_type) = @_;
  my $hub      = $self->hub;
  my $glossary = new EnsEMBL::Web::DBSQL::WebsiteAdaptor($hub)->fetch_glossary_text_lookup;

  my $columns = [
    { key => 'ID',       sort => 'html'                                                                                         },
    { key => 'chr' ,     sort => 'position', title => 'Chr: bp'                                                                 },
    { key => 'Alleles',  sort => 'string',                          align => 'center'                                           },
    { key => 'class',    sort => 'string',   title => 'Class',      align => 'center'                                           },
    { key => 'Source',   sort => 'string'                                                                                       },
    { key => 'status',   sort => 'string',   title => 'Validation', align => 'center', help => $glossary->{'Validation status'} },
    { key => 'snptype',  sort => 'string',   title => 'Type',                                                                   },
    { key => 'aachange', sort => 'string',   title => 'Amino Acid', align => 'center'                                           },
    { key => 'aacoord',  sort => 'position', title => 'AA coord',   align => 'center'                                           },
  ];

  # HGVS
  splice @$columns, 3, 0, { key => 'HGVS', sort => 'string', title => 'HGVS name(s)', align => 'center', export_options => { split_newline => 2 } } if $hub->param('hgvs') eq 'on';

  # add GMAF, SIFT and PolyPhen for human
  if ($hub->species eq 'Homo_sapiens') {
    push @$columns, (
      { key => 'sift',     sort => 'position_html', title => 'SIFT',     align => 'center', help => $glossary->{'SIFT'}     },
      { key => 'polyphen', sort => 'position_html', title => 'PolyPhen', align => 'center', help => $glossary->{'PolyPhen'} },
    );

    splice @$columns, 3, 0, { key => 'gmaf', sort => 'numeric', title => 'Frequency', align => 'center' };
  }
 
  if ($self->hub->type ne 'Transcript'){
   push @$columns, { key => 'Transcript', sort => 'string' };
  }

  return $self->new_table($columns, $table_rows, { data_table => 1, sorting => [ 'chr asc' ], exportable => 1, id => "${consequence_type}_table" });
}

sub render_content {
  my ($self, $table, $consequence_type) = @_;
  my $stable_id = $self->object->stable_id;
  my $html;

  if ($consequence_type) {
    $html = $self->toggleable_table("$consequence_type variants", $consequence_type, $table, 1, qq{<span style="float:right"><a href="#$self->{'id'}_top">[back to top]</a></span>});
  } else {
    $html = qq{<a id="$self->{'id'}_top"></a><h2>Summary of variations in $stable_id by consequence type</h2>} . $table->render;
  }
  
  return $html;
}

sub stats_table {
  my ($self, $transcripts, $gene_object) = @_;
  

  my $hub         = $self->hub;
  my $cons_format = $hub->param('consequence_format');
  
  my $columns = [
    { key => 'count', title => 'Number of variants', sort => 'numeric_hidden', width => '20%', align => 'right'  },   
    { key => 'view',  title => '',                   sort => 'none',           width => '5%',  align => 'center' },
    { key => 'type',  title => 'Type',               sort => 'numeric_hidden', width => '20%'                    },   
    { key => 'desc',  title => 'Description',        sort => 'none',           width => '55%'                    },
  ];
  
  my (%counts, %total_counts, %ranks, %descriptions, %labels);
  my $total_counts;
  
  my @all_cons = grep $_->feature_class =~ /transcript/i, values %Bio::EnsEMBL::Variation::Utils::Constants::OVERLAP_CONSEQUENCES;
  
  foreach my $con(@all_cons) {
    next if $con->SO_accession =~ /x/i;
    
    my $term = $self->select_consequence_term($con, $cons_format);
    
    if ($cons_format eq 'so') {
      $labels{$term}       = $con->label;
      $descriptions{$term} = $con->description.' <span class="small">('.$hub->get_ExtURL_link($con->SO_accession, 'SEQUENCE_ONTOLOGY', $con->SO_accession).')</span' unless $descriptions{$term};
    } else {
      $labels{$term}       = uc($con->display_term);
      $descriptions{$term} = '-';
    }
    
    $ranks{$term} = $con->rank if $con->rank < $ranks{$term} || !defined($ranks{$term});
  }

  if (!exists($gene_object->__data->{'conscounts'})) {
# Generate the data the hard way - from all the vfs and tvs
    my %counts_hash;
    my %total_counts_hash;

    foreach my $tr (@$transcripts) { 
      my $tr_stable_id = $tr->stable_id;
      my $tvs          = $tr->__data->{'transformed'}{'snps'} || {};
      my $gene_snps    = $tr->__data->{'transformed'}{'gene_snps'};
      my $tr_start     = $tr->__data->{'transformed'}{'start'};
      my $tr_end       = $tr->__data->{'transformed'}{'end'};
      my $extent       = $tr->__data->{'transformed'}{'extent'};
      
      foreach (@$gene_snps) {
        my ($snp, $chr, $start, $end) = @$_;
        my $vf_id = $snp->dbID;
        my $tv    = $tvs->{$vf_id};
        
        if ($tv && $end >= $tr_start - $extent && $start <= $tr_end + $extent) {
          foreach my $tva (@{$tv->get_all_alternate_TranscriptVariationAlleles}) {
            foreach my $con (@{$tva->get_all_OverlapConsequences}) {
              my $key  = join '_', $tr_stable_id, $vf_id, $tva->variation_feature_seq;
              my $term = $self->select_consequence_term($con, $cons_format);
              
              $counts_hash{$term}{$key} = 1 if $con;
              $total_counts_hash{$key}++;
            }
          }
        }
      }
    }
    
    foreach my $con (keys %descriptions) {
      $counts{$con} = scalar keys %{$counts_hash{$con}};
    }
    $total_counts = scalar keys %total_counts_hash;

  } else {
# Use the results of the TV count queries
    %counts = %{$gene_object->__data->{'conscounts'}};

    $total_counts = $counts{'ALL'};
  }
  
  my $warning_text = qq{<span style="color:red;">(WARNING: table may not load for this number of variants!)</span>};
  my @rows;
  
  foreach my $con (keys %descriptions) {
    if ($counts{$con}) {
      my $count = $counts{$con};
      my $warning = $count > 10000 ? $warning_text : '';
      
      push @rows, {
        type  => qq{<span class="hidden">$ranks{$con}</span>$labels{$con}},
        desc  => $descriptions{$con}.' '.$warning,
        count => $count,
        view  => $self->ajax_add($self->ajax_url(undef, { sub_table => $con, update_panel => 1 }), $con)
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
  
  # add the row for ALL variations if there are any
  if (my $total = $total_counts) {
    my $hidden_span = qq{<span class="hidden">-</span>}; # create a hidden span to add so that ALL is always last in the table
    my $warning     = $total > 10000 ? $warning_text : '';
    
    push @rows, {
      type  => $hidden_span . 'ALL',
      view  => $self->ajax_add($self->ajax_url(undef, { sub_table => 'ALL', update_panel => 1 }), 'ALL'),
      desc  => "All variations $warning",
      count => $hidden_span . $total,
    };
  }

  return $self->new_table($columns, \@rows, { data_table => 'no_col_toggle', sorting => [ 'type asc' ], exportable => 0 });
}


sub variation_table {
  my ($self, $consequence_type, $transcripts, $slice) = @_;
  my $hub         = $self->hub;
  my $cons_format = $hub->param('consequence_format');
  my $show_scores = $hub->param('show_scores');
  my (@rows, $base_trans_url, $url_transcript_prefix);
  
  # create some URLs - quicker than calling the url method for every variation
  my $base_url = $hub->url({
    type   => 'Variation',
    action => 'Mappings',
    vf     => undef,
    v      => undef,
    source => undef,
  });
  
  if ($self->isa('EnsEMBL::Web::Component::LRG::LRGSNPTable')) {
    my $gene_stable_id     = $transcripts->[0] && $transcripts->[0]->gene ? $transcripts->[0]->gene->stable_id : undef;
    $url_transcript_prefix = 'lrgt';
    
    $base_trans_url = $hub->url({
      type    => 'LRG',
      action  => 'Summary',
      lrg     => $gene_stable_id,
      __clear => 1
    });
  } else {
    $url_transcript_prefix = 't';
    
    $base_trans_url = $hub->url({
      type   => 'Transcript',
      action => 'Summary',
      t      => undef,
    }); 
  }
  
  foreach my $transcript (@$transcripts) {
    my %snps = %{$transcript->__data->{'transformed'}{'snps'} || {}};
   
    next unless %snps;
    
    my $transcript_stable_id = $transcript->stable_id;
    my $gene_snps            = $transcript->__data->{'transformed'}{'gene_snps'} || [];
    my $tr_start             = $transcript->__data->{'transformed'}{'start'};
    my $tr_end               = $transcript->__data->{'transformed'}{'end'};
    my $extent               = $transcript->__data->{'transformed'}{'extent'};
    my $gene                 = $transcript->gene;

    foreach (@$gene_snps) {
      my ($snp, $chr, $start, $end) = @$_;
      my $raw_id               = $snp->dbID;
      my $transcript_variation = $snps{$raw_id};
      
      next unless $transcript_variation;
      
      foreach my $tva (@{$transcript_variation->get_all_alternate_TranscriptVariationAlleles}) {
        my $skip = 1;
        
        if ($consequence_type eq 'ALL') {
          $skip = 0;
        } elsif ($tva) {
          foreach my $con (@{$tva->get_all_OverlapConsequences}) {
            if ($self->select_consequence_term($con, $cons_format) eq $consequence_type) {
              $skip = 0;
              last;
            }
          }
        }
        
        next if $skip;
        
        if ($tva && $end >= $tr_start - $extent && $start <= $tr_end + $extent) {
          #my $var                  = $snp->variation;
          my $validation           = $snp->get_all_validation_states || [];
          my $variation_name       = $snp->variation_name;
          my $var_class            = $snp->var_class;
          my $translation_start    = $transcript_variation->translation_start;
          my $source               = $snp->source;
          my ($aachange, $aacoord) = $translation_start ? ($tva->pep_allele_string, $translation_start) : ('-', '-');
          my $url                  = "$base_url;v=$variation_name;vf=$raw_id;source=$source";
          my $trans_url            = "$base_trans_url;$url_transcript_prefix=$transcript_stable_id";
          my $vf_allele            = $tva->variation_feature_seq;
          my $allele_string        = $snp->allele_string;
             $allele_string        = $self->trim_large_allele_string($allele_string, 'allele_' . $tva->dbID, 20) if length $allele_string > 20; # Check allele string size (for display issues)
             $allele_string        =~ s/$vf_allele/<b>$vf_allele<\/b>/g if $allele_string =~ /\/.+\//; # highlight variant allele in allele string
          
          # sort out consequence type string
          # Avoid duplicated Ensembl terms
          my %term   = map { $self->select_consequence_label($_, $cons_format) => 1 } @{$tva->get_all_OverlapConsequences || []};
          my $type   = join ',<br />', keys %term;
             $type ||= '-';
          
          my $sift = $self->render_sift_polyphen($tva->sift_prediction,     $tva->sift_score);
          my $poly = $self->render_sift_polyphen($tva->polyphen_prediction, $tva->polyphen_score);
          
          # Adds LSDB/LRG sources
          #if ($self->isa('EnsEMBL::Web::Component::LRG::LRGSNPTable')) {
          #  my $syn_sources = $var->get_all_synonym_sources;
          #  
          #  foreach my $s_source (@$syn_sources) {
          #    next if $s_source !~ /LSDB|LRG/;
          #    
          #    my ($synonym) = $var->get_all_synonyms($s_source);
          #       $source   .= ', ' . $hub->get_ExtURL_link($s_source, $s_source, $synonym);
          #  }
          #}
          
          my $gmaf   = $snp->minor_allele_frequency; # global maf
             $gmaf   = sprintf '%.3f (%s)', $gmaf, $snp->minor_allele if defined $gmaf;

          my $status = join '', map {qq{<img height="20px" width="20px" title="$_" src="/i/96/val_$_.gif"/><span class="hidden export">$_,</span>}} @$validation; # validation
          
          my $row = {
            ID         => qq{<a href="$url">$variation_name</a>},
            class      => $var_class,
            Alleles    => $allele_string,
            Ambiguity  => $snp->ambig_code,
            gmaf       => $gmaf   || '-',
            status     => $status || '-',
            chr        => "$chr:$start" . ($start == $end ? '' : "-$end"),
            Source     => $source,
            snptype    => $type,
            Transcript => qq{<a href="$trans_url">$transcript_stable_id</a>},
            aachange   => $aachange,
            aacoord    => $aacoord,
            sift       => $sift,
            polyphen   => $poly,
            HGVS       => $hub->param('hgvs') eq 'on' ? ($self->get_hgvs($tva) || '-') : undef,
          };
          
          push @rows, $row;
        }
      }
    }
  }

  return \@rows;
}

sub create_so_term_subsets {
  my ($self) = @_;

  my @all_cons = grep $_->feature_class =~ /transcript/i, values %Bio::EnsEMBL::Variation::Utils::Constants::OVERLAP_CONSEQUENCES;
  my $cons_format = $self->hub->param('consequence_format');

  my %so_term_subsets;
  
  foreach my $con (@all_cons) {
    next if $con->SO_accession =~ /x/i;
    
    my $term = $self->select_consequence_term($con, $cons_format);
    
    if (!exists($so_term_subsets{$term})) {
      $so_term_subsets{$term} = [];
    }
    push @{$so_term_subsets{$term}}, $con->SO_term;
  }

  return \%so_term_subsets;
}

sub configure {
  my ($self, $context, $consequence) = @_;
  my $object = $self->object;
  my $object_type = $self->hub->type;
  my $extent = $context eq 'FULL' ? 5000 : $context;
  my $gene_object;
  my $transcript_object;

  if ($object->isa('EnsEMBL::Web::Object::Gene')){ #|| $object->isa('EnsEMBL::Web::Object::LRG')){
    $gene_object = $object;
  } elsif ($object->isa('EnsEMBL::Web::Object::LRG')){
    my @genes       = @{$object->Obj->get_all_Genes('LRG_import')||[]};
    my $gene = $genes[0];  
    my $factory = $self->builder->create_factory('Gene');  
    $factory->createObjects($gene);
    $gene_object = $factory->object;
  } else {
    $transcript_object = $object;
    $gene_object = $self->hub->core_objects->{'gene'};
  }
  
  $gene_object->get_gene_slices(
    undef,
    [ 'context',     'normal', '100%'  ],
    [ 'gene',        'normal', '33%'   ],
    [ 'transcripts', 'munged', $extent ]
  );

  # map the selected consequence type to SO terms
  my %cons = %Bio::EnsEMBL::Variation::Utils::Constants::OVERLAP_CONSEQUENCES;
  my %selected_so;

  if (defined $consequence && $self->hub->param('consequence_format') ne 'so') {
    foreach my $con (keys %cons) {
      foreach my $val (values %{$cons{$con}}) {
        $selected_so{$con} = 1 if $val eq $consequence;
      }
    }
  } elsif ( defined $consequence && $consequence ne 'ALL') {
    $selected_so{$consequence} = 1;
  }
 
  
  my @so_terms = keys %selected_so;

  $gene_object->store_TransformedTranscripts;      ## Stores in $transcript_object->__data->{'transformed'}{'exons'|'coding_start'|'coding_end'}
 
  my $transcript_slice = $gene_object->__data->{'slices'}{'transcripts'}[1];
  my (undef, $snps)    = $gene_object->getVariationsOnSlice($transcript_slice, $gene_object->__data->{'slices'}{'transcripts'}[2], undef,  scalar(@so_terms) ? \@so_terms : undef);


  my $vf_objs = [ map $_->[2], @$snps];

  # For stats table (no $consquence) without a set intron context ($context). Also don't try for a single transcript (because its slower)
  if (!$consequence && !$transcript_object && $context eq 'FULL') {
    my $so_term_subsets = $self->create_so_term_subsets;
    $gene_object->store_ConsequenceCounts($so_term_subsets, $vf_objs);
  }

  # If doing subtable or can't calculate consequence counts
  if ($consequence || !exists($gene_object->__data->{'conscounts'})) {
    $gene_object->store_TransformedSNPS(\@so_terms,$vf_objs); ## Stores in $transcript_object->__data->{'transformed'}{'snps'}
  }

  ## Map SNPs for the last SNP display  
  my @gene_snps = map {[
    $_->[2], $transcript_slice->seq_region_name,
    $transcript_slice->strand > 0 ?
      ( $transcript_slice->start + $_->[2]->start - 1, $transcript_slice->start + $_->[2]->end   - 1 ) :
      ( $transcript_slice->end   - $_->[2]->end   + 1, $transcript_slice->end   - $_->[2]->start + 1 )
  ]} @$snps;

  foreach (@{$gene_object->get_all_transcripts}) {
    next if $object_type eq 'Transcript' && $_->stable_id ne $self->hub->param('t'); 
    $_->__data->{'transformed'}{'extent'}    = $extent;
    $_->__data->{'transformed'}{'gene_snps'} = \@gene_snps;
  }

  return $gene_object;
}

sub get_hgvs {
  my ($self, $tva) = @_;
  my $hgvs_c = $tva->hgvs_coding;
  my $hgvs_p = $tva->hgvs_protein;
  my $hgvs;

  if ($hgvs_c) {
    if (length $hgvs_c > 35) {
      my $display_hgvs_c  = substr($hgvs_c, 0, 35) . '...';
         $display_hgvs_c .= $self->trim_large_string($hgvs_c, 'hgvs_c_' . $tva->dbID);

      $hgvs_c = $display_hgvs_c;
    }

    $hgvs .= $hgvs_c;
  }

  if ($hgvs_p) {
    if (length $hgvs_p > 35) {
      my $display_hgvs_p  = substr($hgvs_p, 0, 35) . '...';
         $display_hgvs_p .= $self->trim_large_string($hgvs_p, 'hgvs_p_'. $tva->dbID);

      $hgvs_p = $display_hgvs_p;
    }

    $hgvs .= "<br />$hgvs_p";
  }

  return $hgvs;
}

sub select_consequence_term {
  my ($self, $con, $format) = @_;

  if ($format eq 'so') {
    return $con->SO_term;
  } else {
    return $con->display_term;
  }
}

sub select_consequence_label {
  my ($self, $con, $format) = @_;

  if ($format eq 'so') {
    return $self->hub->get_ExtURL_link($con->label, 'SEQUENCE_ONTOLOGY', $con->SO_accession);
  } else {
    return $con->display_term;
  }
}

1;
