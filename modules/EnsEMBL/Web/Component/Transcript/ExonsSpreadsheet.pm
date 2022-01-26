=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2022] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

package EnsEMBL::Web::Component::Transcript::ExonsSpreadsheet;

use strict;

use base qw(EnsEMBL::Web::Component::TextSequence EnsEMBL::Web::Component::Transcript);

use EnsEMBL::Web::TextSequence::View::ExonsSpreadsheet;

sub initialize {
  my ($self, $export) = @_;
  my $hub        = $self->hub;
  my $entry_exon = $hub->param('exon');
  my $object     = $self->object || $hub->core_object('transcript');
  my $transcript = $object->Obj;
  my @exons      = @{$transcript->get_all_Exons};
  my $strand     = $exons[0]->strand;
  my $chr_name   = $exons[0]->slice->seq_region_name;
  my $i          = 0;
  my @data;

  my $type   = $hub->param('data_type') || $hub->type;
  my $vc = $self->view_config($type);
  
  my $config = {
    exons_only    => (scalar $self->param('exons_only'))||'off',
    display_width => scalar $self->param('display_width'),
    sscon         => scalar $self->param('sscon'),     # no of bp to show either side of a splice site
    flanking      => scalar $self->param('flanking'),  # no of bp up/down stream of transcript
    full_seq      => scalar $self->param('fullseq'),   # flag to display full sequence (introns and exons)
    snp_display   => scalar $self->param('snp_display'),
    number        => scalar $self->param('line_numbering'),
    coding_start  => $transcript->coding_region_start,
    coding_end    => $transcript->coding_region_end,
    strand        => $strand,
    export        => $export,
    variants_as_n   => scalar $self->param('variants_as_n'),
  };
  
  $config->{'last_number'} = $strand == 1 ? $exons[0]->seq_region_start - $config->{'flanking'} - 1 : $exons[0]->seq_region_end + $config->{'flanking'} + 1 if $config->{'number'} eq 'slice';
  $config->{'snp_display'} = 'off' unless $hub->species_defs->databases->{'DATABASE_VARIATION'};
  
  if ($config->{'snp_display'} ne 'off') {
    my @consequence = $self->param('consequence_filter');
    my @evidence    = $self->param('evidence_filter');
    my $filter      = $self->param('population_filter');
    
    if ($filter && $filter ne 'off') {
      $config->{'population'}    = $hub->get_adaptor('get_PopulationAdaptor', 'variation')->fetch_by_name($filter);
      $config->{'min_frequency'} = $self->param('min_frequency');
    }
    
    $config->{'consequence_filter'} = { map { $_ => 1 } @consequence } if join('', @consequence) ne 'off';
    $config->{'evidence_filter'}    = { map { $_ => 1 } @evidence }    if join('', @evidence) ne 'off';
    $config->{'hide_long_snps'}     = $self->param('hide_long_snps') eq 'yes';
    $config->{'hide_rare_snps'}     = $self->param('hide_rare_snps');
    delete $config->{'hide_rare_snps'} if $config->{'hide_rare_snps'} eq 'off';
    $config->{'hidden_sources'}     = [$self->param('hidden_sources')];
  }
  
  # Get flanking sequence
  my ($upstream, $downstream, $offset) = $config->{'exons_only'} eq 'off' && $config->{'flanking'} ? $self->get_flanking_sequence_data($config, $exons[0], $exons[-1]) : ();
  
  if ($upstream) {
    $self->add_line_numbers('upstream', $config, $config->{'flanking'}, $offset);
    
    push @data, $export ? $upstream : {
      exint    => "5' upstream sequence", 
      Sequence => $self->build_sequence($upstream, $config)
    };
  }
  
  foreach my $exon (@exons) {
    my $next_exon  = $exons[++$i];
    my $exon_id    = $exon->stable_id;
    my $exon_start = $exon->seq_region_start;
    my $exon_end   = $exon->seq_region_end;

    $exon_id = "<strong>$exon_id</strong>" if $entry_exon && $entry_exon eq $exon_id;

    my $exon_seq = $self->get_exon_sequence_data($config, $exon);
    
    push @data, $export ? $exon_seq : {
      Number     => $i,
      exint      => $exon_id,
      Start      => sprintf('<a href="%s">%s</a>', $hub->url({ type => 'Location', action => 'View', r => "$chr_name:" . ($exon_start - 50) . '-' . ($exon_end + 50) }), $self->thousandify($strand == 1 ? $exon_start : $exon_end)),
      End        => sprintf('<a href="%s">%s</a>', $hub->url({ type => 'Location', action => 'View', r => "$chr_name:" . ($exon_start - 50) . '-' . ($exon_end + 50) }), $self->thousandify($strand == 1 ? $exon_end   : $exon_start)),
      StartPhase => $exon->phase     >= 0 ? $exon->phase     : '-',
      EndPhase   => $exon->end_phase >= 0 ? $exon->end_phase : '-',
      Length     => $self->thousandify(scalar @$exon_seq),
      Sequence   => $self->build_sequence($exon_seq, $config)
    };

    # Add intronic sequence
    if ($config->{'exons_only'} eq 'off' && $next_exon) {
      my ($intron_start, $intron_end) = $strand == 1 ? ($exon_end + 1, $next_exon->start - 1) : ($next_exon->end + 1, $exon_start - 1);
      my $intron_length = $intron_end - $intron_start + 1;
      my $intron_id     = "Intron $i-" . ($i + 1);
      my $intron_seq    = $self->get_intron_sequence_data($config, $exon, $next_exon, $intron_start, $intron_end, $intron_length);
      
      push @data, $export ? $intron_seq : {
        Number   => '&nbsp;',
        exint    => $intron_id,
        Start    => sprintf('<a href="%s">%s</a>', $hub->url({ type => 'Location', action => 'View', r => "$chr_name:" . ($intron_start - 50) . '-' . ($intron_end + 50) }), $self->thousandify($strand == 1 ? $intron_start : $intron_end)),
        End      => sprintf('<a href="%s">%s</a>', $hub->url({ type => 'Location', action => 'View', r => "$chr_name:" . ($intron_start - 50) . '-' . ($intron_end + 50) }), $self->thousandify($strand == 1 ? $intron_end   : $intron_start)),
        Length   => $self->thousandify($intron_length),
        Sequence => $self->build_sequence($intron_seq, $config)
      };
    }
  }
  
  if ($downstream) {
    $self->add_line_numbers('downstream', $config, $config->{'flanking'});
    
    push @data, $export ? $downstream : { 
      exint    => "3' downstream sequence", 
      Sequence => $self->build_sequence($downstream, $config,1)
    };
  }
  
  return (\@data, $config);
}

