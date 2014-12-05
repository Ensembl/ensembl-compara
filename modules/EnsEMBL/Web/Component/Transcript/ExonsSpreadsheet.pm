=head1 LICENSE

Copyright [1999-2014] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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
    exons_only    => $hub->param('exons_only') || $vc->get('exons_only'),
    display_width => $hub->param('display_width') || $vc->get('display_width'),
    sscon         => $hub->param('sscon') || $vc->get('sscon'),   # no of bp to show either side of a splice site
    flanking      => $hub->param('flanking') || $vc->get('flanking'),   # no of bp up/down stream of transcript
    full_seq      => $hub->param('fullseq') || $vc->get('fullseq'),     # flag to display full sequence (introns and exons)
    snp_display   => $hub->param('snp_display') || $vc->get('snp_display'),
    number        => $hub->param('line_numbering') || $vc->get('line_numbering'),
    coding_start  => $transcript->coding_region_start,
    coding_end    => $transcript->coding_region_end,
    strand        => $strand,
    export        => $export
  };
  
  $config->{'end_number'}  = $config->{'number'};
  $config->{'last_number'} = $strand == 1 ? $exons[0]->seq_region_start - $config->{'flanking'} - 1 : $exons[0]->seq_region_end + $config->{'flanking'} + 1 if $config->{'number'} eq 'slice';
  $config->{'snp_display'} = 'off' unless $hub->species_defs->databases->{'DATABASE_VARIATION'};
  
  if ($config->{'snp_display'} ne 'off') {
    my @consequence = $hub->param('consequence_filter');
    my $filter      = $hub->param('population_filter');
    
    if ($filter && $filter ne 'off') {
      $config->{'population'}    = $hub->get_adaptor('get_PopulationAdaptor', 'variation')->fetch_by_name($filter);
      $config->{'min_frequency'} = $hub->param('min_frequency');
    }
    
    $config->{'consequence_filter'} = { map { $_ => 1 } @consequence } if $config->{'snp_display'} ne 'off' && join('', @consequence) ne 'off';
    $config->{'hide_long_snps'}     = $hub->param('hide_long_snps') eq 'yes';
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
      exint      => sprintf('<a href="%s">%s</a>', $hub->url({ type => 'Location', action => 'View', r => "$chr_name:" . ($exon_start - 50) . '-' . ($exon_end + 50) }), $exon_id),
      Start      => $self->thousandify($strand == 1 ? $exon_start : $exon_end),
      End        => $self->thousandify($strand == 1 ? $exon_end   : $exon_start),
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
        exint    => sprintf('<a href="%s">%s</a>', $hub->url({ type => 'Location', action => 'View', r => "$chr_name:" . ($intron_start - 50) . '-' . ($intron_end + 50) }), $intron_id),
        Start    => $self->thousandify($strand == 1 ? $intron_start : $intron_end),
        End      => $self->thousandify($strand == 1 ? $intron_end   : $intron_start),
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

  return sprintf '<div class="adornment-key"></div><div class="adornment-load">'.$table->render."</div>";
}

sub export_options { return {'action' => 'ExonSeq'}; }

