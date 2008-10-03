package EnsEMBL::Web::Component::Transcript::ProteinSeq;

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
  my $transcript = $self->object;
  my $object = $transcript->translation_object;
  return $self->non_coding_error unless $object;

  my $number     = $object->param('number') || "no";
  my $show       = $object->param('show') || "snps"; 
  my $peptide    = $object->Obj;
  my $trans      = $object->transcript;
  my $pep_splice = $object->pep_splice_site($peptide);
  my $pep_snps   = $object->pep_snps;;
  my $wrap       = $object->param('seq_cols') || 60;
  my $db         = $object->get_db;
  my $pep_id     = $object->stable_id;
  my $pep_seq    = $peptide->seq;
  my @exon_colours = qw(black blue red);
  my %bg_color = (
    'c0'      => '#ffffff',
    'syn'     => '#76ee00',
    'insert'  => '#99ccff',
    'delete'  => '#99ccff',
    'snp'     => '#ffd700',
  );
my @aas = map {{'aa' => $_ }} split //, uc($pep_seq) ; # store peptide seq in hash
  my ($output, $fasta, $previous) = '';
  $output .= "<pre>";
  my ($count, $flip, $i) = 0;
  my $pos = 1;
  my $SPACER = $number eq 'yes' ? '       ' : '';
  foreach (@aas) {                        # build markup
    if($count == $wrap) {
      my $NUMBER = '';
      if($number eq 'yes') {
        $NUMBER = sprintf("%6d ",$pos);
        $pos += $wrap;
      }
    $output .= ($show eq 'snps' ? "\n$SPACER" : '' ).
        $NUMBER.$fasta. ($previous eq '' ? '':'</span>')."\n" ;
      $previous=''; $count=0; $fasta ='';
    }
    if ( $pep_splice->{$i}{'exon'} ){ $flip = 1 - $flip }
       my $fg = $pep_splice->{$i}{'overlap'} ? $exon_colours[2] : $exon_colours[$flip];
    my $bg = $bg_color{$pep_snps->[$i]{'type'}};
    my $style = qq(style="color:$fg;");
    my $type = $pep_snps->[$i]{'type'}; 
    if( $show eq 'snps') { 
        $style = qq(style="color:$fg;). ( $bg ? qq( background-color:$bg;) : '' ) .qq(");
      if ($type eq 'snp'){;
        $style .= qq(title="Residues: $pep_snps->[$i]{'pep_snp'} ");
        }
        if ($type eq 'syn'){
        my $string = '';
        for my $letter ( 0..2 ){
                $string .= $pep_snps->[$i]{'ambigcode'}[$letter]  ? '('.$pep_snps->[$i]{'ambigcode'}[$letter].')' : $pep_snps->[$i]{'nt'}[$letter];
        }
        $style .= qq(title="Codon: $string ");
        }
        if($type eq 'insert') {
        $pep_snps->[$i]{'alleles'} = join '', @{$pep_snps->[$i]{'nt'}};
        $pep_snps->[$i]{'alleles'} = Bio::Perl::translate_as_string($pep_snps->[$i]{'alleles'});   # translate insertion.. bio::perl call
        $style .= qq(title="Insert: $pep_snps->[$i]{'allele'} ");
        }
        if($type eq 'delete') {
        $style .= qq(title="Deletion: $pep_snps->[$i]{'allele'} ");
      }
        if($type eq 'frameshift') {
        $style .= qq(title="Frame-shift ");
      }
    }        # end if snp

    if($style ne $previous) {
      $fasta.=qq(</span>) unless $previous eq '';
      $fasta.=qq(<span $style>) unless $style eq '';
      $previous = $style;
    }
    $count++; $i++;
    $fasta .= $_->{'aa'};   
  }

  my $NUMBER = '';
  if($number eq 'yes') {
    $NUMBER = sprintf("%6d ",$pos); $pos += $wrap;
  }
  $output .= ($show eq 'snps' ? "\n$SPACER" : '' ).$NUMBER.$fasta. ($previous eq '' ? '':'</span>')."\n";

  my( $sel_snps, $sel_exons,$sel_peptide)=('','','');
  if($show eq'snps') { $sel_snps = ' selected'; }
  elsif($show eq 'exons') {$sel_exons=' selected'; }
  else { ($sel_snps, $sel_exons ) = ''; }

  my ( $sel_numbers, $sel_no)=('','');
  if($number eq 'yes') { $sel_numbers = ' selected'; }
  else {$sel_no=' selected'; }
 
  my $SNP_LINE = exists($object->species_defs->databases->{'DATABASE_VARIATION'}) ? qq(<option value="snps" $sel_snps>Exons/SNPs</option>) : '' ;

  my $html = $output;
  $html .="</pre>";

  if( $show eq 'exons' || $show eq 'snps' ) {
    $html .= qq(<img src="/img/help/protview_key1.gif" alt="[Key]" border="0" />);
  }

 return $html;
}

1;

