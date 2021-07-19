=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2021] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Query::Sequence::TVGet;

use strict;
use warnings;

use parent qw(EnsEMBL::Web::Query::Generic::Sequence);

our $VERSION = 1;

sub precache {
  return {
    'tv-get' => {
      loop => ['species','transcripts'],
      args => {
        type => "core"
      },
      parts => 5000,
    }
  };
}

sub fixup {
  my ($self) = @_;

  $self->fixup_transcript('transcript','species','type');
  $self->SUPER::fixup();
}

sub _transcript_variation_to_variation_feature {
  my ($self,$tv,$vf_cache) = @_;

  my $vfid = $tv->_variation_feature_id;
  my $val = ($vf_cache||{})->{$vfid};
  return $val if defined $val;
  return $tv->variation_feature;
}

sub _build_vf_cache {
  my ($self,$config,$trans,$cache,$tvs) = @_;

  my $need_db_fetch = 0;
  foreach my $tv(@$tvs) {
    if(my $vf = $tv->{base_variation_feature} || $tv->{variation_feature}) {
      $cache->{$vf->dbID} = $vf;
    }
    else {
      $need_db_fetch = 1;
    }
  }

  if($need_db_fetch) {
    my $ad = $self->source('Adaptors');
    my $vfa = $ad->variation_feature_adaptor($config->{'species'});
    my $vfs = $vfa->fetch_all_by_Slice_constraint($trans->feature_Slice);
    return if @$vfs > 60000;
    $cache->{$_->dbID} = $_ for(@$vfs);
    $vfs = $vfa->fetch_all_somatic_by_Slice_constraint($trans->feature_Slice);
    return if @$vfs > 60000;
    $cache->{$_->dbID} = $_ for(@$vfs);
  }
}

sub _get_transcript_variations {
  my ($self,$config,$trans,$vf_cache) = @_;

  my $ad = $self->source('Adaptors');
  my $tva = $ad->transcript_variation_adaptor($config->{'species'});
  return $tva->fetch_all_by_Transcripts_with_constraint([ $trans ], undef, 1);
}

sub _get_variation_data {
  my ($self,$config,$strand) = @_;

  my $transcript = $config->{'transcript'};
  my $cd_start           = $transcript->cdna_coding_start;
  my $cd_end             = $transcript->cdna_coding_end;
  my @coding_sequence;
  if($cd_start) {
    @coding_sequence = split '', substr $transcript->seq->seq, $cd_start - 1, $cd_end - $cd_start + 1;
  }
  my @data;

  # get TVs first
  my $tvs = $self->_get_transcript_variations($config,$transcript);

  my $vf_cache = {};
  $self->_build_vf_cache($config,$transcript,$vf_cache,$tvs);
  
  foreach my $tv (@{$tvs}) {

    next unless $tv->cdna_start && $tv->cdna_end;

    my $vf    = $self->_transcript_variation_to_variation_feature($tv,$vf_cache) or next;
    my $vdbid = $vf->dbID;

    my $start = $vf->start;
    my $end   = $vf->end;

    push @data, {
      order         =>
        [$vf->length,$vf->most_severe_OverlapConsequence->rank],

      tv_conseq_type => $tv->consequence_type,
      tv_cdna_start => $tv->cdna_start,
      tv_cdna_end   => $tv->cdna_end,
      tv_pep_allele => $tv->pep_allele_string,
      tv_affects_peptide => $tv->affects_peptide,

      vf_maf        => $vf->minor_allele_frequency,
      vf_source     => $vf->source_name,
      vf_length     => $vf->length,

      position      => $tv->translation_start,
      vdbid         => $vdbid,
      snp_id        => $vf->variation_name,
      ambigcode     => $vf->ambig_code($strand),
      allele        => $vf->allele_string(undef, $strand),
      type          => $tv->display_consequence,
      evidence      => $vf->get_all_evidence_values,
    };
  }

  @data = map $_->[2], sort { $a->[0] <=> $b->[0] || $a->[1] <=> $b->[1] } map [ (@{$_->{'order'}}, $_) ], @data;

  return \@data;
}

sub get {
  my ($self,$args) = @_;

  my @exons = @{$args->{'transcript'}->get_all_Exons};
  my $strand = $exons[0]->strand;
  return $self->_get_variation_data($args,$strand);
}

1;