sub initialize_export {
  my $self = shift;
  my $hub = $self->hub;
  my ($data, $config) = $self->initialize(1);
  $config->{'v_space'} = "\n";
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
  my $class        = $coding_start && $coding_end ? 'e0' : 'eu';   # if the transcript is entirely UTR, use utr class for the whole sequence
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
      $sequence[$_]{'class'} = 'eu' for $coding_length..$seq_length - 1;
      $config->{'key'}{'exons/Introns'}{'utr'} = 1;
    }
    
    if ($utr_start) {
      $sequence[$_]{'class'} = 'eu' for 0..($utr_length < $seq_length ? $utr_length : $seq_length) - 1;
      $config->{'key'}{'exons/Introns'}{'utr'} = 1;
    }
  }
  
  $config->{'last_number'} = $strand == 1 ? $exon_start - 1 : $exon_end + 1 if $config->{'number'} eq 'slice'; # Ensures that line numbering is correct if there are no introns
  $config->{'key'}{'exons/Introns'}{$coding_start && $coding_end ? 'exon' : 'utr'} = 1;
  
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
  my @dots          = map {{ letter => $_, class => 'e1' }} split '', '.' x ($display_width - 2 * ($sscon % ($display_width / 2)));
  my @sequence;
  
  eval {
    if ((!$config->{'full_seq'} || $config->{'full_seq'} eq 'off') && $intron_length > ($sscon * 2)) {
      my $start = { slice => $exon->slice->sub_Slice($intron_start, $intron_start + $sscon - 1, $strand) };
      my $end   = { slice => $next_exon->slice->sub_Slice($intron_end - ($sscon - 1), $intron_end, $strand) };
      
      $start->{'sequence'} = [ map {{ letter => $_, class => 'e1' }} split '', lc $start->{'slice'}->seq ];
      $end->{'sequence'}   = [ map {{ letter => $_, class => 'e1' }} split '', lc $end->{'slice'}->seq   ];
     
      if ($config->{'snp_display'} eq 'on') {
        $self->add_variations($config, $_->{'slice'}, $_->{'sequence'}) for $start, $end;
      }
      
      $self->add_line_numbers('intron', $config, $intron_length, 1);
      
      @sequence = $strand == 1 ? (@{$start->{'sequence'}}, @dots, @{$end->{'sequence'}}) : (@{$end->{'sequence'}}, @dots, @{$start->{'sequence'}});
    } else {
      my $slice = $exon->slice->sub_Slice($intron_start, $intron_end, $strand);
      
      @sequence = map {{ letter => $_, class => 'e1' }} split '', lc $slice->seq;
      
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
  
  if ($config->{'snp_display'} eq 'yes') {
    $self->add_variations($config, $_->{'slice'}, $_->{'sequence'}) for $upstream, $downstream;
  }
  
  my @upstream_sequence   = (@dots, @{$upstream->{'sequence'}});
  my @downstream_sequence = (@{$downstream->{'sequence'}}, @dots);
  
  $config->{'key'}{'exons/Introns'}{'flanking'} = 1;
  
  return (\@upstream_sequence, \@downstream_sequence, scalar @dots);
}

sub add_variations {
  my ($self, $config, $slice, $sequence) = @_;

  my $adorn = $self->hub->param('adorn') || 'none';

  return if $adorn eq 'none';

  my $object = $self->object || $self->hub->core_object('transcript');
  my $variation_features    = $config->{'population'} ? $slice->get_all_VariationFeatures_by_Population($config->{'population'}, $config->{'min_frequency'}) : $slice->get_all_VariationFeatures;
  my @transcript_variations = @{$self->hub->get_adaptor('get_TranscriptVariationAdaptor', 'variation')->fetch_all_by_VariationFeatures($variation_features, [ $object->Obj ])};
     @transcript_variations = grep $_->variation_feature->length <= $self->{'snp_length_filter'}, @transcript_variations if $config->{'hide_long_snps'};
  my $length                = scalar @$sequence - 1;
  my (%href, %class);
  
  foreach my $transcript_variation (map $_->[2], sort { $b->[0] <=> $a->[0] || $b->[1] <=> $a->[1] } map [ $_->variation_feature->length, $_->most_severe_OverlapConsequence->rank, $_ ], @transcript_variations) {
    my $consequence = $config->{'consequence_filter'} ? lc [ grep $config->{'consequence_filter'}{$_}, @{$transcript_variation->consequence_type} ]->[0] : undef;

    next if $config->{'consequence_filter'} && %{$config->{'consequence_filter'}} && !$consequence;

    my $vf    = $transcript_variation->variation_feature;
    my $name  = $vf->variation_name;
    my $start = $vf->start - 1;
    my $end   = $vf->end   - 1;
    
    # Variation is an insert if start > end
    ($start, $end) = ($end, $start) if $start > $end;
    
    $start = 0 if $start < 0;
    $end   = $length if $end > $length;
    
    $consequence ||= lc $transcript_variation->display_consequence;
    
    $config->{'key'}{'variations'}{$consequence} = 1;
    
    for ($start..$end) {
      $class{$_}  = $consequence;
      $href{$_} ||= {
        type        => 'ZMenu',
        action      => 'TextSequence',
        factorytype => 'Location'
      };
      
      push @{$href{$_}{'v'}},  $name;
      push @{$href{$_}{'vf'}}, $vf->dbID;
    }
  }
  
  $sequence->[$_]{'class'} .= " $class{$_}"              for keys %class;
  $sequence->[$_]{'href'}   = $self->hub->url($href{$_}) for keys %href;
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
      
      last if ($strand == 1 && $end >= $length) || ($strand == -1 && $start && $start <= $length);
    }
  }
  
  $config->{'last_number'} = $end;
}

sub build_sequence {
  my ($self, $sequence, $config) = @_;
  $config->{'html_template'} = '<pre class="exon_sequence">%s</pre>';
  return $self->SUPER::build_sequence([ $sequence ], $config,1);
}

sub get_key {
  return shift->SUPER::get_key($_[0], {
    'exons/Introns' => {
      exon     => { class => 'e0', text => 'Translated sequence' },
      intron   => { class => 'e1', text => 'Intron sequence'     },
      utr      => { class => 'eu', text => 'UTR'                 },
      flanking => { class => 'ef', text => 'Flanking sequence'   },
    }
  },$_[2]);
}

1;
