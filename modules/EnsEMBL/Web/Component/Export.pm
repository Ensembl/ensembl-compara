package EnsEMBL::Web::Component::Export;

use strict;

use base qw(Exporter);
our @EXPORT = our @EXPORT_OK = qw(export export_file);

use POSIX qw(floor ceil);
use EnsEMBL::Web::SeqDumper;
use EnsEMBL::Web::Document::SpreadSheet;
use EnsEMBL::Web::Document::Renderer::Excel;

sub export {
  my $class = shift;
  my $custom_outputs = shift || {};
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
  map { $params->{'misc_set'}->{$_} = 1 if $_ } $object->param('miscset');
  
  my $outputs = {
    'fasta'   => sub { return fasta($object, $slice, $params, @inputs); },
    'csv'     => sub { return features($object, $slice, $params, 'csv'); },
    'gff'     => sub { return features($object, $slice, $params, 'gff'); },
    'tab'     => sub { return features($object, $slice, $params, 'tab'); },
    'embl'    => sub { return flat($object, $slice, $params, 'embl'); },
    'genbank' => sub { return flat($object, $slice, $params, 'genbank'); },
    %$custom_outputs
  };
  
  return $outputs->{$o}() if $outputs->{$o};
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
      
      $output->{$_}->[1] =~ s/(.{60})/$1\r\n/g;
      
      $html .= ">$output->{$_}->[0]\r\n$output->{$_}->[1]\r\n";
    }
  }
  
  if ($params->{'genomic'}) {
    my $seq = $slice->seq;
    $seq =~ s/(.{60})/$1\r\n/g;
    
    $html .= ">@{[$object->seq_region_name]} dna:@{[$object->seq_region_type]} @{[$slice->name]}\r\n$seq\r\n";
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
    'other'  => \@other_fields,
    'format' => $format,
    'delim'  => $delim->{$format}
  };
  
  my @features = ();
  
  my $header = join ($delim->{$format}, @common_fields, @other_fields) . "\r\n" if ($format ne 'gff');
  
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
  
  $html = "<pre>$header$html</pre>" if $html;
  
  if ($params->{'misc_set'}) {    
    my $misc_sets = $object->species_defs->databases->{'DATABASE_CORE'}{'tables'}{'misc_feature'}{'sets'};
    my $f = $object->param('_format');
    my $table;
    
    $options->{'seq_region'} = $object->seq_region_name;
    $options->{'start'} = $object->seq_region_start;
    $options->{'end'} = $object->seq_region_end;
    
    foreach (sort { $misc_sets->{$a}->{'name'} cmp $misc_sets->{$b}->{'name'} } keys %{$params->{'misc_set'}}) {
      my $tmp = { 
        'misc_set' => $_, 
        'name' => $misc_sets->{$_}->{'name'}
      };
      
      $table = $f eq 'Text' ? undef : new EnsEMBL::Web::Document::SpreadSheet;
      
      $html .= misc_set($object, $slice, { %$options, %$tmp }, $table);
    }
    
    $table = $f eq 'Text' ? undef : new EnsEMBL::Web::Document::SpreadSheet;
    
    $html .= misc_set_genes($object, $slice, $options, $table);
  }
  
  return $html || "No data available";
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
  
  return join ($options->{'delim'}, @results) . "\r\n";
}

sub misc_set {
  my ($object, $slice, $options, $table) = @_;
  
  my @fields = ( 'SeqRegion', 'Start', 'End', 'Name', 'Well name', 'Sanger', 'EMBL Acc', 'FISH', 'Centre', 'State' ); 
  my $header = "<h2>Features in set $options->{'name'} in Chromosome $options->{'seq_region'} $options->{'start'} - $options->{'end'}</h2>"; 
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
      $table->add_columns(map {{ 'title' => $_, 'align' => 'left' }} @fields);
    } else {
      $header .= "\r\n" . join ($options->{'delim'}, @fields) . "\r\n";
    }
    
    push (@regions, $slice);
    
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
  
  return $header . ($i ? ($table ? $table->render : $results) : "No data available\r\n") . ($table ? "<br /><br />" : "\r\n");
}

