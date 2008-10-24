package EnsEMBL::Web::Component::Gene::GeneExport;

use EnsEMBL::Web::Component;
use EnsEMBL::Web::Form;
use EnsEMBL::Web::Document::SpreadSheet;
use EnsEMBL::Web::SeqDumper;

use strict;
use warnings;
no warnings "uninitialized";

use base qw( EnsEMBL::Web::Component::Gene );

sub _init {
  my $self = shift;
  $self->cacheable(1);
  $self->ajaxable(0);
}

# TODO: UNHACK!
# This package controls exporting for transcripts and locations as well as genes. These functions should be moved elsewhere.

sub content_transcript {
  my $self = shift;
  
  return $self->content('Transcript');
}

sub content_location {
  my $self = shift;
  
  return $self->content('Location');
}

sub content {
  my $self = shift;
  my $type = shift || 'Gene';
  my $object = $self->object;
  
  my ($translation, $three, $five);
  my $html;
  
  if ($type eq 'Location') {
    my $links = [
      [ 'fasta', 'FASTA' ],
      [ 'csv', 'CSV (Comma separated values)' ],
      [ 'gff', 'GFF Format' ],
      [ 'tab', 'Tab separated values' ],
      [ 'embl', 'EMBL' ],
      [ 'genbank', 'GenBank' ]
    ];
    
    $html .= qq{<p><a href="/@{[$object->species]}/$type/Export/$_->[0]?$ENV{'QUERY_STRING'};_format=Text" target="_blank">$_->[1]</a></p>} for (@$links);
  } else {
    if ($type eq 'Transcript') {
      $translation = 1 if $object->Obj->translation;
      $three = 1 if $object->Obj->three_prime_utr;
      $five = 1 if $object->Obj->five_prime_utr;
    } else {
      # Gene
      for (@{$object->get_all_transcripts}) {
        $translation = 1 if $_->Obj->translation;
        $three = 1 if $_->Obj->three_prime_utr;
        $five = 1 if $_->Obj->five_prime_utr;
        
        last if $translation && $three && $five;
      }
    }
    
    my $links = [
      [ 'cdna', 'cDNA', 1 ],
      [ 'coding', 'Coding sequence', $translation ],
      [ 'peptide', 'Peptide sequence', $translation ],
      [ 'utr5', "5' UTR", $five ],
      [ 'utr3', "3' UTR", $three ]
    ];
    
    for (@$links) {
      $html .= qq{<p><a href="/@{[$object->species]}/$type/Export/fasta?$ENV{'QUERY_STRING'};st=$_->[0];_format=Text" target="_blank">$_->[1]</a></p>} if $_->[2];
    }
  }
  
  return $html;
}

sub content_transcript_fasta {
  my $self = shift;

  return '<pre>' . $self->fasta_trans($self->object, $self->object->param('st')) . '</pre>';
}

sub content_location_fasta {
  my $self   = shift;
  my $object = $self->object;
  my $slice  = $object->slice->seq;
  
  $slice =~ s/(.{60})/$1\n/g;
  
  return "<pre>>@{[$object->seq_region_name]} dna:@{[$object->seq_region_type]} @{[$object->slice->name]}\n$slice\n</pre>";
}

sub content_gene_fasta {
  my $self   = shift;
  my $object = $self->object;
  
  my $html;
  $html .= $self->fasta_trans($_, $object->param('st'), $object->stable_id) for (@{$object->get_all_transcripts||[]});
  
  return "<pre>$html</pre>";
}

sub fasta_trans {
  my $self = shift;
  my ($trans_obj, $type, $obj_id) = @_;
  
  my $transcript = $trans_obj->Obj;
  my $id_type = $transcript->isa('Bio::EnsEMBL::PredictionTranscript') ? $transcript->analysis->logic_name : $transcript->status . '_' . $transcript->biotype;
  my $id = $obj_id ? "$obj_id:" : "" . $transcript->stable_id;
  
  my $output = {
    'cdna'    => [ "$id cdna:$id_type", $transcript->spliced_seq ],
    'coding'  => eval { [ "$id cds:$id_type", $transcript->translateable_seq ] },
    'peptide' => eval { [ "$id peptide:@{[$transcript->translation->stable_id]} pep:$id_type", $transcript->translate->seq ] },
    'utr3'    => eval { [ "$id utr3:$id_type", $transcript->three_prime_utr->seq ] },
    'utr5'    => eval { [ "$id utr5:$id_type", $transcript->five_prime_utr->seq ] }
  };
  
  $output->{$type}->[1] =~ s/(.{60})/$1\n/g;
  
  return ">$output->{$type}->[0]\n$output->{$type}->[1]\n";
}

