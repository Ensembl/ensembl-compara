
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
     { key => 'pos',    sort => 'position_html', title => 'Chr:bp'                },
     { key => 'class',  sort => 'string',        title => 'Allele type'           },
     { key => 'clin',   sort => 'string',        title => 'Clinical significance' },
     { key => 'sample', sort => 'string',        title => 'Sample name'           }, 
  ];
  
  if ($self->hub->species ne 'Homo_sapiens') {  
     push(@$columns,{ key => 'strain', sort => 'string', title => 'Strain' });
  };

  my $rows = ();
  
  # Supporting evidences list
  if (scalar @{$ssvs}) {
    my $ssv_names = {};
    foreach my $ssv (@$ssvs){
      my $name = $ssv->name;
      $name =~ /(\d+)$/;
      my $ssv_nb = $1;
      $ssv_names->{$1} = $ssv;
    }
    
    foreach my $ssv_n (sort {$a <=> $b} (keys(%$ssv_names))) {
      my $ssv_obj = $ssv_names->{$ssv_n};
      my $name = $ssv_obj->variation_name;
      my $loc;
      
      # Location(s)
      foreach my $svf (@{$ssv_obj->get_all_StructuralVariationFeatures}) {
        my $sv_name;
        my $chr_bp = $svf->seq_region_name . ':' . $svf->seq_region_start . '-' . $svf->seq_region_end;
        my $loc_url;
        
        my $loc_hash = {
            type   => 'Location',
            action => 'View',
            r      => $chr_bp,
          };
        $loc_hash->{sv} = $name if ($ssv_obj->is_evidence == 0);
          
        my $loc_url = $hub->url($loc_hash);
        $loc .= <br /> if ($loc);
        $loc .= qq{<a href="$loc_url">$chr_bp</a>};
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
      my ($clin, $sample, $strain);
      foreach my $annot (@{$ssv_obj->get_all_StructuralVariationAnnotations}) {
        my $aclin = $annot->clinical_significance;
        my $asample = $annot->sample_name;
        my $astrain = $annot->strain_name;
        
        if ($aclin) {
          $clin .= '<br />' if ($clin);
          $clin = $aclin;
        }
        if ($asample) {
          $sample .= '<br />' if ($sample);
          $sample = $asample;
        }
        if ($astrain) {
          $strain .= '<br />' if ($strain);
          $strain = $astrain;
        }
      }
      
      my %row = (
                  ssv    => $name,
                  class  => $sv_class,
                  pos    => $loc,
                  clin   => $clin ? $clin : '-',
                  sample => $sample ? $sample : '-',
                  strain => $strain ? $strain : '-',
                );
        
      push @$rows, \%row;
    }
    return $self->new_table($columns, $rows, { data_table => 1, sorting => [ 'location asc' ] })->render;
  }
}
1;
