# $Id$

package EnsEMBL::Web::Component::Transcript::ExonsSpreadsheet;

use strict;

use RTF::Writer;

use EnsEMBL::Web::TmpFile::Text;

use base qw(EnsEMBL::Web::Component::Transcript EnsEMBL::Web::Component::TextSequence);

sub _init {
  my $self = shift;
  $self->cacheable(1);
  $self->ajaxable(1);
}

sub initialize {
  my ($self, $export) = @_;
  my $hub        = $self->hub;
  my $only_exon  = $hub->param('oexon') eq 'yes'; # display only exons
  my $entry_exon = $hub->param('exon');
  my $object     = $self->object;
  my $transcript = $object->Obj;
  my @exons      = @{$transcript->get_all_Exons};
  my $strand     = $exons[0]->strand;
  my $chr_name   = $exons[0]->slice->seq_region_name;
  my $i          = 0;
  my @data;
  
  my $config = {
    display_width => $hub->param('seq_cols') || 60,
    sscon         => $hub->param('sscon')    || 25,   # no of bp to show either side of a splice site
    flanking      => $hub->param('flanking') || 50,   # no of bp up/down stream of transcript
    full_seq      => $hub->param('fullseq') eq 'yes', # flag to display full sequence (introns and exons)
    variation     => $hub->param('variation'),
    coding_start  => $transcript->coding_region_start,
    coding_end    => $transcript->coding_region_end,
    strand        => $strand
  };
  
  $config->{'variation'} = 'off' unless $hub->species_defs->databases->{'DATABASE_VARIATION'};
  
  if ($config->{'variation'} ne 'off') {
    my $filter = $hub->param('population_filter');
    
    if ($filter && $filter ne 'off') {
      $config->{'population'}    = $hub->get_adaptor('get_PopulationAdaptor', 'variation')->fetch_by_name($filter);
      $config->{'min_frequency'} = $hub->param('min_frequency');
    }
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
      Start      => $self->thousandify($exon_start),
      End        => $self->thousandify($exon_end),
      StartPhase => $exon->phase     >= 0 ? $exon->phase     : '-',
      EndPhase   => $exon->end_phase >= 0 ? $exon->end_phase : '-',
      Length     => $self->thousandify(scalar @$exon_seq),
      Sequence   => $self->build_sequence($exon_seq, $config)
    };

    # Add intronic sequence
    if ($next_exon && !$only_exon) {
      my ($intron_start, $intron_end) = $strand == 1 ? ($exon_end + 1, $next_exon->start - 1) : ($next_exon->end + 1, $exon_start - 1);
      my $intron_length = $intron_end - $intron_start + 1;
      my $intron_id     = "Intron $i-" . ($i + 1);
      my $intron_seq    = $self->get_intron_sequence_data($config, $exon, $next_exon, $intron_start, $intron_end, $intron_length);
      
      push @data, $export ? $intron_seq : {
        Number   => '&nbsp;',
        exint    => sprintf('<a href="%s">%s</a>', $hub->url({ type => 'Location', action => 'View', r => "$chr_name:" . ($intron_start - 50) . '-' . ($intron_end + 50) }), $intron_id),
        Start    => $self->thousandify($intron_start),
        End      => $self->thousandify($intron_end),
        Length   => $self->thousandify($intron_length),
        Sequence => $self->build_sequence($intron_seq, $config)
      };
    }
  }

  # Add flanking sequence
  if ($config->{'flanking'} && !$only_exon) {
    my ($upstream, $downstream) = $self->get_flanking_sequence_data($config, $exons[0], $exons[-1]);
    
    unshift @data, $export ? $upstream : {
      exint    => "5' upstream sequence", 
      Sequence => $self->build_sequence($upstream, $config)
    };
    
    push @data, $export ? $downstream : { 
      exint    => "3' downstream sequence", 
      Sequence => $self->build_sequence($downstream, $config)
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
    { data_table => 'no_sort' }
  );
  
  my $html = $self->tool_buttons . $table->render;
     $html = sprintf '<div class="sequence_key">%s</div>%s', $self->get_key($config), $html if $config->{'variation'} ne 'off';
  
  return $html;
}

sub content_rtf {
  my $self = shift;
  my ($data, $config) = $self->initialize(1);
  $config->{'v_space'} = "\n";
  return $self->export_sequence($data, $config, sprintf('Exons-%s-%s', $self->hub->species, $self->object->stable_id), 1);
}

sub get_exon_sequence_data {
  my $self = shift;
  my ($config, $exon) = @_;
  
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
  my @sequence     = map {{ letter => $_, class => $class }} split //, $seq;

  if ($utr_start || $utr_end) {
    my ($coding_length, $utr_length);
    
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
      $sequence[$_]->{'class'} = 'eu' for $coding_length..$seq_length - 1;
    }
    
    if ($utr_start) {
      $sequence[$_]->{'class'} = 'eu' for 0..($utr_length < $seq_length ? $utr_length : $seq_length) - 1;
    }
  }

  $self->add_variations($config, $exon->feature_Slice, \@sequence) if $config->{'variation'} ne 'off';

  return \@sequence;
}

