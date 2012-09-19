package EnsEMBL::Web::Component::Variation::FlankingSequence;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Variation EnsEMBL::Web::Component::TextSequence);

use Bio::EnsEMBL::Variation::Utils::Sequence qw(align_seqs);
sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable( 1 );
}

sub content {
  my $self    = shift;
  my $object  = $self->object;
  my $table   = $self->new_twocol;
  my $hub     = $self->hub;
  my @consequence = $hub->param('consequence_filter');
  
  ## first check we have uniquely determined variation
  return $self->_info('A unique location can not be determined for this Variation', $object->not_unique_location) if $object->not_unique_location;
  
  ## count locations
  my $mapping_count = scalar keys %{$object->variation_feature_mapping};

  ## Add flanking sequence
  my $f_label;
  my $f_html;
  my $if_fs_diff = qq{It differs from the flanking sequence submitted to <a href....>dbSNP</a>*};
  
  my $f_info = $self->_info('Flanking sequence', '<p>The sequence below is from the <b>reference genome</b> flanking the variant location.The variant is shown in <span class="alt_allele"><u>red</u></span> text. Neighbouring variants are shown with highlighted letters and ambiguity codes</p>', 'auto');

  my $status   = 'status_ambig_sequence';

  my $ambig_code = $object->vari->ambig_code;
  unless ($ambig_code) {
    $ambig_code = "[".$object->alleles."]";
  }
  
  my $config = { 
    display_width   => $hub->param('display_width') || 60,
    species         => $hub->species,
    maintain_colour => 1,
    snp_display     => $hub->param('snp_display'),
    select_sequence => $hub->param('select_sequence') || 'both',
  };
  
  $config->{'consequence_filter'} = { map { $_ => 1 } @consequence } if $config->{'snp_display'} && join('', @consequence) ne 'off';

  # first determine correct SNP location 
  my %mappings = %{ $object->variation_feature_mapping }; 
  my $loc;
  if( keys %mappings == 1 ) {
    ($loc) = values %mappings;
  } else { 
    $loc = $mappings{$object->param('vf')};
  }
  
  # check if the flanking sequences match the reference sequence
  my $align_info;
  my $vf = $object->vari->get_VariationFeature_by_dbID($object->param('vf'));
  my $align_quality = $vf->flank_match;
  if (defined($align_quality) && $align_quality < 1) {
    my $source_link = $hub->get_ExtURL_link("here", uc($object->source), $object->param('v')."#submission");
    $source_link =~ s/%23/#/;
    $align_info = $self->_warning('Alignment quality', "<p>The longest flanking sequence submitted to dbSNP for this variant doesn't match the reference sequence displayed below.<br />For more information about the submitted sequences, please click on the dbSNP link $source_link.</p>", 'auto');
  }
  
  my $flank_size = $object->param('flank_size') || 400;
  $flank_size ++;
  # get a slice adaptor
  my $sa = $object->vari->adaptor->db->dnadb->get_SliceAdaptor(); 
  
  my $chr_slice = $sa->fetch_by_region(undef,$loc->{Chr});
  my $chr_end = $chr_slice->end;
  
  my $slice_start = ($loc->{start} - $flank_size > 1) ? $loc->{start} - $flank_size : 1;
  my $slice_end   = ($loc->{end} + $flank_size > $chr_end) ? $chr_end : $loc->{end} + $flank_size;

  # get slice
  my $slice = $sa->fetch_by_region(
      undef,
      $loc->{Chr},
      $slice_start,
      $slice_end,
      $loc->{strand}
  );
  
  # get up slice
  my $up_end = ($loc->{start} - 1 > 1) ? $loc->{start} - 1 : 1;
  my $up_slice = $sa->fetch_by_region(
      undef,
      $loc->{Chr},
      $slice_start,
      $up_end,
      $loc->{strand}
  );
    
  # get down slice
  my $down_start = ($loc->{end} + 1 > $chr_end) ? $chr_end : $loc->{end} + 1;
  my $down_slice = $sa->fetch_by_region(
      undef,
      $loc->{Chr},
      $down_start,
      $slice_end,
      $loc->{strand}
  );
  
  my $mk = {};
  my @markup;
  my @sequence;
  
  my @reference_seq;
  my @reference_seq_up   = map {{ letter => $_ }} split //, $up_slice->seq;
  my @reference_seq_down = map {{ letter => $_ }} split //, $down_slice->seq;

  
  my $v_name = $object->param('v');
  my $v_dbID = $object->param('vf');
  
  if ($config->{'snp_display'} eq 'yes') {

    # Upstream sequence
    if ($config->{'select_sequence'} ne 'down') {
      @reference_seq = @reference_seq_up;
      $self->find_variations(0, $up_slice, $mk);
    }
    # Variation
    my $length = @reference_seq;
    foreach my $v_letter (split //, $ambig_code) {
      push @reference_seq, {letter => $v_letter, is_main_variation => 1};
      $mk->{'variations'}->{$length}->{'alleles'}   .= ($mk->{'variations'}->{$_}->{'alleles'} ? ', ' : '') . $ambig_code;
      $mk->{'variations'}->{$length}->{'ambigcode'} = $v_letter;
      $length++;
    }
    
    # Downstream sequence
    if ($config->{'select_sequence'} ne 'up'){
  
     foreach my $down (@reference_seq_down) {
       push @reference_seq, $down;
     }
     $self->find_variations($length, $down_slice, $mk);
    }
    push @sequence, \@reference_seq;
    push @markup, $mk;

    $self->markup_variation(\@sequence, \@markup, $config); 
    $f_html .= $self->tool_buttons($slice->seq, $config->{'species'});
    $f_html .= sprintf('<div class="sequence_key">%s</div>', $self->get_key($config));
    $f_html .= $self->build_sequence(\@sequence, $config);
  
  }
  elsif(defined($up_slice) && defined($down_slice)) {
    $f_html .= uc( $up_slice->seq ) if ($config->{'select_sequence'} ne 'down');
    $f_html .= lc( $ambig_code );
    $f_html .= uc( $down_slice->seq ) if ($config->{'select_sequence'} ne 'up');

    $f_html =~ s/(.{60})/$1\n/g;
    $f_html =~ s/(([a-z]|\/|-|\[|\])+)/'<span class="alt_allele"><u>'.uc("$1").'<\/u><\/span>'/eg;
    $f_html =~ s/\n/\n/g;
  }
  return  qq{$f_info\n$align_info\n<pre>$f_html</pre>};
}


