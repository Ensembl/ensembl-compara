package EnsEMBL::Web::Component::Transcript::TranscriptSeq;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Transcript);

sub _init {
  my $self = shift;
  $self->cacheable(1);
  $self->ajaxable(1);
}

sub caption {
  return undef;
}

sub get_sequence_data {
  my $self = shift;
  my ($object, $config) = @_;
  
  my $trans = $object->Obj;
  my @exons = @{$trans->get_all_Exons};
  my $trans_strand = $exons[0]->strand;
  my $cd_start = $trans->cdna_coding_start;
  my $cd_end = $trans->cdna_coding_end;

  my $mk = {};
  my $length = 0;
  my $flip = 0;
  my $seq = '';
  
  my @sequence;
  my @markup;

  my $variation_seq = { name => 'variation', seq => [] };
  my $coding_seq = { name => 'coding_seq', seq => [] };
  my $protein_seq = { name => 'translation', seq => [] };
  my $rna_seq = { name => 'rna', seq => [ map {{ letter => $_ }} (split (//, $object->rna_notation)) ] };
  
  my @reference_seq = map { 
    $length += length $_->seq->seq;
    $seq .= $_->seq->seq;
        
    if ($config->{'exons'}) {
      $flip = 1 - $flip;
      push (@{$mk->{'exons'}->{$length}->{'type'}}, $mk->{'exons'}->{$length}->{'overlap'} ? 'exon2' : "exon$flip");
    }
    
    map {{ 'letter' => $_ }} split (//, uc($_->seq->seq)) 
  } @exons;
  
  delete $mk->{$length}; # We get a key which is too big, causing an empty span to be printed later 
  
  # Used to se the initial sequence colour
  if ($config->{'exons'}) {
    $mk->{'exons'}->{0}->{'type'} = [ 'exon0' ];
  }
  
  $config->{'length'} = $length;
  $config->{'numbering'} = [1];
  $config->{'seq_order'} = [ $config->{'species'} ];
  $config->{'slices'} = [{ slice => $seq, name => $config->{'species'} }];
  
  for (0..$length-1) {
    # Set default vaules
    $variation_seq->{'seq'}->[$_]->{'letter'} = ' ';
    $coding_seq->{'seq'}->[$_]->{'letter'} = $protein_seq->{'seq'}->[$_]->{'letter'} = '.';
    
    if ($_+1 >= $cd_start && $_+1 <= $cd_end) {         
      $coding_seq->{'seq'}->[$_]->{'letter'} = $reference_seq[$_]->{'letter'} if $config->{'coding_seq'};
    } elsif ($config->{'codons'}) {
      $mk->{'codons'}->{$_} = 1;
      $mk->{'bg'}->{$_} = 'utr'; # Needed to colour variations correctly in untranslated sections
    }
  }
  
  my $can_translate = 0;
  
  eval {
    my $pep_obj = $trans->translate;
    my $peptide = $pep_obj->seq;
    my $flip = 0;
    my $startphase = $trans->translation->start_Exon->phase;
    my $s = 0;
    
    $can_translate = 1;
    
    if ($startphase > 0) {
      $s = 3 - $startphase;
      $peptide = substr($peptide, 1);
    }
    
    for (my $i = $cd_start + $s - 1; ($i+2) <= $cd_end; $i+=3) {
      if ($config->{'codons'}) {
        $mk->{'codons'}->{$i} = $mk->{'codons'}->{$i+1} = $mk->{'codons'}->{$i+2} = 1;
        $mk->{'bg'}->{$i} = $mk->{'bg'}->{$i+1} = $mk->{'bg'}->{$i+2} = "c$flip";
        
        $flip = 1 - $flip;
      }
      
      if ($config->{'translation'}) {        
        $protein_seq->{'seq'}->[$i]->{'letter'} = $protein_seq->{'seq'}->[$i+2]->{'letter'} = '-';
        $protein_seq->{'seq'}->[$i+1]->{'letter'} = substr($peptide, int(($i+1-$cd_start)/3), 1) || ($i+1 < $cd_end ? '*' : '.');
      }
    }
  };

  if ($config->{'variation'}) {    
    $object->database('variation');
    
    my $source = '';
    
    if (exists($object->species_defs->databases->{'ENSEMBL_GLOVAR'})) {
      $source = 'glovar';
      $object->database('glovar');
    }
    
    $source = 'variation' if $object->database('variation');
    
    my %snps = %{$trans->get_all_cdna_SNPs($source)};
    my %protein_features = $can_translate == 0 ? () : %{ $trans->get_all_peptide_variations($source) };

    foreach my $t (values %snps) {
      foreach my $snp (@$t) {
        # Due to some changes start of a variation can be greater than its end - insertion happened
        my ($st, $en);
        
        if ($snp->start > $snp->end) {
          $st = $snp->end;
          $en = $snp->start;
        } else {
          $en = $snp->end;
          $st = $snp->start;
        }
        
        foreach my $r ($st..$en) {  
          my $snpclass = $snp->var_class;
          my $ambigcode;
               
          $mk->{'variations'}->{$r-1}->{'alleles'} .= $snp->allele_string;
          $mk->{'variations'}->{$r-1}->{'url_params'} .= "source=" . $snp->source . ";snp=" . $snp->variation_name;
          $mk->{'variations'}->{$r-1}->{'type'} = 'transcript';
          
          my $url_params = $mk->{'variations'}->{$r-1}->{'url_params'};
          
          if ($snpclass eq 'snp' || $snpclass eq 'SNP - substitution') { 
            my $aa = int(($r - $cd_start + 3)/3);
            my $aa_bp = $aa * 3 + $cd_start - 3;
            my @Q = @{$protein_features{$aa}||[]};
                       
            $ambigcode = $snp->ambig_code;
            $mk->{'variations'}->{$r-1}->{'snp'} = ($mk->{'variations'}->{$r-1}->{'snp'} eq 'snp' || @Q != 1) ? 'snp' : 'syn';
            
            if ($snp->strand == -1 && $trans_strand == -1) {
              $ambigcode =~ tr/acgthvmrdbkynwsACGTDBKYHVMRNWS\//tgcadbkyhvmrnwsTGCAHVMRDBKYNWS\//;
              $mk->{'variations'}->{$r-1}->{'alleles'} =~ tr/acgthvmrdbkynwsACGTDBKYHVMRNWS\//tgcadbkyhvmrnwsTGCAHVMRDBKYNWS\//;
            }
            
            if ($config->{'translation'} && @Q > 1) {
              $protein_seq->{'seq'}->[$aa_bp-1]->{'letter'} = $protein_seq->{'seq'}->[$aa_bp+1]->{'letter'} = '=';
              $protein_seq->{'seq'}->[$aa_bp-1]->{'color'} = $config->{'colours'}->{'aminoacids'};
              $protein_seq->{'seq'}->[$aa_bp+2]->{'color'} = 'auto';
              $protein_seq->{'seq'}->[$_]->{'title'} = join (', ', @Q) for ($aa_bp-1..$aa_bp+1);
            }
          } else {            
            $mk->{'variations'}->{$r-1}->{'snp'}= 'indel';
          }
          
          $variation_seq->{'seq'}->[$r-1]->{'letter'} = $url_params ? qq{<a href="../snpview?$url_params">$ambigcode</a>} : $ambigcode;
        }
      }
    }
  }
   
  push (@sequence, \@reference_seq);
  push (@markup, $mk);
  
  for ($variation_seq, $coding_seq, $protein_seq, $rna_seq) {
    if ($config->{$_->{'name'}}) {
      if ($_->{'name'} eq 'variation') {
        unshift (@sequence, $_->{'seq'});
        unshift (@markup, {});
        unshift (@{$config->{'numbering'}}, 0);
        unshift (@{$config->{'seq_order'}}, $_->{'name'});
        unshift (@{$config->{'slices'}}, { slice => join ('', map { $_->{'letter'} } @{$_->{seq}}), name => $_->{'name'} });
      } else {
        push (@sequence, $_->{'seq'});
        push (@markup, {});
        push (@{$config->{'numbering'}}, 1);
        push (@{$config->{'seq_order'}}, $_->{'name'});
        push (@{$config->{'slices'}}, { slice => join ('', map { $_->{'letter'} } @{$_->{seq}}), name => $_->{'name'} });
      }
    }
  }
  
  return (\@sequence, \@markup);
}

sub content {
  my $self   = shift;
  my $object = $self->object;
  
  my $colours = $object->species_defs->colour('sequence_markup');
  my %c = map { $_ => $colours->{$_}->{'default'} } keys %$colours;
  
  my $config = { 
    display_width => $object->param('display_width') || 60,
    colours => \%c,
    species => $object->species,
    maintain_colour => 1
  };
  
  for ('exons', 'codons', 'coding_seq', 'translation', 'rna', 'variation', 'number') {
    $config->{$_} = ($object->param($_) eq "yes") ? 1 : 0;
  }
  
  $config->{'codons'} = $config->{'coding_seq'} = $config->{'translation'} = 0 unless $object->Obj->translation;
  $config->{'variation'} = 0 unless $object->species_defs->databases->{'DATABASE_VARIATION'};
  $config->{'rna'} = 0 unless $object->rna_notation;
  
  my ($sequence, $markup) = $self->get_sequence_data($object, $config);
  
  $self->markup_exons($sequence, $markup, $config) if $config->{'exons'};
  $self->markup_codons($sequence, $markup, $config) if $config->{'codons'};
  $self->markup_variation($sequence, $markup, $config) if $config->{'variation'};  
  $self->markup_line_numbers($sequence, $config) if $config->{'number'};
  
  $config->{'v_space'} = "\n" if ($config->{'coding_seq'} || $config->{'translation'} || $config->{'rna'});
  
  my $html = $self->build_sequence($sequence, $config);
  
  if ($config->{'codons'} || $config->{'variation'} || $config->{'translation'}  || $config->{'coding_seq'}) {
    $html .= qq(<img src="/i/help/transview_key3.gif" alt="[Key]" border="0" />);
  }
  
  return $html;
}

1;

