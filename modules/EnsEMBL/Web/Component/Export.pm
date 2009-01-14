package EnsEMBL::Web::Component::Export;

use strict;

use base qw(Exporter);
our @EXPORT = our @EXPORT_OK = qw(export export_file);

use POSIX qw(floor ceil);
use Bio::EnsEMBL::Variation::DBSQL::LDFeatureContainerAdaptor;
use EnsEMBL::Web::SeqDumper;
use EnsEMBL::Web::Document::SpreadSheet;
use EnsEMBL::Web::Document::Renderer::Excel;

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
    'fasta'   => sub { return fasta($object, $slice, $params, @inputs); },
    'csv'     => sub { return features($object, $slice, $params, 'csv'); },
    'gff'     => sub { return features($object, $slice, $params, 'gff'); },
    'tab'     => sub { return features($object, $slice, $params, 'tab'); },
    'embl'    => sub { return flat($object, $slice, $params, 'embl'); },
    'genbank' => sub { return flat($object, $slice, $params, 'genbank'); },
    'ld'      => sub { return ld_dump($object); }
  };
  
  my $html = $outputs->{$o}() if $outputs->{$o};
  
  return $html;
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
      
      $html .= ">$output->{$_}->[0]\n$output->{$_}->[1]\r\n";
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
    'common' => \@common_fields,
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
  
  if ($params->{'cytoview'}) {
    $html = "<pre>$header$html</pre>" if $html; # Only add header and formatting if we have export data so far
    
    $html .= cytoview($object, $options);
    
    return $html;
  } else {
    return "<pre>$header$html</pre>";
  }
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

sub cytoview {
  my ($object, $options) = @_;
  
  my @fields = ( 'SeqRegion', 'Start', 'End', 'Name', 'Well name', 'Sanger', 'EMBL Acc', 'FISH', 'Centre', 'State' );  
  my $db = $object->database('core');
  my $table_format = ($object->param('_format') eq 'HTML');
  my $dump = $object->param('cytoview_dump');
  my $misc_set = $object->param('cytoview_misc_set');
  my $i = 0;
  
  my ($seq_region, $start, $end);
  
  if ($dump eq 'set') {
    $seq_region = $object->seq_region_name;
  } elsif ($dump eq 'slice') {
    $seq_region = $object->seq_region_name;
    $start = $object->seq_region_start;
    $end = $object->seq_region_end;
  }
  
  my $slice = $db->get_SliceAdaptor->fetch_by_region(undef, $seq_region, $start, $end) if $seq_region;
  
  my @regions;
  my $results;
  my $html;
  my $table;
  my $adaptor;
  my $row;
  my $header;
  
  eval {
    $adaptor = $db->get_MiscSetAdaptor->fetch_by_code($misc_set);
  };
  
  if ($adaptor) {
    if ($table_format) {
      $table = new EnsEMBL::Web::Document::SpreadSheet;
      $table->add_columns(map {{ 'title' => $_, 'align' => 'left' }} @fields);
      
      my $header_keys = {
        tilepath => 'Tilepath',
        cloneset_1mb => '1MB clone set',
        cloneset_32k => '32k clone set',
        cloneset_30k => '30k clone set'
      };
      
      if ($seq_region) {
        $header = "Chromosome $seq_region";
        $header = $start ? " in $header $start - $end" : " on $header";
      }
      
      $header = "<h2>Features in set $header_keys->{$misc_set}$header</h2>";
    } else {
      $header = join ($options->{'delim'}, @fields) . "\r\n";
    }
    
    if ($seq_region) {
      push (@regions, $slice);
    } else {
      push (@regions, $db->get_SliceAdaptor->fetch_by_region(undef, $_)) for (@{$object->species_defs->ENSEMBL_CHROMOSOMES});
    }
    
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
        
        if ($table_format) {
          $table->add_row($row);
        } else {
          $results .= join ($options->{'delim'}, @$row) . "\r\n";
        }
        
        $i++;
      }
    }
    
    $html .= $header . ($table_format ? $table->render : $results) if $i;
  }  
  
  if ($start) {
    my @gene_fields = ( 'SeqRegion', 'Start', 'End', 'Ensembl ID', 'DB', 'Name' );
    
    $results = '';
    
    if ($table_format) {
      $table = new EnsEMBL::Web::Document::SpreadSheet;
      $table->add_columns(map {{ 'title' => $_, 'align' => 'left' }} @gene_fields);
      
      $header = "<h2>Genes in Chromosome $seq_region $start - $end</h2>";
    } else {
      $header = join ($options->{'delim'}, @gene_fields) . "\r\n";
    }
    
    $i = 0;
    
    foreach (sort { $a->seq_region_start <=> $b->seq_region_start } map { @{$slice->get_all_Genes($_)||[]} } qw( ensembl havana ensembl_havana_gene )) {
      $row = [
        $_->seq_region_name,
        $_->seq_region_start,
        $_->seq_region_end,
        $_->stable_id,
        $_->external_db || '-',
        $_->external_name || '-novel-'
      ];
      
      if ($table_format) {
        $table->add_row($row);
      } else {
        $results .= join ($options->{'delim'}, @$row) . "\r\n";
      }
      
      $i++;
    }
    
    $html .= $header . ($table_format ? $table->render : $results) if $i;
  }
  
  return "$html\r\n";
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

