package EnsEMBL::Web::TextSequence::Annotation::TranscriptVariations;

use strict;
use warnings;

use parent qw(EnsEMBL::Web::TextSequence::Annotation::Variations);

use EnsEMBL::Web::Lazy::Hash qw(lazy_hash);

sub too_rare_snp {
  my ($self,$vf,$config) = @_;

  return 0 unless $config->{'hide_rare_snps'} and $config->{'hide_rare_snps'} ne 'off';
  my $val = abs $config->{'hide_rare_snps'};
  my $mul = ($config->{'hide_rare_snps'}<0)?-1:1;
  return ($mul>0) unless $vf->minor_allele_frequency;
  return ($vf->minor_allele_frequency - $val)*$mul < 0;
}

sub _transcript_variation_to_variation_feature {
  my ($self,$tv) = @_;

  my $vfid = $tv->_variation_feature_id;
  my $val = ($self->{'vf_cache'}||{})->{$vfid};
  return $val if defined $val;
  return $tv->variation_feature;
}

sub _get_transcript_variations {
  my ($self,$hub,$trans,$vf_cache) = @_;

  # Most VFs will be in slice for transcript, so cache them.
  if($vf_cache and !$self->{'vf_cache'}) {

    my $vfa = $hub->get_adaptor('get_VariationFeatureAdaptor','variation');
    $self->{'vf_cache'} = {};
    my $vfs = $vfa->fetch_all_by_Slice_constraint($trans->feature_Slice);
    $self->{'vf_cache'}{$_->dbID} = $_ for(@$vfs);
    $vfs = $vfa->fetch_all_somatic_by_Slice_constraint($trans->feature_Slice);
    $self->{'vf_cache'}{$_->dbID} = $_ for(@$vfs);
  }
  my $tva = $hub->get_adaptor('get_TranscriptVariationAdaptor', 'variation');
  return $tva->fetch_all_by_Transcripts_with_constraint([ $trans ]);
}

sub _get_variation_data {
  my ($self,$hub,$transcript, $slice, $include_utr,$strand,$conseq_filter_in) = @_;

  my $cd_start           = $transcript->cdna_coding_start;
  my $cd_end             = $transcript->cdna_coding_end;
  my @coding_sequence;
  if($cd_start) {
    @coding_sequence = split '', substr $transcript->seq->seq, $cd_start - 1, $cd_end - $cd_start + 1;
  }
  my %consequence_filter = map { $_ ? ($_ => 1) : () } @$conseq_filter_in;
     %consequence_filter = () if join('', keys %consequence_filter) eq 'off';
  my @data;

  foreach my $tv (@{$self->_get_transcript_variations($hub,$transcript,1)}) {
    my $pos = $tv->translation_start;

    next if !$include_utr && !$pos;
    next unless $tv->cdna_start && $tv->cdna_end;
    next if scalar keys %consequence_filter && !grep $consequence_filter{$_}, @{$tv->consequence_type};

    my $vf    = $self->_transcript_variation_to_variation_feature($tv) or next;
    my $vdbid = $vf->dbID;

    my $start = $vf->start;
    my $end   = $vf->end;

    push @data, lazy_hash({
      tva           => sub {
        return $tv->get_all_alternate_TranscriptVariationAlleles->[0];
      },
      tv            => $tv,
      vf            => $vf,
      position      => $pos,
      vdbid         => $vdbid,
      snp_source    => sub { $vf->source },
      snp_id        => sub { $vf->variation_name },
      ambigcode     => sub { $vf->ambig_code($strand) },
      codons        => sub {
        my $tva = $_[0]->get('tva');
        return $pos ? join(', ', split '/', $tva->display_codon_allele_string) : '';
      },
      allele        => sub { $vf->allele_string(undef, $strand) },
      pep_snp       => sub {
        my $tva = $_[0]->get('tva');
        return join(', ', split '/', $tva->pep_allele_string);
      },
      type          => sub { $tv->display_consequence },
      class         => sub { $vf->var_class },
      length        => $vf->length,
      indel         => sub { $vf->var_class =~ /in\-?del|insertion|deletion/ ? ($start > $end ? 'insert' : 'delete') : '' },
      codon_seq     => sub { [ map $coding_sequence[3 * ($pos - 1) + $_], 0..2 ] },
      codon_var_pos => sub { ($tv->cds_start + 2) - ($pos * 3) },
    });
  }

  @data = map $_->[2], sort { $a->[0] <=> $b->[0] || $a->[1] <=> $b->[1] } map [ $_->{'vf'}->length, $_->{'vf'}->most_severe_OverlapConsequence->rank, $_ ], @data;

  return \@data;
}