sub content {
  my $self = shift;
  my ($data, $config) = $self->initialize;
  my $html = $self->describe_filter($config);
  my $table = $self->new_table([
      { key => 'Number',     title => 'No.',           width => '6%',  align => 'left' },
      { key => 'exint',      title => 'Exon / Intron', width => '15%', align => 'left' },
      { key => 'Start',      title => 'Start',         width => '10%', align => 'left' },
      { key => 'End',        title => 'End',           width => '10%', align => 'left' },
      { key => 'StartPhase', title => 'Start Phase',   width => '7%',  align => 'left' },
      { key => 'EndPhase',   title => 'End Phase',     width => '7%',  align => 'left' },
      { key => 'Length',     title => 'Length',        width => '10%', align => 'left' },
      { key => 'Sequence',   title => 'Sequence',      width => '15%', align => 'left' }
    ], 
    $data, 
    { data_table => 'no_sort', exportable => 1 }
  );

  $html .= sprintf '<div class="_adornment_key adornment-key"></div><div class="adornment-load">'.$table->render."</div>";
  return $html;
}

sub export_options { return {'action' => 'ExonSeq'}; }

sub initialize_export {
  my $self = shift;
  my $hub = $self->hub;
  my ($data, $config) = $self->initialize(1);
  return ($data, $config, 1);
}

