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

package EnsEMBL::Web::Component::StructuralVariation::Phenotype;

use strict;

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
  return $self->_info('A unique location can not be determined for this Structural Variation', $object->not_unique_location) if $object->not_unique_location;
  
  my $supporting_evidences = $object->Obj->get_all_SupportingStructuralVariants();
  my ($table_rows, $column_flags) = $self->table_data($supporting_evidences);
  
  return $self->_info('No phenotype data','We do not have any phenotype data associated wih this structural variation.') unless scalar (keys(%$table_rows));
  
  my $table = $self->new_table([], [], { data_table => 1 });
   

  my $columns = [
    { key => 'disease',    title => 'Disease/Trait',  align => 'left', sort => 'html' }, 
  ];

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
  
  my %phenotypes;
  my %clin_sign;
  my %column_flags;
  my %ssv_phen;

  # SV phenotype
  my $sv_pf = $self->object->Obj->get_all_PhenotypeFeatures();
  foreach my $pf (@$sv_pf) {
    my $phe = $pf->phenotype->description;
    if (!exists $phenotypes{$phe}) {
      $phenotypes{$phe} = { disease => qq{<b>$phe</b>} };
    }

    # Clinical significance in PF
    my $pf_clin_sign = $pf->clinical_significance;
    if ($pf_clin_sign) {
      $clin_sign{$phe}{$pf_clin_sign} = 1;
    }
  }


  # SSV phenotype
  my $count_se = scalar @$supporting_evidences;
                 
  foreach my $evidence (@$supporting_evidences) {
  
    my $svas = $evidence->get_all_PhenotypeFeatures();
    my $ssv_name = $evidence->variation_name;

    foreach my $sva (@$svas) {
      next if ($sva->seq_region_start==0 || $sva->seq_region_end==0);
      
      my $phe = ($sva->phenotype) ? $sva->phenotype->description : undef;

      # Clinical significance in SV
      my $sv_clin_sign = $evidence->get_all_clinical_significance_states;
      if ($sv_clin_sign) {
        foreach my $cs (@$sv_clin_sign) {
          $clin_sign{$phe}{$cs} = 1;
        }
      }
      # Clinical significance in PF
      my $pf_clin_sign = $sva->clinical_significance;
      if ($pf_clin_sign) {
        $clin_sign{$phe}{$pf_clin_sign} = 1;
      }

      if ($phe && !$ssv_phen{$ssv_name}{$phe}) {
        $ssv_phen{$ssv_name}{$phe} = 1;
        if (exists $phenotypes{$phe}{s_evidence}) {
          $phenotypes{$phe}{s_evidence} .= ', '.$sva->object_id;
        } 
        else {
          $phenotypes{$phe} = {
            disease    => qq{<b>$phe</b>},
            s_evidence => $sva->object_id
          };
        }
      }
    }
  }

  foreach my $phe (keys(%clin_sign)) {
    my $clin_sign_data;
    foreach my $cs (keys(%{$clin_sign{$phe}})) {
      my $icon_name = $cs;
      $icon_name =~ s/ /-/g;
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

  return \%phenotypes,\%column_flags;
}


1;
