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

sub markup_variation {
  my $self = shift;
  my ($sequence, $data, $config) = @_;
  
  for (sort {$a <=> $b} keys %$data) {
    if ($data->{$_}->{'snp'} ne '') {
      if ($config->{'trans_strand'} == -1) {
        $data->{$_}->{'alleles'} =~ tr/acgthvmrdbkynwsACGTDBKYHVMRNWS\//tgcadbkyhvmrnwsTGCAHVMRDBKYNWS\//;
        $data->{$_}->{'ambigcode'} =~ tr/acgthvmrdbkynwsACGTDBKYHVMRNWS\//tgcadbkyhvmrnwsTGCAHVMRDBKYNWS\//;
      }
      
      $sequence->[$_]->{'background-color'} = $config->{'translation'} ?  $config->{'colours'}->{"$data->{$_}->{'snp'}$data->{$_}->{'bg'}"} : $config->{'colours'}->{'utr'};
      $sequence->[$_]->{'title'} = "Alleles: $data->{$_}->{'alleles'}";
      $sequence->[$_]->{'ambigcode'} = $data->{$_}->{'url_params'} ? qq{<a href="../snpview?$data->{$_}->{'url_params'}">$data->{$_}->{'ambigcode'}</a>} : $data->{$_}->{'ambigcode'};
    } else {
      $sequence->[$_]->{'ambigcode'} = $data->{$_}->{'ambigcode'};
    }
  }
}

sub content {
  my $self        = shift;
  my $object      = $self->object;
  
  my $colours = $object->species_defs->colour('sequence_markup');
  my %c = map { $_ => $colours->{$_}->{'default'} } keys %$colours;
  
  my $config = { 
    wrap => $object->param('seq_cols') || 60,
    colours => \%c
  };
 
  my ($sequence, $markup);
  
  for ('exons', 'codons', 'coding_seq', 'translation', 'rna', 'variation', 'number') {
    $config->{$_} = ($object->param($_) eq "yes") ? 1 : 0;
  }
  
  $config->{'codons'} = $config->{'coding_seq'} = $config->{'translation'} = 0 unless $object->Obj->translation;
  $config->{'variation'} = 0 unless $object->species_defs->databases->{'DATABASE_VARIATION'};
  $config->{'rna'} = 0 unless $object->rna_notation;
  
  push (@{$config->{'pre'}}, { key => 'ambigcode', default => ' ' }) if $config->{'variation'};
  
  push (@{$config->{'post'}}, { key => 'coding_seq', default => '.' }) if $config->{'coding_seq'};
  push (@{$config->{'post'}}, { key => 'peptide', default => '.' }) if $config->{'translation'};
  push (@{$config->{'post'}}, { key => 'rna', default => '.' }) if $config->{'rna'};
  
  ($sequence, $markup, $config->{'trans_strand'}) = $object->get_trans_seq_with_markup($config);
  
  $self->markup_exons($sequence, $markup, $config) if $config->{'exons'};
  $self->markup_codons($sequence, $markup, $config) if $config->{'codons'};
  $self->markup_coding_seq($sequence, $markup, $config) if $config->{'coding_seq'};
  $self->markup_translation($sequence, $markup, $config) if $config->{'translation'};
  $self->markup_rna($sequence, $object->rna_notation, $config) if $config->{'rna'};
  $self->markup_variation($sequence, $markup, $config) if $config->{'variation'};
 
  my $html = $self->build_sequence($sequence, $config);
  
  if ($config->{'codons'} || $config->{'variation'} || $config->{'translation'}  || $config->{'coding_seq'}) {
    $html .= qq(<img src="/img/help/transview_key3.gif" alt="[Key]" border="0" />);
  }
  
  return $html;
}

1;

