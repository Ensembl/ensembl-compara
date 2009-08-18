package EnsEMBL::Web::Component::Export;

use strict;

use Bio::AlignIO;
use IO::String;

use EnsEMBL::Web::Component::Compara_Alignments;
use EnsEMBL::Web::Document::SpreadSheet;
use EnsEMBL::Web::SeqDumper;

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
  
  my $params = {};
  
  my $html_format = !$format || $format eq 'HTML';
  
  if ($slice->length > 5000000) {
    my $error = 'The region selected is too large to export. Please select a region of less than 5Mb.';
    
    $self->string($html_format ? $self->_warning('Region too large', "<p>$error</p>") : $error);
  } else {
    my $outputs = {
      fasta     => sub { return $self->fasta(@inputs); },
      csv       => sub { return $self->features('csv'); },
      tab       => sub { return $self->features('tab'); },
      gff       => sub { return $self->features('gff'); },
      gff3      => sub { return $self->gff3_features; },
      embl      => sub { return $self->flat('embl'); },
      genbank   => sub { return $self->flat('genbank'); },
      alignment => sub { return $self->alignment; },
      %$custom_outputs
    };
    
    if ($outputs->{$o}) {
      map { $params->{$_} = 1 if $_ } $object->param('param');
      map { $params->{'misc_set'}->{$_} = 1 if $_ } $object->param('misc_set');
      
      $self->slice($slice);
      $self->params($params);
      $self->html_format($html_format);
      
      $outputs->{$o}();
    }
  }
  
  my $string = $self->string;
  my $html   = $self->html; # contains html tags
  
  if ($html_format) {
    $string = "<pre>$string</pre>" if $string;
  } else {
    s/<.*?>//g for $string, $html; # Strip html tags;
    $string .= "\r\n" if $string && $html;
  }
  
  return ($string . $html) || 'No data available';
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

sub html_format {
  my $self = shift;
  $self->{'html_format'} = $_[0] if $_[0];
  return $self->{'html_format'};
}

sub string { return shift->output('string', @_); }
sub html   { return shift->output('html',   @_); }

sub output {
  my ($self, $key, $string) = @_;
  
  $self->{$key} .= "$string\r\n" if defined $string;
  return $self->{$key};
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
  
  my $fasta;
  
  if (scalar keys %$params) {
    my $intron_id;
    
    my $output = {
      cdna    => sub { my ($t, $id, $type) = @_; [[ "$id cdna:$type", $t->spliced_seq ]] },
      coding  => sub { my ($t, $id, $type) = @_; [[ "$id cds:$type", $t->translateable_seq ]] },
      peptide => sub { my ($t, $id, $type) = @_; eval { [[ "$id peptide: " . $t->translation->stable_id . " pep:$type", $t->translate->seq ]] }},
      utr3    => sub { my ($t, $id, $type) = @_; eval { [[ "$id utr3:$type", $t->three_prime_utr->seq ]] }},
      utr5    => sub { my ($t, $id, $type) = @_; eval { [[ "$id utr5:$type", $t->five_prime_utr->seq ]] }},
      exon    => sub { my ($t, $id, $type) = @_; eval { [ map {[ "$id " . $_->id . " exon:$type", $_->seq->seq ]} @{$t->get_all_Exons} ] }},
      intron  => sub { my ($t, $id, $type) = @_; eval { [ map {[ "$id intron " . $intron_id++ . ":$type", $_->seq ]} @{$t->get_all_Introns} ] }}
    };
    
    foreach (@$trans_objects) {
      my $transcript = $_->Obj;
      my $id         = ($object_id ? "$object_id:" : '') . $transcript->stable_id;
      my $type       = $transcript->isa('Bio::EnsEMBL::PredictionTranscript') ? $transcript->analysis->logic_name : $transcript->status . '_' . $transcript->biotype;
      
      $intron_id = 1;
      
      foreach (sort keys %$params) {      
        my $o = $output->{$_}($transcript, $id, $type) if exists $output->{$_};
        
        next unless ref $o eq 'ARRAY';
        
        foreach (@$o) {
          $self->string(">$_->[0]");
          $self->string($fasta) while $fasta = substr $_->[1], 0, 60, '';
        }
      }
      
      $self->string('');
    }
  }
  
  if (defined $genomic && $genomic ne 'off') {
    my $masking = $genomic eq 'soft_masked' ? 1 : $genomic eq 'hard_masked' ? 0 : undef;
    my ($seq, $start, $end, $flank_slice);
    
    if ($genomic =~ /flanking/) {
      for (5, 3) {
        if ($genomic =~ /$_/) {
          ($start, $end) = $_ == 3 ? ($slice_length - $object->param('flank3_display'), $slice_length) : (1, $object->param('flank5_display'));
          $flank_slice = $slice->sub_Slice($start, $end, $strand);
          
          if ($flank_slice) {
            $seq  = $flank_slice->seq;
            
            $self->string(">$_' Flanking sequence " . $flank_slice->name);
            $self->string($fasta) while $fasta = substr $seq, 0, 60, '';
          }
        }
      }
    } else {
      $seq = defined $masking ? $slice->get_repeatmasked_seq(undef, $masking)->seq : $slice->seq;
      
      $self->string(">$seq_region_name dna:$seq_region_type $slice_name");
      $self->string($fasta) while $fasta = substr $seq, 0, 60, '';
    }
  }
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
  
  $self->string($seq_dumper->dump($slice, $format));
}