sub ld_dump {
  my ($object, $file, $params) = @_;
  
  my ($format, $pop_param, $snp_param);
  
  if ($params) {
    $format = 'Excel';
    $pop_param = $params->{'opt_pop'}->[0];
    $snp_param = $params->{'v'}->[0];
  } else {
    $format = $object->param('_format');
    $pop_param = $object->param('opt_pop');
    $snp_param = $object->param('v');
  }
  my $zoom = 20000; # Currently non-configurable
  
  if (!$pop_param) {
    warn "****** ERROR: No population defined";
    return;
  }
  
  my @colour_gradient = (
    'ffffff', 
    $object->image_config_hash('ldview')->colourmap->build_linear_gradient(41, 'mistyrose', 'pink', 'indianred2', 'red')
  );
  
  my $ld_values = ld_values($object, $pop_param, $snp_param, $zoom);
  
  my $table;
  my $text;
  my $html;
  my $header_style = "background-color:#CCCCCC;font-weight:bold;";
  
  my $populations = {};
  map { $populations->{$_} = 1 } map { keys %{$ld_values->{$_}} } keys %$ld_values;
  
  foreach my $pop_name (sort { $a cmp $b } keys %$populations) {
    my $flag = 1;

    foreach my $ld_type (keys %$ld_values) {      
      next unless $ld_values->{$ld_type}{$pop_name}{'data'};
      
      my ($starts, $snps, $data) = (@{$ld_values->{$ld_type}{$pop_name}{'data'}});
      
      unshift (@$data, []);
      
      if ($format eq 'Excel') {
        if (!$table) {
          my $renderer = new EnsEMBL::Web::Document::Renderer::Excel({ fh => $file->{'full_path'} });
          $table = $renderer->new_table_renderer;
        }
        
        (my $sheet_name = $pop_name) =~ s/[^\w\s]/_/g;
        
        if ($flag) {
          $table->new_sheet($sheet_name); # Start a new sheet(and new table)
          $flag = 0;
        } else {
          $table->new_table; # Start a new table
        }
        
        $table->set_width(2 + @$snps);
        $table->heading($ld_values->{$ld_type}{$pop_name}{'text'});
        $table->new_row;
        
        $table->write_header_cell('bp position');
        $table->write_header_cell('SNP');
        
        $table->write_header_cell($_) for @$snps;
        $table->new_row;
      } elsif ($format eq 'Text') {
        $text = join ("\t", 'bp position', 'SNP', @$snps) . "\n";
      } else {
        $table = new EnsEMBL::Web::Document::SpreadSheet;
        
        $table->add_option('cellspacing', 2);
        $table->add_option('rows', '', ''); # No row colouring
        $table->add_columns(map {{ 'title' => $_, 'align' => 'center' }} ( 'bp&nbsp;position', 'SNP', @$snps ));
      }
      
      foreach my $row (@$data) {
        next unless ref $row eq 'ARRAY';
        
        my $snp = shift @$snps;
        my $pos = shift @$starts;
        
        my @ld_values = map { $_ ? sprintf("%.3f", $_) : '-' } @$row;
        my @row_style = map { 'background-color:#' . ($_ eq '-' ? 'ffffff' : $colour_gradient[floor($_*40)]) . ';' } @ld_values;
        
        if ($format eq 'Excel') {
          $table->write_header_cell($pos);
          $table->write_header_cell($snp);
          
          foreach my $value (@ld_values) {
            my $format = $table->new_format({
              'align'   => 'center',
              'bgcolor' => $value eq '-' ? 'ffffff' : $colour_gradient[floor($value*40)]
            });
            
            $table->write_cell($value, $format);
          }
          
          $table->write_header_cell($snp);
          $table->new_row;
        } elsif ($format eq 'Text') {
          $text .= join ("\t", $pos, $snp, @ld_values, $snp) . "\n";
        } else {
          $table->add_row([ $pos, $snp, @ld_values, $snp ]);
          $table->add_option('row_style', [ $header_style, $header_style, @row_style, $header_style ]);
        }
      }
      
      next if $format eq 'Excel'; # No html to return
      
      if ($format eq 'Text') {
        $html .= "$ld_values->{$ld_type}{$pop_name}->{'text'}\n";
        $html .= ("=" x length $ld_values->{$ld_type}{$pop_name}->{'text'}) . "\n\n";
        $html .= "$text\n";
      } else {
        $html .= "<h3>$ld_values->{$ld_type}{$pop_name}->{'text'}</h3>";
        $html .= $table->render;
      }
    }
  }

  return $html;
}

