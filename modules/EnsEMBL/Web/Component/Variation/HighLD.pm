# $Id$

package EnsEMBL::Web::Component::Variation::HighLD;

use strict;

use Bio::EnsEMBL::Variation::DBSQL::LDFeatureContainerAdaptor;

use base qw(EnsEMBL::Web::Component::Variation);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(1);
}

sub content {
  my $self   = shift;
  my $object = $self->object;
  
  ## first check we have a location.
  return $self->_info('A unique location can not be determined for this Variation', $object->not_unique_location) if $object->not_unique_location;
  
  my $hub          = $self->hub;
  my $species_defs = $hub->species_defs;
  my $variation    = $object->Obj;
  
  # check we have a location and LD populations are defined
  return unless $self->builder->object('Location') && $species_defs->databases->{'DATABASE_VARIATION'}{'DEFAULT_LD_POP'};
  
  # get populations
  my @pops = grep $hub->param($_->name) eq 'yes', @{$variation->adaptor->db->get_PopulationAdaptor->fetch_all_LD_Populations};
  
  return 'No populations' unless scalar @pops;
  
  ## set path information for LD calculations  
  $Bio::EnsEMBL::Variation::DBSQL::LDFeatureContainerAdaptor::BINARY_FILE = $species_defs->ENSEMBL_CALC_GENOTYPES_FILE;
  $Bio::EnsEMBL::Variation::DBSQL::LDFeatureContainerAdaptor::TMP_PATH    = $species_defs->ENSEMBL_TMP_TMP;
  
  my $v               = $object->name;
  my $source          = $variation->source;
  my $vaa             = $variation->adaptor->db->get_VariationAnnotationAdaptor;
  my $ldca            = $variation->adaptor->db->get_LDFeatureContainerAdaptor;
  my $max_distance    = $hub->param('max_distance') || 50000;  
  my $min_r2          = defined $hub->param('min_r2')      ? $hub->param('min_r2')      : 0.8;
  my $min_d_prime     = defined $hub->param('min_d_prime') ? $hub->param('min_d_prime') : 0.8;
  my $min_p_log       = $hub->param('min_p_log');
  my $only_phenotypes = $hub->param('only_phenotypes') eq 'yes';
  my @colour_scale    = $hub->colourmap->build_linear_gradient(40, '#0000FF', '#770088', '#BB0044', 'red'); # define a colour scale for p-values
  my %mappings        = %{$object->variation_feature_mapping};  # first determine correct SNP location 
  my ($vf, $loc, $html);
  
  if (keys %mappings == 1) {
    ($loc) = values %mappings;
  } else { 
    $loc = $mappings{$hub->param('vf')};
  }
  
  # get the VF that matches the selected location  
  foreach (@{$object->get_variation_features}) {
    if ($_->seq_region_start == $loc->{'start'} && $_->seq_region_end == $loc->{'end'} && $_->seq_region_name eq $loc->{'Chr'}) {
      $vf = $_;
      last;
    }
  }
  
  my $vf_dbID    = $vf->dbID;
  my $vf_start   = $vf->seq_region_start;
  my $vf_end     = $vf->seq_region_end;
  my $temp_slice = $vf->feature_Slice->expand($max_distance, $max_distance);
  
  foreach my $pop (sort { $a->name cmp $b->name } @pops) {
    my $pop_id = $pop->dbID;
    my $table  = $self->new_table([], [], { data_table => 1 });
    
    # add header row
    $table->add_columns(
      { key => 'variation',   title => 'Variation',               align => 'center', sort => 'html'                 },
      { key => 'location',    title => 'Location',                align => 'center', sort => 'position_html'        },
      { key => 'distance',    title => 'Distance (bp)',           align => 'center', sort => 'numeric'              },
      { key => 'r2',          title => 'r<sup>2</sup>',           align => 'center', sort => 'numeric'              },
      { key => 'd_prime',     title => q{D'},                     align => 'center', sort => 'numeric'              },
      { key => 'tag',         title => 'Tag SNP',                 align => 'center', sort => 'string'               },
      { key => 'genes',       title => 'Located in gene(s)',      align => 'center', sort => 'html'                 },
      { key => 'annotations', title => 'Associated phenotype(s)', align => 'center', sort => 'html', width => '30%' },
    );
    
    # do some filtering
    my @old_values = @{$ldca->fetch_by_Slice($temp_slice, $pop)->get_all_ld_values};
    my @new_values;
    my @other_vfs;
    
    foreach my $ld (@old_values) {
      next unless $ld->{'variation1'}->dbID == $vf_dbID || $ld->{'variation2'}->dbID == $vf_dbID;
      next unless $ld->{'sample_id'} == $pop_id;
      next unless $ld->{'r2'}      >= $min_r2;
      next unless $ld->{'d_prime'} >= $min_d_prime;
      
      my $other_vf = $ld->{'variation1'}->dbID == $vf_dbID ? $ld->{'variation2'} : $ld->{'variation1'};
      $ld->{'other_vf'} = $other_vf;
      
      push @new_values, $ld;
      push @other_vfs, $other_vf;
    }
    
    if (@new_values) {
      # get phenotype data
      foreach my $va (@{$vaa->fetch_all_by_VariationFeature_list(\@other_vfs)}) {
        # filter on p-value
        next if $min_p_log > 0 && defined $va->p_value && (-log($va->p_value) / log(10)) <= $min_p_log;
        
        $_->{'annotations'}->{$va->{'_phenotype_id'}} = $va for grep $_->{'other_vf'}->{'_variation_id'} == $va->{'_variation_id'}, @new_values;
      }
      
      my @sorted = 
        map  { $_->[0] }
        sort { $b->[0]{'r2'} <=> $a->[0]{'r2'} || $b->[0]{'d_prime'} <=> $a->[0]{'d_prime'} || $a->[1] <=> $b->[1] } 
        map  {[ $_, abs($_->{'other_vf'}->seq_region_start - $vf_start) ]}
        @new_values;
       
      foreach my $ld (@sorted) {
        next if $only_phenotypes && !defined $ld->{'annotations'};
        
        my $ld_vf = $ld->{'other_vf'};
        my $variation_name = $ld_vf->variation_name;
        my $ld_vf_dbID     = $ld_vf->dbID;
        
        # switch start and end to avoid faff
        my ($start, $end) = ($ld_vf->seq_region_start, $ld_vf->seq_region_end);
        ($start, $end)    = ($end, $start) if $start > $end;
        
        my $va_string;
        
        # check if any VAs for this variation
        if ($ld->{'annotations'}) {
          $va_string .= '<table style="border:none; width:100%; padding:0px; margin:0px;">';
          
          # iterate through all VAs
          foreach (values %{$ld->{'annotations'}}) {
            my $phenotype_description = $_->phenotype_description;
            my $p_value               = $_->p_value;
            
            my $va_url = $hub->url({
              type           => 'Location',
              action         => 'Genome',
              ftype          => 'Phenotype',
              id             => $_->{'_phenotype_id'},
              phenotype_name => $phenotype_description,
              v              => $variation_name,
              vf             => $ld_vf_dbID,
            });
            
            $va_string .= sprintf qq{<tr><td style="padding:0px; margin:0px;"><a href="$va_url">%s</a></td><td style="padding:0px; margin:0px;">}, $_->phenotype_name || $phenotype_description;
              
            # p value part
            if (defined $p_value) {
              my $p_scaled = sprintf '%.0f', (-log($p_value)/log(10)); # scale the p-value to an integer that might fall in @colour_scale
              my $colour  = $colour_scale[$p_scaled > $#colour_scale ? $#colour_scale : $p_scaled]; # set a colour
              
              $va_string .= sprintf '<span style="float:right;color:#%s;white-space:nowrap;">(%s)</span>', $colour, $p_value;
            }
              
            $va_string .= '</td></tr>';
          }
          
          $va_string .= '</table>';
        }
        
        # get tagging info
        my $tag = (grep $_->dbID == $pop_id, @{$ld_vf->is_tagged}) ? 'Yes' : 'No';
        
        # get genes
        my $genes = join ', ', map sprintf(
          '<a href="%s">%s</a>',
          $hub->url({
            type   => 'Gene',
            action => 'Variation_Gene',
            db     => 'core',
            r      => undef,
            g      => $_->stable_id,
            v      => $v,
            source => $source
          }),
          $_->external_name
        ), @{$ld_vf->feature_Slice->get_all_Genes};
        
        # build URLs
        my $var_url = $hub->url({
          type   => 'Variation',
          action => 'Summary',
          vdb    => 'variation',
          v      => $variation_name,
          vf     => $ld_vf_dbID,
        });
        
        my $loc_url = $hub->url({
          type   => 'Location',
          action => 'View',
          db     => 'core',
          v      => $variation_name,
          vf     => $ld_vf_dbID,
        });
        
        $table->add_row({
          variation   => qq{<a href="$var_url">$variation_name</a>},
          location    => sprintf('<a href="%s">%s:%s</a>', $loc_url, $ld_vf->seq_region_name, $start == $end ? $start : "$start-$end"),
          distance    => abs($start - ($vf_start > $vf_end ? $vf_end : $vf_start)),
          r2          => $ld->{'r2'},
          d_prime     => $ld->{'d_prime'},
          tag         => $tag,
          genes       => $genes     || '-',
          annotations => $va_string || '-',
        });
      }
    }
    
    $html .= sprintf '<h2>%s</h2>%s', $pop->name, ($table->has_rows ? $table->render : 'No variations found<br /><br />');
  }
  
  return $html;
}

1;
