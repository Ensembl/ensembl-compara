=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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
  my $object   = $self->object || $self->hub->core_object('transcript');
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

  my $hub   = $self->hub;
  my $type  = $hub->param('data_type') || $hub->type;
  my $vc    = $self->view_config($type);
  $config->{'exons_case'} = ($hub->param('exons_case') eq 'on' || $vc->get('exons_case') eq 'on') ? 1 : 0;
 
  if ($config->{'snp_display'}) {
    foreach my $snp (reverse @{$object->variation_data($translation->get_Slice, undef, $strand)}) {
      next if $config->{'hide_long_snps'} && $snp->{'vf'}->length > $self->{'snp_length_filter'};
      
      my $pos  = $snp->{'position'} - 1;
      my $dbID = $snp->{'vdbid'};
      $markup->{'variations'}->{$pos}->{'type'}    = lc(($config->{'consequence_filter'} && keys %{$config->{'consequence_filter'}}) ? [ grep $config->{'consequence_filter'}{$_}, @{$snp->{'tv'}->consequence_type} ]->[0] : $snp->{'type'});
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
    $config->{$_} = $hub->param($_) =~ /yes|on/ ? 1 : 0;
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

  return $self->build_sequence($sequence, $config);
}

sub export_options { return {'action' => 'Protein'}; }

sub initialize_export {
  my $self = shift;
  my $hub = $self->hub;
  my $vc = $hub->get_viewconfig('ProteinSeq', 'Transcript');
  $hub->param('exons', $vc->get('exons'));
  my $transcript = $self->object || $hub->core_object('transcript');
  return $self->initialize($transcript->translation_object);
}

1;
