# $Id$

package EnsEMBL::Web::Component::Gene::TranscriptComparison;

use strict;

use base qw(EnsEMBL::Web::Component::TextSequence EnsEMBL::Web::Component::Gene);

sub _init { $_[0]->SUPER::_init(100); }

sub initialize {
  my ($self, $slice, $start, $end) = @_;
  my $hub         = $self->hub;
  my @consequence = $hub->param('consequence_filter');
  
  my $config = {
    display_width   => $hub->param('display_width') || 60,
    species         => $hub->species,
    v_space         => "\n",
    comparison      => 1,
    exon_display    => 1,
    sub_slice_start => $start,
    sub_slice_end   => $end
  };

  for (qw(exons_only snp_display title_display line_numbering hide_long_snps)) {
    $config->{$_} = $hub->param($_) unless $hub->param($_) eq 'off';
  }
  
  $config->{'snp_display'}        = 0 unless $hub->species_defs->databases->{'DATABASE_VARIATION'};
  $config->{'consequence_filter'} = { map { $_ => 1 } @consequence } if $config->{'snp_display'} && join('', @consequence) ne 'off';
  
  if ($config->{'line_numbering'}) {
    $config->{'end_number'} = 1;
    $config->{'number'}     = 1;
  }
  
  my ($sequence, $markup) = $self->get_sequence_data($config);

  $self->markup_exons($sequence, $markup, $config);
  $self->markup_variation($sequence, $markup, $config) if $config->{'snp_display'};
  $self->markup_comparisons($sequence, $markup, $config);
  $self->markup_line_numbers($sequence, $config)       if $config->{'line_numbering'};
  
  return ($sequence, $config);
}

sub content {
  my $self   = shift;
  my $slice  = $self->object->slice; # Object for this section is the slice
  my $length = $slice->length;
  my $html;
  
  if (!$self->hub->param('t1')) {
    $html = $self->_info(
      'No transcripts selected',
      sprintf(
        'You must select transcripts using the "Select transcripts" button from menu on the left hand side of this page, or by clicking <a href="%s" class="modal_link" rel="modal_select_transcripts">here</a>.',
        $self->view_config->extra_tabs->[1]
      )
    ); 
  } elsif ($length >= $self->{'subslice_length'}) {
    $html .= '<div class="sequence_key"></div>' . $self->chunked_content($length, $self->{'subslice_length'}, { length => $length });
  } else {
    $html .= $self->content_sub_slice($slice); # Direct call if the sequence length is short enough
  }
  
  return $html;
}

sub content_sub_slice {
  my ($self, $slice) = @_;
  my $hub    = $self->hub;
  my $start  = $hub->param('subslice_start');
  my $end    = $hub->param('subslice_end');
  my $length = $hub->param('length');
  
  $slice ||= $self->object->slice;
  $slice   = $slice->sub_Slice($start, $end) if $start && $end;
  
  my ($sequence, $config) = $self->initialize($slice, $start, $end);
  
  if ($end && $end == $length) {
    $config->{'html_template'} = '<pre class="text_sequence">%s</pre>';
  } elsif ($start && $end) {
    $config->{'html_template'} = '<pre class="text_sequence" style="margin:0">%s</pre>';
  } else {
    $config->{'html_template'} = sprintf('<div class="sequence_key">%s</div>', $self->get_key($config)) . '<pre class="text_sequence">%s</pre>';
  }
  
  $config->{'html_template'} .= '<p class="invisible">.</p>';
  $self->id('');
  
  return $self->build_sequence($sequence, $config);
}

