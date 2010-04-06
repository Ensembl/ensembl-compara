package EnsEMBL::Web::Component::Transcript::TranscriptSeq;

use strict;

use RTF::Writer;

use EnsEMBL::Web::TmpFile::Text;
  
use base qw(EnsEMBL::Web::Component::Transcript EnsEMBL::Web::Component::TextSequence);

sub _init {
  my $self = shift;
  $self->cacheable(1);
  $self->ajaxable(1);
}

sub get_sequence_data {
  my $self = shift;
  my ($object, $config) = @_;
  
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
  my $rna_seq       = { name => 'rna',         seq => [ map {{ letter => $_ }} split //, $object->rna_notation ] };
  
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
  
  # Used to se the initial sequence colour
  $mk->{'exons'}->{0}->{'type'} = [ 'exon0' ] if $config->{'exons'};
  
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
    my $filter = $object->param('population_filter');
    my %population_filter;
    
    if ($filter && $filter ne 'off') {
      %population_filter = map { $_->dbID => $_ }
        @{$slice->get_all_VariationFeatures_by_Population(
          $object->get_adaptor('get_PopulationAdaptor', 'variation')->fetch_by_name($filter), 
          $object->param('min_frequency')
        )};
    }
    
    foreach my $transcript_variation (@{$object->get_transcript_variations}) {
      my ($start, $end) = ($transcript_variation->cdna_start, $transcript_variation->cdna_end);
      
      next unless $start && $end;
      
      my $var  = $transcript_variation->variation_feature->transfer($slice);
      my $dbID = $var->dbID;
      
      next if keys %population_filter && !$population_filter{$dbID};
      
      my $var_class         = $var->var_class;
      my $variation_name    = $var->variation_name;
      my $alleles           = $var->allele_string;
      my $ambigcode         = $var->ambig_code || '*';
      my $pep_allele_string = $transcript_variation->pep_allele_string;
      my $amino_acid_pos    = $transcript_variation->translation_start * 3 + $cd_start - 4 - $start_pad;
      my $consequence_type  = join '', @{$transcript_variation->consequence_type};
      my $utr_var           = $consequence_type =~ /UTR/;
      my $frameshift_var    = $consequence_type =~ /FRAMESHIFT/;
      my $allele_count      = scalar split /\//, $pep_allele_string;
      my $insert            = 0;
      
      if ($var->strand == -1 && $trans_strand == -1) {
        $ambigcode =~ tr/acgthvmrdbkynwsACGTDBKYHVMRNWS\//tgcadbkyhvmrnwsTGCAHVMRDBKYNWS\//;
        $alleles   =~ tr/acgthvmrdbkynwsACGTDBKYHVMRNWS\//tgcadbkyhvmrnwsTGCAHVMRDBKYNWS\//;
      }
      
      # Variation is an insert if start > end
      if ($start > $end) {
        ($start, $end, $insert) = ($end, $start, 1);
        $insert = 1;
      }
      
      ($_ += $start_pad)-- for $start, $end; # Adjust from start = 1 (slice coords) to start = 0 (sequence array)
      
      foreach ($start..$end) {
        $mk->{'variations'}->{$_}->{'alleles'}   .= ($mk->{'variations'}->{$_}->{'alleles'} ? ', ' : '') . $alleles;
        $mk->{'variations'}->{$_}->{'url_params'} = { v => $variation_name, vf => $dbID, vdb => 'variation' };
        $mk->{'variations'}->{$_}->{'transcript'} = 1;
        
        my $url = $mk->{'variations'}->{$_}->{'url_params'} ? $object->_url({ type => 'Variation', action => 'Summary', %{$mk->{'variations'}->{$_}->{'url_params'}} }) : '';
        
        if ($frameshift_var) {
          $mk->{'variations'}->{$_}->{'type'} = 'frameshift';
        } elsif ($var_class eq 'in-del') {
          $mk->{'variations'}->{$_}->{'type'} = $insert ? 'insert' : 'delete';
        } else {
          $mk->{'variations'}->{$_}->{'type'} = $utr_var || $allele_count > 1 ? 'snp' : 'syn';
          
          if ($config->{'translation'} && $allele_count > 1) {
            $protein_seq->{'seq'}->[$amino_acid_pos]->{'letter'}     = 
            $protein_seq->{'seq'}->[$amino_acid_pos + 2]->{'letter'} = '=';
            
            foreach my $aa ($amino_acid_pos..$amino_acid_pos + 2) {
              $protein_seq->{'seq'}->[$aa]->{'class'}  = 'aa';
              $protein_seq->{'seq'}->[$aa]->{'title'} .= ', ' if $protein_seq->{'seq'}->[$aa]->{'title'};
              $protein_seq->{'seq'}->[$aa]->{'title'} .= $pep_allele_string;
            }
          }
        }
        
        $mk->{'variations'}->{$_}->{'type'} .= 'utr' if $config->{'codons'} && $mk->{'codons'}->{$_} && $mk->{'codons'}->{$_}->{'class'} eq 'cu';
        
        $variation_seq->{'seq'}->[$_]->{'letter'} = $url ? qq{<a href="$url" title="$variation_name">$ambigcode</a>} : $ambigcode;
        $variation_seq->{'seq'}->[$_]->{'url'}    = $url;
      }
    }
  }
  
  push @sequence, \@reference_seq;
  push @markup, $mk;
  
  for ($variation_seq, $coding_seq, $protein_seq, $rna_seq) {
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
    
    foreach my $mk (grep scalar keys %$_, @markup) {
      my $shifted;
      
      foreach my $type (keys %$mk) {
        my %tmp = map { $_-$cd_start+1 => $mk->{$type}->{$_} } keys %{$mk->{$type}};
        $shifted->{$type} = \%tmp;
      }
      
      $mk = $shifted;
    }
  }
  
  return (\@sequence, \@markup, $seq);
}

sub content {
  my $self = shift;
  my $object = $self->object;
  
  my $html;
  
  my $config = { 
    display_width   => $object->param('display_width') || 60,
    species         => $object->species,
    maintain_colour => 1
  };
  
  $config->{$_} = $object->param($_) eq 'yes' ? 1 : 0 for qw(exons codons coding_seq translation rna variation number utr);
  
  $config->{'codons'} = $config->{'coding_seq'} = $config->{'translation'} = 0 unless $object->Obj->translation;
  
  $config->{'variation'} = 0 unless $object->species_defs->databases->{'DATABASE_VARIATION'};
  $config->{'rna'}       = 0 unless $object->rna_notation;
  
  my ($sequence, $markup, $raw_seq) = $self->get_sequence_data($object, $config);
  
  $self->markup_exons($sequence, $markup, $config)     if $config->{'exons'};
  $self->markup_codons($sequence, $markup, $config)    if $config->{'codons'};
  $self->markup_variation($sequence, $markup, $config) if $config->{'variation'};  
  $self->markup_line_numbers($sequence, $config)       if $config->{'number'};
  
  $config->{'v_space'} = "\n" if $config->{'coding_seq'} || $config->{'translation'} || $config->{'rna'};
  
  if ($object->param('export')) {
    $html = $self->export_sequence($sequence, $config, sprintf 'cDNA-Sequence-%s-%s', $config->{'species'}, $object->stable_id);
  } else {    
    $html = sprintf('
      <div class="other-tool">
        <p><a class="seq_export export" href="%s;export=rtf">Download view as RTF</a></p>
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
      $self->ajax_url,
      $raw_seq,
      $config->{'species'}
    );
    
    $html .= $self->build_sequence($sequence, $config);
    $html .= '<img src="/i/help/transview_key3.gif" alt="[Key]" border="0" />' if $config->{'codons'} || $config->{'variation'} || $config->{'translation'} || $config->{'coding_seq'};
  }
  
  return $html;
}

sub export_sequence {
  my $self = shift;
  my ($sequence, $config, $filename) = @_;
  
  my $object  = $self->object;
  my @colours = (undef);
  my @output;
  my ($i, $j);
  
  my $styles = $object->species_defs->colour('sequence_markup');
  
  my %class_to_style = (
    con  => [ 1,  { '\chcbpat1'  => $styles->{'SEQ_CONSERVATION'}->{'default'} }],
    dif  => [ 2,  { '\chcbpat2'  => $styles->{'SEQ_DIFFERENCE'}->{'default'} }],
    res  => [ 3,  { '\cf3'       => $styles->{'SEQ_RESEQEUNCING'}->{'default'} }],
    e0   => [ 4,  { '\cf4'       => $styles->{'SEQ_EXON0'}->{'default'} }],
    e1   => [ 5,  { '\cf5'       => $styles->{'SEQ_EXON1'}->{'default'} }],
    e2   => [ 6,  { '\cf6'       => $styles->{'SEQ_EXON2'}->{'default'} }],
    eo   => [ 7,  { '\chcbpat7'  => $styles->{'SEQ_EXONOTHER'}->{'default'} }],
    eg   => [ 8,  { '\cf8'       => $styles->{'SEQ_EXONGENE'}->{'default'}, '\b' => 1 }],
    c0   => [ 9,  { '\chcbpat9'  => $styles->{'SEQ_CODONC0'}->{'default'} }],
    c1   => [ 10, { '\chcbpat10' => $styles->{'SEQ_CODONC1'}->{'default'} }],
    cu   => [ 11, { '\chcbpat11' => $styles->{'SEQ_CODONUTR'}->{'default'} }],
    sn   => [ 12, { '\chcbpat12' => $styles->{'SEQ_SNP'}->{'default'} }],      
    si   => [ 13, { '\chcbpat13' => $styles->{'SEQ_SNPINSERT'}->{'default'} }],
    sd   => [ 14, { '\chcbpat14' => $styles->{'SEQ_SNPDELETE'}->{'default'} }],   
    snt  => [ 15, { '\chcbpat15' => $styles->{'SEQ_SNP_TR'}->{'default'} }],
    syn  => [ 16, { '\chcbpat16' => $styles->{'SEQ_SYN'}->{'default'} }],
    snu  => [ 17, { '\chcbpat17' => $styles->{'SEQ_SNP_TR_UTR'}->{'default'} }],
    siu  => [ 18, { '\chcbpat18' => $styles->{'SEQ_SNPINSERT_TR_UTR'}->{'default'} }],
    sdu  => [ 19, { '\chcbpat19' => $styles->{'SEQ_SNPDELETE_TR_UTR'}->{'default'} }],
    sf   => [ 20, { '\chcbpat20' => $styles->{'SEQ_FRAMESHIFT'}->{'default'} }],
    aa   => [ 21, { '\cf21'      => $styles->{'SEQ_AMINOACID'}->{'default'} }],
    var  => [ 22, { '\cf22'      => $styles->{'SEQ_MAIN_SNP'}->{'default'} }],
    end  => [ 23, { '\cf23'      => $styles->{'SEQ_REGION_CHANGE'}->{'default'}, '\chcbpat24' => $styles->{'SEQ_REGION_CHANGE_BG'}->{'default'} }],
    bold => [ 24, { '\b'         => 1 }]
  );
  
  foreach my $class (sort { $class_to_style{$a}->[0] <=> $class_to_style{$b}->[0] } keys %class_to_style) {
    push @colours, [ map hex, unpack 'A2A2A2', $class_to_style{$class}->[1]->{$_} ] for sort grep /\d/, keys %{$class_to_style{$class}->[1]};
  }
  
  foreach my $lines (@$sequence) {
    my ($section, $class, $previous_class, $count);
    
    $lines->[-1]->{'end'} = 1;
    
    foreach my $seq (@$lines) {
      if ($seq->{'class'}) {
        $class = $seq->{'class'};
       
        if ($config->{'maintain_colour'} && $previous_class =~ /\s*(e\w)\s*/ && $class !~ /\s*(e\w)\s*/) {
          $class .= " $1";
        }
      } elsif ($config->{'maintain_colour'} && $previous_class =~ /\s*(e\w)\s*/) {
        $class = $1;
      } else {
        $class = '';
      }
      
      $class = join ' ', sort { $class_to_style{$a}->[0] <=> $class_to_style{$b}->[0] } split /\s+/, $class;
      
      if ($count == $config->{'display_width'} || $seq->{'end'} || defined $previous_class && $class ne $previous_class) {
        my $style = join '', map keys %{$class_to_style{$_}->[1]}, split / /, $previous_class;
        
        $section .= $seq->{'letter'} if $seq->{'end'};
        
        if (scalar !@{$output[$i][$j]||[]}) {
          if ($config->{'number'}) {
            my $num = shift @{$config->{'line_numbers'}->{$i}};
            
            my $pad1 = ' ' x ($config->{'padding'}->{'pre_number'} - length $num->{'label'});
            my $pad2 = ' ' x ($config->{'padding'}->{'number'} - length $num->{'start'});
            
            push @{$output[$i][$j]}, [ \'', $config->{'h_space'} . sprintf('%6s ', "$pad1$num->{'label'}$pad2$num->{'start'}") ];
          }
        }
        
        push @{$output[$i][$j]}, [ \$style, $section ];
        
        if ($count == $config->{'display_width'}) {
          $count = 0;
          $j++;
        }
        
        $section = '';
      }
      
      if ($seq->{'url'}) {
        $class .= qq{ HYPERLINK "$seq->{'url'}" }; # FIXME: Doesn't work
        $seq->{'letter'} =~ s/<a.+>(.+)<\/a>/$1/;
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
  
  my $spacer = ' ' x $config->{'display_width'} if $config->{'v_space'};
  
  for my $i (0..scalar @{$output[0]} - 1) {
    $rtf->paragraph(\'\fs20', $_->[$i]) for @output;
    $rtf->paragraph(\'\fs20', $spacer) if $spacer;
  }
  
  $rtf->close;
  
  print $file $string;
  
  $file->save;
  
  $object->input->header( -type => 'application/rtf', -attachment => "$filename.rtf" );
  
  return $file->content;
}

1;