sub get_exon_sequence_data {
  my ($self, $config, $exon) = @_;
  my $coding_start = $config->{'coding_start'};
  my $coding_end   = $config->{'coding_end'};
  my $strand       = $config->{'strand'};
  my $seq          = uc $exon->seq->seq;
  my $seq_length   = length $seq;
  my $exon_start   = $exon->start;
  my $exon_end     = $exon->end;
  my $utr_start    = $coding_start && $coding_start > $exon_start; # exon starts with UTR
  my $utr_end      = $coding_end   && $coding_end   < $exon_end;   # exon ends with UTR
  my $class        = defined $coding_start ? 'e1' : 'e0';
  my $utr_class    = defined $coding_start ? 'eu' : 'e0';
  my $utr_key      = defined $coding_start ? 'utr' : 'exon0';
  my @sequence     = map {{ letter => $_, class => $class }} split '', $seq;
  my ($coding_length, $utr_length);
  
  if ($utr_start || $utr_end) {
    if ($strand == 1) {
      $coding_length = $seq_length - ($exon_end - $coding_end);
      $utr_length    = $coding_start - $exon_start;
    } else {
      $coding_length = $exon_end - $coding_start + 1;
      $utr_length    = $exon_end - $coding_end;
      ($utr_start, $utr_end) = ($utr_end, $utr_start);
    }
    
    if ($utr_end) {
      $coding_length = 0 if $coding_length < 0;
      $sequence[$_]{'class'} = $utr_class for $coding_length..$seq_length - 1;
      $config->{'key'}{'exons/Introns'}{$utr_key} = 1;
    }
    
    if ($utr_start) {
      $sequence[$_]{'class'} = $utr_class for 0..($utr_length < $seq_length ? $utr_length : $seq_length) - 1;
      $config->{'key'}{'exons/Introns'}{$utr_key} = 1;
    }
  }
  
  $config->{'last_number'} = $strand == 1 ? $exon_start - 1 : $exon_end + 1 if $config->{'number'} eq 'slice'; # Ensures that line numbering is correct if there are no introns
  $config->{'key'}{'exons/Introns'}{$coding_start && $coding_end ? 'exon1' : $utr_key} = 1;
  
  $self->add_variations($config, $exon->feature_Slice, \@sequence) if $config->{'snp_display'} ne 'off';
  
  if ($config->{'number'} eq 'cds') {
    if (defined $coding_start && (!defined $utr_length || $utr_length > 0 || $coding_length > 0)) {
      my $skip = $utr_start ? $utr_length : 0;
      $self->add_line_numbers('exon', $config, ($utr_end ? $coding_length : $seq_length) - $skip, $skip);
    }
  } else {
    $self->add_line_numbers('exon', $config, $seq_length);
  }

  return \@sequence;
}

sub get_intron_sequence_data {
  my ($self, $config, $exon, $next_exon, $intron_start, $intron_end, $intron_length) = @_;
  my $display_width = $config->{'display_width'};
  my $strand        = $config->{'strand'};
  my $sscon         = $config->{'sscon'};
  my @dots          = map {{ letter => $_, class => 'ei' }} split '', '.' x ($display_width - 2 * ($sscon % ($display_width / 2)));
  my @sequence;
  
  eval {
    if ((!$config->{'full_seq'} || $config->{'full_seq'} eq 'off') && $intron_length > ($sscon * 2)) {
      my $start = { slice => $exon->slice->sub_Slice($intron_start, $intron_start + $sscon - 1, $strand) };
      my $end   = { slice => $next_exon->slice->sub_Slice($intron_end - ($sscon - 1), $intron_end, $strand) };
      
      $start->{'sequence'} = [ map {{ letter => $_, class => 'ei' }} split '', lc $start->{'slice'}->seq ];
      $end->{'sequence'}   = [ map {{ letter => $_, class => 'ei' }} split '', lc $end->{'slice'}->seq   ];
     
      if ($config->{'snp_display'} eq 'on') {
        $self->add_variations($config, $_->{'slice'}, $_->{'sequence'}) for $start, $end;
      }
      
      $self->add_line_numbers('intron', $config, $intron_length, 1);
      
      @sequence = $strand == 1 ? (@{$start->{'sequence'}}, @dots, @{$end->{'sequence'}}) : (@{$end->{'sequence'}}, @dots, @{$start->{'sequence'}});
    } else {
      my $slice = $exon->slice->sub_Slice($intron_start, $intron_end, $strand);
      
      @sequence = map {{ letter => $_, class => 'ei' }} split '', lc $slice->seq;
      
      $self->add_variations($config, $slice, \@sequence) if $config->{'snp_display'} eq 'on';
      $self->add_line_numbers('intron', $config, $intron_length);
    }
  };
  
  $config->{'key'}{'exons/Introns'}{'intron'} = 1;
  
  return \@sequence;
}

