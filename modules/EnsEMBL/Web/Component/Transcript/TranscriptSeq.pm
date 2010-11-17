# $Id$

package EnsEMBL::Web::Component::Transcript::TranscriptSeq;

use strict;
  
use base qw(EnsEMBL::Web::Component::Transcript EnsEMBL::Web::Component::TextSequence);

sub _init {
  my $self = shift;
  $self->cacheable(1);
  $self->ajaxable(1);
}

sub get_sequence_data {
  my $self = shift;
  my ($object, $config) = @_;
  
  my $hub          = $self->hub;
  my $trans        = $object->Obj;
  my @exons        = @{$trans->get_all_Exons};
  my $trans_strand = $exons[0]->strand;
  my $start_phase  = $exons[0]->phase;
  my $start_pad    = $start_phase > 0 ? $start_phase : 0; # Determines if the transcript starts mid-codon
  my $cd_start     = $trans->cdna_coding_start;
  my $cd_end       = $trans->cdna_coding_end;
  my $mk           = {};
  my $seq;
  
  if ($trans->translation) {
    my $five_prime  = $trans->five_prime_utr;
    my $three_prime = $trans->three_prime_utr;
    
    $_ = $_ ? $_->seq : $_ for $five_prime, $three_prime;
    
    $seq = join '', $five_prime, $trans->translateable_seq, $three_prime;
  } else {
    $seq = $trans->seq->seq;
  }
      
  my $length = length $seq;
  
  my @sequence;
  my @markup;

  my @reference_seq = map {{ letter => $_ }} split //, $seq;
  my $variation_seq = { name => 'variation',   seq => [] };
  my $coding_seq    = { name => 'coding_seq',  seq => [] };
  my $protein_seq   = { name => 'translation', seq => [] };
  my @rna_seq; 

  if ($config->{'rna'}) {
    my @rna_notation = $object->rna_notation;
    
    if (@rna_notation) {
      @rna_seq = map {{ name => 'rna', seq => [ map {{ letter => $_ }} split //, $_ ] }} @rna_notation;
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
      push @{$mk->{'exons'}->{$pos}->{'type'}}, $mk->{'exons'}->{$pos}->{'overlap'} ? 'exon2' : "exon$flip";
    }
  }  
  
  delete $mk->{$length}; # We get a key which is too big, causing an empty span to be printed later 
    
  $config->{'length'}    = $length;
  $config->{'numbering'} = [1];
  $config->{'seq_order'} = [ $config->{'species'} ];
  $config->{'slices'}    = [{ slice => $seq, name => $config->{'species'} }];
  
  for (0..$length-1) {
    # Set default vaules
    $variation_seq->{'seq'}->[$_]->{'letter'} = ' ';
    $coding_seq->{'seq'}->[$_]->{'letter'}    = $protein_seq->{'seq'}->[$_]->{'letter'} = '.';
    
    if ($_+1 >= $cd_start && $_+1 <= $cd_end) {         
      $coding_seq->{'seq'}->[$_]->{'letter'} = $reference_seq[$_]->{'letter'} if $config->{'coding_seq'};
    } elsif ($config->{'codons'}) {
      $mk->{'codons'}->{$_}->{'class'} = 'cu';
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
        $mk->{'codons'}->{$i}->{'class'} = $mk->{'codons'}->{$i+1}->{'class'} = $mk->{'codons'}->{$i+2}->{'class'} = "c$flip";
        
        $flip = 1 - $flip;
      }
      
      if ($config->{'translation'}) {        
        $protein_seq->{'seq'}->[$i]->{'letter'} = $protein_seq->{'seq'}->[$i+2]->{'letter'} = '-';
        $protein_seq->{'seq'}->[$i+1]->{'letter'} = substr($peptide, int(($i + 1 - $cd_start) / 3), 1) || ($i + 1 < $cd_end ? '*' : '.');
      }
    }
  };
  
  # If the transcript starts mid-codon, make the protein sequence show -X- at the start
  if ($config->{'translation'} && $start_pad) {
    my $pos     = scalar grep $protein_seq->{'seq'}->[$_]->{'letter'} eq '.', 0..2; # Find the number of . characters at the start
    my @partial = qw(- X -);
    
    $protein_seq->{'seq'}->[$pos]->{'letter'} = $partial[$pos] while $pos--; # Replace . with as much of -X- as fits in the space
  }
  
  if ($config->{'variation'}) {
    my $slice  = $trans->feature_Slice;
    my $filter = $hub->param('population_filter');
    my %population_filter;
    
    if ($filter && $filter ne 'off') {
      %population_filter = map { $_->dbID => $_ }
        @{$slice->get_all_VariationFeatures_by_Population(
          $hub->get_adaptor('get_PopulationAdaptor', 'variation')->fetch_by_name($filter), 
          $hub->param('min_frequency')
        )};
    }
    
    foreach my $snp (@{$object->variation_data($config->{'utr'})}) {
      my $tv = $snp->{'tv'};
      my ($start, $end) = ($tv->cdna_start, $tv->cdna_end);
      
      next unless $start && $end;
      
      my $var  = $snp->{'vf'}->transfer($slice);
      my $dbID = $snp->{'vdbid'};
      
      next if keys %population_filter && !$population_filter{$dbID};
      
      my $variation_name    = $snp->{'snp_id'};
      my $alleles           = $snp->{'allele'};
      my $ambigcode         = $snp->{'ambigcode'} || '*';
      my $pep_allele_string = $tv->pep_allele_string;
      my $amino_acid_pos    = $snp->{'position'} * 3 + $cd_start - 4 - $start_pad;
      my $consequence_type  = join ' ', @{$tv->consequence_type};
      my $aa_change         = $consequence_type =~ /\b(NON_SYNONYMOUS_CODING|FRAMESHIFT_CODING|STOP_LOST|STOP_GAINED)\b/;
      my $type              = lc $snp->{'type'};
      
      if ($var->strand == -1 && $trans_strand == -1) {
        $ambigcode =~ tr/acgthvmrdbkynwsACGTDBKYHVMRNWS\//tgcadbkyhvmrnwsTGCAHVMRDBKYNWS\//;
        $alleles   =~ tr/acgthvmrdbkynwsACGTDBKYHVMRNWS\//tgcadbkyhvmrnwsTGCAHVMRDBKYNWS\//;
      }
      
      # Variation is an insert if start > end
      ($start, $end) = ($end, $start) if $start > $end;
      
      ($_ += $start_pad)-- for $start, $end; # Adjust from start = 1 (slice coords) to start = 0 (sequence array)
      
      foreach ($start..$end) {
        $mk->{'variations'}->{$_}->{'alleles'}   .= ($mk->{'variations'}->{$_}->{'alleles'} ? ', ' : '') . $alleles;
        $mk->{'variations'}->{$_}->{'url_params'} = { v => $variation_name, vf => $dbID, vdb => 'variation' };
        $mk->{'variations'}->{$_}->{'transcript'} = 1;
        
        my $url = $mk->{'variations'}->{$_}->{'url_params'} ? $hub->url({ type => 'Variation', action => 'Summary', %{$mk->{'variations'}->{$_}->{'url_params'}} }) : '';
        
        $mk->{'variations'}->{$_}->{'type'} = $type;
        
        if ($config->{'translation'} && $aa_change) {
          $protein_seq->{'seq'}->[$amino_acid_pos]->{'letter'}     = 
          $protein_seq->{'seq'}->[$amino_acid_pos + 2]->{'letter'} = '=';
          
          foreach my $aa ($amino_acid_pos..$amino_acid_pos + 2) {
            $protein_seq->{'seq'}->[$aa]->{'class'}  = 'aa';
            $protein_seq->{'seq'}->[$aa]->{'title'} .= ', ' if $protein_seq->{'seq'}->[$aa]->{'title'};
            $protein_seq->{'seq'}->[$aa]->{'title'} .= $pep_allele_string;
          }
        }
        
        $mk->{'variations'}->{$_}->{'href'} ||= {
          type        => 'ZMenu',
          action      => 'TextSequence',
          factorytype => 'Location'
        };
        
        push @{$mk->{'variations'}->{$_}->{'href'}->{'v'}},  $variation_name;
        push @{$mk->{'variations'}->{$_}->{'href'}->{'vf'}}, $dbID;
        
        $variation_seq->{'seq'}->[$_]->{'letter'} = $url ? qq{<a href="$url" title="$variation_name">$ambigcode</a>} : $ambigcode;
        $variation_seq->{'seq'}->[$_]->{'url'}    = $url;
      }
    }
  }
  
  push @sequence, \@reference_seq;
  push @markup, $mk;
  
  for ($variation_seq, $coding_seq, $protein_seq, @rna_seq) {
    if ($config->{$_->{'name'}}) {
      if ($_->{'name'} eq 'variation') {
        unshift @sequence, $_->{'seq'};
        unshift @markup, {};
        unshift @{$config->{'numbering'}}, 0;
        unshift @{$config->{'seq_order'}}, $_->{'name'};
        unshift @{$config->{'slices'}}, { slice => join('', map $_->{'letter'}, @{$_->{'seq'}}), name => $_->{'name'} };
      } else {
        push @sequence, $_->{'seq'};
        push @markup, {};
        push @{$config->{'numbering'}}, 1;
        push @{$config->{'seq_order'}}, $_->{'name'};
        push @{$config->{'slices'}}, { slice => join('', map $_->{'letter'}, @{$_->{'seq'}}), name => $_->{'name'} };
      }
    }
  }
  
  # It's much easier to calculate the sequence with UTR, then lop off both ends than to do it without
  # If you don't include UTR from the begining, you run into problems with $cd_start and $cd_end being "wrong"
  # as well as transcript variation starts and ends. This way involves much less hassle.
  if (!$config->{'utr'}) {
    foreach (@sequence) {
      splice @$_, $cd_end;
      splice @$_, 0, $cd_start-1;
    }
    
    $length = scalar @{$sequence[0]};
    
    foreach my $mk (grep scalar keys %$_, @markup) {
      my $shifted;
      
      foreach my $type (keys %$mk) {
        my %tmp = map { $_-$cd_start+1 >= 0 && $_-$cd_start+1 < $length ? ($_-$cd_start+1 => $mk->{$type}->{$_}) : () } keys %{$mk->{$type}};
        $shifted->{$type} = \%tmp;
      }
      
      $mk = $shifted;
    }
  }
  
  # Used to set the initial sequence colour
  if ($config->{'exons'}) {
    $_->{'exons'}->{0}->{'type'} = [ 'exon0' ] for @markup;
  }
  
  return (\@sequence, \@markup, $seq);
}

sub initialize {
  my $self   = shift;
  my $hub    = $self->hub;
  my $object = $self->object;
  
  my $config = { 
    display_width   => $hub->param('display_width') || 60,
    species         => $hub->species,
    maintain_colour => 1,
    transcript      => 1
  };
  
  $config->{$_} = $hub->param($_) eq 'yes' ? 1 : 0 for qw(exons codons coding_seq translation rna variation number utr);
  
  $config->{'codons'}    = $config->{'coding_seq'} = $config->{'translation'} = 0 unless $object->Obj->translation;
  $config->{'variation'} = 0 unless $hub->species_defs->databases->{'DATABASE_VARIATION'};
  
  my ($sequence, $markup, $raw_seq) = $self->get_sequence_data($object, $config);
  
  $self->markup_exons($sequence, $markup, $config)     if $config->{'exons'};
  $self->markup_codons($sequence, $markup, $config)    if $config->{'codons'};
  $self->markup_variation($sequence, $markup, $config) if $config->{'variation'};  
  $self->markup_line_numbers($sequence, $config)       if $config->{'number'};
  
  $config->{'v_space'} = "\n" if $config->{'coding_seq'} || $config->{'translation'} || $config->{'rna'};
  
  return ($sequence, $config, $raw_seq);
}

sub content {
  my $self = shift;
  my $hub  = $self->hub;
  
  my ($sequence, $config, $raw_seq) = $self->initialize;
  
  my $html = sprintf('
    <div class="other-tool">
      <p><a class="seq_export export" href="%s">Download view as RTF</a></p>
    </div>
    <div class="other-tool">
      <p><a class="seq_blast find" href="#">BLAST this sequence</a></p>
      <form class="external hidden seq_blast" action="/Multi/blastview" method="post">
        <fieldset>
          <input type="hidden" name="_query_sequence" value="%s" />
          <input type="hidden" name="species" value="%s" />
        </fieldset>
      </form>
    </div>', 
    $self->ajax_url('rtf'),
    $raw_seq,
    $config->{'species'}
  );
  
  $html .= sprintf('<div class="sequence_key">%s</div>', $self->get_key($config));
  $html .= $self->build_sequence($sequence, $config);

  return $html;
}

sub content_rtf {
  my $self = shift;
  my ($sequence, $config) = $self->initialize;
  return $self->export_sequence($sequence, $config, sprintf 'cDNA-Sequence-%s-%s', $config->{'species'}, $self->object->stable_id);
}

1;
