package EnsEMBL::Web::TextSequence::Annotation::Protein::Variations;

use strict;
use warnings;

use parent qw(EnsEMBL::Web::TextSequence::Annotation);

sub annotate {
  my ($self, $config, $slice_data, $markup) = @_;

  my $object = $config->{'object'};
  my $translation = $config->{'translation'};
  my $strand   = $object->Obj->strand;
  foreach my $snp (reverse @{$object->variation_data($translation->get_Slice, undef, $strand)}) {
    next if $config->{'hide_long_snps'} && $snp->{'vf'}->length > $config->{'snp_length_filter'};
    next if $self->too_rare_snp($snp->{'vf'},$config);
    next if $self->hidden_source($snp->{'vf'},$config);
        
    my $pos  = $snp->{'position'} - 1;
    my $dbID = $snp->{'vdbid'};
    $markup->{'variants'}->{$pos}->{'type'}    = lc(($config->{'consequence_filter'} && keys %{$config->{'consequence_filter'}}) ? [ grep $config->{'consequence_filter'}{$_}, @{$snp->{'tv'}->consequence_type} ]->[0] : $snp->{'type'});
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
