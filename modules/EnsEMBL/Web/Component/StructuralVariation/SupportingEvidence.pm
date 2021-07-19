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


package EnsEMBL::Web::Component::StructuralVariation::SupportingEvidence;

use strict;

use base qw(EnsEMBL::Web::Component);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(1);
}

sub content {
  my $self = shift;
  my $object        = $self->object;
  my $hub           = $self->hub;
  my $supporting_sv = $object->supporting_sv;
  my $html          = $self->supporting_evidence_table($supporting_sv);
  return $html;
}


sub supporting_evidence_table {
  my $self     = shift;
  my $ssvs     = shift;
  my $hub      = $self->hub;
  my $object   = $self->object;
  my $table_id = 'evidence';
  
  my $columns = [
     { key => 'ssv', sort => 'string',        title => 'Variant call ID' },
     { key => 'pos', sort => 'position_html', title => 'Chr:bp (strand)'     }, 
  ];
  my $sorting = 'pos';

  my $rows = ();
  my %has_data;
  
  # Supporting evidences list
  if (scalar @{$ssvs}) {
    foreach my $ssv_obj (@{$ssvs}) {
      my $name = $ssv_obj->variation_name;
      my $loc;
      my $bp_order;
      my $is_somatic = $ssv_obj->is_somatic;
      my $copy_number = $ssv_obj->copy_number;

      # Location(s)
      foreach my $svf (sort {$a->seq_region_start <=> $b->seq_region_start} @{$ssv_obj->get_all_StructuralVariationFeatures}) {
        my ($sv_name,$chr_bp);
        my $start  = $svf->seq_region_start;
        my $end    = $svf->seq_region_end;
        my $strand = $svf->seq_region_strand;
           $strand = ' <small>('.($strand > 0 ? 'forward' : 'reverse').' strand)</small>';
        next if ($start == 0 || $end == 0);
        
        $bp_order = $svf->breakpoint_order;
        my $chr = $svf->seq_region_name.':';
        
        
        if ($bp_order) {
          my @c_list = ($start!=$end) ? ($start,$end) : ($start);
            
          foreach my $coord (@c_list) {
            $chr_bp = $chr.$coord;
            my $loc_hash = {
                type   => 'Location',
                action => 'View',
                r      => $chr_bp,
            };

            $loc_hash->{sv} .= $name if ($ssv_obj->is_evidence == 0);
          
            my $loc_url = $hub->url($loc_hash);
            $loc .= ($loc) ? "<br />to " : "from ";
            $loc .= qq{<a href="$loc_url">$chr_bp</a>$strand};
          }
        }
        else {
          $chr_bp  = $chr;
          $chr_bp .= $start == $end ? $start : $start.'-'.$end;
          my $loc_url;
        
          my $loc_hash = {
              type   => 'Location',
              action => 'View',
              r      => $chr_bp,
          };
          $loc_hash->{sv} = $name if ($ssv_obj->is_evidence == 0);
          
          my $loc_url = $hub->url($loc_hash);
          $loc .= "<br />" if ($loc);
          $loc .= qq{<a href="$loc_url">$chr_bp</a>$strand};
        }
        
        $has_data{'bp'}   = 1 if ($bp_order && $bp_order > 1 && $is_somatic == 1);
        $has_data{'copy'} = 1 if ($copy_number);
      }
      $loc = '-' if (!$loc);
  
      # Name
      if ($ssv_obj->is_evidence == 0) {
        my $sv_link = $hub->url({
                        type   => 'StructuralVariation',
                        action => 'Explore',
                        sv     => $name,
                      });
        $name = qq{<a href="$sv_link">$name</a>};
      }
  
      # Class + class colour
      my $colour = $object->get_class_colour($ssv_obj->class_SO_term);
      my $sv_class = sprintf('<span class="hidden export">%s</span><span class="structural-variation-allele" style="background-color:%s"></span><span style="margin-bottom:2px">%s</span>', $ssv_obj->var_class, $colour, $ssv_obj->var_class);


      ## Annotation(s) ##

      # Clinical significance
      my %clin_sign_icon;
      my $clin;

      my $clin_sign = $ssv_obj->get_all_clinical_significance_states;

      if (scalar @$clin_sign) {
        foreach my $cs (@{$clin_sign}) {
          my $icon_name = $cs;
          $icon_name =~ s/ /-/g;
          $clin_sign_icon{$cs} = $icon_name;
        }

        $clin = join('',
           map {
             sprintf(
               '<img class="_ht" style="margin-right:6px;margin-bottom:-2px;vertical-align:top" title="%s" src="/i/val/clinsig_%s.png" />',
               $_, $clin_sign_icon{$_}
             )
           } @$clin_sign
        );

        my $clin_export = sprintf('<span class="hidden export">%s</span>', join(',',@$clin_sign));
        $clin = $clin_export.$clin;
        $has_data{'clin'} = 1;
      }

      my ($sample, $strain, $phen);
      my ($samples, $strains, $phens);
      
      # Phenotype
      foreach my $pf (sort {$a->seq_region_start <=> $b->seq_region_start} @{$ssv_obj->get_all_PhenotypeFeatures}) {
        my $a_phen = $pf->phenotype->description;
        $phens->{$a_phen} = 1;
        $has_data{'phen'} = 1;
      }
      
      # Sample/strain
      foreach my $svs (@{$ssv_obj->get_all_StructuralVariationSamples}) {
        
        my $a_sample  = ($svs->sample) ? $svs->sample->name : undef;
        my $a_strain = ($svs->strain && $hub->species =~ /^(mus|mouse)/i) ? $svs->strain->name : undef;
        
        if ($a_sample) {
          $samples->{$a_sample} = 1;
          $has_data{'sample'} = 1;
        }
        if ($a_strain) {
          $strains->{$a_strain} = 1;
          $has_data{'str'} = 1 
        }
      }
     
      $sample  = join(';<br />', sort (keys(%$samples)));
      $strain = join(';<br />', sort (keys(%$strains)));
      $phen   = join(';<br />', sort (keys(%$phens)));
      
      my %row = (
                  ssv      => $name,
                  class    => $sv_class,
                  pos      => $loc,
                  copy     => $copy_number ? $copy_number : '-',
                  clin     => $clin ? $clin : '-',
                  sample   => $sample ? $sample : '-',
                  strain   => $strain ? $strain : '-',
                  bp_order => $bp_order ? $bp_order : '-',
                  phen     => $phen ? $phen : '-',
                );
        
      push @$rows, \%row;
    }
    
    if ($has_data{'bp'}) {  
     push(@$columns,{ key => 'bp_order', sort => 'numeric', title => 'Breakpoint order' });
     $sorting = 'bp_order';
    };
    
    push(@$columns,{ key => 'class', sort => 'hidden_string', title => 'Allele type' });

    if ($has_data{'copy'}) {
      push(@$columns,{ key => 'copy',  sort => 'integer', title => 'Copy number', help => 'for the structural variants classified as Copy Number Variant (CNV)' });
    }

    if ($has_data{'clin'}) {
      push(@$columns,{ key => 'clin',  sort => 'hidden_string', title => 'Clinical significance' });
    }
    
    if ($has_data{'sample'}) {
      push(@$columns, { key => 'sample', sort => 'string', title => 'Sample name(s)'});
    }
    
    if ($has_data{'phen'}) {  
     push(@$columns,{ key => 'phen', sort => 'string', title => 'Phenotype(s)' });
    };
    
    if ($has_data{'str'}) {  
     push(@$columns,{ key => 'strain', sort => 'string', title => ucfirst $hub->species_defs->STRAIN_TYPE });
    };

    my $ssv_count   = scalar(@{$ssvs});
    my $sub_header  = $object->name." has ".$self->thousandify($ssv_count)." variant call";
       $sub_header .= 's' if ($ssv_count > 1);
    return "<h4>$sub_header</h4>".$self->new_table($columns, $rows, { data_table => 1, sorting => [ "$sorting asc" ] })->render;
  }
}
1;
