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

package EnsEMBL::Web::TextSequence::Annotation::TranscriptVariations;

use strict;
use warnings;

use parent qw(EnsEMBL::Web::TextSequence::Annotation::Variations);

sub _hide_utr {
  my ($self,$config,$snp) = @_;

  return !$config->{'utr'} && !$snp->{'position'};
}

sub _hide_conseq {
  my ($self,$snp,$filter) = @_;

  return scalar keys %$filter && !grep $filter->{$_},@{$snp->{'tv_conseq_type'}};
}

sub _hide_evidence {
  my ($self,$snp,$filter) = @_;

  return scalar keys %$filter && !grep $filter->{$_},@{$snp->{'evidence'}};
}

sub _get_variation_data {
  my ($self,$ph,$config) = @_;

  my %ct_filter = map { $_ ? ($_ => 1) : () } @{$config->{'consequence_filter'}};
     %ct_filter = () if join('', keys %ct_filter) eq 'off';

  my %ef_filter = map { $_ ? ($_ => 1) : () } @{$config->{'evidence_filter'}};
     %ef_filter = () if join('', keys %ef_filter) eq 'off';

  my $out = $ph->get_query('Sequence::TVGet')->go($self,{
    species => $config->{'species'},
    type => $config->{'type'},
    transcript => $config->{'transcript'},
  });

  $out = [ grep { !$self->_hide_utr($config,$_) and !$self->_hide_conseq($_,\%ct_filter) and !$self->_hide_evidence($_,\%ef_filter) } @$out ];

  return $out;
}

sub annotate {
  my ($self, $config, $slice_data, $mk, $seq, $ph,$real_sequence) = @_;

  my $transcript = $config->{'transcript'};
  my @exons = @{$transcript->get_all_Exons};
  my $cd_start     = $transcript->cdna_coding_start;
  my $cd_end       = $transcript->cdna_coding_end;
  my $start_phase  = $exons[0]->phase;
  my $start_pad    = $start_phase > 0 ? $start_phase : 0; # mid-codon?
  return unless $slice_data->{'vtype'} eq 'main';
  my $has_var = exists $ph->databases($config->{'species'})->{'DATABASE_VARIATION'};
  return unless $config->{'snp_display'} and $has_var;

  my @snps = reverse @{$self->_get_variation_data($ph,$config)};

  foreach my $snp (@snps) {
    next if $config->{'hide_long_snps'} && $snp->{'vf_length'} > $config->{'snp_length_filter'};
    next if $self->too_rare_snp($snp->{'vf_maf'},$config);
    next if $self->hidden_source($snp->{'vf_source'},$config);

    $snp->{'position'}||=0;
    my $dbID              = $snp->{'vdbid'};
    my $variation_name    = $snp->{'snp_id'};
    my $alleles           = $snp->{'allele'};
    my $ambigcode         = $snp->{'ambigcode'} || '*';
    my $amino_acid_pos    = $snp->{'position'} * 3 + $cd_start - 4 - $start_pad;
    my $type              = lc(($config->{'consequence_types'} ? [ grep $config->{'consequence_types'}{$_}, @{$snp->{'tv_conseq_type'}} ]->[0] : $snp->{'type'}||''));
    my $start             = $snp->{'tv_cdna_start'};
    my $end               = $snp->{'tv_cdna_end'};
    my $pep_allele_string = $snp->{'tv_pep_allele'};
    my $aa_change         = $pep_allele_string =~ /\// && $snp->{'tv_affects_peptide'};
    # Variation is an insert if start > end
    ($start, $end) = ($end, $start) if $start > $end;
        
    ($_ += $start_pad)-- for $start, $end; # Adjust from start = 1 (slice coords) to start = 0 (sequence array)

    foreach ($start..$end) {
      $mk->{'variants'}{$_}{'alleles'}   .= ($mk->{'variants'}{$_}{'alleles'} ? ', ' : '') . $alleles;
      $mk->{'variants'}{$_}{'url_params'} = { vf => $dbID, vdb => 'variation' };
      $mk->{'variants'}{$_}{'transcript'} = 1;
          
      my $url = {
        type => 'Variation',
        action => 'Explore',
        %{$mk->{'variants'}{$_}{'url_params'}}
      };
      $mk->{'variants'}{$_}{'href'} ||= {
        type        => 'ZMenu',
        action      => 'TextSequence',
        factorytype => 'Location'
      };
      $mk->{'variants'}{$_}{'type'} = $type;

      if ($config->{'translation'} && $aa_change) {
        foreach my $aa ($amino_acid_pos..$amino_acid_pos + 2) {
          $mk->{'variants'}{$aa}{'aachange'} = "$variation_name: $pep_allele_string";
        }
      }     
      push @{$mk->{'variants'}{$_}{'href'}{'vf'}}, $dbID;

      my $vseq = ($mk->{'variants'}{$_}{'vseq'} = {});
      if($config->{'variants_as_n'} and $ambigcode ne $vseq->{'letter'} and $ambigcode !~ /CGAT\*/) {
        $mk->{'variants'}{$_}{'ambiguity'} = 'N';
      }
      $vseq->{'letter'} = $ambigcode;
      $vseq->{'new_letter'} = $ambigcode;
      $vseq->{'href'} = $url;
      $vseq->{'title'} = $variation_name;
      $vseq->{'tag'} = 'a';
      $vseq->{'class'} = '';
    }
  }
}

1;