sub get_intron_sequence_data {
  my $self = shift;
  my ($config, $exon, $next_exon, $intron_start, $intron_end, $intron_length) = @_;
  
  my $display_width = $config->{'display_width'};
  my $strand        = $config->{'strand'};
  my $sscon         = $config->{'sscon'};
  my @dots          = map {{ letter => $_, class => 'e1' }} split //, '.' x ($display_width - 2*($sscon % ($display_width/2)));
  my @sequence;
  
  eval {
    if (!$config->{'full_seq'} && $intron_length > ($sscon * 2)) {
      my $start = { slice => $exon->slice->sub_Slice($intron_start, $intron_start + $sscon - 1, $strand) };
      my $end   = { slice => $next_exon->slice->sub_Slice($intron_end - ($sscon - 1), $intron_end, $strand) };
      
      $start->{'sequence'} = [ map {{ letter => $_, class => 'e1' }} split //, lc $start->{'slice'}->seq ];
      $end->{'sequence'}   = [ map {{ letter => $_, class => 'e1' }} split //, lc $end->{'slice'}->seq   ];
      
      if ($config->{'variation'} eq 'on') {
        $self->add_variations($config, $_->{'slice'}, $_->{'sequence'}) for $start, $end;
      }
      
      @sequence = $strand == 1 ? (@{$start->{'sequence'}}, @dots, @{$end->{'sequence'}}) : (@{$end->{'sequence'}}, @dots, @{$start->{'sequence'}});
    } else {
      my $slice = $exon->slice->sub_Slice($intron_start, $intron_end, $strand);
      
      @sequence = map {{ letter => $_, class => 'e1' }} split //, lc $slice->seq;
      
      $self->add_variations($config, $slice, \@sequence) if $config->{'variation'} eq 'on';
    }
  };
  
  return \@sequence;
}

sub get_flanking_sequence_data {
  my $self = shift;
  my ($config, $first_exon, $last_exon) = @_;
  
  my $display_width = $config->{'display_width'};
  my $strand        = $config->{'strand'};
  my $flanking      = $config->{'flanking'};
  my @dots          = map {{ letter => $_, class => 'ef' }} split //, '.' x ($display_width - ($flanking % $display_width));
  my ($upstream, $downstream);

  if ($strand == 1) {
    $upstream = { 
      slice => $first_exon->slice->sub_Slice($first_exon->start - $flanking, $first_exon->start - 1, $strand),
      seq   => $first_exon->slice->subseq($first_exon->start - $flanking, $first_exon->start - 1, $strand)
    };
    
    $downstream = {
      slice => $last_exon->slice->sub_Slice($last_exon->end + 1, $last_exon->end + $flanking, $strand),
      seq   => $last_exon->slice->subseq($last_exon->end + 1, $last_exon->end + $flanking, $strand)
    };
  } else {
    $upstream = {
      slice => $first_exon->slice->sub_Slice($first_exon->end + 1, $first_exon->end + $flanking, $strand),
      seq   => $first_exon->slice->subseq($first_exon->end + 1, $first_exon->end + $flanking, $strand)
    };
    
    $downstream = {
      slice => $last_exon->slice->sub_Slice($last_exon->start - $flanking, $last_exon->start - 1, $strand),
      seq   => $last_exon->slice->subseq($last_exon->start - $flanking, $last_exon->start - 1, $strand)
    };
  }
  
  $upstream->{'sequence'}   = [ map {{ letter => $_, class => 'ef' }} split //, lc $upstream->{'seq'}   ];
  $downstream->{'sequence'} = [ map {{ letter => $_, class => 'ef' }} split //, lc $downstream->{'seq'} ];
  
  if ($config->{'variation'} eq 'on') {
    $self->add_variations($config, $_->{'slice'}, $_->{'sequence'}) for $upstream, $downstream;
  }
  
  my @upstream_sequence   = (@dots, @{$upstream->{'sequence'}});
  my @downstream_sequence = (@{$downstream->{'sequence'}}, @dots);
  
  return (\@upstream_sequence, \@downstream_sequence);
}

sub add_variations {
  my ($self, $config, $slice, $sequence) = @_;
  
  my $transcript         = $self->object->Obj;
  my $variation_features = $config->{'population'} ? $slice->get_all_VariationFeatures_by_Population($config->{'population'}, $config->{'min_frequency'}) : $slice->get_all_VariationFeatures;
  
  my %href;
  
  foreach my $vf (@$variation_features) {
    my $transcript_variation = $vf->get_all_TranscriptVariations([$transcript])->[0];
    
    next unless $transcript_variation;
    
    my $class = lc $transcript_variation->display_consequence;
    my $name  = $vf->variation_name;
    
    $config->{'key'}->{'variations'}->{$class} = 1;
    $class = " $class";
    
    for ($vf->start-1..$vf->end-1) {
      $sequence->[$_]->{'class'} .= $class;
      $sequence->[$_]->{'title'}  = $name;
       
      $href{$_} ||= {
        type        => 'ZMenu',
        action      => 'TextSequence',
        factorytype => 'Location'
      };
      
      push @{$href{$_}->{'v'}},  $name;
      push @{$href{$_}->{'vf'}}, $vf->dbID;
    }
  }
  
  $sequence->[$_]->{'href'} = $self->hub->url($href{$_}) for keys %href;
}

sub build_sequence {
  my ($self, $sequence, $config) = @_;
  
  $config->{'html_template'} = '<pre class="exon_sequence">%s</pre>';
  
  return $self->SUPER::build_sequence([ $sequence ], $config);
}

1;
