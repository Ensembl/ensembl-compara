# $Id$

package EnsEMBL::Web::Component::Variation::HighLD;

use strict;

use HTML::Entities qw(encode_entities);

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
  
  # check we have a location and LD populations are defined
  return unless $self->builder->object('Location') && $species_defs->databases->{'DATABASE_VARIATION'}{'DEFAULT_LD_POP'};
  
  my $selected_pop = $hub->param('pop_id');
  
  return $selected_pop ? $self->linked_var_table($selected_pop) : $self->summary_table;
}

sub summary_table {
  my $self               = shift;
  my $object             = $self->object; 
  my $variation          = $object->Obj;
  my $v                  = $variation->name;
  my $hub                = $self->hub;
  my $available_pops     = $self->ld_populations;
  my @pops               = @{$variation->adaptor->db->get_PopulationAdaptor->fetch_all_LD_Populations};
  my $table_with_no_rows = 0;
  my $table              = $self->new_table([
    { key => 'name',   title => 'Population',              sort => 'html',   align => 'left'   },
    { key => 'desc',   title => 'Description',             sort => 'string', align => 'left'   },
    { key => 'tag',    title => 'Tag SNP',                 sort => 'string', align => 'center' },
    { key => 'table',  title => 'Linked variations table', sort => 'none',   align => 'center' },
    { key => 'plot',   title => 'LD plot (image)',         sort => 'none',   align => 'center' },
    { key => 'export', title => 'LD plot (table)',         sort => 'none',   align => 'center' },
  ], [], { data_table => 1, sorting => [ 'name asc' ] });
  
  
  foreach my $pop (@pops) {
    my $description = $pop->description;
    
    if (length $description > 30) {
      my $full_desc = $self->strip_HTML($description);
      
      while ($description =~ m/^.{30}.*?(\s|\,|\.)/g) {
        $description = sprintf '<span title="%s">%s...(more)</span>', $full_desc, substr($description, 0, (pos $description) - 1);
        last;
      }
    }
    
    my $row = {
      name => $self->hub->get_ExtURL_link($pop->name, 'DBSNPPOP', $pop->get_all_synonyms('dbSNP')->[0]),
      desc => $description,
      tag  => $object->tagged_snp->{$pop->name} ? 'Yes' : 'No',
    };
    
    if ($available_pops->{$pop->name}) {
      # plot
      my $url = $hub->url({
        type   => 'Location',
        action => 'LD',
        r      => $object->ld_location,
        v      => $object->name,
        vf     => $hub->param('vf'),
        pop1   => $pop->name ,
        focus  => 'variation'
      });
      
      $row->{'plot'} = qq{<a href="$url">Show</a>};
      
      my $id  = $pop->dbID;
      
      $row->{'table'} = $self->ajax_add($self->ajax_url(undef, { pop_id => $id, update_panel => 1 }), $id);
      
      # export table
      $url = $hub->url({
        type    => 'Export/Output',
        action  => 'Location',
        r       => $object->ld_location,
        v       => $object->name,
        vf      => $hub->param('vf'),
        pop1    => $pop->name ,
        focus   => 'variation',
        _format => 'HTML',
        output  => 'ld',
      });
      
      $row->{'export'} = qq{<a href="$url">Show</a>};
    } else {
      $row->{'plot'}   = '-';
      $row->{'table'}  = '-';
      $row->{'export'} = '-';
      
      $table_with_no_rows = 1;
    }
    
    $table->add_row($row);
  }
  
  my $html = '<h2>Links to linkage disequilibrium data by population</h2>';
  
  if ($table_with_no_rows) {
    $html .= $self->_hint('HighLD', 'Linked variation information', qq{
      A variation may have no LD data in a given population for the following reasons:
      <ul>
        <li>Linked variations are being filtered out by page configuration</li>
        <li>Variation $v has a minor allele frequency close or equal to 0</li>
        <li>Variation $v does not have enough genotypes to calculate LD values</li>
        <li>Estimated r<sup>2</sup> values are below 0.05 and have been filtered out</li>
      </ul>
    }, '80%');
  }
  
  $html .= $table->render;
  
  return $html;
}
  
