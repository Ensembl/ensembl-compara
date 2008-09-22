package EnsEMBL::Web::Component::Transcript::TranscriptSeq;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Transcript);

sub _init {
  my $self = shift;
  $self->cacheable( 1 );
  $self->ajaxable(  1 );
}

sub caption {
  return undef;
}

sub content {
  my $self = shift;
  my $object = $self->object;
  my $show   = $object->param('show') || '';
  my $number = $object->param('number' || 'off');
  my $html = ''; 

  if( $show eq 'plain' ) {
    my $fasta = $object->get_trans_seq;
    $fasta =~ s/([acgtn\*]+)/'<span style="color: blue">'.uc($1).'<\/span>'/eg;
    $html = "<pre>" . $fasta ."</pre>";
    return $html;
  }
  elsif( $show eq 'revcom' ) {
    my $fasta = $object->get_trans_seq("revcom");
    $fasta =~ s/([acgtn\*]+)/'<span style="color: blue">'.uc($1).'<\/span>'/eg;
    $html = "<pre>" . $fasta ."</pre>";
    return $html;
  }
 elsif( $show eq 'rna' ) {
    my @strings = $object->rna_notation;
    my @extra_array;
    foreach( @strings ) {
      s/(.{60})/$1\n/g;
      my @extra = split /\n/;
      if( $number eq 'on' ) {
        @extra = map { "       $_\n" } @extra;
      } else {
        @extra = map { "$_\n" } @extra;
      }
      push @extra_array, \@extra;
    }

    my @fasta = split /\n/, $object->get_trans_seq;
    my $out = '<pre>';
    foreach( @fasta ) {
      $out .= "$_\n";
      foreach my $array_ref (@extra_array) {
        $out .= shift @$array_ref;
      }
    }
    $html .=  $out . "</pre>";
    return $html;
}

  # If $show ne rna or plan
  my( $cd_start, $cd_end, $trans_strand, $bps ) = $object->get_markedup_trans_seq;
  my $trans  = $object->transcript;
  my $wrap = 60;
  my $count = 0;
  my ($pep_previous, $ambiguities, $previous, $coding_previous, $output, $fasta, $peptide)  = '';
  my $coding_fasta;
  $output .= "<pre>";
  my $pos = 1;
  my $SPACER = $number eq 'on' ? '       ' : '';
  my %bg_color = (  # move to constant MARKUP_COLOUR
    'utr'      => $object->species_defs->ENSEMBL_STYLE->{'BACKGROUND1'},
    'c0'       => 'ffffff',
    'c1'       => $object->species_defs->ENSEMBL_STYLE->{'BACKGROUND2'},
    'c99'      => 'ffcc99',
    'synutr'   => '7ac5cd',
    'sync0'    => '76ee00',
    'sync1'    => '76ee00',
    'indelutr' => '9999ff',
    'indelc0'  => '99ccff',
    'indelc1'  => '99ccff',
    'snputr'   => '7ac5cd',
    'snpc0'    => 'ffd700',
    'snpc1'    => 'ffd700',
  );

  foreach(@$bps) {
   if($count == $wrap) {
      my( $NUMBER, $PEPNUM ) = ('','');
      my $CODINGNUM;
      if($number eq 'on') {
        $NUMBER = sprintf("%6d ",$pos);
        $PEPNUM = ( $pos>=$cd_start && $pos<=$cd_end ) ? sprintf("%6d ",int( ($pos-$cd_start+3)/3) ) : $SPACER ;
        $CODINGNUM = ( $pos>=$cd_start && $pos<=$cd_end ) ? sprintf("%6d ", $pos-$cd_start+1 ) : $SPACER ;
      }
      $pos += $wrap;
      $output .=  "$SPACER$ambiguities\n" if $show =~ /^snp/;
      $output .= $NUMBER.$fasta. ($previous eq '' ? '':'</span>')."\n";
      $output .="$CODINGNUM$coding_fasta".($coding_previous eq ''?'':'</span>')."\n" if $show =~ /coding/;
      $output .="$PEPNUM$peptide". ($pep_previous eq ''?'':'</span>')."\n\n" if $show =~/^snp/ || $show eq 'peptide' || $show =~ /coding/;

      $previous='';
      $pep_previous='';
      $coding_previous='';
      $ambiguities = '';
      $count=0;
      $peptide = '';
      $fasta ='';
      $coding_fasta ='';
    }
 my $bg = $bg_color{"$_->{'snp'}$_->{'bg'}"};
    my $style = qq(style="color: $_->{'fg'};). ( $bg ? qq( background-color: #$bg;) : '' ) .qq(");
    my $pep_style = '';
    my $coding_style;

    # SNPs
    if( $show =~ /^snp/) {
      if($_->{'snp'} ne '') {
        if( $trans_strand == -1 ) {
          $_->{'alleles'}=~tr/acgthvmrdbkynwsACGTDBKYHVMRNWS\//tgcadbkyhvmrnwsTGCAHVMRDBKYNWS\//;
          $_->{'ambigcode'} =~ tr/acgthvmrdbkynwsACGTDBKYHVMRNWS\//tgcadbkyhvmrnwsTGCAHVMRDBKYNWS\//;
        }
        $style .= qq( title="Alleles: $_->{'alleles'}");
      }
      if($_->{'aminoacids'} ne '') {
        $pep_style = qq(style="color: #ff0000" title="$_->{'aminoacids'}");
      }

      # Add links to SNPs in markup
      if ( my $url_params = $_->{'url_params'} ){
  $ambiguities .= qq(<a href="snpview?$url_params">).$_->{'ambigcode'}."</a>";
      } else {
        $ambiguities.= $_->{'ambigcode'};
      }
    }

    my $where =  $count + $pos;
    if($style ne $previous) {
      $fasta.=qq(</span>) unless $previous eq '';
      $fasta.=qq(<span $style>) unless $style eq '';
      $previous = $style;
    }
    if ($coding_style ne $coding_previous) {
      if ( $where>=$cd_start && $where<=$cd_end ) {
  $coding_fasta.=qq(<span $coding_style>) unless $coding_style eq '';
      }
      $coding_fasta.=qq(</span>) unless $coding_previous eq '';
      $coding_previous = $coding_style;
    }

    if($pep_style ne $pep_previous) {
      $peptide.=qq(</span>) unless $pep_previous eq '';
      $peptide.=qq(<span $pep_style>) unless $pep_style eq '';
      $pep_previous = $pep_style;
    }
    $count++;
    $fasta.=$_->{'letter'};
    $coding_fasta.=( $where>=$cd_start && $where<=$cd_end ) ? $_->{'letter'} :".";
    $peptide.=$_->{'peptide'};

  }# end foreach bp

  my( $NUMBER, $PEPNUM, $CODINGNUM)  = ("", "", "");
  if($number eq 'on') {
    $NUMBER = sprintf("%6d ",$pos);
    $CODINGNUM = ( $pos>=$cd_start && $pos<=$cd_end ) ? sprintf("%6d ", $pos-$cd_start +1 ) : $SPACER ;
    $PEPNUM = ( $pos>=$cd_start && $pos<=$cd_end ) ? sprintf("%6d ",int( ($pos-$cd_start-1)/3 +1) ) : $SPACER ;
    $pos += $wrap;
  }
      $output .=  "$SPACER$ambiguities\n" if $show =~ /^snp/;
      $output .= $NUMBER.$fasta. ($previous eq '' ? '':'</span>')."\n";
      $output .="$CODINGNUM$coding_fasta".($coding_previous eq ''?'':'</span>')."\n" if $show =~ /coding/;
      $output .="$PEPNUM$peptide". ($pep_previous eq ''?'':'</span>')."\n\n" if $show =~/^snp/ || $show eq 'peptide' || $show =~ /coding/;

 
   $html .= $output;
   $html .= "</pre>";

 return $html;
}

1;

