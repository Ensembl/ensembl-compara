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

package EnsEMBL::Web::Component::StructuralVariation::Phenotype;

use strict;

use EnsEMBL::Web::Utils::Variation qw(display_items_list);

use base qw(EnsEMBL::Web::Component::StructuralVariation);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(1);
}

sub content {
  my $self = shift;
  my $object = $self->object;

  ## first check we have uniquely determined variation
  return $self->_info('A unique location can not be determined for this structural variant', $object->not_unique_location) if $object->not_unique_location;
  
  my $supporting_evidences = $object->Obj->get_all_SupportingStructuralVariants();
  my ($table_rows, $column_flags) = $self->table_data($supporting_evidences);
  
  return $self->_info('No phenotype data','We do not have any phenotype data associated with this structural variant.') unless scalar (keys(%$table_rows));
  
  my $table = $self->new_table([], [], { data_table => 1 });
   

  my $columns = [
    { key => 'disease',    title => 'Disease/Trait',  align => 'left', sort => 'html' }, 
  ];

  if ($column_flags->{'ontology'}) {
    push(@$columns, { key => 'terms',      title => 'Mapped Terms',        align => 'left', sort => 'html' });
    push(@$columns, { key => 'accessions', title => 'Ontology Accessions', align => 'left', sort => 'html' });
  }

  # Clinical significance
  if ($column_flags->{'clin_sign'}) {
   push(@$columns,{ key => 'clin_sign', title => 'Clinical significance',  align => 'left', sort => 'hidden_string' });
  }

  push(@$columns,{ key => 's_evidence', title => 'Supporting evidence(s)', align => 'left', sort => 'html' });

  $table->add_columns(@$columns);
  $table->add_rows($_) for values %$table_rows;
  
  return $table->render;
};


sub table_data { 
  my ($self, $supporting_evidences) = @_;
  
  my $hub        = $self->hub;
  my $object     = $self->object;
  
  my $skip_phenotypes_link = 'non_specified';

  my %phenotypes;
  my %clin_sign;
  my %column_flags;
  my %ssv_phen;
  my ($terms, $accessions);

  # SV phenotype
  my $sv_pf = $self->object->Obj->get_all_PhenotypeFeatures();
  foreach my $pf (@$sv_pf) {
    my $phe = $pf->phenotype->description;
    my $phe_class = $pf->phenotype_class;

    if (!exists $phenotypes{$phe} && $phe_class ne $skip_phenotypes_link) {
      my $phe_url = $hub->url({ type => 'Phenotype', action => 'Locations', ph => $pf->phenotype->dbID, name => $phe });
      $phenotypes{$phe} = { disease => qq{<a href="$phe_url" title="View associate loci"><b>$phe</b></a>} };
    }

    # Ontology data
    ($terms, $accessions) = $self->get_ontology_data($pf,$phe,$terms,$accessions);

    # Clinical significance in PF
    %clin_sign = %{$self->get_pf_clin_sign($pf,$phe,\%clin_sign)};
  }


  # SSV phenotype
  my $count_se = scalar @$supporting_evidences;
                 
  foreach my $evidence (@$supporting_evidences) {
  
    my $svas = $evidence->get_all_PhenotypeFeatures();
    my $ssv_name = $evidence->variation_name;

    foreach my $sva (@$svas) {
      next if ($sva->seq_region_start==0 || $sva->seq_region_end==0);
      
      my $phe = ($sva->phenotype) ? $sva->phenotype->description : undef;
      my $phe_class = $sva->phenotype_class;

       # Ontology data
      ($terms, $accessions) = $self->get_ontology_data($sva,$phe,$terms,$accessions);

      # Clinical significance in SV
      my $sv_clin_sign = $evidence->get_all_clinical_significance_states;
      if ($sv_clin_sign) {
        foreach my $cs (@$sv_clin_sign) {
          $clin_sign{$phe}{$cs} = 1;
        }
      }
      # Clinical significance in PF
      %clin_sign = %{$self->get_pf_clin_sign($sva,$phe,\%clin_sign)};

      if ($phe && !$ssv_phen{$ssv_name}{$phe}) {
        $ssv_phen{$ssv_name}{$phe} = 1;
        if (exists $phenotypes{$phe}{s_evidence}) {
          $phenotypes{$phe}{s_evidence} .= ', '.$sva->object_id;
        } 
        else {
          my $phe_url = $hub->url({ type => 'Phenotype', action => 'Locations', ph => $sva->phenotype->dbID, name => $phe });
          $phenotypes{$phe} = {
            disease    => qq{<a href="$phe_url" title="View associate loci"><b>$phe</b></a>},
            s_evidence => $sva->object_id
          };
          $phenotypes{$phe}{disease}=$phe if ($phe_class eq $skip_phenotypes_link);

        }
      }
    }
  }

  foreach my $phe (keys(%clin_sign)) {
    my $clin_sign_data;
    foreach my $cs (keys(%{$clin_sign{$phe}})) {
      my $icon_name = $cs;
      $icon_name =~ s/ /-/g;
      $icon_name = 'other' if ($icon_name =~ /conflict/);
      $clin_sign_data .= sprintf(
        '<span class="hidden export">%s</span>'.
        '<img class="_ht" style="margin-right:6px;margin-bottom:-2px;vertical-align:top" title="%s" src="/i/val/clinsig_%s.png" />',
        $cs, $cs, $icon_name
      );
    }
    $phenotypes{$phe}{clin_sign} = ($clin_sign_data) ? $clin_sign_data : '-';
  }
  $column_flags{'clin_sign'} = 1 if (%clin_sign);

  foreach my $phe (keys(%phenotypes)) {
    $phenotypes{$phe}{s_evidence} = '-' if (!$phenotypes{$phe}{s_evidence});
  }


  # Ontology
  if ($terms || $accessions) {
    foreach my $phe (keys(%phenotypes)) {
      # Ontology terms
      my $terms_html = '-';
      if ($terms && $terms->{$phe}) {
        my $div_id = $terms->{$phe}{'id'}."_term";
        my @terms_list = sort(keys(%{$terms->{$phe}{'term'}}));
        $terms_html = display_items_list($div_id, 'ontology terms', 'terms', \@terms_list, \@terms_list);
      }
      $phenotypes{$phe}{terms} = $terms_html;

      # Ontology accessions
      my $accessions_html = '-';
      if ($accessions && $accessions->{$phe}) {
        my $div_id = $accessions->{$phe}{'id'}."_accession";
        my @accessions_list = sort(keys(%{$accessions->{$phe}{'acc'}}));
        my @accessions_urls = sort(keys(%{$accessions->{$phe}{'url'}}));
        $accessions_html = display_items_list($div_id, 'ontology accessions', 'accessions', \@accessions_urls, \@accessions_list);
      }
      $phenotypes{$phe}{accessions} = $accessions_html;

    }
    $column_flags{'ontology'} = 1 if ($terms || $accessions);
  }

  return \%phenotypes,\%column_flags;
}

