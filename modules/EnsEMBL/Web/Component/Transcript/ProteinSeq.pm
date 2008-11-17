package EnsEMBL::Web::Component::Transcript::ProteinSeq;

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
  
  my $peptide = $object->Obj;
  my $pep_seq = $peptide->seq;

  my @sequence = [ map {{'letter' => $_ }} split (//, uc $pep_seq) ];
  my $markup;
  
  $config->{'slices'} = [{ slice => $pep_seq }];
  $config->{'length'} = length $pep_seq;
  
  if ($config->{'exons'}) {
    my $exons = $object->pep_splice_site($peptide);
    my $flip = 0;
    
    foreach (sort {$a <=> $b} keys %$exons) {
      last if $_ >= $config->{'length'};
      
      if ($exons->{$_}->{'exon'}) {
        $flip = 1 - $flip;
        $markup->{$_}->{'exons'} = 1;
        
        push (@{$markup->{$_}->{'exon_type'}}, "exon$flip");
      } elsif ($exons->{$_}->{'overlap'}) {
        $markup->{$_}->{'exons'} = 1;
        push (@{$markup->{$_}->{'exon_type'}}, 'exon2');
      }
    }
    
    $markup->{0}->{'exons'} = 1;
    $markup->{0}->{'exon_type'} = [ 'exon0' ];
  }
  
  if ($config->{'variation'}) {
    my $variations = $object->pep_snps('hash');
    
    foreach (sort {$a <=> $b} keys %$variations) {
      last if $_ >= $config->{'length'};
      
      $markup->{$_}->{'variation'} = $variations->{$_}->{'type'};
      $markup->{$_}->{'alleles'} = $variations->{$_}->{'allele'};
      $markup->{$_}->{'ambigcode'} = $variations->{$_}->{'ambigcode'};
      $markup->{$_}->{'pep_snp'} = $variations->{$_}->{'pep_snp'};
      $markup->{$_}->{'nt'} = $variations->{$_}->{'nt'};
    }
  }
  
  return (\@sequence,  [ $markup ]);
}

sub content {
  my $self = shift;
  my $transcript = $self->object;
  my $object = $transcript->translation_object;
  
  return $self->non_coding_error unless $object;
  
  my $colours = $object->species_defs->colour('sequence_markup');
  my %c = map { $_ => $colours->{$_}->{'default'} } keys %$colours;
  
  my $config = { 
    wrap => $object->param('seq_cols') || 60,
    colours => \%c,
    species => $object->species,
    maintain_colour => 1
  };
  
  for ('exons', 'variation', 'number') {
    $config->{$_} = ($object->param($_) eq 'yes') ? 1 : 0;
  }

  my ($sequence, $markup) = $self->get_sequence_data($object, $config);
  
  $self->markup_exons($sequence, $markup, $config) if $config->{'exons'};
  $self->markup_variation($sequence, $markup, $config) if $config->{'variation'};
  $self->markup_line_numbers($sequence, $config) if $config->{'number'};
  
  my $html = $self->build_sequence($sequence, $config);
  
  $html .= qq(<img src="/i/help/protview_key1.gif" alt="[Key]" border="0" />) if ($config->{'exons'} || $config->{'variation'});

  return $html;
}

1;

