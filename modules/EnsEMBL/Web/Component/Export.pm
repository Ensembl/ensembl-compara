package EnsEMBL::Web::Component::Export;

use strict;

use base qw(Exporter);
our @EXPORT = our @EXPORT_OK = qw(export);

use EnsEMBL::Web::SeqDumper;

sub export {
  my $class = shift;
  my $object = $class->object;
  my $slice = $object->can('slice') ? $object->slice : $object->get_Slice;
  my @inputs = @_;
  
  my $o = $object->param('output');
  my $flank5 = $object->param('flank5_display');
  my $flank3 = $object->param('flank3_display');
  my $strand = $object->param('strand');
  $strand = undef unless ($strand == 1 || $strand == -1); # Feature strand will be correct automatically
  
  $slice = $slice->invert if ($strand && $strand != $slice->strand);
  $slice = $slice->expand($flank5, $flank3) if ($flank5 || $flank3);
  
  my $params = {};
  map { $params->{$_} = 1 } $object->param('st');
  
  my $outputs = {
    'fasta' =>   sub { return fasta($object, $slice, $params, @inputs); },
    'csv' =>     sub { return features($object, $slice, $params, 'csv'); },
    'gff' =>     sub { return features($object, $slice, $params, 'gff'); },
    'tab' =>     sub { return features($object, $slice, $params, 'tab'); },
    'embl' =>    sub { return flat($object, $slice, $params, 'embl'); },
    'genbank' => sub { return flat($object, $slice, $params, 'genbank'); }
  };
  
  my $html = $outputs->{$o}() if $outputs->{$o};
  
  return "<pre>$html</pre>";
}

sub fasta {
  my ($object, $slice, $params, $trans_objects, $object_id) = @_;
  
  my $html;
  
  foreach (@$trans_objects) {
    my $transcript = $_->Obj;
    my $id_type = $transcript->isa('Bio::EnsEMBL::PredictionTranscript') ? $transcript->analysis->logic_name : $transcript->status . '_' . $transcript->biotype;
    my $id = ($object_id ? "$object_id:" : "") . $transcript->stable_id;
    
    my $output = {
      'cdna'    => [ "$id cdna:$id_type", $transcript->spliced_seq ],
      'coding'  => eval { [ "$id cds:$id_type", $transcript->translateable_seq ] },
      'peptide' => eval { [ "$id peptide:@{[$transcript->translation->stable_id]} pep:$id_type", $transcript->translate->seq ] },
      'utr3'    => eval { [ "$id utr3:$id_type", $transcript->three_prime_utr->seq ] },
      'utr5'    => eval { [ "$id utr5:$id_type", $transcript->five_prime_utr->seq ] }
    };
    
    foreach (sort keys %$params) {
      next unless ref $output->{$_} eq 'ARRAY';
      
      $output->{$_}->[1] =~ s/(.{60})/$1\n/g;
      
      $html .= ">$output->{$_}->[0]\n$output->{$_}->[1]\n";
    }
  }
  
  if ($params->{'genomic'}) {
    my $seq = $slice->seq;
    $seq =~ s/(.{60})/$1\n/g;
    
    $html .= ">@{[$object->seq_region_name]} dna:@{[$object->seq_region_type]} @{[$slice->name]}\n$seq\n";
  }
  
  return $html;
}