sub get_flanking_sequence_data {
  my ($self, $config, $first_exon, $last_exon) = @_;
  my $display_width = $config->{'display_width'};
  my $strand        = $config->{'strand'};
  my $flanking      = $config->{'flanking'};
  my @dots          = $display_width == $flanking ? () : map {{ letter => $_, class => 'ef' }} split '', '.' x ($display_width - ($flanking % $display_width));
  my ($upstream, $downstream);

  if ($strand == 1) {
    $upstream = { 
      slice => $first_exon->slice->sub_Slice($first_exon->start - $flanking, $first_exon->start - 1, $strand),
      seq   => $first_exon->slice->subseq($first_exon->start    - $flanking, $first_exon->start - 1, $strand)
    };
    
    $downstream = {
      slice => $last_exon->slice->sub_Slice($last_exon->end + 1, $last_exon->end + $flanking, $strand),
      seq   => $last_exon->slice->subseq($last_exon->end    + 1, $last_exon->end + $flanking, $strand)
    };
  } else {
    $upstream = {
      slice => $first_exon->slice->sub_Slice($first_exon->end + 1, $first_exon->end + $flanking, $strand),
      seq   => $first_exon->slice->subseq($first_exon->end    + 1, $first_exon->end + $flanking, $strand)
    };
    
    $downstream = {
      slice => $last_exon->slice->sub_Slice($last_exon->start - $flanking, $last_exon->start - 1, $strand),
      seq   => $last_exon->slice->subseq($last_exon->start    - $flanking, $last_exon->start - 1, $strand)
    };
  }
  
  $upstream->{'sequence'}   = [ map {{ letter => $_, class => 'ef' }} split '', lc $upstream->{'seq'}   ];
  $downstream->{'sequence'} = [ map {{ letter => $_, class => 'ef' }} split '', lc $downstream->{'seq'} ];
  
  if ($config->{'snp_display'} eq 'on') {
    $self->add_variations($config, $upstream->{'slice'}, $upstream->{'sequence'}, 'upstream');
    $self->add_variations($config, $downstream->{'slice'}, $downstream->{'sequence'}, 'downstream');
  }
  
  my @upstream_sequence   = (@dots, @{$upstream->{'sequence'}});
  my @downstream_sequence = (@{$downstream->{'sequence'}}, @dots);
  
  $config->{'key'}{'exons/Introns'}{'flanking'} = 1;
  
  return (\@upstream_sequence, \@downstream_sequence, scalar @dots);
}

sub add_variations {
  my ($self, $config, $slice, $sequence, $flank) = @_;

  my $hub = $self->hub;

  my $adorn = $hub->param('adorn') || 'none';

  return if $adorn eq 'none';

  my $object = $self->object || $hub->core_object('transcript');
  my $vf_adaptor = $hub->database('variation')->get_VariationFeatureAdaptor;
  my $vf_slice = $slice->strand == -1 ? $slice->invert : $slice;
  my $variation_features    = $config->{'population'} ? $vf_adaptor->fetch_all_by_Slice_Population($vf_slice, $config->{'population'}, $config->{'min_frequency'}) : $vf_adaptor->fetch_all_by_Slice($vf_slice);
  my @variations;

  ## Filter and sort variants
  if ($flank) {
    @variations = @{$variation_features||[]};
    if($config->{'hide_rare_snps'}) {
      @variations = grep {
        !$self->too_rare_snp($_, $config)
      } @variations;
    }
    if($config->{'hidden_sources'}) {
      @variations = grep {
        !$self->hidden_source($_, $config)
      } @variations;
    }
    @variations = grep $_->length <= $config->{'snp_length_filter'}, @variations if $config->{'hide_long_snps'};
    @variations = (map $_->[1], sort { $b->[0] <=> $a->[0] } map [ $_->length, $_ ], @variations);
  }
  else {
    ## Within the transcript we only want transcript variants, so we get the correct consequence
    @variations = @{$hub->get_adaptor('get_TranscriptVariationAdaptor', 'variation')->fetch_all_by_VariationFeatures($variation_features, [ $object->Obj ])};
    if($config->{'hide_rare_snps'}) {
      @variations = grep {
        !$self->too_rare_snp($_->variation_feature, $config)
      } @variations;
    }
    if($config->{'hidden_sources'}) {
      @variations = grep {
        !$self->hidden_source($_->variation_feature, $config)
      } @variations;
    }
    @variations = grep $_->variation_feature->length <= $config->{'snp_length_filter'}, @variations if $config->{'hide_long_snps'};
    @variations = (map $_->[2], sort { $b->[0] <=> $a->[0] || $b->[1] <=> $a->[1] } map [ $_->variation_feature->length, $_->most_severe_OverlapConsequence->rank, $_ ], @variations);
  }
  my $length = scalar @$sequence - 1;
  my (%href, %class);

  my %cf = %{$config->{'consequence_filter'}||{}};
  delete $cf{'off'} if exists $cf{'off'};
  my %ef = %{$config->{'evidence_filter'}||{}};
  delete $ef{'off'} if exists $ef{'off'};

  foreach my $variation (@variations) {
    my ($name, $start, $end, $consequence, $vf);

    if ($flank) {
      my $flanking  = $config->{'flanking'};
      $name         = $variation->name;
      $start        = ($slice->strand == 1) ? $variation->start - 1 : $flanking - $variation->start;
      $end          = ($slice->strand == 1) ? $variation->end - 1  : $flanking - $variation->end;
      $consequence  = $flank.'_gene_variant';
    }
    else {
      $vf          = $variation->variation_feature;
      $vf          = $vf->transfer($slice) if ($vf->slice + 0) ne ($slice + 0);
      $name        = $vf->variation_name;
      $start       = $vf->start - 1;
      $end         = $vf->end   - 1;
      $consequence = $variation->consequence_type->[0];
      next if (%ef && !grep $ef{$_}, @{$vf->get_all_evidence_values});
    }

    $consequence ||= lc $variation->display_consequence;
    next if (%cf && !$cf{$consequence});

    # Variation is an insert if start > end
    ($start, $end) = ($end, $start) if $start > $end;
    
    $start = 0 if $start < 0;
    $end   = $length if $end > $length;
    
    $config->{'key'}{'variants'}{lc($consequence)} = 1;
    
    for ($start..$end) {
      $class{$_}  = $consequence;
      $href{$_} ||= {
        type        => 'ZMenu',
        action      => 'TextSequence',
        factorytype => 'Location'
      };
      
      push @{$href{$_}{'v'}},  $name;
      if ($vf) {
        push @{$href{$_}{'vf'}}, $vf->dbID;
      }
      else {
        push @{$href{$_}{'vf'}}, $variation->dbID; #upstream/downstream variant object is in fact variation feature obj.
        push @{$href{$_}{'flanking_variant'}}, 1;
      }
      if($config->{'variants_as_n'}) {
        $sequence->[$_]{'letter'} = 'N';
      }
    }
  }
  
  $sequence->[$_]{'class'} .= " $class{$_}"        for keys %class;
  $sequence->[$_]{'href'}   = $hub->url($href{$_}) for keys %href;
}