sub linked_var_table {
  my ($self, $selected_pop) = @_;
  my $object       = $self->object; 
  my $variation    = $object->Obj;
  my $hub          = $self->hub;
  my $species_defs = $hub->species_defs;
  my $pop          = $variation->adaptor->db->get_PopulationAdaptor->fetch_by_dbID($selected_pop);
  
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
  my ($vf, $loc);
  
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
  
  my $vf_dbID             = $vf->dbID;
  my $vf_start            = $vf->seq_region_start;
  my $vf_end              = $vf->seq_region_end;
  my $temp_slice          = $vf->feature_Slice->expand($max_distance, $max_distance);
  my $pop_id              = $pop->dbID;
  my $pop_name            = $pop->name;
  my $tables_with_no_rows = 0;
  my $table               = $self->new_table([
    { key => 'variation',   title => 'Variation',               align => 'center', sort => 'html'                 },
    { key => 'location',    title => 'Location',                align => 'center', sort => 'position_html'        },
    { key => 'distance',    title => 'Distance (bp)',           align => 'center', sort => 'numeric'              },
    { key => 'r2',          title => 'r<sup>2</sup>',           align => 'center', sort => 'numeric'              },
    { key => 'd_prime',     title => q{D'},                     align => 'center', sort => 'numeric'              },
    { key => 'tag',         title => 'Tag SNP',                 align => 'center', sort => 'string'               },
    { key => 'genes',       title => 'Located in gene(s)',      align => 'center', sort => 'html'                 },
    { key => 'annotations', title => 'Associated phenotype(s)', align => 'center', sort => 'html', width => '30%' },
  ], [], { data_table => 1 });
  
  # do some filtering
  my @old_values = @{$ldca->fetch_by_Slice($temp_slice, $pop)->get_all_ld_values};
  my (@new_values, @other_vfs);
  
  foreach my $ld (@old_values) {
    next unless $ld->{'variation1'}->dbID == $vf_dbID || $ld->{'variation2'}->dbID == $vf_dbID;
    next unless $ld->{'sample_id'} == $pop_id;
    next unless $ld->{'r2'}        >= $min_r2;
    next unless $ld->{'d_prime'}   >= $min_d_prime;
    
    my $other_vf = $ld->{'variation1'}->dbID == $vf_dbID ? $ld->{'variation2'} : $ld->{'variation1'};
    
    $ld->{'other_vf'} = $other_vf;
    
    push @new_values, $ld;
    push @other_vfs,  $other_vf;
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
      
      my $ld_vf          = $ld->{'other_vf'};
      my $variation_name = $ld_vf->variation_name;
      my $ld_vf_dbID     = $ld_vf->dbID;
      
      # switch start and end to avoid faff
      my ($start, $end) = ($ld_vf->seq_region_start, $ld_vf->seq_region_end);
         ($start, $end) = ($end, $start) if $start > $end;
      
      my $va_string;
      
      # check if any VAs for this variation
      if ($ld->{'annotations'}) {
        $va_string .= '<table style="border:none;width:100%;padding:0;margin:0">';
        
        # iterate through all VAs
        foreach my $va (values %{$ld->{'annotations'}}) {
          my $phenotype_description = $va->phenotype_description;
          my $p_value               = $va->p_value;
          
          my $va_url = $hub->url({
            type           => 'Location',
            action         => 'Genome',
            ftype          => 'Phenotype',
            id             => $va->{'_phenotype_id'},
            phenotype_name => $phenotype_description,
            v              => $variation_name,
            vf             => $ld_vf_dbID,
          });
          
          $va_string .= sprintf '<tr><td style="padding:0;margin:0"><a href="%s">%s</a></td><td style="padding:0;margin:;">', $va_url, $va->phenotype_name || $phenotype_description;
          
          # p value part
          if (defined $p_value) {
            my $p_scaled = sprintf '%.0f', (-log($p_value)/log(10)); # scale the p-value to an integer that might fall in @colour_scale
            my $colour   = $colour_scale[$p_scaled > $#colour_scale ? $#colour_scale : $p_scaled]; # set a colour
            
            $va_string .= sprintf '<span style="float:right;color:#%s;white-space:nowrap">(%s)</span>', $colour, $p_value;
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
  
  return $table->has_rows ?
    $self->toggleable_table("Variations linked to $v in $pop_name", $pop_id, $table, 1, qq{<span style="float:right"><a href="#$self->{'id'}_top">[back to top]</a></span>}) :
    '<h3>No variations found</h3><br /><br />';
}

sub ld_populations {
  ### LD
  ### Description : data structure with population id and name of pops
  ### with LD info for this SNP
  ### Returns  hashref

  my $self    = shift;
  my $object  = $self->object;
  my $pop_ids = $object->ld_pops_for_snp;
  
  return {} unless @$pop_ids;

  my %pops;
  
  foreach (@$pop_ids) {    
    my $pop_obj = $object->pop_obj_from_id($_);
    $pops{$pop_obj->{$_}{'Name'}} = 1;
  }
  
  return \%pops;
}

1;
