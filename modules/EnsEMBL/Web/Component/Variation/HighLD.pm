package EnsEMBL::Web::Component::Variation::HighLD;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Variation);
use Bio::EnsEMBL::Variation::DBSQL::LDFeatureContainerAdaptor;


sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  1 );
}

sub content {
  my $self = shift;
  my $object = $self->object;
  my $html = '';
 
  ## first check we have a location.
  if ( $object->not_unique_location ){
    return $self->_info(
      'A unique location can not be determined for this Variation',
      $object->not_unique_location
    );
  }
  
  # get params
  my $max_distance = $object->param('max_distance') || "50000";  
  my $min_r2 = (defined($object->param('min_r2')) ? $object->param('min_r2') : "0.8");
  my $min_d_prime = (defined($object->param('min_d_prime')) ? $object->param('min_d_prime') : "0.8");
  
  # define a colour scale for p-values
  my @colour_scale =  $object->get_imageconfig('ldview')->colourmap->build_linear_gradient(40, '#0000FF', '#770088', '#BB0044', 'red');
 
  ## set path information for LD calculations  
  $Bio::EnsEMBL::Variation::DBSQL::LDFeatureContainerAdaptor::BINARY_FILE = $object->species_defs->ENSEMBL_CALC_GENOTYPES_FILE;
  $Bio::EnsEMBL::Variation::DBSQL::LDFeatureContainerAdaptor::TMP_PATH = $object->species_defs->ENSEMBL_TMP_TMP;

  # if we have a location
  if($self->model->object('Location')) {
    
    # check we have LD populations defined
    if($object->species_defs->databases->{'DATABASE_VARIATION'}{'DEFAULT_LD_POP'}) {
      my $default_pop = $object->species_defs->databases->{'DATABASE_VARIATION'}{'DEFAULT_LD_POP'};
      
      my $ldca = $object->vari->adaptor->db->get_LDFeatureContainerAdaptor;
      
      # first determine correct SNP location 
      my %mappings = %{ $object->variation_feature_mapping }; 
      my $loc;
      if( keys %mappings == 1 ) {
        ($loc) = values %mappings;
      } else { 
        $loc = $mappings{$object->param('vf')};
      }
      
      # get the VF that matches the selected location
      my $vf;
      
      foreach(@{$object->get_variation_features}) {
        if($_->seq_region_start == $loc->{start}
          and $_->seq_region_end == $loc->{end}
          and $_->seq_region_name eq $loc->{Chr}) {
          $vf = $_;
          last;
        }
      }
      
      # get some adaptors
      my $pa = $object->vari->adaptor->db->get_PopulationAdaptor;
      my $vaa = $object->vari->adaptor->db->get_VariationAnnotationAdaptor;
      
      # get populations
      my @pops = grep {$object->param($_->name) eq 'yes'} @{$pa->fetch_all_LD_Populations};
      
      if(!@pops) {
        return "No populations"
      }
      
      foreach my $pop(sort {$a->name cmp $b->name} @pops) {
        my $pop_id = $pop->dbID;
        
        # make a table
        my $table = new EnsEMBL::Web::Document::SpreadSheet( [], [], {'margin' => '1em 0px', data_table => 1 } );
        
        my $align = 'center';
        
        # add header row
        $table->add_columns (
          {key  =>"variation",   title => "Variation", align => $align, sort => "html"},
          {key  =>"location",    title => "Location", align => $align, sort => "position_html"},
          {key  =>"distance",    title => "Distance (bp)", align => $align, sort => "numeric"},
          {key  =>"r2",    title => "r<sup>2</sup>", align => $align, sort => "numeric"},
          {key  =>"d_prime", title => "D\'", align => $align, sort => "numeric"},
          {key  =>"tag", title => "Tag SNP", align => $align, sort => "string"},
          {key  =>"genes", title => "Located in gene(s)", align => $align, sort => "html"},
          {key  =>"annotations", title => "Associated phenotype(s)", align => $align, width => "30%", sort => "html"},
        );
        
        my $temp_slice = $vf->feature_Slice->expand($max_distance, $max_distance);
        my $ldc = $ldca->fetch_by_Slice($temp_slice, $pop);
        
        # do some filtering
        my @old_values = @{$ldc->get_all_ld_values};
        my @new_values;
        my @other_vfs;
        
        foreach my $ld(@old_values) {
          next unless $ld->{variation1}->dbID == $vf->dbID or $ld->{variation2}->dbID == $vf->dbID;
          next unless $ld->{sample_id} == $pop_id;
          next unless $ld->{r2} >= $min_r2;
          next unless $ld->{d_prime} >= $min_d_prime;
          
          my $other_vf = ($ld->{variation1}->dbID == $vf->dbID ? $ld->{variation2} : $ld->{variation1});
          $ld->{other_vf} = $other_vf;
          
          push @new_values, $ld;
          push @other_vfs, $other_vf;
        }
        
        if(@new_values) {
          
          # get phenotype data
          foreach my $va(@{$vaa->fetch_all_by_VariationFeature_list(\@other_vfs)}) {
            
            # filter on p-value
            if($object->param('min_p_log') > 0) {
              if(defined($va->p_value)) {
                next unless (-log($va->p_value)/log(10)) > $object->param('min_p_log');
              }
            }
            
            foreach my $ld(@new_values) {
              $ld->{annotations}->{$va->{_phenotype_id}} = $va if $ld->{other_vf}->{_variation_id} == $va->{_variation_id};
            }
          }
          
          my @rows;
          
          foreach my $ld(sort {
            $b->{r2} <=> $a->{r2} ||
            $b->{d_prime} <=> $a->{d_prime} ||
            abs($a->{other_vf}->seq_region_start - $vf->seq_region_start) <=> abs($b->{other_vf}->seq_region_start - $vf->seq_region_start)} @new_values) {
            
            my $ld_vf = $ld->{other_vf};
            
            # switch start and end to avoid faff
            my ($start, $end) = ($ld_vf->seq_region_start, $ld_vf->seq_region_end);
            ($start, $end) = ($end, $start) if $start > $end;
            
            # create VA string
            my $va_string;
            my $vf_link_bit = "v=".$object->param('v').";vf=".$object->param('vf');
            
            next if $object->param('only_phenotypes') eq 'yes' and !defined($ld->{annotations});
            
            # check if any VAs for this variation
            if($ld->{annotations}) {
              
              $va_string .= '<table style="border:none; width:100%; padding:0px; margin:0px;">';
              
              # iterate through all VAs
              foreach(values %{$ld->{annotations}}) {
                #
                ## name part
                #$va_string .=
                #  '<a href="../Location/Genome?ftype=Phenotype;'.
                #    $vf_link_bit.
                #    ';id='.$_->{_phenotype_id}.';phenotype_name='.$_->phenotype_description.'">'.
                #    ($_->phenotype_name ? $_->phenotype_name : $_->phenotype_description).
                #  '</a>';
                #  
                ## p value part
                #if(defined $_->p_value) {
                #  
                #  # scale the p-value to an integer that might fall in @colour_scale
                #  my $p_scaled = sprintf("%.0f", (-log($_->p_value)/log(10)));
                #  
                #  # set a colour
                #  my $colour = $colour_scale[($p_scaled > $#colour_scale ? $#colour_scale : $p_scaled)];
                #  
                #  $va_string .= ' <span style="color:#'.$colour.';">('.$_->p_value.')</span>';
                #}
                #
                #$va_string .= ', ';
                
                ## p value part
                #if(defined $_->p_value) {
                #  
                #  # scale the p-value to an integer that might fall in @colour_scale
                #  my $p_scaled = sprintf("%.0f", (-log($_->p_value)/log(10)));
                #  
                #  # set a colour
                #  my $colour = $colour_scale[($p_scaled > $#colour_scale ? $#colour_scale : $p_scaled)];
                #  
                #  $va_string .= '<span style="-webkit-border-radius:1em; -moz-border-radius:1em; padding-left:0.5em; padding-right:0.5em; background:#'.$colour.';" title="'.$_->p_value.'">&nbsp;</span>';
                #}
                
                # name part
                #$va_string .=
                #  ' <a href="../Location/Genome?ftype=Phenotype;'.
                #    $vf_link_bit.
                #    ';id='.$_->{_phenotype_id}.';phenotype_name='.$_->phenotype_description.'">'.
                #    ($_->phenotype_name ? $_->phenotype_name : $_->phenotype_description).
                #  '</a>';
                #
                ## p value part
                #if(defined $_->p_value) {
                #  
                #  # scale the p-value to an integer that might fall in @colour_scale
                #  my $p_scaled = sprintf("%.0f", (-log($_->p_value)/log(10)));
                #  
                #  # set a colour
                #  my $colour = $colour_scale[($p_scaled > $#colour_scale ? $#colour_scale : $p_scaled)];
                #  
                #  $va_string .= ' <span style="float:right; color:#'.$colour.';">('.$_->p_value.')</span>';
                #}
                #  
                #$va_string .= '<br/>';
                
                my $va_url = $object->_url({
                  type           => 'Location',
                  action         => 'Genome',
                  ftype          => 'Phenotype',
                  id             => $_->{_phenotype_id},
                  phenotype_name => $_->phenotype_description,
                  v              => $ld_vf->variation_name,
                  vf             => $ld_vf->dbID,
                });
                
                $va_string .= 
                  '<tr ><td style="padding:0px; margin:0px;"><a href="'.$va_url.'">'.
                    ($_->phenotype_name ? $_->phenotype_name : $_->phenotype_description).
                  '</a></td><td style="padding:0px; margin:0px;">';
                  
                # p value part
                if(defined $_->p_value) {
                  
                  # scale the p-value to an integer that might fall in @colour_scale
                  my $p_scaled = sprintf("%.0f", (-log($_->p_value)/log(10)));
                  
                  # set a colour
                  my $colour = $colour_scale[($p_scaled > $#colour_scale ? $#colour_scale : $p_scaled)];
                  
                  $va_string .= '<span style="float:right; color:#'.$colour.';">('.$_->p_value.')</span>';
                }
                  
                $va_string .= '</td></tr>';
              }
              
              $va_string .= '</table>';
            }
            
            $va_string ||= "-";
            
            # get tagging info
            my $tag = "No";
            
            foreach my $tag_pop(@{$ld_vf->is_tagged}) {
              $tag = "Yes" if $tag_pop->dbID == $pop->dbID;
            }
            
            # get genes
            my $genes = join ", ", map {'<a href="'.
              $object->_url({
                type   => 'Gene',
                action => 'Variation_Gene',
                db     => 'core',
                r      => undef,
                g      => $_->stable_id,
                v      => $object->name,
                source => $object->vari->source
              }).'">'.$_->external_name.'</a>'} @{$ld_vf->feature_Slice->get_all_Genes};
            $genes ||= "-";
            
            # build URLs
            my $var_url = $object->_url({
              type   => 'Variation',
              action => 'Summary',
              vdb    => 'variation',
              v      => $ld_vf->variation_name,
              vf     => $ld_vf->dbID,
            });
            
            my $loc_url = $object->_url({
              type   => 'Location',
              action => 'View',
              db     => 'core',
              v      => $ld_vf->variation_name,
              vf     => $ld_vf->dbID,
            });
            
            my %row = (
              'variation' => '<a href="'.$var_url.'">'.$ld_vf->variation_name.'</a>',
              'location' => '<a href="'.$loc_url.'">'.$ld_vf->seq_region_name.':'.($start == $end ? $start : $start.'-'.$end).'</a>',
              'distance' => abs($start - ($vf->seq_region_start > $vf->seq_region_end ? $vf->seq_region_end : $vf->seq_region_start)),
              'r2' => $ld->{r2}, #sprintf("%.3f", $ld->{r2}),
              'd_prime' => $ld->{d_prime}, #sprintf("%.3f", $ld->{d_prime}),
              'tag' => $tag,
              'genes' => $genes,
              'annotations' => $va_string,
            );
            
            push @rows, \%row;
          }
          
          if(@rows) {
            map {$table->add_row($_)} @rows;
            $html .= '<h2>'.$pop->name.'</h2>';
            $html .= $table->render;
          }
        }
        
        else {
          $html .= '<h2>'.$pop->name.'</h2>';
          $html .= "No variations found<br/><br/>";
        }
      }
    }
  }
 
  return $html;
}

1;
