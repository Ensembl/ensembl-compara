package EnsEMBL::Web::Component::Export;

use strict;

use EnsEMBL::Web::SeqDumper;
use EnsEMBL::Web::Document::SpreadSheet;

use base 'EnsEMBL::Web::Component';

sub export {
  my $self = shift;
  my $custom_outputs = shift || {};
  my @inputs = @_;
  
  my $object = $self->object;
  
  my $o = $object->param('output');
  my $format = $object->param('_format');
  my $flank5 = $object->param('flank5_display');
  my $flank3 = $object->param('flank3_display');
  
  my $strand = $object->param('strand');
  $strand = undef unless $strand == 1 || $strand == -1; # Feature strand will be correct automatically
  
  my $slice = $object->can('slice') ? $object->slice : $object->get_Slice;
  $slice = $slice->invert if $strand && $strand != $slice->strand;
  $slice = $slice->expand($flank5, $flank3) if $flank5 || $flank3;
  
  my $params = { html_format => !$format || $format eq 'HTML' };
  
  if ($slice->length > 5000000) {
    my $error = 'The region selected is too large to export. Please select a region of less than 5Mb.';
    return $params->{'html_format'} ? $self->_warning('Region too large', "<p>$error</p>") : $error;
  }
  
  my $outputs = {
    fasta   => sub { return $self->fasta(@inputs); },
    csv     => sub { return $self->features('csv'); },
    gff     => sub { return $self->features('gff'); },
    tab     => sub { return $self->features('tab'); },
    embl    => sub { return $self->flat('embl'); },
    genbank => sub { return $self->flat('genbank'); },
    %$custom_outputs
  };
  
  if ($outputs->{$o}) {
    map { $params->{$_} = 1 } $object->param('st');
    map { $params->{'misc_set'}->{$_} = 1 if $_ } $object->param('miscset');
    
    $self->slice($slice);
    $self->params($params);
    
    return $outputs->{$o}();
  }
}

sub slice {
  my $self = shift;
  $self->{'slice'} = $_[0] if $_[0];
  return $self->{'slice'};
}

sub params {
  my $self = shift;
  $self->{'params'} = $_[0] if $_[0];
  return $self->{'params'};
}

sub fasta {
  my $self = shift;
  my ($trans_objects, $object_id) = @_;
  
  my $object = $self->object;
  my $slice = $self->slice;
  my $params = $self->params;
  
  my $genomic = $object->param('genomic');
  my $seq_region_name = $object->seq_region_name;
  my $seq_region_type = $object->seq_region_type;
  my $slice_name = $slice->name;
  my $slice_length = $slice->length;
  my $strand = $slice->strand;
  
  my $html;
  
  foreach (@$trans_objects) {
    my $transcript = $_->Obj;
    my $id_type = $transcript->isa('Bio::EnsEMBL::PredictionTranscript') ? $transcript->analysis->logic_name : $transcript->status . '_' . $transcript->biotype;
    my $id = ($object_id ? "$object_id:" : '') . $transcript->stable_id;
    my $intron_id = 1;
    
    my $output = {
      cdna    => [[ "$id cdna:$id_type", $transcript->spliced_seq ]],
      coding  => eval { [[ "$id cds:$id_type", $transcript->translateable_seq ]] },
      peptide => eval { [[ "$id peptide:@{[$transcript->translation->stable_id]} pep:$id_type", $transcript->translate->seq ]] },
      utr3    => eval { [[ "$id utr3:$id_type", $transcript->three_prime_utr->seq ]] },
      utr5    => eval { [[ "$id utr5:$id_type", $transcript->five_prime_utr->seq ]] },
      exons   => eval { [ map {[ "$id " . $_->id . " exon:$id_type", $_->seq->seq ]} @{$transcript->get_all_Exons} ] },
      introns => eval { [ map {[ "$id intron " . $intron_id++ . ":$id_type", $_->seq ]} @{$transcript->get_all_Introns} ] }
    };
    
    foreach (sort keys %$params) {
      next unless ref $output->{$_} eq 'ARRAY';
      
      foreach (@{$output->{$_}}) {
        $_->[1] =~ s/(.{60})/$1\r\n/g;
        $_->[1] =~ s/\r\n$//g;
        
        $html .= ">$_->[0]\r\n$_->[1]\r\n";
      }
    }
    
    $html .= "\r\n";
  }
  
  if (defined $genomic && $genomic ne 'off') {
    my $masking = $genomic eq 'soft_masked' ? 1 : $genomic eq 'hard_masked' ? 0 : undef;
    my ($name, $seq);
    
    if ($genomic =~ /flanking/) {
      if ($genomic =~ /5/) {
        my $flank5_slice = $slice->sub_Slice(1, $object->param('flank5_display'), $strand);
        
        if ($flank5_slice) {
          $name = $flank5_slice->name;
          $seq = $flank5_slice->seq;
          $seq =~ s/(.{60})/$1\r\n/g;
          
          $html .= ">5' Flanking sequence $name\r\n$seq\r\n";
        }
      }
      
      if ($genomic =~ /3/) {
        my $flank3_slice = $slice->sub_Slice($slice_length - $object->param('flank3_display'), $slice_length, $strand);
        
        if ($flank3_slice) {
          $name = $flank3_slice->name;
          $seq = $flank3_slice->seq;
          $seq =~ s/(.{60})/$1\r\n/g;
          
          $html .= ">3' Flanking sequence $name\r\n$seq\r\n";
        }
      }
    } else {
      $seq = defined $masking ? $slice->get_repeatmasked_seq(undef, $masking)->seq : $slice->seq;
      $seq =~ s/(.{60})/$1\r\n/g;
      
      $html .= ">$seq_region_name dna:$seq_region_type $slice_name\r\n$seq\r\n";
    }
  }
  
  $html = "<pre>$html</pre>" if $html && $params->{'html_format'};
  
  return $html || 'No data available';
}