sub markup_variation {
  my $self = shift;
  my ($sequence, $markup, $config) = @_;

  my ($snps, $inserts, $deletes, $seq, $variation, $ambiguity);
  my $hub = $self->hub;
  my $i   = 0;
  
  my $class = {
    snp    => 'sn',
    insert => 'si',
    delete => 'sd'
  };

  foreach my $data (@$markup) {
    $seq = $sequence->[$i];
    
    foreach (sort {$a <=> $b} keys %{$data->{'variations'}}) {
      $variation  = $data->{'variations'}->{$_};
      my $ambigcode = $variation->{ambigcode};
      
      if ($seq->[$_]->{'is_main_variation'}) {
        my $letter = $seq->[$_]->{'letter'};
        $seq->[$_]->{'letter'} = qq{<span class="alt_allele"><u>$letter</u></span>};
        $seq->[$_]->{'class'} = undef;
      }
      else {
        $seq->[$_]->{'letter'} = $ambigcode if $ambigcode;
        #$seq->[$_]->{'letter'} = $ambiguity if $ambiguity;
        $seq->[$_]->{'title'} .= ($seq->[$_]->{'title'} ? '; ' : '') . $variation->{'alleles'} if $config->{'title_display'};
        $seq->[$_]->{'class'} .= ($class->{$variation->{'type'}} || $variation->{'type'}) . ' ';
        $seq->[$_]->{'href'}   = $hub->url($variation->{'href'});
        $seq->[$_]->{'post'}   = join '', @{$variation->{'link_text'}} if $config->{'snp_display'} eq 'snp_link' && $variation->{'link_text'};
     
        $config->{'key'}->{'variations'}->{$variation->{'type'}} = 1 if ($variation->{'type'});
      }
    }
    $i++;
  }
}


sub find_variations {
  my $self   = shift;
  my $length = shift;
  my $slice  = shift;
  my $mk     = shift;
  
  my $hub = $self->hub;
  
  foreach my $var (reverse @{$slice->get_all_VariationFeatures()}) {
    my $dbID           = $var->dbID;
    my $variation_name = $var->variation_name;
    my $alleles        = $var->allele_string;
    my $ambigcode      = $var->ambig_code || undef;
    my $start          = $var->start - 1 + $length; # -1 because of the sequence index starts at 0
    my $end            = $var->end - 1 + $length;   # -1 because of the sequence index starts at 0 
    my $type           = lc($var->display_consequence);
    if ($var) {
      if ($var->strand == -1) {
        $ambigcode =~ tr/acgthvmrdbkynwsACGTDBKYHVMRNWS\//tgcadbkyhvmrnwsTGCAHVMRDBKYNWS\//;
        $alleles   =~ tr/acgthvmrdbkynwsACGTDBKYHVMRNWS\//tgcadbkyhvmrnwsTGCAHVMRDBKYNWS\//;
      }
    }
      
    # Variation is an insert if start > end
    ($start, $end) = ($end, $start) if $start > $end;
      
    foreach ($start..$end) {
      $mk->{'variations'}->{$_}->{'alleles'}   .= ($mk->{'variations'}->{$_}->{'alleles'} ? ', ' : '') . $alleles;
      $mk->{'variations'}->{$_}->{'url_params'} = { v => $variation_name, vf => $dbID, vdb => 'variation' };
      $mk->{'variations'}->{$_}->{'ambigcode'} = $ambigcode;
        
      my $url = $mk->{'variations'}->{$_}->{'url_params'} ? $hub->url({ type => 'Variation', action => 'Summary', %{$mk->{'variations'}->{$_}->{'url_params'}} }) : '';
        
      $mk->{'variations'}->{$_}->{'type'} = $type;
      $mk->{'variations'}->{$_}->{'href'} ||= {
         type        => 'ZMenu',
         action      => 'TextSequence',
         factorytype => 'Location'
      };
        
      push @{$mk->{'variations'}->{$_}->{'href'}->{'v'}},  $variation_name;
      push @{$mk->{'variations'}->{$_}->{'href'}->{'vf'}}, $dbID;
    }
  }
}
1;