sub add_line_numbers {
  my ($self, $type, $config, $seq_length, $arg) = @_;
  
  return if $config->{'number'} eq 'off';
  return $config->{'lines'}++ if $seq_length < 1;
  return $config->{'lines'}++ unless $type eq 'exon' || $config->{'number'} =~ /^(gene|slice)$/;
  
  my $i            = $config->{'export'} ? $config->{'lines'}++ : 0;
  my $start        = $config->{'last_number'};
  my $strand       = $config->{'number'} eq 'slice' ? $config->{'strand'} : 1;
  my $length       = $start + ($seq_length * $strand);
  my $truncated    = $type eq 'intron'   ? $arg : undef;
  my $offset       = $type eq 'upstream' ? $arg : undef;
  my $skip         = $type eq 'exon'     ? $arg : undef;
  my $total_length = $length + $skip;
  my $end;
  
  if ($truncated) {
    $end = $length;
    push @{$config->{'line_numbers'}{$i}}, { start => $start + $strand, end => $end };
  } else {
    while (($strand == 1 && $end < $total_length) || ($strand == -1 && $start > $total_length)) {
      $end = $start + ($config->{'display_width'} * $strand);
      
      if ($skip > $start) {
        if ($skip < $end) {
          $end -= $skip;
        } else {
          push @{$config->{'line_numbers'}{$i}}, {};
          $skip -= $config->{'display_width'} * $strand;
          next;
        }
      }
      
      $end -= $strand * $offset if $offset;
      $end  = $length if ($strand == 1 && $end > $length) || ($strand == -1 && $end < $length);
      
      push @{$config->{'line_numbers'}{$i}}, { start => $start + $strand, end => $end };
      
      $start  = $end;
      $offset = $skip = 0;
      $config->{'padding'}{'number'} = length $start if length $start > $config->{'padding'}{'number'};
      $config->{'padding'}{'number'} = length $end if length $end > $config->{'padding'}{'number'};
      
      last if ($strand == 1 && $end >= $length) || ($strand == -1 && $start && $start <= $length);
    }
  }
  
  $config->{'padding'}{'number'} = length $end if length $end > $config->{'padding'}{'number'};
  $config->{'last_number'} = $end;
}

sub make_view {
  my ($self) = @_;

  my $view = EnsEMBL::Web::TextSequence::View::ExonsSpreadsheet->new(
    $self->hub,
  );
  $view->output($view->output->subslicer);
  return $view;
}

sub build_sequence {
  my ($self, $sequence, $config) = @_;
  $self->view->reset;
  $self->view->new_sequence;
  $self->view->sequences->[0]->legacy($sequence);
  $self->view->output->template('<pre class="text_sequence exon_sequence">%s</pre>');
  return $self->SUPER::build_sequence([ $sequence ], $config,1);
}

1;