sub ld_values {
  my ($object, $populations, $snp, $zoom) = @_;
  
  ## set path information for LD calculations
  $Bio::EnsEMBL::Variation::DBSQL::LDFeatureContainerAdaptor::BINARY_FILE = $object->species_defs->ENSEMBL_CALC_GENOTYPES_FILE;
  $Bio::EnsEMBL::Variation::DBSQL::LDFeatureContainerAdaptor::TMP_PATH = $object->species_defs->ENSEMBL_TMP_TMP;
  
  my %ld_values;
  my $display_zoom = $object->round_bp($zoom);

  foreach my $pop_name (sort split (/\|/, $populations)) {
    my $pop_obj = $object->pop_obj_from_name($pop_name);
    
    next unless $pop_obj;
    
    my $pop_id = $pop_obj->{$pop_name}{'dbID'};
    my $data = $object->ld_for_slice($pop_obj->{$pop_name}{'PopObject'}, $zoom);
    
    foreach my $ld_type ('r2', 'd_prime') {
      my $display = $ld_type eq 'r2' ? 'r2' : "D'";
      my $no_data = "No $display linkage data in $display_zoom window for population $pop_name";
      
      unless (%$data && keys %$data) {
        $ld_values{$ld_type}{$pop_name}{'text'} = $no_data;
        next;
      }

      my @snp_list = sort { $a->[1]->start <=> $b->[1]->start } map  {[ $_ => $data->{'variationFeatures'}{$_} ]} keys %{$data->{'variationFeatures'}};

      unless (scalar @snp_list) {
        $ld_values{$ld_type}{$pop_name}{'text'} = $no_data;
        next;
      }

      # Do each column starting from 1 because first col is empty
      my @table;
      my $flag = 0;
      
      for (my $x = 0; $x < scalar @snp_list; $x++) { 
        # Do from left side of table row across to current snp
        for (my $y = 0; $y < $x; $y++) {
          my $ld_pair1 = "$snp_list[$x]->[0]" . -$snp_list[$y]->[0];
          my $ld_pair2 = "$snp_list[$y]->[0]" . -$snp_list[$x]->[0];
          my $cell;
          
          if ($data->{'ldContainer'}{$ld_pair1}) {
            $cell = $data->{'ldContainer'}{$ld_pair1}{$pop_id}{$ld_type};
          } elsif ($data->{'ldContainer'}{$ld_pair2}) {
            $cell = $data->{'ldContainer'}{$ld_pair2}{$pop_id}{$ld_type};
          }
          
          $flag = $cell ? 1 : 0 unless $flag;
          $table[$x][$y] = $cell;
        }
      }
      
      unless ($flag) {
        $ld_values{$ld_type}{$pop_name}{'text'} = $no_data;
        next;
      }

      # Turn snp_list from an array of variation_feature IDs to SNP 'rs' names
      # Make current SNP bold
      my @snp_names;
      my @starts_list;
      
      
      foreach (@snp_list) {
        my $name = $_->[1]->variation_name;
        
        if ($name eq $snp || $name eq "rs$snp") {
          push (@snp_names, "*$name*");
        } else { 
          push (@snp_names, $name);
        }

        my ($start, $end) = ($_->[1]->start, $_->[1]->end);
        my $pos = $start;
        
        if ($start > $end) {
          $pos = "between $start & $end";
        } elsif ($start < $end) {
          $pos = "$start-$end";
        }
        
        push (@starts_list, $pos);
      }

      my $location = $object->seq_region_name . ':' . $object->seq_region_start . '-' . $object->seq_region_end;
      
      $ld_values{$ld_type}{$pop_name}{'text'} = "Pairwise $display values for $location. Population: $pop_name";
      $ld_values{$ld_type}{$pop_name}{'data'} = [ \@starts_list, \@snp_names, \@table ];
    }
  }
  
  return \%ld_values;
}