sub get_sequence_data {
  my ($self, $config) = @_;
  my $hub            = $self->hub;
  my $object         = $self->object;
  my $gene           = $object->Obj;
  my $gene_name      = $gene->external_name;
  my $subslice_start = $config->{'sub_slice_start'};
  my $subslice_end   = $config->{'sub_slice_end'};
  my $slice          = $object->slice;
     $slice          = $slice->sub_Slice($subslice_start, $subslice_end) if $subslice_start && $subslice_end;
  my $start          = $slice->start;
  my $length         = $slice->length;
  my $strand         = $slice->strand;
  my @gene_seq       = split '', $slice->seq;
  my %selected       = map { $hub->param("t$_") => $_ } grep s/^t(\d+)$/$1/, $hub->param;
  my @transcripts    = map { $selected{$_->stable_id} ? [ $selected{$_->stable_id}, $_ ] : () } @{$gene->get_all_Transcripts};
  my @sequence       = ([ map {{ letter => $_ }} @gene_seq ]);
  my @markup         = ({});
  
  push @{$config->{'slices'}}, { slice => $slice, name => $gene_name || $gene->stable_id };
  
  $_-- for grep $_, $subslice_start, $subslice_end;
  
  foreach my $transcript (map $_->[1], sort { $a->[0] <=> $b->[0] } @transcripts) {
    my $transcript_id   = $transcript->stable_id;
    my $transcript_name = $transcript->external_name || $transcript_id;
       $transcript_name = $transcript_id if $transcript_name eq $gene_name;
    my @exons           = @{$transcript->get_all_Exons};
    my @seq             = map {{ letter => $_ }} @gene_seq;
    my $type            = 'exon1';
    my $mk              = {};
    
    my ($crs, $cre, $transcript_start) = map $_ - $start, $transcript->coding_region_start, $transcript->coding_region_end, $transcript->start;
    my ($first_exon, $last_exon)       = map $exons[$_]->stable_id, 0, -1;
    
    if ($strand == -1) {
      $_ = $length - $_ - 1, for $crs, $cre;
      ($crs, $cre) = ($cre, $crs);
    }
    
    $crs--;
    
    for my $exon (@exons) {
      my $exon_id = $exon->stable_id;
      my ($s, $e) = map $_ - $start, $exon->start, $exon->end;
      
      if ($strand == -1) {
        $_ = $length - $_ - 1, for $s, $e;
        ($s, $e) = ($e, $s);
      }
      
      if ($subslice_start || $subslice_end) {        
        if ($e < 0 || $s > $subslice_end) {
          if (!$config->{'exons_only'} && (($exon_id eq $first_exon && $s > $subslice_end) || ($exon_id eq $last_exon && $e < 0))) {
            $seq[$_]{'letter'} = '-' for 0..$#seq;
          }
          
          next;
        }
        
        $s = 0           if $s < 0;
        $e = $length - 1 if $e >= $length;
      }
      
      if (!$config->{'exons_only'}) {
        if ($exon_id eq $first_exon && $s) {
          $seq[$_]{'letter'} = '-' for 0..$s-1;
        } elsif ($exon_id eq $last_exon) {
          $seq[$_]{'letter'} = '-' for $e+1..$#seq;
        }
      }
      
      if ($exon->phase == -1) {
        $type = 'eu';
      } elsif ($exon->end_phase == -1) {
        $type = 'exon1';
      }
      
      for ($s..$e) {
        push @{$mk->{'exons'}{$_}{'type'}}, $type;
        $type = $type eq 'exon1' ? 'eu' : 'exon1' if $_ == $crs || $_ == $cre;
        
        $mk->{'exons'}{$_}{'id'} .= ($mk->{'exons'}{$_}{'id'} ? "\n" : '') . $exon_id unless $mk->{'exons'}{$_}{'id'} =~ /$exon_id/;
      }
    }
    
    if ($config->{'exons_only'}) {
      $seq[$_]{'letter'} = '-' for grep !$mk->{'exons'}{$_}, 0..$#seq;
    }
    
    $self->set_variations($config, $slice, $mk, $transcript, \@seq) if $config->{'snp_display'};
    
    push @sequence, \@seq;
    push @markup, $mk;
    push @{$config->{'slices'}}, {
      slice => $slice,
      name  => sprintf(
        '<a href="%s"%s>%s</a>',
        $hub->url({ type => 'Transcript', action => 'Summary', t => $transcript_id }),
        $transcript_id eq $transcript_name ? '' : qq{title="$transcript_id"},
        $transcript_name
      )
    };
  }
  
  $config->{'ref_slice_seq'} = $sequence[0];
  $config->{'length'}        = $length;
  
  return (\@sequence, \@markup);
}

sub set_variations {
  my ($self, $config, $slice, $markup, $transcript, $sequence) = @_;
  my $variation_features    = $config->{'population'} ? $slice->get_all_VariationFeatures_by_Population($config->{'population'}, $config->{'min_frequency'}) : $slice->get_all_VariationFeatures;
  my @transcript_variations = @{$self->hub->get_adaptor('get_TranscriptVariationAdaptor', 'variation')->fetch_all_by_VariationFeatures($variation_features, [ $transcript ])};
     @transcript_variations = grep $_->variation_feature->length <= $self->{'snp_length_filter'}, @transcript_variations if $config->{'hide_long_snps'};
  my $length                = scalar @$sequence - 1;
  my $transcript_id         = $transcript->stable_id;
  my $strand                = $transcript->strand;
  my (%href, %class);
  
  foreach my $transcript_variation (map $_->[2], sort { $b->[0] <=> $a->[0] || $b->[1] <=> $a->[1] } map [ $_->variation_feature->length, $_->most_severe_OverlapConsequence->rank, $_ ], @transcript_variations) {
    my $consequence = $config->{'consequence_filter'} ? lc [ grep $config->{'consequence_filter'}{$_}, @{$transcript_variation->consequence_type} ]->[0] : undef;
    
    next if $config->{'consequence_filter'} && !$consequence;
    
    my $vf            = $transcript_variation->variation_feature;
    my $name          = $vf->variation_name;
    my $allele_string = $vf->allele_string(undef, $strand);
    my $dbID          = $vf->dbID;
    my $start         = $vf->start - 1;
    my $end           = $vf->end   - 1;
    
    # Variation is an insert if start > end
    ($start, $end) = ($end, $start) if $start > $end;
    
    $start = 0 if $start < 0;
    $end   = $length if $end > $length;
    
    $consequence ||= lc $transcript_variation->display_consequence;
    
    $config->{'key'}{'variations'}{$consequence} = 1;
    
    for ($start..$end) {
      next if $sequence->[$_]{'letter'} eq '-';
      
      $markup->{'variations'}{$_}{'type'}     = $consequence;
      $markup->{'variations'}{$_}{'alleles'} .= ($markup->{'variations'}{$_}{'alleles'} ? "\n" : '') . $allele_string;
      $markup->{'variations'}{$_}{'href'}   ||= {
        type        => 'ZMenu',
        action      => 'TextSequence',
        factorytype => 'Location',
        _transcript => $transcript_id,
      };
      
      push @{$markup->{'variations'}{$_}{'href'}{'v'}},  $name;
      push @{$markup->{'variations'}{$_}{'href'}{'vf'}}, $dbID;
    }
  }
}

sub class_to_style { return $_[0]->{'class_to_style'} ||= { %{$_[0]->SUPER::class_to_style}, intron => [ 9e9, { color => '#555555' } ] }; }

sub get_key {
  $_[1]->{'key'}{'exons/Introns'} = 1;
  $_[1]->{'key'}{'exons'} = 0;
  
  return shift->SUPER::get_key(@_, {
    exons           => {},
    'exons/Introns' => {
      exon1  => { class => 'e1',     text => 'Translated sequence'          },
      eu     => { class => 'eu',     text => 'UTR'                          },
      intron => { class => 'intron', text => 'Intron or gene sequence' }
    }
  });
}

1;