sub content_location_csv {
  my $self = shift;
  
  return $self->content_location_feature('csv');
}

sub content_location_gff {
  my $self = shift;
  
  return $self->content_location_feature('gff');
}

sub content_location_tab {
  my $self = shift;
  
  return $self->content_location_feature('tab');
}

sub content_location_feature {
  my $self   = shift;
  my $format = shift;
  my $object = $self->object;
  
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
    $html .= join $delim->{$format}, @common_fields, @other_fields;
    $html .= "\n";
  }

  foreach (@{$object->slice->get_all_SimilarityFeatures}) {
    $html .= $self->feature('similarity', $options, $_, { 'hid' => $_->hseqname, 'hstart' => $_->hstart, 'hend' => $_->hend });
  }

  foreach (@{$object->slice->get_all_RepeatFeatures}) {
    $html .= $self->feature('repeat', $options, $_, { 'hid' => $_->repeat_consensus->name, 'hstart' => $_->hstart, 'hend' => $_->hend });
  }

  foreach my $t (@{$object->slice->get_all_PredictionTranscripts}) {
    foreach my $f (@{$t->get_all_Exons}) {
      $html .= $self->feature('pred.trans.', $options, $f, { 'genscan' => $t->stable_id });
    }
  }

  foreach (@{$object->slice->get_all_VariationFeatures}) {
    $html .= $self->feature('variation', $options, $_, {});
  }

  my @dbs = ('core');
  push @dbs, 'vega' if $object->species_defs->databases->{'DATABASE_VEGA'};
  push @dbs, 'otherfeatures' if $object->species_defs->databases->{'DATABASE_OTHERFEATURES'};

  foreach my $db (@dbs) {
    foreach my $g (@{$object->slice->get_all_Genes(undef, $db)}) {
      foreach my $t (@{$g->get_all_Transcripts}) {
        foreach my $f (@{$t->get_all_Exons}) {
          $html .= $self->feature('gene', $options, $f, { 
             'exon_id' => $f->stable_id, 
             'transcript_id' => $t->stable_id, 
             'gene_id' => $g->stable_id, 
             'gene_type' => $g->status . '_' . $g->biotype
          }, $db eq 'vega' ? 'Vega' : 'Ensembl');
        }
      }
    }
  }
  
  return "<pre>$html</pre>";
}

sub feature {
  my $self = shift;
  my ($type, $options, $feature, $extra, $def_source) = @_;
  
  my $score  = $feature->can('score') ? $feature->score : '.';
  my $frame  = $feature->can('frame') ? $feature->frame : '.';
  my $source = $feature->can('source_tag') ? $feature->source_tag : ($def_source || 'Ensembl');
  my $tag    = $feature->can('primary_tag') ? $feature->primary_tag : (ucfirst(lc($type)) || '.');
  
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
    push @results, join "; ", map { defined $extra->{$_} ? "$_=$extra->{$_}" : () } @{$options->{'other'}};
  } else {
    push @results, map { $extra->{$_} } @{$options->{'other'}};
  }
  
  return join($options->{'delim'}, @results) . "\n";
}

sub content_location_embl {
  my $self = shift;

  return $self->content_location_flat('embl');
}

sub content_location_genbank {
  my $self = shift;

  return $self->content_location_flat('genbank');
}

sub content_location_flat {
  my $self   = shift;
  my $format = shift;
  my $object = $self->object;
  
  my $seq_dumper = EnsEMBL::Web::SeqDumper->new();

  $seq_dumper->enable_feature_type('vegagene');
  $seq_dumper->attach_database('vega', $object->database('vega'));
  $seq_dumper->enable_feature_type('estgene');
  $seq_dumper->attach_database('otherfeatures', $object->database('otherfeatures'));


  my $html = $seq_dumper->dump($object->slice, $format, $self);
  
  return "<pre>$html</pre>";
}

1;