sub get_pf_clin_sign {
  my $self      = shift;
  my $pf        = shift;
  my $phe       = shift;
  my $clin_sign = shift;

  my $pf_clin_sign = $pf->clinical_significance;
  if ($pf_clin_sign) {
    foreach my $clin_sign_term (split(/\/|,/,$pf_clin_sign)) {
      $clin_sign_term =~ s/^\s//;
      $clin_sign->{$phe}{$clin_sign_term} = 1;
    }
  }
  return $clin_sign;
}


## Ontology information
sub get_ontology_data {
  my $self  = shift;
  my $pf    = shift;
  my $phe   = shift;
  my $terms = shift;
  my $acc   = shift;

  my $hub = $self->hub;

  my $ontology_accessions = $pf->phenotype()->ontology_accessions();

  my $adaptor = $hub->get_adaptor('get_OntologyTermAdaptor', 'go');

  foreach my $oa (@{$ontology_accessions}){

    ## only these ontologies have links defined currently
    next unless $oa =~ /^EFO|^Orph|^DO|^HP/;
    ## skip if the ontology is already in the hash
    next unless !$acc->{$phe}{'acc'}{$oa};

    $acc->{$phe}{'acc'}{$oa} = 1;

    ## build link out to Ontology source
    my $iri_form = $oa;
    $iri_form =~ s/\:/\_/;

    my $ontology_link;
    $ontology_link = $hub->get_ExtURL_link($oa, 'EFO',  $iri_form) if $oa =~ /^EFO/;
    $ontology_link = $hub->get_ExtURL_link($oa, 'OLS',  $iri_form) if $oa =~ /^Orp/;
    $ontology_link = $hub->get_ExtURL_link($oa, 'DOID', $iri_form) if $oa =~ /^DO/;
    $ontology_link = $hub->get_ExtURL_link($oa, 'HPO',  $iri_form) if $oa =~ /^HP/;

    $acc->{$phe}{'url'}{$ontology_link} = 1 ;

    ## get term name from ontology db
    my $ontology_term = $adaptor->fetch_by_accession($oa);
    if (defined $ontology_term){
      my $name = $ontology_term->name();
      $terms->{$phe}{'term'}{$ontology_term->name()} = 1;
    }
  }

  $acc->{$phe}{'id'}   = $pf->dbID if ($acc->{$phe});
  $terms->{$phe}{'id'} = $pf->dbID if ($terms->{$phe});

  return $terms,$acc;
}

1;
