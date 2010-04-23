package EnsEMBL::Web::Component::Transcript::ExonsSpreadsheet;

use strict;

use RTF::Writer;

use EnsEMBL::Web::Document::SpreadSheet;
use EnsEMBL::Web::TmpFile::Text;

use base qw(EnsEMBL::Web::Component::Transcript EnsEMBL::Web::Component::TextSequence);

sub _init {
  my $self = shift;
  $self->cacheable(1);
  $self->ajaxable(1);
}

sub content {
  my $self       = shift;
  my $object     = $self->object; 
  my $only_exon  = $object->param('oexon') eq 'yes'; # display only exons
  my $entry_exon = $object->param('exon');
  my $export     = $object->param('export');
  my $transcript = $object->Obj;
  my @exons      = @{$transcript->get_all_Exons};
  my $strand     = $exons[0]->strand;
  my $chr_name   = $exons[0]->slice->seq_region_name;
  my $i          = 0;
  my @data;
  
  my $config = {
    display_width => $object->param('seq_cols') || 60,
    sscon         => $object->param('sscon')    || 25,   # no of bp to show either side of a splice site
    flanking      => $object->param('flanking') || 50,   # no of bp up/down stream of transcript
    full_seq      => $object->param('fullseq') eq 'yes', # flag to display full sequence (introns and exons)
    variation     => $object->param('variation'),
    coding_start  => $transcript->coding_region_start,
    coding_end    => $transcript->coding_region_end,
    strand        => $strand
  };
  
  $config->{'variation'} = 'off' unless $object->species_defs->databases->{'DATABASE_VARIATION'};
  
  if ($config->{'variation'} ne 'off') {
    my $filter = $object->param('population_filter');
    
    if ($filter && $filter ne 'off') {
      $config->{'population'}    = $object->get_adaptor('get_PopulationAdaptor', 'variation')->fetch_by_name($filter);
      $config->{'min_frequency'} = $object->param('min_frequency');
    }
  }
  
  foreach my $exon (@exons) {
    my $next_exon  = $exons[++$i];
    my $exon_id    = $exon->stable_id;
    my $exon_start = $exon->start;
    my $exon_end   = $exon->end;
    
    $exon_id = "<strong>$exon_id</strong>" if $entry_exon && $entry_exon eq $exon_id;
    
    my $exon_seq = $self->get_exon_sequence_data($config, $exon);
    
    push @data, $export ? $exon_seq : {
      Number     => $i,
      exint      => sprintf('<a href="%s">%s</a>', $object->_url({ type => 'Location', action => 'View', r => "$chr_name:" . ($exon_start - 50) . '-' . ($exon_end + 50) }), $exon_id),
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
      my $intron_id     = "Intron $i-" . ($i+1);
      my $intron_seq    = $self->get_intron_sequence_data($config, $exon, $next_exon, $intron_start, $intron_end, $intron_length);
      
      push @data, $export ? $intron_seq : {
        Number   => '&nbsp;',
        exint    => sprintf('<a href="%s">%s</a>', $object->_url({ type => 'Location', action => 'View', r => "$chr_name:" . ($intron_start - 50) . '-' . ($intron_end + 50) }), $intron_id),
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
  
  my $html;
  
  if ($export) {
    $html = $self->export_sequence(\@data, $config, sprintf 'Exons-%s-%s', $object->species, $object->stable_id);
  } else {    
    $html = sprintf('
      <div class="other-tool">
        <p><a class="seq_export export" href="%s;export=rtf">Download view as RTF</a></p>
      </div>', 
      $self->ajax_url
    );
    
    my $table = new EnsEMBL::Web::Document::SpreadSheet([
        { key => 'Number',     title => 'No.',           width => '6%',  align => 'center' },
        { key => 'exint',      title => 'Exon / Intron', width => '15%', align => 'center' },
        { key => 'Start',      title => 'Start',         width => '10%', align => 'right'  },
        { key => 'End',        title => 'End',           width => '10%', align => 'right'  },
        { key => 'StartPhase', title => 'Start Phase',   width => '7%',  align => 'center' },
        { key => 'EndPhase',   title => 'End Phase',     width => '7%',  align => 'center' },
        { key => 'Length',     title => 'Length',        width => '10%', align => 'right'  },
        { key => 'Sequence',   title => 'Sequence',      width => '15%', align => 'left'   }
      ], 
      \@data, 
      { margin => '1em 0px', data_table => 'no_sort' }
    );
    
    $html .= $table->render;
  }
  
  return $html;
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
  
  my $object = $self->object;
  
  my $variation_features = $config->{'population'} ? $slice->get_all_VariationFeatures_by_Population($config->{'population'}, $config->{'min_frequency'}) : $slice->get_all_VariationFeatures;
  
  foreach my $vf (@$variation_features) {
    my $name = $vf->variation_name;
    my $url  = $object->_url({ type => 'Variation', action => 'Summary', v => $name, vf => $vf->dbID, vdb => 'variation' });
    
    for ($vf->start-1..$vf->end-1) {
      $sequence->[$_]->{'class'} .= ' sn';
      $sequence->[$_]->{'title'}  = $name;
      $sequence->[$_]->{'url'}    = $url;
    }
  }
}

sub build_sequence {
  my ($self, $sequence, $config) = @_;
  
  foreach (@$sequence) {
    $_->{'letter'} = qq{<a href="$_->{'url'}">$_->{'letter'}</a>} if $_->{'url'};
  }
  
  $config->{'html_template'} = '<pre class="exon_sequence">%s</pre>';
  
  return $self->SUPER::build_sequence([ $sequence ], $config);
}

sub export_sequence {
  my $self = shift;
  my ($sequence, $config, $filename) = @_;
  
  my $object  = $self->object;
  my $space   = ' ' x $config->{'display_width'};
  my @colours = (undef);
  my @output;
  my ($i, $j);
  
  my $styles = $object->species_defs->colour('sequence_markup');
  
  my %class_to_style = (
    e0   => [ 1, { '\cf1'      => $styles->{'SEQ_EXON0'}->{'default'} }],
    e1   => [ 2, { '\cf2'      => $styles->{'SEQ_EXON1'}->{'default'} }],
    eu  =>  [ 3, { '\cf3'      => $styles->{'SEQ_EXONUTR'}->{'default'} }],
    ef  =>  [ 4, { '\cf4'      => $styles->{'SEQ_EXONFLANK'}->{'default'} }],
    sn   => [ 5, { '\chcbpat5' => $styles->{'SEQ_SNP'}->{'default'} }]
  );
  
  foreach my $class (sort { $class_to_style{$a}->[0] <=> $class_to_style{$b}->[0] } keys %class_to_style) {
    push @colours, [ map hex, unpack 'A2A2A2', $class_to_style{$class}->[1]->{$_} ] for sort grep /\d/, keys %{$class_to_style{$class}->[1]};
  }
  
  foreach my $part (@$sequence) {
    my ($section, $class, $previous_class, $count);
    
    $part->[-1]->{'end'} = 1;
    
    foreach my $seq (@$part) {
      $class = join ' ', sort { $class_to_style{$a}->[0] <=> $class_to_style{$b}->[0] } split /\s+/, $seq->{'class'};
      
      if ($count == $config->{'display_width'} || $seq->{'end'} || defined $previous_class && $class ne $previous_class) {
        my $style = join '', map keys %{$class_to_style{$_}->[1]}, split / /, $previous_class;
        
        $section .= $seq->{'letter'} if $seq->{'end'};
        
        push @{$output[$i][$j]}, [ \$style, $section ];
        
        if ($count == $config->{'display_width'}) {
          $count = 0;
          $j++;
        }
        
        $section = '';
      }
      
      $section .= $seq->{'letter'};
      $count++;
      $previous_class = $class;
    }
    
    $i++;
    $j = 0;
  }
  
  my $string;
  my $file = new EnsEMBL::Web::TmpFile::Text(extension => 'rtf', prefix => '');
  
  my $rtf = RTF::Writer->new_to_string(\$string);

  $rtf->prolog(
    'fonts'  => [ 'Courier New' ],
    'colors' => \@colours,
  );
  
  foreach my $block (@output) {
    $rtf->paragraph(\'\fs20', $_) for @$block;
    $rtf->paragraph(\'\fs20', $space);
  }
  
  $rtf->close;
  
  print $file $string;
  
  $file->save;
  
  $object->input->header( -type => 'application/rtf', -attachment => "$filename.rtf" );
  
  return $file->content;
}

1;
