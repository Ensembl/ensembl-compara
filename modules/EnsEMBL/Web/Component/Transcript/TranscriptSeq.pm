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
  my $cd_start     = $trans->cdna_coding_start;
  my $cd_end       = $trans->cdna_coding_end;
  my $mk           = {};
  my $length       = 0;
  my $flip         = 0;
  my $seq          = '';
  
  my @sequence;
  my @markup;

  my $variation_seq = { name => 'variation',   seq => [] };
  my $coding_seq    = { name => 'coding_seq',  seq => [] };
  my $protein_seq   = { name => 'translation', seq => [] };
  my $rna_seq       = { name => 'rna',         seq => [ map {{ letter => $_ }} split //, $object->rna_notation ] };
  
  my @reference_seq = map { 
    $length += length $_->seq->seq;
    $seq .= $_->seq->seq;
        
    if ($config->{'exons'}) {
      $flip = 1 - $flip;
      push @{$mk->{'exons'}->{$length}->{'type'}}, $mk->{'exons'}->{$length}->{'overlap'} ? 'exon2' : "exon$flip";
    }
    
    map {{ 'letter' => $_ }} split //, uc $_->seq->seq 
  } @exons;
  
  delete $mk->{$length}; # We get a key which is too big, causing an empty span to be printed later 
  
  # Used to se the initial sequence colour
  $mk->{'exons'}->{0}->{'type'} = [ 'exon0' ] if $config->{'exons'};
  
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
      $mk->{'codons'}->{$_}->{'class'} = 'cu';
    }
  }
  
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
      $peptide = substr($peptide, 1);
    }
    
    for (my $i = $cd_start + $s - 1; ($i+2) <= $cd_end; $i+=3) {
      if ($config->{'codons'}) {
        $mk->{'codons'}->{$i}->{'class'} = $mk->{'codons'}->{$i+1}->{'class'} = $mk->{'codons'}->{$i+2}->{'class'} = "c$flip";
        
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
    my %protein_features = $can_translate == 0 ? () : %{$trans->get_all_peptide_variations($source)};

    foreach (values %snps) {
      foreach my $snp (@$_) {
        # Due to some changes start of a variation can be greater than its end - insertion happened
        my ($st, $en);
        
        my $snpclass = $snp->var_class;
        my $source = $snp->source;
        my $variation_name = $snp->variation_name;
        my $strand = $snp->strand;
        my $alleles = $snp->allele_string;
        my $ambigcode = $snpclass eq 'in-del' ? '*' : $snp->ambig_code;
        my $insert = 0;
        
        if ($strand == -1 && $trans_strand == -1) {
          $ambigcode =~ tr/acgthvmrdbkynwsACGTDBKYHVMRNWS\//tgcadbkyhvmrnwsTGCAHVMRDBKYNWS\//;
          $alleles   =~ tr/acgthvmrdbkynwsACGTDBKYHVMRNWS\//tgcadbkyhvmrnwsTGCAHVMRDBKYNWS\//;
        }
        
        if ($snp->start > $snp->end) {
          $st = $snp->end;
          $en = $snp->start;
          $insert = 1;
        } else {
          $en = $snp->end;
          $st = $snp->start;
        }
        
        foreach my $r ($st..$en) {               
          $mk->{'variations'}->{$r-1}->{'alleles'}    .= $alleles;
          $mk->{'variations'}->{$r-1}->{'url_params'} .= "source=" . $source . ";snp=" . $variation_name. ";";
          $mk->{'variations'}->{$r-1}->{'transcript'}  = 1;
          
          my $url = $object->_url({ type => 'Variation', action => 'Summary' }, 1)->[0] . "?$mk->{'variations'}->{$r-1}->{'url_params'}" if $mk->{'variations'}->{$r-1}->{'url_params'};
          
          if ($snpclass eq 'snp' || $snpclass eq 'SNP - substitution') {
            my $aa    = int(($r - $cd_start + 3)/3);
            my $aa_bp = $aa * 3 + $cd_start - 3;
            my @feat  = @{$protein_features{$aa}||[]};
            my $f     = scalar @feat;
            my $title = join ', ', @feat;
            
            $mk->{'variations'}->{$r-1}->{'type'} = $mk->{'variations'}->{$r-1}->{'type'} eq 'snp' || $f != 1 ? 'snp' : 'syn';
            
            if ($config->{'translation'} && $f > 1) {
              $protein_seq->{'seq'}->[$aa_bp-1]->{'letter'} = $protein_seq->{'seq'}->[$aa_bp+1]->{'letter'} = '=';
              
              for ($aa_bp-1..$aa_bp+1) {
                $protein_seq->{'seq'}->[$_]->{'class'} = 'aa';
                $protein_seq->{'seq'}->[$_]->{'title'} = $title;
              }
            }
          } else {
            $mk->{'variations'}->{$r-1}->{'type'} = $insert ? 'insert' : 'delete';
          }
          
          $mk->{'variations'}->{$r-1}->{'type'} .= 'utr' if $config->{'codons'} && $mk->{'codons'}->{$r-1} && $mk->{'codons'}->{$r-1}->{'class'} eq 'cu';
          
          $variation_seq->{'seq'}->[$r-1]->{'letter'} = $url ? sprintf '<a href="%s">%s</a>', $url, $ambigcode : $ambigcode;
          $variation_seq->{'seq'}->[$r-1]->{'url'}    = $url;
        }
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
  
  $config->{$_} = $object->param($_) eq 'yes' ? 1 : 0 for qw(exons codons coding_seq translation rna variation number);
  
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
      <div class="text_seq_buttons">
        <div class="other-tool">
          <p><a class="seq_export export" href="%s;export=rtf;no_wrap=1">Download view as RTF</a></p>
        </div>
        <div class="other-tool">
          <p><a class="seq_blast find" href="#">BLAST this sequence</a></p>
          <form class="external hidden seq_blast" action="/Multi/blastview" method="post">
            <fieldset>
              <input type="hidden" name="_query_sequence" value="%s" />
              <input type="hidden" name="species" value="%s" />
            </fieldset>
          </form>
        </div>
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