sub alignment {
  my $self = shift;
  
  my $object = $self->object;
  my $species = $object->species;$object->param('align');
  
  $self->{'alignments_function'} = 'get_SimpleAlign';
  
  my $alignments = EnsEMBL::Web::Component::Compara_Alignments::get_alignments($self, $object, $self->slice, $object->param('align'), $object->species);
  my $export;

  my $align_io = Bio::AlignIO->newFh(
    -fh     => new IO::String($export),
    -format => $object->param('format')
  );

  print $align_io $alignments;
  
  $self->string($export);
}

sub features {
  my $self = shift;
  my $format = shift;
  
  my $object = $self->object;
  my $slice  = $self->slice;
  my $params = $self->params;
  
  my @common_fields = qw( seqname source feature start end score strand frame );
  my @extra_fields  = qw( hid hstart hend genscan gene_id transcript_id exon_id gene_type variation_name );
  
  $self->{'config'} = {
    extra_fields  => \@extra_fields,
    format        => $format,
    delim         => $format eq 'csv' ? ',' : "\t"
  };
  
  $self->string(join $self->{'config'}->{'delim'}, @common_fields, @extra_fields) unless $format eq 'gff';
  
  if ($params->{'similarity'}) {
    foreach (@{$slice->get_all_SimilarityFeatures}) {
      $self->feature('similarity', $_, { 
        hid    => $_->hseqname, 
        hstart => $_->hstart, 
        hend   => $_->hend 
      });
    }
  }
  
  if ($params->{'repeat'}) {
    foreach (@{$slice->get_all_RepeatFeatures}) {
      $self->feature('repeat', $_, { 
        hid    => $_->repeat_consensus->name, 
        hstart => $_->hstart, 
        hend   => $_->hend 
      });
    }
  }
  
  if ($params->{'genscan'}) {
    foreach my $t (@{$slice->get_all_PredictionTranscripts}) {
      foreach my $e (@{$t->get_all_Exons}) {
        $self->feature('pred.trans.', $e, { genscan => $t->stable_id });
      }
    }
  }
  
  if ($params->{'variation'}) {
    foreach (@{$slice->get_all_VariationFeatures}) {
      $self->feature('variation', $_, { variation_name => $_->variation_name });
    }
  }
  
  if ($params->{'gene'}) {
    my $species_defs = $object->species_defs;
    
    my @dbs = ('core');
    push @dbs, 'vega' if $species_defs->databases->{'DATABASE_VEGA'};
    push @dbs, 'otherfeatures' if $species_defs->databases->{'DATABASE_OTHERFEATURES'};
  
    foreach my $db (@dbs) {
      foreach my $g (@{$slice->get_all_Genes(undef, $db)}) {
        foreach my $t (@{$g->get_all_Transcripts}) {
          foreach my $e (@{$t->get_all_Exons}) {
            $self->feature('gene', $e, { 
               exon_id       => $e->stable_id, 
               transcript_id => $t->stable_id, 
               gene_id       => $g->stable_id, 
               gene_type     => $g->status . '_' . $g->biotype
            }, { source => $db eq 'vega' ? 'Vega' : 'Ensembl' });
          }
        }
      }
    }
  }
  
  $self->misc_sets(keys %{$params->{'misc_set'}}) if $params->{'misc_set'};
}