sub misc_set_genes {
  my ($object, $slice, $options, $table) = @_;
  
  my @gene_fields = ( 'SeqRegion', 'Start', 'End', 'Ensembl ID', 'DB', 'Name' );
  my $header = "<h2>Genes in Chromosome $options->{'seq_region'} $options->{'start'} - $options->{'end'}</h2>";
  my $row;
  my $results;
  my $i = 0;
  
  if ($table) {
    $table->add_columns(map {{ 'title' => $_, 'align' => 'left' }} @gene_fields);
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
  
  return $header . ($i ? ($table ? $table->render : $results) : "No data available");
}

sub flat {
  my ($object, $slice, $params, $format) = @_;
  
  my $seq_dumper = EnsEMBL::Web::SeqDumper->new;

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
  
  return $seq_dumper->dump($slice, $format);
}

sub export_file {
  my ($file, $object, $o) = @_;
  
  my $slice = $object->can('slice') ? $object->slice : $object->get_Slice unless $o =~ /haploview|ld_excel/;
  
  my $outputs = {
    'seq'      => sub { pip_seq_file($file, $object, $slice);  },
    'pipmaker' => sub { pip_anno_file($file, $object, $slice, $o); },
    'vista'    => sub { pip_anno_file($file, $object, $slice, $o); }
  };
  
  if (!$outputs->{$o}) {
    warn "Invalid file format $o";
    return;
  }
  
  $outputs->{$o}();
}

sub pip_seq_file {
  my ($file, $object, $slice) = @_;
  
  (my $seq = $slice->seq) =~ s/(.{60})/$1\r\n/g;
  
  my $fh;
  if (ref $file) {
    $fh = $file;
  } else {
    open $fh, ">$file";
  }

  print $fh ">@{[$slice->name]}\r\n$seq";

  close $fh unless ref $file;
}

sub pip_anno_file {
  my ($file, $object, $slice, $o) = @_;
  
  my $slice_length = $slice->length;
  
  my $outputs = {
    'pipmaker' => sub { return pip_anno_file_pipmaker(@_); },
    'vista'    => sub { return pip_anno_file_vista(@_); }
  };
  
  my $fh;
  if (ref $file) {
    $fh = $file;
  } else {
    open $fh, ">$file";
  }
  
  foreach my $gene (@{$slice->get_all_Genes(undef, undef, 1) || []}) {
    # only include genes that don't overlap slice boundaries
    next if ($gene->start < 1 or $gene->end > $slice_length);
    
    my $gene_header = join(" ", ($gene->strand == 1 ? ">" : "<"), $gene->start, $gene->end, $gene->external_name || $gene->stable_id);
    $gene_header .= "\r\n";
    
    foreach my $transcript (@{$gene->get_all_Transcripts}) {
      # get UTR/exon lines
      my @exons = @{$transcript->get_all_Exons};
      @exons = reverse @exons if ($gene->strand == -1);
      
      my $out = $outputs->{$o}($transcript, \@exons);
      
      # write output to file if there are exons in the exported region
      print $fh $gene_header, $out if $out;
    }
  }
  
  close $fh unless ref $file;
}


sub pip_anno_file_vista {
  my ($transcript, $exons) = @_;
  
  my $coding_start = $transcript->coding_region_start;
  my $coding_end = $transcript->coding_region_end;
  my $out;
  
  foreach my $exon (@$exons) {
    if (!$coding_start) {                                    # no coding region at all
      $out .= join(" ", $exon->start, $exon->end, "UTR\r\n");
    } elsif ($exon->start < $coding_start) {                 # we begin with an UTR
      if ($coding_start < $exon->end) {                      # coding region begins in this exon
        $out .= join(" ", $exon->start, $coding_start - 1, "UTR\r\n");
        $out .= join(" ", $coding_start, $exon->end, "exon\r\n");
      } else {                                               # UTR until end of exon
        $out .= join(" ", $exon->start, $exon->end, "UTR\r\n");
      }
    } elsif ($coding_end < $exon->end) {                     # we begin with an exon
      if ($exon->start < $coding_end) {                      # coding region ends in this exon
        $out .= join(" ", $exon->start, $coding_end, "exon\r\n");
        $out .= join(" ", $coding_end + 1, $exon->end, "UTR\r\n");
      } else {                                               # UTR (coding region has ended in previous exon)
        $out .= join(" ", $exon->start, $exon->end, "UTR\r\n");
      }
    } else {                                                 # coding exon
      $out .= join(" ", $exon->start, $exon->end, "exon\r\n");
    }
  }
  return $out;
}

sub pip_anno_file_pipmaker {
  my ($transcript, $exons) = @_;
  
  my $coding_start = $transcript->coding_region_start;
  my $coding_end = $transcript->coding_region_end;
  my $out;
  
  # do nothing for non-coding transcripts
  return unless ($coding_start);

  # add UTR line
  if ($transcript->start < $coding_start or $transcript->end > $coding_end) {
    $out .= join(" ", "+", $coding_start, $coding_end, "\r\n");
  }
  
  # add exon lines
  foreach my $exon (@$exons) {
    $out .= join(" ", $exon->start, $exon->end, "\r\n");
  }
  
  return $out;
}

1;
