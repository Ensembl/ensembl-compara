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

  my $peptide     = $object->Obj;
  my $pep_splice  = $object->pep_splice_site($peptide);
  my $pep_snps    = $object->pep_snps('hash');
  my $pep_seq     = $peptide->seq;

  my @sequence = map {{'letter' => $_ }} split (//, uc($pep_seq));
  
  my $colours = $object->species_defs->colour('sequence_markup');
  my %c = map { $_ => $colours->{$_}->{'default'} } keys %$colours;
  
  my $config = { 
    wrap => $object->param('seq_cols') || 60,
    colours => \%c
  };
  
  for ('exons', 'variation', 'number') {
    $config->{$_} = ($object->param($_) eq "yes") ? 1 : 0;
  }

  $self->markup_exons(\@sequence, $pep_splice, $config) if $config->{'exons'};
  $self->markup_variation(\@sequence, $pep_snps, $config) if $config->{'variation'};
  
  my $html = $self->build_sequence(\@sequence, $config);
  
  $html .= qq(<img src="/i/help/protview_key1.gif" alt="[Key]" border="0" />) if ($config->{'exons'} || $config->{'variation'});

  return $html;
}

1;