sub gff3_features {
  my $self = shift;
  
  my $object       = $self->object;
  my $slice        = $self->slice;
  my $params       = $self->params;
  my $species_defs = $object->species_defs;
  
  $self->{'config'} = {
    format             => 'gff3',
    delim              => "\t",
    ordered_attributes => {},
    feature_order      => {},
    feature_type_count => 0
  };
  
  
  my @dbs = ('core');
  push @dbs, 'vega' if $species_defs->databases->{'DATABASE_VEGA'};
  push @dbs, 'otherfeatures' if $species_defs->databases->{'DATABASE_OTHERFEATURES'};
  
  my ($g_id, $t_id);
  
  foreach my $db (@dbs) {
    my $properties = { source => $db eq 'vega' ? 'Vega' : 'Ensembl' };
    
    foreach my $g (@{$slice->get_all_Genes(undef, $db)}) {
      if ($params->{'gene'}) {
        $g_id = $g->stable_id;
        $self->feature('gene', $g, { ID => $g_id, Name => $g_id, biotype => $g->biotype }, $properties);
      }
    
      foreach my $t (@{$g->get_all_Transcripts}) {
        if ($params->{'transcript'}) {
          $t_id = $t->stable_id;
          $self->feature('transcript', $t, { ID => $t_id, Parent => $g_id, Name => $t_id, biotype => $t->biotype }, $properties);
        }
        
        if ($params->{'intron'}) {
          $self->feature('intron', $_, { Parent => $t_id, Name => $self->id_counter('intron') }, $properties) for @{$t->get_all_Introns};
        }
        
        if ($params->{'exon'} || $params->{'cds'}) {
          foreach my $e (@{$t->get_all_Exons}) {
            $self->feature('exon', $e, { Parent => $t_id, Name => $e->stable_id }, $properties) if $params->{'exon'};
            
            if ($params->{'cds'}) {
              my $start = $e->coding_region_start($t);
              my $end   = $e->coding_region_end($t);
              
              next unless $start || $end;
              
              $_ += $e->seq_region_start for $start, $end; # why isn't there an API call for this?
              
              $self->feature('CDS', $e, { Parent => $t_id, Name => $t->translation->stable_id }, { start => $start, end => $end, %$properties });
            }
          }
        }
      }
    }
  }
  
  my %order = reverse %{$self->{'config'}->{'feature_order'}};
  
  $self->string(join "\t", '##gff-version', '3');
  $self->string(join "\t", '##sequence-region', $slice->seq_region_name, '1', $slice->seq_region_length);
  $self->string('');
  $self->string($self->output($order{$_})) for sort { $a <=> $b } keys %order;
}

sub feature {
  my $self = shift;
  my ($type, $feature, $attributes, $properties) = @_;
  
  my $config = $self->{'config'};
  
  my %vals;
  
  if ($feature->can('seq_region_name')) {
    %vals = (
      seqid  => $feature->seq_region_name,
      start  => $feature->seq_region_start,
      end    => $feature->seq_region_end,
      strand => $feature->seq_region_strand
    );
  } else {
    %vals = (
      seqid  => $feature->can('entire_seq') && $feature->entire_seq ? $feature->entire_seq->name : $feature->can('seqname') ? $feature->seqname : undef,
      start  => $feature->can('start') ? $feature->start : undef,
      end    => $feature->can('end') ? $feature->end : undef,
      strand => $feature->can('strand') ? $feature->strand : undef
    );
  }   
  %vals = (%vals, (
    type   => $type || ($feature->can('primary_tag') ? $feature->primary_tag : '.'),
    source => $feature->can('source_tag') ? $feature->source_tag : $feature->can('source') ? $feature->source : 'Ensembl',
    score  => $feature->can('score') ? $feature->score : '.',
    phase  => '.'
  ));
  
  # Overwrite values where passed in
  foreach (keys %$properties) {
    $vals{$_} = $properties->{$_} if defined $properties->{$_};
  }
  
  if ($vals{'strand'} == 1) {
    $vals{'strand'} = '+';
    $vals{'phase'}  = $feature->phase if $feature->can('phase');
  } elsif ($vals{'strand'} == -1) {
    $vals{'strand'} = '-';
    $vals{'phase'}  = $feature->end_phase if $feature->can('end_phase');
  }
  
  $vals{'phase'} = '.' if $vals{'phase'} == -1;
  $vals{'strand'} ||= '.';
  $vals{'seqid'}  ||= 'SEQ';
  
  my @results = map { $vals{$_} =~ s/ /_/g; $vals{$_} } qw(seqid source type start end score strand phase);
  
  if ($config->{'format'} eq 'gff') {
    push @results, join ';', map { defined $attributes->{$_} ? "$_=$attributes->{$_}" : () } @{$config->{'extra_fields'}};
  } elsif ($config->{'format'} eq 'gff3') {
    push @results, join ';', map { "$_=" . $self->escape_attribute($attributes->{$_}) } $self->order_attributes($type, $attributes);
  } else {
    push @results, map { $attributes->{$_} } @{$config->{'extra_fields'}};
  }
  
  if ($config->{'format'} eq 'gff3') {
    $config->{'feature_order'}->{$type} ||= ++$config->{'feature_type_count'};
    $self->output($type, join "\t", @results);
  } else {
    $self->string(join $config->{'delim'}, @results);
  }
}

