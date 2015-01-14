=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Component::Transcript::TranscriptSeq;

use strict;
  
use base qw(EnsEMBL::Web::Component::TextSequence EnsEMBL::Web::Component::Transcript);

use List::Util qw(max);

sub get_sequence_data {
  my ($self, $object, $config,$adorn) = @_;
  my $hub          = $self->hub;
  my $trans        = $object->Obj;
  my $slice        = $trans->feature_Slice;
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

  my @reference_seq = map {{ letter => $_ }} split '', $seq;
  my $variation_seq = { name => 'snp_display', seq => [] };
  my $coding_seq    = { name => 'coding_seq',  seq => [] };
  my $protein_seq   = { name => 'translation', seq => [] };
  my @rna_seq; 

  if ($config->{'rna'}) {
    my @rna_notation = $object->rna_notation;
    
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
    
    if ($_ + 1 >= $cd_start && $_ + 1 <= $cd_end) {         
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
  
  # If the transcript starts mid-codon, make the protein sequence show -X- at the start
  if ($config->{'translation'} && $start_pad) {
    my $pos     = scalar grep $protein_seq->{'seq'}[$_]{'letter'} eq '.', 0..2; # Find the number of . characters at the start
    my @partial = qw(- X -);
    
    $protein_seq->{'seq'}[$pos]{'letter'} = $partial[$pos] while $pos--; # Replace . with as much of -X- as fits in the space
  }
  
  if ($config->{'snp_display'} and $adorn ne 'none') {
    foreach my $snp (reverse @{$object->variation_data($slice, $config->{'utr'}, $trans_strand)}) {
      next if $config->{'hide_long_snps'} && $snp->{'vf'}->length > $self->{'snp_length_filter'};
      
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
        $mk->{'variations'}{$_}{'alleles'}   .= ($mk->{'variations'}{$_}{'alleles'} ? ', ' : '') . $alleles;
        $mk->{'variations'}{$_}{'url_params'} = { vf => $dbID, vdb => 'variation' };
        $mk->{'variations'}{$_}{'transcript'} = 1;
        
        my $url = $mk->{'variations'}{$_}{'url_params'} ? $hub->url({ type => 'Variation', action => 'Explore', %{$mk->{'variations'}{$_}{'url_params'}} }) : '';
        
        $mk->{'variations'}{$_}{'type'} = $type;
        
        if ($config->{'translation'} && $aa_change) {
          foreach my $aa ($amino_acid_pos..$amino_acid_pos + 2) {
            $protein_seq->{'seq'}[$aa]{'class'}  = 'aa';
            $protein_seq->{'seq'}[$aa]{'title'} .= "\n" if $protein_seq->{'seq'}[$aa]{'title'};
            $protein_seq->{'seq'}[$aa]{'title'} .= "$variation_name: $pep_allele_string";
          }
        }
        
        $mk->{'variations'}{$_}{'href'} ||= {
          type        => 'ZMenu',
          action      => 'TextSequence',
          factorytype => 'Location'
        };
        
        push @{$mk->{'variations'}{$_}{'href'}{'vf'}}, $dbID;
        
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
        push @{$config->{'slices'}}, { slice => $slice, name => $_->{'name'} };
      }
    }
  }
  
  # It's much easier to calculate the sequence with UTR, then lop off both ends than to do it without
  # If you don't include UTR from the begining, you run into problems with $cd_start and $cd_end being "wrong"
  # as well as transcript variation starts and ends. This way involves much less hassle.
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
  
  return (\@sequence, \@markup);
}

sub markup_line_numbers {
  my ($self, $sequence, $config) = @_;
 
  # Keep track of which element of $sequence we are looking at
  my $n = 0;
  
  foreach my $sl (@{$config->{'slices'}}) {
    my $seq  = $sequence->[$n];
    my $data = $sl->{'slice'} ? { 
      dir   => 1,  
      start => 1,
      end   => $config->{'length'},
      label => ''
    } : {};
    
    my $s = 0;
    my $e = $config->{'display_width'} - 1;
    
    my $row_start = $data->{'start'};
    my ($start, $end);
    
    # One line longer than the sequence so we get the last line's numbers generated in the loop
    my $loop_end = $config->{'length'} + $config->{'display_width'};
    
    while ($e < $loop_end) {
      $start = '';
      $end   = '';
      
      my $seq_length = 0;
      my $segment    = '';
      
      # Build a segment containing the current line of sequence        
      for ($s..$e) {
        # Check the array element exists - must be done so we don't create new elements and mess up the padding at the end of the last line
        if ($seq->[$_]) {
          $seq_length++ if $config->{'line_numbering'} eq 'slice' || $seq->[$_]{'letter'} =~ /\w/;
          $segment .= $seq->[$_]{'letter'};
        }
      }
      
      # Reference sequence starting with N or NN means the transcript begins mid-codon, so reduce the sequence length accordingly.
      $seq_length -= length $1 if $segment =~ /^(N+)\w/;
      
      $end   = $e < $config->{'length'} ? $row_start + $seq_length - $data->{'dir'} : $data->{'end'};
      $start = $row_start if $seq_length;
      
      # If the line starts --,  =- or -= it is at the end of a protein section, so take one off the line number
      $start-- if $start > $data->{'start'} && $segment =~ /^([=-]{2})/;
      
      # Next line starts at current end + 1 for forward strand, or - 1 for reverse strand
      $row_start = $end + $data->{'dir'} if $start && $end;
      
      # Remove the line number if the sequence doesn't start at the beginning of the line
      $start = '' if $segment =~ /^(\.|N+\w)/;
      
      $s = $e + 1;
      
      push @{$config->{'line_numbers'}{$n}}, { start => $start, end => $end || undef };
      
      # Increase padding amount if required
      $config->{'padding'}{'number'} = length $start if length $start > $config->{'padding'}{'number'};
      
      $e += $config->{'display_width'};
    }
    
    $n++;
  }
  
  $config->{'padding'}{'pre_number'}++ if $config->{'padding'}{'pre_number'}; # Compensate for the : after the label
}

sub initialize {
  my $self   = shift;
  my $hub    = $self->hub;
  my $object = $self->object || $hub->core_object('transcript');

  my $type   = $hub->param('data_type') || $hub->type;
  my $vc = $self->view_config($type);
 
  my $adorn = $hub->param('adorn') || 'none';
 
  my $config = { 
    species         => $hub->species,
    maintain_colour => 1,
    transcript      => 1,
  };
 
  $config->{'display_width'} = $hub->param('display_width') || $vc->get('display_width'); 
  $config->{$_} = ($hub->param($_) eq 'on' || $vc->get($_) eq 'on') ? 1 : 0 for qw(exons codons coding_seq translation rna snp_display utr hide_long_snps);
  $config->{'codons'}      = $config->{'coding_seq'} = $config->{'translation'} = 0 unless $object->Obj->translation;
 
  if ($hub->param('line_numbering') ne 'off') {
    $config->{'line_numbering'} = 'on';
    $config->{'number'}         = 1;
  }
  
  $self->set_variation_filter($config);
  
  my ($sequence, $markup) = $self->get_sequence_data($object, $config,$adorn);
  
  $self->markup_exons($sequence, $markup, $config)     if $config->{'exons'};
  $self->markup_codons($sequence, $markup, $config)    if $config->{'codons'};
  if($adorn ne 'none') {
    $self->markup_variation($sequence, $markup, $config) if $config->{'snp_display'};  
    push @{$config->{'loaded'}||=[]},'variations';
  } else {
    push @{$config->{'loading'}||=[]},'variations';
  }
  $self->markup_line_numbers($sequence, $config)       if $config->{'line_numbering'};
  
  $config->{'v_space'} = "\n" if $config->{'coding_seq'} || $config->{'translation'} || $config->{'rna'};
  
  return ($sequence, $config);
}

sub content {
  my $self = shift;
  my ($sequence, $config) = $self->initialize;

  return $self->build_sequence($sequence, $config);
}

sub export_options { return {'action' => 'Transcript'}; }

sub initialize_export {
  my $self = shift;
  my $hub = $self->hub;
  my ($sequence, $config) = $self->initialize;
  return ($sequence, $config);
}

1;