sub export_file {
  my ($file, $object, $o, $params) = @_;
  
  my $slice = $object->can('slice') ? $object->slice : $object->get_Slice unless $o =~ /haploview|ld_excel/;
  
  my $outputs = {
    'seq'       => sub { pip_seq_file($file, $object, $slice);  },
    'pipmaker'  => sub { pip_anno_file($file, $object, $slice, $o); },
    'vista'     => sub { pip_anno_file($file, $object, $slice, $o); },
    'haploview' => sub { haploview_files($file, $object); },
    'ld_excel'  => sub { ld_dump($object, $file, $params); }
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

sub haploview_files {
  my ($files, $object) = @_;
  
  my $fhs = {};
  
  foreach (keys %$files) {
    if (ref $files->{$_}) {
      $fhs->{$_} = $files->{$_};
    } else {
      open $fhs->{$_}, ">$files->{$_}";
    }
  }
  
  my %ind_genotypes;
  my %individuals;
  my @snps;
  my $family;
 
  my ($locus, $genotype);
 
  # gets all genotypes in the Slice as a hash. where key is region_name-region_start
  my $slice_genotypes = $object->get_all_genotypes;

  foreach my $vf (@{$object->get_variation_features}) {
    my ($genotypes, $ind_data) =  $object->individual_genotypes($vf, $slice_genotypes);

    next unless %$genotypes;
    
    my $name = $vf->variation_name;
    my $start = $vf->start;
    
    $locus .= "$name $start\r\n";
    
    push (@snps, $name);
    
    map { $ind_genotypes{$_}{$name} = $genotypes->{$_} } (keys %$genotypes);
    map { $individuals{$_} = $ind_data->{$_} } (keys %$ind_data);
  }
  
  foreach my $individual (keys %ind_genotypes) {
    my $output = join "\t", ("FAM" . $family++, 
      $individual, 
      $individuals{$individual}{'father'}, 
      $individuals{$individual}{'mother'}, 
      $individuals{$individual}{'gender'}, 
      "0\t"
    );
    
    foreach (@snps) {
      my $snp = $ind_genotypes{$individual}{$_} || "00";
      $snp =~ tr/ACGTN/12340/;
      
      $output .= join " ", (split (//, $snp));
      $output .= "\t";
    }
    
    $genotype .= "$output\r\n";
  }
  
  print { $fhs->{'locus'} } $locus;
  print { $fhs->{'genotype'} } $genotype;

  foreach (keys %$files) {
    close $fhs->{$_} unless ref $files->{$_};
  }
}

1;
