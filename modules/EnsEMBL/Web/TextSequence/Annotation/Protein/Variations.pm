=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2022] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::TextSequence::Annotation::Protein::Variations;

use strict;
use warnings;

use parent qw(EnsEMBL::Web::TextSequence::Annotation);

sub annotate {
  my ($self, $config, $slice_data, $markup) = @_;

  my $object = $config->{'object'};
  my $translation = $config->{'translation'};
  my $strand   = $object->Obj->strand;
  my %variants_list;

  my %ct_filter = map { $_ ? ($_ => 1) : () } @{$config->{'consequence_filter'}};
     %ct_filter = () if join('', keys %ct_filter) eq 'off';

  foreach my $snp (reverse @{$object->variation_data($translation->get_Slice, undef, $strand)}) {
    next if $config->{'hide_long_snps'} && $snp->{'vf'}->length > $config->{'snp_length_filter'};
    next if $self->too_rare_snp($snp->{'vf'},$config);
    next if $self->hidden_source($snp->{'vf'},$config);

    my $pos  = $snp->{'position'} - 1;
    my $dbID = $snp->{'vdbid'};

    next if $variants_list{$dbID}; # Avoid duplication
    $variants_list{$dbID} = 1;

    $markup->{'variants'}->{$pos}->{'type'}    = lc((%ct_filter && keys %ct_filter) ? [ grep $ct_filter{$_}, @{$snp->{'tv'}->consequence_type} ]->[0] : $snp->{'type'});
    $markup->{'variants'}->{$pos}->{'alleles'} = $snp->{'allele'};
    $markup->{'variants'}->{$pos}->{'href'} ||= {
      type        => 'ZMenu',
      action      => 'TextSequence',
      factorytype => 'Location'
    };    
        
    push @{$markup->{'variants'}->{$pos}->{'href'}->{'v'}},  $snp->{'snp_id'};
    push @{$markup->{'variants'}->{$pos}->{'href'}->{'vf'}}, $dbID;
  }
}

1;