sub features {
  my $self = shift;
  my $format = shift;
  
  my $object = $self->object;
  my $species_defs = $object->species_defs;
  my $slice = $self->slice;
  my $params = $self->params;
  
  my $html;
  
  my @common_fields = qw( seqname source feature start end score strand frame );
  my @other_fields  = qw( hid hstart hend genscan gene_id transcript_id exon_id gene_type variation_name );
  
  my $options = {
    other  => \@other_fields,
    format => $format,
    delim  => $format eq 'csv' ? ',' : "\t"
  };
  
  my @features;
  
  my $header = join ($options->{'delim'}, @common_fields, @other_fields) . "\r\n" if $format ne 'gff';
  
  if ($params->{'similarity'}) {
    foreach (@{$slice->get_all_SimilarityFeatures}) {
      $html .= $self->feature('similarity', $_, $options, { hid => $_->hseqname, hstart => $_->hstart, hend => $_->hend });
    }
  }
  
  if ($params->{'repeat'}) {
    foreach (@{$slice->get_all_RepeatFeatures}) {
      $html .= $self->feature('repeat', $_, $options, { hid => $_->repeat_consensus->name, hstart => $_->hstart, hend => $_->hend });
    }
  }
  
  if ($params->{'genscan'}) {
    foreach my $t (@{$slice->get_all_PredictionTranscripts}) {
      foreach my $e (@{$t->get_all_Exons}) {
        $html .= $self->feature('pred.trans.', $e, $options, { genscan => $t->stable_id });
      }
    }
  }
  
  if ($params->{'variation'}) {
    foreach (@{$slice->get_all_VariationFeatures}) {
      $html .= $self->feature('variation', $_, $options, { variation_name => $_->variation_name });
    }
  }
  
  if ($params->{'gene'}) {
    my @dbs = ('core');
    push @dbs, 'vega' if $species_defs->databases->{'DATABASE_VEGA'};
    push @dbs, 'otherfeatures' if $species_defs->databases->{'DATABASE_OTHERFEATURES'};
  
    foreach my $db (@dbs) {
      foreach my $g (@{$slice->get_all_Genes(undef, $db)}) {
        foreach my $t (@{$g->get_all_Transcripts}) {
          foreach my $e (@{$t->get_all_Exons}) {
            $html .= $self->feature('gene', $e, $options, { 
               exon_id       => $e->stable_id, 
               transcript_id => $t->stable_id, 
               gene_id       => $g->stable_id, 
               gene_type     => $g->status . '_' . $g->biotype
            }, $db eq 'vega' ? 'Vega' : 'Ensembl');
          }
        }
      }
    }
  }
  
  if ($html) {
    $html = "$header$html";
    $html = "<pre>$html</pre>" if $params->{'html_format'};
  }
  
  if ($params->{'misc_set'}) {    
    my $sets = $species_defs->databases->{'DATABASE_CORE'}->{'tables'}->{'misc_feature'}->{'sets'};
    
    $options->{'seq_region'} = $object->seq_region_name;
    $options->{'start'} = $object->seq_region_start;
    $options->{'end'} = $object->seq_region_end;
    
    $html .= "\r\n";
    $html .= $self->misc_set({%$options, ( misc_set => $_, name => $sets->{$_}->{'name'} )}) for sort { $sets->{$a}->{'name'} cmp $sets->{$b}->{'name'} } keys %{$params->{'misc_set'}};
    $html .= $self->misc_set_genes($options);
  }
  
  return $html || 'No data available';
}