sub misc_sets {
  my $self = shift;
  
  my $object = $self->object;
  
  my $sets = $object->species_defs->databases->{'DATABASE_CORE'}->{'tables'}->{'misc_feature'}->{'sets'};
  my @misc_sets = sort { $sets->{$a}->{'name'} cmp $sets->{$b}->{'name'} } @_;
  
  my $region = $object->seq_region_name;
  my $start  = $object->seq_region_start;
  my $end    = $object->seq_region_end;
  my $db     = $object->database('core');
  my $delim  = $self->{'config'}->{'delim'};
    
  my $header_map = {
    _gene   => { 
      title   => "Genes in Chromosome $region $start - $end",
      columns => [ 'SeqRegion', 'Start', 'End', 'Ensembl ID', 'DB', 'Name' ]
    },
    default => {
      title   => "Features in set %s in Chromosome $region $start - $end",
      columns => [ 'SeqRegion', 'Start', 'End', 'Name', 'Well name', 'Sanger', 'EMBL Acc', 'FISH', 'Centre', 'State' ]
    }
  };
  
  my ($header, $table, @sets);
  
  foreach (@misc_sets, '_gene') {
    $header = $header_map->{$_} || $header_map->{'default'};
    $table = new EnsEMBL::Web::Document::SpreadSheet if $self->html_format;
    
    $self->html(sprintf "<h2>$header->{'title'}</h2>", $sets->{$_}->{'name'});
    
    if ($table) {
      $table->add_columns(map {{ title => $_, align => 'left' }} @{$header->{'columns'}});
    } else {
      $self->html(join $delim, @{$header->{'columns'}});
    }
    
    @sets = $_ eq '_gene' ? $self->misc_set_genes : $self->misc_set($_, $sets->{$_}->{'name'}, $db);
    
    if (scalar @sets) {
      foreach (@sets) {
        if ($table) {
          $table->add_row($_);
        } else {
          $self->html(join $delim, @$_);
        }
      }
      
      $self->html($table->render) if $table;
    } else {
      $self->html('No data available');
    }
  
    $self->html('<br /><br />');
  }
}

sub misc_set {
  my $self = shift;
  my ($misc_set, $name, $db) = @_;
  
  my $adaptor;
  my @rows;

  eval {
    $adaptor = $db->get_MiscSetAdaptor->fetch_by_code($misc_set);
  };
  
  if ($adaptor) {    
    foreach (sort { $a->start <=> $b->start } @{$db->get_MiscFeatureAdaptor->fetch_all_by_Slice_and_set_code($self->slice, $adaptor->code)}) {
      push @rows, [
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
    }
  }
  
  return @rows;
}

sub misc_set_genes {
  my $self = shift;
  
  my $slice = $self->slice;
  my @rows;
  
  foreach (sort { $a->seq_region_start <=> $b->seq_region_start } map @{$slice->get_all_Genes($_)||[]}, qw(ensembl havana ensembl_havana_gene)) {
    push @rows, [
      $_->seq_region_name,
      $_->seq_region_start,
      $_->seq_region_end,
      $_->stable_id,
      $_->external_db || '-',
      $_->external_name || '-novel-'
    ];
  }
  
  return @rows;
}

# Orders attributes - predefined array first, then all other keys in alphabetical order
# Also strip any attributes for which we have keys but no values
sub order_attributes {
  my $self = shift;
  my ($key, $attrs) = @_;
  
  my $attributes = $self->{'config'}->{'ordered_attributes'};
  
  return @{$attributes->{$key}} if $key && $attributes->{$key}; # Reduce the work done
  
  my $i = 1;
  
  my %predefined = map { $_ => $i++ } qw(ID Name Alias Parent Target Gap Derives_from Note Dbxref Ontology_term);
  my %order = map { defined $attrs->{$_} ? ($predefined{$_} || $i++ => $_) : () } sort keys %$attrs;
  my @rtn = map { $order{$_} } sort { $a <=> $b } keys %order;
  
  @{$attributes->{$key}} = @rtn if $key;
  
  return @rtn;
}

sub id_counter {
  my ($self, $type) = @_;
  
  return sprintf '%s%05d', $type, ++$self->{'id_counter'}->{$type};
}

sub escape {
  my $self = shift;
  my ($string, $match) = @_;
  
  return '' unless defined $string;
  
  $match ||= '([^a-zA-Z0-9.:^*$@!+_?-|])';
  
  $string =~ s/$match/sprintf("%%%02x",ord($1))/eg;
  
  return $string;
}

# Can take array, will return comma separated string if this is the case
sub escape_attribute {
  my $self = shift;
  my $attr = shift;
  
  return '' unless defined $attr;
  
  my $match = '([,=;\t])';
  
  $attr = ref $attr eq 'ARRAY' ? join ',', map { $_ ? $self->escape($_, $match) : () } @$attr : $self->escape($attr, $match);
  
  return $attr;
}

1;