sub features {
  my ($object, $slice, $params, $format) = @_;
  
  my $html;
  
  my @common_fields = qw( seqname source feature start end score strand frame );
  my @other_fields = qw( hid hstart hend genscan gene_id transcript_id exon_id gene_type );
  
  my $delim = { 'gff' => "\t", 'csv' => ",", 'tab' => "\t" };
  
  my $options = {
    'common' => \@common_fields,
    'other'  => \@other_fields,
    'delim'  => "\t",
    'format' => $format,
    'delim'  => $delim->{$format}
  };
  
  my @features = ();
  
  if ($format ne 'gff') {
    $html .= join ($delim->{$format}, @common_fields, @other_fields);
    $html .= "\n";
  }
  
  if ($params->{'similarity'}) {
    foreach (@{$slice->get_all_SimilarityFeatures}) {
      $html .= feature('similarity', $options, $_, { 'hid' => $_->hseqname, 'hstart' => $_->hstart, 'hend' => $_->hend });
    }
  }
  
  if ($params->{'repeat'}) {
    foreach (@{$slice->get_all_RepeatFeatures}) {
      $html .= feature('repeat', $options, $_, { 'hid' => $_->repeat_consensus->name, 'hstart' => $_->hstart, 'hend' => $_->hend });
    }
  }
  
  if ($params->{'genscan'}) {
    foreach my $t (@{$slice->get_all_PredictionTranscripts}) {
      foreach my $f (@{$t->get_all_Exons}) {
        $html .= feature('pred.trans.', $options, $f, { 'genscan' => $t->stable_id });
      }
    }
  }
  
  if ($params->{'variation'}) {
    foreach (@{$slice->get_all_VariationFeatures}) {
      $html .= feature('variation', $options, $_, {});
    }
  }
  
  if ($params->{'gene'}) {
    my @dbs = ('core');
    push (@dbs, 'vega') if $object->species_defs->databases->{'DATABASE_VEGA'};
    push (@dbs, 'otherfeatures') if $object->species_defs->databases->{'DATABASE_OTHERFEATURES'};
  
    foreach my $db (@dbs) {
      foreach my $g (@{$slice->get_all_Genes(undef, $db)}) {
        foreach my $t (@{$g->get_all_Transcripts}) {
          foreach my $f (@{$t->get_all_Exons}) {
            $html .= feature('gene', $options, $f, { 
               'exon_id' => $f->stable_id, 
               'transcript_id' => $t->stable_id, 
               'gene_id' => $g->stable_id, 
               'gene_type' => $g->status . '_' . $g->biotype
            }, $db eq 'vega' ? 'Vega' : 'Ensembl');
          }
        }
      }
    }
  }
  
  return $html;
}

sub feature {
  my ($type, $options, $feature, $extra, $def_source) = @_;
  
  my $score  = $feature->can('score') ? $feature->score : '.';
  my $frame  = $feature->can('frame') ? $feature->frame : '.';
  my $source = $feature->can('source_tag') ? $feature->source_tag : ($def_source || 'Ensembl');
  my $tag    = $feature->can('primary_tag') ? $feature->primary_tag : (ucfirst(lc $type) || '.');
  
  $source =~ s/\s/_/g;
  $tag  =~ s/\s/_/g;
  
  my ($name, $strand, $start, $end);
  
  if ($feature->can('seq_region_name')) {
    $strand = $feature->seq_region_strand;
    $name   = $feature->seq_region_name;
    $start  = $feature->seq_region_start;
    $end    = $feature->seq_region_end;
  } else {
    $strand = $feature->can('strand') ? $feature->strand : undef;
    $name   = $feature->can('entire_seq') && $feature->entire_seq ? $feature->entire_seq->name : undef;
    $name   = $feature->seqname if !$name && $feature->can('seqname');
    $start  = $feature->can('start') ? $feature->start : undef;
    $end    = $feature->can('end') ? $feature->end : undef;
  }
  
  $name ||= 'SEQ';
  $name =~ s/\s/_/g;
  
  $strand ||= '.';
  $strand = '+' if $strand eq 1;
  $strand = '-' if $strand eq -1;

  my @results = ($name, $source, $tag, $start, $end, $score, $strand, $frame);

  if ($options->{'format'} eq 'gff') {
    push (@results, join ("; ", map { defined $extra->{$_} ? "$_=$extra->{$_}" : () } @{$options->{'other'}}));
  } else {
    push (@results, map { $extra->{$_} } @{$options->{'other'}});
  }
  
  return join ($options->{'delim'}, @results) . "\n";
}

sub flat {
  my ($object, $slice, $params, $format) = @_;
  
  my $seq_dumper = EnsEMBL::Web::SeqDumper->new;

  foreach (qw( genscan similarity gene repeat variation contig marker )) {
    $seq_dumper->disable_feature_type($_) unless $params->{$_};
  }

  if ($params->{'vegagene'}) {
    $seq_dumper->enable_feature_type('vegagene');
    $seq_dumper->attach_database('vega', $object->database('vega'));
  }
  
  if ($params->{'estgene'}) {
    $seq_dumper->enable_feature_type('estgene');
    $seq_dumper->attach_database('estgene', $object->database('otherfeatures'));
  }
  
  return $seq_dumper->dump($slice, $format);
}

1;
