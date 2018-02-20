package EnsEMBL::Web::Query::Sequence::Transcript;

use strict;
use warnings;

use parent qw(EnsEMBL::Web::Query::Generic::Sequence);

use EnsEMBL::Web::Lazy::Hash qw(lazy_hash);

our $VERSION = 1;

sub precache {
  return {
    'seq-cdna-only' => {
      loop => 'transcripts',
      args => {
        conseq_filter => ["off"],
        adorn => "only",
        species => "Homo_sapiens",
        type => "core",
        config => {
          hide_long_snps => "",
          number => 1,
          utr => 1,
          transcript => 1,
          codons => 1,
          exons_case => 0,
          hide_rare_snps => "off",
          translation => 1,
          exons => 1,
          maintain_colour => 1,
          rna => 0,
          line_numbering => "on",
          species => "Homo_sapiens",
          coding_seq => 1,
          display_width => 60,
          snp_display => 1
        }
      }
    },
    'seq-cdna-none' => {
      loop => 'transcripts',
      args => {
        conseq_filter => ["off"],
        adorn => "none",
        species => "Homo_sapiens",
        type => "core",
        config => {
          hide_long_snps => "",
          number => 1,
          utr => 1,
          transcript => 1,
          codons => 1,
          exons_case => 0,
          hide_rare_snps => "off",
          translation => 1,
          exons => 1,
          maintain_colour => 1,
          rna => 0,
          line_numbering => "on",
          species => "Homo_sapiens",
          coding_seq => 1,
          display_width => 60,
          snp_display => 1
        }
      }
    }
  };
}

sub fixup {
  my ($self) = @_;

  $self->SUPER::fixup();

  # Fixup hrefs for links above variants
  if($self->phase eq 'post_process') {
    my $data = $self->data;
    foreach my $f (@$data) {
      my $seq = $f->{'sequence'};
      next unless $seq;
      foreach my $s (@$seq) {
        foreach my $el (@$s) {
          next unless $el->{'href'};
          $el->{'href'} = $self->context->hub->url($el->{'href'});
        }
      }
    }
  }
  $self->fixup_transcript('transcript','species','type');
}

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
  my ($self,$args,$vf_cache) = @_;

  my $trans = $args->{'transcript'};
  my $ads = $self->source('Adaptors');
  my $tva = $ads->transcript_variation_adaptor($args->{'species'});
  my $tvs = $tva->fetch_all_by_Transcripts_with_constraint([ $trans ], undef, 1);

  # Most VFs will be in slice for transcript, so cache them.
  if($vf_cache and !$self->{'vf_cache'}) {

    # if fetched from VCF, VFs will already be attached to TVs
    my $need_db_fetch = 0;
    foreach my $tv(@$tvs) {
      if(my $vf = $tv->{base_variation_feature} || $tv->{variation_feature}) {
        $self->{'vf_cache'}{$vf->dbID} = $vf;
      }
      else {
        $need_db_fetch = 1;
      }
    }

    if($need_db_fetch) {
      my $vfa = $ads->variation_feature_adaptor($args->{'species'}); 
      $self->{'vf_cache'} = {};
      my $vfs = $vfa->fetch_all_by_Slice_constraint($trans->feature_Slice);
      $self->{'vf_cache'}{$_->dbID} = $_ for(@$vfs);
      $vfs = $vfa->fetch_all_somatic_by_Slice_constraint($trans->feature_Slice);
      $self->{'vf_cache'}{$_->dbID} = $_ for(@$vfs);
    }
  }

  return $tvs;
}

