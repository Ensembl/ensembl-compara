=head1 LICENSE

Copyright [1999-2013] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

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
      next if $config->{'hide_long_snps'} && $snp->{'vf'}->length > $self->{'snp_length_filter'};
      
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
  
  for (qw(exons snp_display number hide_long_snps)) {
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
  
  my $html  = $self->tool_buttons($translation->Obj->seq, 'peptide');
     $html .= sprintf('<div class="sequence_key">%s</div>', $self->get_key($config));
     $html .= $self->build_sequence($sequence, $config);

  return $html;
}

sub content_rtf {
  my $self = shift;
  return $self->export_sequence($self->initialize($self->object->translation_object));
}

1;