sub feature {
  my $self = shift;
  my ($type, $feature, $options, $extra, $def_source) = @_;
  
  my $score  = $feature->can('score') ? $feature->score : '.';
  my $source = $feature->can('source_tag') ? $feature->source_tag : ($def_source || 'Ensembl');
  my $tag    = $feature->can('primary_tag') ? $feature->primary_tag : (ucfirst(lc $type) || '.');
  
  $source =~ s/\s/_/g;
  $tag    =~ s/\s/_/g;
  
  my ($name, $strand, $start, $end, $phase);
  
  if ($feature->can('seq_region_name')) {
    $strand = $feature->seq_region_strand;
    $name   = $feature->seq_region_name;
    $start  = $feature->seq_region_start;
    $end    = $feature->seq_region_end;
  } else {
    $strand = $feature->can('strand') ? $feature->strand : undef;
    $name   = $feature->can('entire_seq') && $feature->entire_seq ? $feature->entire_seq->name : $feature->can('seqname') ? $feature->seqname : undef;
    $start  = $feature->can('start') ? $feature->start : undef;
    $end    = $feature->can('end') ? $feature->end : undef;
  }
  
  $name ||= 'SEQ';
  $name =~ s/\s/_/g;
  
  if ($strand == 1) {
    $strand = '+';
    $phase = $feature->can('phase') ? $feature->phase : '.';
  } elsif ($strand == -1) {
    $strand = '-';
    $phase = $feature->can('end_phase') ? $feature->end_phase : '.';
  }
  
  $phase = '.' if $phase == -1 || !defined $phase;
  
  $strand ||= '.';
  
  my @results = ($name, $source, $tag, $start, $end, $score, $strand, $phase);
  
  if ($options->{'format'} eq 'gff') {
    push @results, join ';', map { defined $extra->{$_} ? "$_=$extra->{$_}" : () } @{$options->{'other'}};
  } else {
    push @results, map { $extra->{$_} } @{$options->{'other'}};
  }
  
  return join ($options->{'delim'}, @results) . "\r\n";
}