sub _get_variation_data {
  my ($self,$args, $slice, $include_utr,$strand,$conseq_filter_in) = @_;

  my $transcript = $args->{'transcript'};
  my $cd_start           = $transcript->cdna_coding_start;
  my $cd_end             = $transcript->cdna_coding_end;
  my @coding_sequence;
  if($cd_start) {
    @coding_sequence = split '', substr $transcript->seq->seq, $cd_start - 1, $cd_end - $cd_start + 1;
  }
  my %consequence_filter = map { $_ ? ($_ => 1) : () } @$conseq_filter_in;
     %consequence_filter = () if join('', keys %consequence_filter) eq 'off';
  my @data;

  foreach my $tv (@{$self->_get_transcript_variations($args,1)}) {
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

sub get {
  my ($self,$args) = @_;

  my $ad = $self->source('Adaptors');
  my $trans = $args->{'transcript'};
  my $object = EnsEMBL::Web::Root->new_object('Transcript',$trans);
  my $slice = $trans->feature_Slice;
  my @exons = @{$trans->get_all_Exons};
  my $trans_strand = $exons[0]->strand;
  my $start_phase  = $exons[0]->phase;
  my $start_pad    = $start_phase > 0 ? $start_phase : 0; # Determines if the transcript starts mid-codon
  my $cd_start     = $trans->cdna_coding_start;
  my $cd_end       = $trans->cdna_coding_end;
  my $config = {%{$args->{'config'}}};
  my $adorn = $args->{'adorn'};

  my $seq;
  my $mk = {};
  if ($trans->translation) {
    my $five_prime  = $trans->five_prime_utr;
    my $three_prime = $trans->three_prime_utr;
        
    $_ = $_ ? $_->seq : $_ for $five_prime, $three_prime;
        
    $seq = join '', ($five_prime||''), $trans->translateable_seq, ($three_prime||'');
  } else {
    $seq = $trans->seq->seq;
  }
  my $length = length $seq;
  my @sequence;
  my @markup;

  my @reference_seq = map {{ letter => $_ }} split '', $seq;
  my $variation_seq = { name => 'snp_display', seq => [] };
  my $coding_seq    = { name => 'coding_seq',  seq => [] };
  my $protein_seq   = { name => 'translation', seq => [] };
  my @rna_seq;
  if ($config->{'rna'}) {
    my @rna_notation = $object->rna_notation($trans);
    
    if (@rna_notation) {
      @rna_seq = map {{ name => 'rna', seq => [ map {{ letter => $_ }} split '', $_ ] }} @rna_notation;
    } else {
      $config->{'rna'} = 0;
    }
  }

  if ($config->{'exons'}) {
    my $flip = 0;
    my $pos = $start_pad;
    
    foreach (@exons) {
      $pos += length $_->seq->seq;
      $flip = 1 - $flip;
      push @{$mk->{'exons'}{$pos}{'type'}}, $mk->{'exons'}{$pos}{'overlap'} ? 'exon2' : "exon$flip";
    }   
  }   
  delete $mk->{$length}; # We get a key which is too big, causing an empty span to be printed later

  $config->{'length'}    = $length;
  $config->{'seq_order'} = [ $config->{'species'} ];
  $config->{'slices'}    = [{ slice => $slice, name => $config->{'species'} }];

  for (0..$length - 1) {
    # Set default vaules
    $variation_seq->{'seq'}[$_]{'letter'} = ' ';
    $coding_seq->{'seq'}[$_]{'letter'}    = $protein_seq->{'seq'}[$_]{'letter'} = '.'; 
    
    if (defined $cd_start and $_ + 1 >= $cd_start && $_ + 1 <= $cd_end) {
      $coding_seq->{'seq'}[$_]{'letter'} = $reference_seq[$_]{'letter'} if $config->{'coding_seq'};
    } elsif ($config->{'codons'}) {
      $mk->{'codons'}{$_}{'class'} = 'cu';
    }     
  }
  
  $_ += $start_pad for $cd_start, $cd_end; # Shift values so that codons and variations appear in the right place

  my $can_translate = 0;

  eval {
    my $pep_obj    = $trans->translate;
    my $peptide    = $pep_obj->seq;
    my $flip       = 0;
    my $startphase = $trans->translation->start_Exon->phase;
    my $s          = 0;
    
    $can_translate = 1;
    
    if ($startphase > 0) {
      $s = 3 - $startphase;
      $peptide = substr $peptide, 1;
    }   
    
    for (my $i = $cd_start + $s - 1; $i + 2 <= $cd_end; $i += 3) {
      if ($config->{'codons'}) {
        $mk->{'codons'}{$i}{'class'} = $mk->{'codons'}{$i + 1}{'class'} = $mk->{'codons'}{$i + 2}{'class'} = "c$flip";
    
        $flip = 1 - $flip;
      }   
    
      if ($config->{'translation'}) {
        $protein_seq->{'seq'}[$i]{'letter'}     = $protein_seq->{'seq'}[$i + 2]{'letter'} = '-';
        $protein_seq->{'seq'}[$i + 1]{'letter'} = substr($peptide, int(($i + 1 - $cd_start) / 3), 1) || ($i + 1 < $cd_end ? '*' : '.'); 
      }   
    }   
  };  

  # If the transcript starts or ends mid-codon, make the protein sequence show -X- at the start or the end respectively
  if ($config->{'translation'}) {
    my ($pos_start, $pos_end, $strip_end);
    my @partial = qw(- X -);

    if ($start_pad) {
      ($pos_start) = grep $protein_seq->{'seq'}[$_ - 1]{'letter'} eq '.', 1..3; # Find the positions of . characters at the start
    }   

    # If length is multiple of 3, ignore it. If length is 1 or 2 more than a multiple of 3 we use 2 or 1 (respectively) characters from @partial to complete 3 bases.
    if ($strip_end = (3 - ($cd_end - $cd_start + 1) % 3) % 3) {
      ($pos_end) = grep $protein_seq->{'seq'}[$_ + 1]{'letter'} =~ /\*|\-/, -3..-1; # Find the positions of - or * characters at the end
    }   

    # Replace with as much of -X- as fits in the space and remove the extra chars from the end if required
    $protein_seq->{'seq'}[$pos_start]{'letter'} = $partial[ $pos_start ]  while $pos_start--;
    $protein_seq->{'seq'}[$pos_end]{'letter'}   = $partial[ $pos_end ]    while $pos_end++;

    splice @{$protein_seq->{'seq'}}, -1 * $strip_end if $strip_end;
  }

  my $has_var = exists
    $self->species_defs->config($args->{'species'},'databases')->{'DATABASE_VARIATION'};
  if ($config->{'snp_display'} and $adorn ne 'none' and $has_var) {
    foreach my $snp (reverse @{$self->_get_variation_data($args,$slice, $config->{'utr'}, $trans_strand,$args->{'conseq_filter'})}) {
      next if $config->{'hide_long_snps'} && $snp->{'vf'}->length > $self->{'snp_length_filter'};
      next if $self->too_rare_snp($snp->{'vf'},$config);
      next unless defined $snp->{'position'}; 

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
          foreach my $aa ($amino_acid_pos..$amino_acid_pos + 2) {
            $protein_seq->{'seq'}[$aa]{'class'}  = 'aa';
            $protein_seq->{'seq'}[$aa]{'title'} .= "\n" if $protein_seq->{'seq'}[$aa]{'title'};
            $protein_seq->{'seq'}[$aa]{'title'} .= "$variation_name: $pep_allele_string";      
          }
        }     
            
        $mk->{'variants'}{$_}{'href'} ||= {
          type        => 'ZMenu',
          action      => 'TextSequence',
          factorytype => 'Location'
        };    
            
        push @{$mk->{'variants'}{$_}{'href'}{'vf'}}, $dbID;
            
        $variation_seq->{'seq'}[$_]{'letter'} = $ambigcode;
        $variation_seq->{'seq'}[$_]{'new_letter'} = $ambigcode;
        $variation_seq->{'seq'}[$_]{'href'} = $url;
        $variation_seq->{'seq'}[$_]{'title'} = $variation_name;
        $variation_seq->{'seq'}[$_]{'tag'} = 'a';
        $variation_seq->{'seq'}[$_]{'class'} = '';
      }
    }
  }

  push @sequence, \@reference_seq;
  push @markup, $mk;
  
  for ($variation_seq, $coding_seq, $protein_seq, @rna_seq) {
    if ($config->{$_->{'name'}}) {
      if ($_->{'name'} eq 'snp_display') {
        unshift @sequence, $_->{'seq'};
        unshift @markup, {}; 
        unshift @{$config->{'seq_order'}}, $_->{'name'};
        unshift @{$config->{'slices'}}, {}; 
      } else {
        push @sequence, $_->{'seq'};
        push @markup, {}; 
        push @{$config->{'seq_order'}}, $_->{'name'};
        push @{$config->{'slices'}}, { slice => $slice, name => $_->{'name'} };      }
    }     
  }
 
  if (!$config->{'utr'}) {
    foreach (@sequence) {
      splice @$_, $cd_end;
      splice @$_, 0, $cd_start - 1;
    }     
        
    $length = scalar @{$sequence[0]};
        
    foreach my $mk (grep scalar keys %$_, @markup) {
      my $shifted; 
          
      foreach my $type (keys %$mk) {
        my %tmp = map { $_ - $cd_start + 1 >= 0 && $_ - $cd_start + 1 < $length ? ($_ - $cd_start + 1 => $mk->{$type}{$_}) : () } keys %{$mk->{$type}};
        my $decap = max(-1,grep {  $_-$cd_start+1 < 0 } keys %{$mk->{$type}});
        $shifted->{$type} = \%tmp;
        if($decap > 0 and $type eq 'exons') {
          $shifted->{$type}{0}{'type'} = $mk->{$type}{$decap}{'type'};
        }   
      }     
              
      $mk = $shifted;
    }
  }

 # Used to set the initial sequence colour
  if ($config->{'exons'}) {
    $_->{'exons'}{0}{'type'} ||= [ 'exon0' ] for @markup;
  }
 
  return [{ sequence => \@sequence, markup => \@markup }];
}

1;
