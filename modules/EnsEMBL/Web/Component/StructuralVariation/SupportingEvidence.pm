
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
  my $object         = $self->object;
  my $hub           = $self->hub;
  my $supporting_sv  = $object->supporting_sv;
  my $html          = $self->supporting_evidence_table($supporting_sv);
  return $html;
}


sub supporting_evidence_table {
  my $self     = shift;
  my $ssvs     = shift;
  my $hub      = $self->hub;
  my $object   = $self->object;
  my $title    = 'Supporting evidence';
  my $table_id = 'evidence';
  
  my $columns = [
     { key => 'ssv',    sort => 'string',        title => 'Supporting evidence'   },
     { key => 'pos',    sort => 'position_html', title => 'Chr:bp (strand)'       }, 
  ];
  my $sorting = 'pos';

  my $rows = ();
  my $has_bp;
  my $has_phen;
  
  # Supporting evidences list
  if (scalar @{$ssvs}) {
    my $ssv_names = {};
    foreach my $ssv (@$ssvs){
      my $name = $ssv->variation_name;
      $name =~ /(\d+)$/;
      my $ssv_nb = $1;
      $ssv_names->{$1} = $ssv;
    }
   
    foreach my $ssv_n (sort {$a <=> $b} (keys(%$ssv_names))) {
      my $ssv_obj = $ssv_names->{$ssv_n};
      my $name = $ssv_obj->variation_name;
      my $loc;
      my $bp_order;
      my $is_somatic = $ssv_obj->is_somatic;
      
      # Location(s)
      foreach my $svf (@{$ssv_obj->get_all_StructuralVariationFeatures}) {
        my ($sv_name,$chr_bp);
        my $start  = $svf->seq_region_start;
        my $end    = $svf->seq_region_end;
        my $strand = $svf->seq_region_strand;
           $strand = ' <small>('.($strand > 0 ? 'forward' : 'reverse').' strand)</small>';
        
        $bp_order = $svf->breakpoint_order;
        my $chr = $svf->seq_region_name.':';
        
        
        if ($bp_order && $is_somatic == 1) {
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
        
        $has_bp = 1 if ($bp_order && $bp_order > 1 && $is_somatic == 1);
      }
      $loc = '-' if (!$loc);
  
      # Name
      if ($ssv_obj->is_evidence == 0) {
        my $sv_link = $hub->url({
                        type   => 'StructuralVariation',
                        action => 'Summary',
                        sv     => $name,
                      });
        $name = qq{<a href="$sv_link">$name</a>};
      }
  
      # Class + class colour
      my $colour = $object->get_class_colour($ssv_obj->class_SO_term);
      my $sv_class = '<table style="border-spacing:0px"><tr><td style="background-color:'.$colour.';width:5px"></td><td style="margin:0px;padding:0px">&nbsp;'.$ssv_obj->var_class.'</td></tr></table>';
       
      # Annotation(s)
      my ($clin, $sample, $strain, $phen);
      foreach my $annot (@{$ssv_obj->get_all_StructuralVariationAnnotations}) {
        my $aclin = $annot->clinical_significance;
        my $asample = $annot->sample_name;
        my $astrain = $annot->strain_name;
        my $aphen   = $annot->phenotype_description;
        
        if ($aclin) {
          $clin .= ';<br />' if ($clin);
          $clin .= $aclin;
        }
        if ($asample) {
          $sample .= ';<br />' if ($sample);
          $sample .= $asample;
        }
        if ($astrain) {
          $strain .= ';<br />' if ($strain);
          $strain .= $astrain;
        }
        if ($aphen) {
          $phen .= ';<br />' if ($phen);
          $phen .= $aphen;
          $has_phen = 1;
        }    
      }
      
      my %row = (
                  ssv      => $name,
                  class    => $sv_class,
                  pos      => $loc,
                  clin     => $clin ? $clin : '-',
                  sample   => $sample ? $sample : '-',
                  strain   => $strain ? $strain : '-',
                  bp_order => $bp_order ? $bp_order : '-',
                  phen     => $phen ? $phen : '-',
                );
        
      push @$rows, \%row;
    }
    
    if (defined($has_bp)) {  
     push(@$columns,{ key => 'bp_order', sort => 'numeric', title => 'Breakpoint order' });
     $sorting = 'bp_order';
    };
    
    push @$columns, (
     { key => 'class',  sort => 'string',        title => 'Allele type'           },
     { key => 'clin',   sort => 'string',        title => 'Clinical significance' },
     { key => 'sample', sort => 'string',        title => 'Sample name(s)'        },
    );
    
    if (defined($has_phen)) {  
     push(@$columns,{ key => 'phen', sort => 'string', title => 'Phenotype(s)' });
    };
    
    if ($self->hub->species ne 'Homo_sapiens') {  
     push(@$columns,{ key => 'strain', sort => 'string', title => 'Strain' });
    };
    
    
    return $self->new_table($columns, $rows, { data_table => 1, sorting => [ "$sorting asc" ] })->render;
  }
}
1;