sub misc_set {
  my $self = shift;
  my $options = shift;
  
  my $object = $self->object;
  my $table = new EnsEMBL::Web::Document::SpreadSheet if $self->params->{'html_format'};
  
  my @fields = ( 'SeqRegion', 'Start', 'End', 'Name', 'Well name', 'Sanger', 'EMBL Acc', 'FISH', 'Centre', 'State' ); 
  my $header = "Features in set $options->{'name'} in Chromosome $options->{'seq_region'} $options->{'start'} - $options->{'end'}"; 
  $header = "<h2>$header</h2>" if $table;
    
  my $db = $object->database('core');
  my @regions;
  my $adaptor;
  my $row;
  my $results;
  my $i = 0;

  eval {
    $adaptor = $db->get_MiscSetAdaptor->fetch_by_code($options->{'misc_set'});
  };
  
  if ($adaptor) {
    if ($table) {
      $table->add_columns(map {{ title => $_, align => 'left' }} @fields);
    } else {
      $header .= "\r\n" . join ($options->{'delim'}, @fields) . "\r\n";
    }
    
    push @regions, $self->slice;
    
    foreach my $r (@regions) {
      foreach (sort { $a->start <=> $b->start } @{$db->get_MiscFeatureAdaptor->fetch_all_by_Slice_and_set_code($r, $adaptor->code)}) {
        $row = [
          $_->seq_region_name,
          $_->seq_region_start,
          $_->seq_region_end,
          join (';', @{$_->get_all_attribute_values('clone_name')}, @{$_->get_all_attribute_values('name')}),
          join (';', @{$_->get_all_attribute_values('well_name')}),
          join (';', @{$_->get_all_attribute_values('synonym')}, @{$_->get_all_attribute_values('sanger_project')}),
          join (';', @{$_->get_all_attribute_values('embl_acc')}),
          $_->get_scalar_attribute('fish'),
          $_->get_scalar_attribute('org'),
          $_->get_scalar_attribute('state')
        ];
        
        if ($table) {
          $table->add_row($row);
        } else {
          $results .= join ($options->{'delim'}, @$row) . "\r\n";
        }
        
        $i++;
      }
    }
  }
  
  return $header . ($i ? ($table ? $table->render : $results) : "No data available\r\n") . ($table ? '<br /><br />' : "\r\n");
}

sub misc_set_genes {
  my $self = shift;
  my $options = shift;
  
  my $object = $self->object;
  my $slice = $self->slice;
  my $table = new EnsEMBL::Web::Document::SpreadSheet if $self->params->{'html_format'};
  
  my @gene_fields = ( 'SeqRegion', 'Start', 'End', 'Ensembl ID', 'DB', 'Name' );
  my $header = "Genes in Chromosome $options->{'seq_region'} $options->{'start'} - $options->{'end'}";
  $header = "<h2>$header</h2>" if $table;
  
  my $row;
  my $results;
  my $i = 0;
  
  if ($table) {
    $table->add_columns(map {{ title => $_, align => 'left' }} @gene_fields);
  } else {
    $header .= "\r\n" . join ($options->{'delim'}, @gene_fields) . "\r\n";
  }
  
  foreach (sort { $a->seq_region_start <=> $b->seq_region_start } map { @{$slice->get_all_Genes($_)||[]} } qw( ensembl havana ensembl_havana_gene )) {
    $row = [
      $_->seq_region_name,
      $_->seq_region_start,
      $_->seq_region_end,
      $_->stable_id,
      $_->external_db || '-',
      $_->external_name || '-novel-'
    ];
    
    if ($table) {
      $table->add_row($row);
    } else {
      $results .= join ($options->{'delim'}, @$row) . "\r\n";
    }
    
    $i++;
  }
  
  return $header . ($i ? ($table ? $table->render : $results) : 'No data available');
}

sub flat {
  my $self = shift;
  my $format = shift;
  
  my $object = $self->object;
  my $slice = $self->slice;
  my $params = $self->params;
  
  my $seq_dumper = new EnsEMBL::Web::SeqDumper;

  foreach (qw( genscan similarity gene repeat variation contig marker )) {
    $seq_dumper->disable_feature_type($_) unless $params->{$_};
  }
  
  my $vega_db = $object->database('vega');
  my $estgene_db = $object->database('otherfeatures');

  if ($params->{'vegagene'} && $vega_db) {
    $seq_dumper->enable_feature_type('vegagene');
    $seq_dumper->attach_database('vega', $vega_db);
  }
  
  if ($params->{'estgene'} && $estgene_db) {
    $seq_dumper->enable_feature_type('estgene');
    $seq_dumper->attach_database('estgene', $estgene_db);
  }
  
  my $html = $seq_dumper->dump($slice, $format);
  $html = "<pre>$html</pre>" if $params->{'html_format'};
  
  return $html || 'No data available';
}

1;
