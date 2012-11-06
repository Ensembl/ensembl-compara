package EnsEMBL::Web::Component::Transcript::ProteinSeq;

use strict;

use base qw(EnsEMBL::Web::Component::TextSequence EnsEMBL::Web::Component::Transcript);

sub get_sequence_data {
  my ($self, $translation, $config) = @_;
  my $object   = $self->object;
  my $pep_seq  = $translation->Obj->seq;
  my $strand   = $object->Obj->strand;
  my @sequence = [ map {{ letter => $_ }} split //, uc $pep_seq ];
  my $markup;
  
  $config->{'slices'} = [{ slice => $pep_seq }];
  $config->{'length'} = length $pep_seq;
  
  if ($config->{'exons'}) {
    my $exons = $object->peptide_splice_sites;
    my $flip  = 0;
    
    foreach (sort {$a <=> $b} keys %$exons) {
      last if $_ >= $config->{'length'};
      
      if ($exons->{$_}->{'exon'}) {
        $flip = 1 - $flip;
        push @{$markup->{'exons'}->{$_}->{'type'}}, "exon$flip";
      } elsif ($exons->{$_}->{'overlap'}) {
        push @{$markup->{'exons'}->{$_}->{'type'}}, 'exon2';
      }
    }
    
    $markup->{'exons'}->{0}->{'type'} = [ 'exon0' ];
  }
  
  if ($config->{'snp_display'}) {
    foreach my $snp (reverse @{$object->variation_data($translation->get_Slice, undef, $strand)}) {
      my $pos  = $snp->{'position'} - 1;
      my $dbID = $snp->{'vdbid'};
      
      $markup->{'variations'}->{$pos}->{'type'}    = lc($config->{'consequence_filter'} ? [ grep $config->{'consequence_filter'}{$_}, @{$snp->{'tv'}->consequence_type} ]->[0] : $snp->{'type'});
      $markup->{'variations'}->{$pos}->{'alleles'} = $snp->{'allele'};
      $markup->{'variations'}->{$pos}->{'href'} ||= {
        type        => 'ZMenu',
        action      => 'TextSequence',
        factorytype => 'Location'
      };
      
      push @{$markup->{'variations'}->{$pos}->{'href'}->{'v'}},  $snp->{'snp_id'};
      push @{$markup->{'variations'}->{$pos}->{'href'}->{'vf'}}, $dbID;
    }
  }
  
  return (\@sequence, [ $markup ]);
}

sub initialize {
  my ($self, $translation) = @_;
  my $hub         = $self->hub;
  my @consequence = $hub->param('consequence_filter');
  
  my $config = {
    display_width   => $hub->param('display_width') || 60,
    species         => $hub->species,
    maintain_colour => 1,
    transcript      => 1,
  };
  
  for (qw(exons snp_display number)) {
    $config->{$_} = $hub->param($_) eq 'yes' ? 1 : 0;
  }
  
  $config->{'consequence_filter'} = { map { $_ => 1 } @consequence } if $config->{'snp_display'} && join('', @consequence) ne 'off';
  
  my ($sequence, $markup) = $self->get_sequence_data($translation, $config);
  
  $self->markup_exons($sequence, $markup, $config)     if $config->{'exons'};
  $self->markup_variation($sequence, $markup, $config) if $config->{'snp_display'};
  $self->markup_line_numbers($sequence, $config)       if $config->{'number'};
  
  return ($sequence, $config);
}

sub content {
  my $self        = shift;
  my $translation = $self->object->translation_object;
  
  return $self->non_coding_error unless $translation;
  
  my ($sequence, $config) = $self->initialize($translation);
  
  my $html = $self->tool_buttons($translation->Obj->seq, $config->{'species'}, 'peptide');
  $html   .= sprintf('<div class="sequence_key">%s</div>', $self->get_key($config));
  $html   .= $self->build_sequence($sequence, $config);

  return $html;
}

sub content_rtf {
  my $self        = shift;
  my $translation = $self->object->translation_object;
  
  my ($sequence, $config) = $self->initialize($translation);
  
  return $self->export_sequence($sequence, $config, sprintf 'Protein-Sequence-%s-%s', $config->{'species'}, $translation->stable_id);
}

1;