sub annotate {
  my ($self, $config, $slice_data, $mk, $seq, $hub,$real_sequence) = @_;

  my $transcript = $config->{'transcript'};
  my @exons = @{$transcript->get_all_Exons};
  my $trans_strand = $exons[0]->strand;
  my $cd_start     = $transcript->cdna_coding_start;
  my $cd_end       = $transcript->cdna_coding_end;
  my $start_phase  = $exons[0]->phase;
  my $start_pad    = $start_phase > 0 ? $start_phase : 0; # mid-codon?
  my $slice = $slice_data->{'slice'};
  return unless $slice_data->{'vtype'} eq 'main';
  my $has_var = exists $hub->species_defs->databases->{'DATABASE_VARIATION'};
  return unless $config->{'snp_display'} and $has_var;
  my @snps = reverse @{$self->_get_variation_data($hub,$config->{'transcript'},$slice, $config->{'utr'}, $trans_strand,$config->{'conseq_filter'})};

  my $protein_rope = $real_sequence->relation('protein');
  my $variation_rope = $real_sequence->relation('aux');

  foreach my $snp (@snps) {
    next if $config->{'hide_long_snps'} && $snp->{'vf'}->length > $config->{'snp_length_filter'};
    next if $self->too_rare_snp($snp->{'vf'},$config);
    $snp->{'position'}||=0;

    my $dbID              = $snp->{'vdbid'};
    my $tv                = $snp->{'tv'};
    my $var               = $snp->{'vf'}->transfer($slice);
    my $variation_name    = $snp->{'snp_id'};
    my $alleles           = $snp->{'allele'};
    my $ambigcode         = $snp->{'ambigcode'} || '*';
    my $amino_acid_pos    = $snp->{'position'} * 3 + $cd_start - 4 - $start_pad;
    my $type              = lc($config->{'consequence_types'} ? [ grep $config->{'consequence_types'}{$_}, @{$tv->consequence_type} ]->[0] : $snp->{'type'});
    my $start             = $tv->cdna_start;
    my $end               = $tv->cdna_end;
    my $pep_allele_string = $tv->pep_allele_string;
    my $aa_change         = $pep_allele_string =~ /\// && $tv->affects_peptide;
        
    # Variation is an insert if start > end
    ($start, $end) = ($end, $start) if $start > $end;
        
    ($_ += $start_pad)-- for $start, $end; # Adjust from start = 1 (slice coords) to start = 0 (sequence array)

    foreach ($start..$end) {
      $mk->{'variants'}{$_}{'alleles'}   .= ($mk->{'variants'}{$_}{'alleles'} ? ', ' : '') . $alleles;
      $mk->{'variants'}{$_}{'url_params'} = { vf => $dbID, vdb => 'variation' };
      $mk->{'variants'}{$_}{'transcript'} = 1;
          
      my $url = $mk->{'variants'}{$_}{'url_params'} ? { type => 'Variation', action => 'Explore', %{$mk->{'variants'}{$_}{'url_params'}} } : undef; 
      
      $mk->{'variants'}{$_}{'type'} = $type;

      if ($config->{'translation'} && $aa_change) {
        my $pseq = $protein_rope->legacy;
        foreach my $aa ($amino_acid_pos..$amino_acid_pos + 2) {
          $pseq->[$aa]{'class'}  = 'aa';
          $pseq->[$aa]{'title'} .= "\n" if $pseq->[$aa]{'title'}; 
          $pseq->[$aa]{'title'} .= "$variation_name: $pep_allele_string";       
        }
      }     
      push @{$mk->{'variants'}{$_}{'href'}{'vf'}}, $dbID;

      my $vseq = $variation_rope->legacy;
      $vseq->[$_]{'letter'} = $ambigcode;
      $vseq->[$_]{'new_letter'} = $ambigcode;
      $vseq->[$_]{'href'} = $hub->url($url);
      $vseq->[$_]{'title'} = $variation_name;
      $vseq->[$_]{'tag'} = 'a';
      $vseq->[$_]{'class'} = '';
    }
  }
}

1;
