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
  return $self->_info('A unique location can not be determined for this variant', $object->not_unique_location) if $object->not_unique_location;
  
  my $hub          = $self->hub;
  my $species_defs = $hub->species_defs;
  
  # check we have a location and LD populations are defined
  return unless $self->builder->object('Location') && $species_defs->databases->{'DATABASE_VARIATION'} && $species_defs->databases->{'DATABASE_VARIATION'}{'DEFAULT_LD_POP'};
  
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
  my %mappings           = %{$object->variation_feature_mapping};
  my %tree;

  my $manplot_help = "Manhattan plot of population specific LD values for variants linked to the variant $v";
  my $linked_help  = "Links to tables showing the variants having a significant LD value (>0.8 by default) with the variant $v";
  my $plot_help    = "LD values of the variants within the 20kb surrounding the variant $v";
 
  my $table              = $self->new_table([
    { key => 'name',     title => 'Population',          sort => 'none', align => 'left'   },
    { key => 'desc',     title => 'Description',         sort => 'none', align => 'left'   },
    { key => 'manplot',  title => 'LD Manhattan plot',   sort => 'none', align => 'center', help => $manplot_help },
    { key => 'table',    title => 'Variants in high LD', sort => 'none', align => 'center', help => $linked_help  },
    { key => 'plot',     title => 'LD plot',             sort => 'none', align => 'center', help => $plot_help    },
  ], [], { data_table => 1 });
  
  my ($loc, $vf) = ($object->selected_variation_feature_mapping, $object->get_selected_variation_feature);
  $vf ||= $variation->variation_feature;

  # Building population tree
  my %pop_data;
  my $pop_adaptor = $variation->adaptor->db->get_PopulationAdaptor();

  foreach my $pop (@pops) {
    my $pop_id = $pop->dbID;
    my $name   = $pop->name;
    $pop_data{$pop_id} = $pop;
    if ($available_pops->{$name} && $available_pops->{$name}{'super'}) {
      my $super_data = $available_pops->{$name}{'super'};
      foreach my $super (keys(%{$super_data})) {
        my $super_name = $super_data->{$super}{'Name'};
        $tree{$super}{'children'}{$pop_id} = $name;
        $tree{$super}{'name'} = $super_name;
        # Get the Population object of the super-pop
        $pop_data{$super} = $pop_adaptor->fetch_by_dbID($super) if (!$pop_data{$super});
      }
      next;
    }
    $tree{$pop_id}{'name'} = $name;
  }

  # Order populations by name
  my @ids;
  my @super_order = sort {$tree{$a}{'name'} cmp $tree{$b}{'name'}} keys (%tree);
  foreach my $super (@super_order) {
    push @ids, $super;
    my $children = $tree{$super}{'children'} || {};
    push @ids, sort {$children->{$a} cmp $children->{$b}} keys (%$children);
  }

  ## Now build table rows
  foreach my $pop_id (@ids) {

    my $pop = $pop_data{$pop_id};

    my $description = $pop->description;
       $description ||= '-';
    
    if (length $description > 30) {
      my $full_desc = $self->strip_HTML($description);
      
      while ($description =~ m/^.{30}.*?(\s|\,|\.)/g) {
        $description = sprintf '%s... <span class="_ht ht small" title="%s">(more)</span>', substr($description, 0, (pos $description) - 1), $full_desc;
        last;
      }
    }
 
    my $pop_name  = $pop->name;    
    my $pop_dbSNP = $pop->get_all_synonyms('dbSNP');

    # Population label
    my $pop_label = $pop_name;
    if ($pop_label =~ /^.+\:.+$/ and $pop_label !~ /(http|https):/) {
      my @composed_name = split(':', $pop_label);
      $composed_name[$#composed_name] = '<b>'.$composed_name[$#composed_name].'</b>';
      $pop_label = join(':',@composed_name);
    }

    # Population external links
    my $pop_url = $self->pop_link($pop_name, $pop_dbSNP, $pop_label);
    
    my $row = {
      name    => $pop_url,
      desc    => $description,
    };

    if ($tree{$pop_id}{'children'}) {
      $row->{'options'}{'class'} = 'subgroup';
    }

    if ($available_pops->{$pop->name}) {
      my $id  = $pop->dbID;      

      # manhattan plot
      my $url = $hub->url({
        type   => 'Variation',
        action => 'LDPlot',
        v      => $object->name,
        vf     => $hub->param('vf'),
        pop1   => $id
      });

      $row->{'manplot'} = qq{<a class="ld_manplot_link" href="$url">View plot</a>};

      # plot
      $url = $hub->url({
        type   => 'Location',
        action => 'LD',
        r      => $object->ld_location,
        v      => $object->name,
        vf     => $hub->param('vf'),
        pop1   => $id,
        focus  => 'variation'
      });
      
      $row->{'plot'} = qq{<a class="ld_plot_link space-right" href="$url">View plot</a>};
      
      $row->{'table'} = $self->ajax_add($self->ajax_url(undef, { pop_id => $id, update_panel => 1 }), $id);
      
      # export table
      $url = $hub->url({
        type    => 'Export/Output',
        action  => 'Location',
        r       => $object->ld_location,
        v       => $object->name,
        vf      => $hub->param('vf'),
        pop1    => $pop->name ,
        _format => 'HTML',
        output  => 'ld',
      });
      
      $row->{'plot'} .= qq{<a href="$url">View table</a>};
    } else {
      if ($tree{$pop_id}{'children'} && $pop_name =~ /^1000GENOMES/) {
        $row->{'name'} = $row->{'desc'};
        $row->{'desc'} = '';
      }

      $row->{'manplot'} = '';
      $row->{'plot'}    = '';
      $row->{'table'}   = '';
      
      $table_with_no_rows = 1 if (!$tree{$pop_id}{'children'});
    }

    $table->add_row($row);
  }

  my $html = '<h2>Links to linkage disequilibrium data by population</h2>';
  
  if ($table_with_no_rows) {
    $html .= $self->_hint('HighLD', 'Linked variant information', qq{
      <p>A variant may have no LD data in a given population for the following reasons:</p>
      <ul>
        <li>Linked variants are being filtered out by page configuration</li>
        <li>Variant $v has a minor allele frequency close or equal to 0</li>
        <li>Variant $v does not have enough genotypes to calculate LD values</li>
        <li>Estimated r<sup>2</sup> values are below 0.05 and have been filtered out</li>
      </ul>
    });
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
  $Bio::EnsEMBL::Variation::DBSQL::LDFeatureContainerAdaptor::BINARY_FILE     = $species_defs->ENSEMBL_CALC_GENOTYPES_FILE;
  $Bio::EnsEMBL::Variation::DBSQL::LDFeatureContainerAdaptor::VCF_BINARY_FILE = $species_defs->ENSEMBL_LD_VCF_FILE;
  $Bio::EnsEMBL::Variation::DBSQL::LDFeatureContainerAdaptor::TMP_PATH        = $species_defs->ENSEMBL_TMP_TMP;
  
  my $v               = $object->name;
  my $source          = $variation->source_name;
  my $pfa             = $variation->adaptor->db->get_PhenotypeFeatureAdaptor;
  my $ldca            = $variation->adaptor->db->get_LDFeatureContainerAdaptor;
  my $max_distance    = $hub->param('max_distance') || 50000;  
  my $min_r2          = defined $hub->param('min_r2')      ? $hub->param('min_r2')      : 0.8;
  my $min_d_prime     = defined $hub->param('min_d_prime') ? $hub->param('min_d_prime') : 0.8;
  my $min_p_log       = $hub->param('min_p_log');
  my $only_phenotypes = $hub->param('only_phenotypes') eq 'yes';
  my @colour_scale    = $hub->colourmap->build_linear_gradient(40, '#0000FF', '#770088', '#BB0044', 'red'); # define a colour scale for p-values
  my %mappings        = %{$object->variation_feature_mapping};  # first determine correct SNP location 
  my ($loc, $vf) = ($object->selected_variation_feature_mapping, $object->get_selected_variation_feature);
  $vf ||= $variation->variation_feature;
  
  my $vf_start            = $vf->seq_region_start;
  my $vf_end              = $vf->seq_region_end;
  my $vf_dbID             = $vf->dbID;
  my $temp_slice          = $vf->feature_Slice->expand($max_distance, $max_distance);
  my $pop_id              = $pop->dbID;
  my $pop_name            = $pop->name;
  my $glossary            = $hub->glossary_lookup;
  my $tables_with_no_rows = 0;
  my $table               = $self->new_table([
    { key => 'variation', title => 'Variant',                 align => 'left',  sort => 'html'                               },
    { key => 'location',  title => 'Location',                align => 'left',  sort => 'position_html'                      },
    { key => 'distance',  title => 'Distance (bp)',           align => 'left',  sort => 'numeric'                            },
    { key => 'r2',        title => 'r<sup>2</sup>',           align => 'left',  sort => 'numeric', help => $glossary->{'r2'} },
    { key => 'd_prime',   title => q{D'},                     align => 'left',  sort => 'numeric', help => $glossary->{"D'"} },
    { key => 'pfs',       title => 'Associated phenotype(s)', align => 'left',  sort => 'html'                               },
    { key => 'ctype',     title => 'Consequence Type',        align => 'left',  sort => 'html'                               },
    { key => 'genes',     title => 'Located in gene(s)',      align => 'left',  sort => 'html'                               },
    { key => 'pgene',     title => 'Gene phenotype(s)',       align => 'left',  sort => 'html'                               },
  ], [], { data_table => 1 });
  
  # do some filtering
  # my @old_values = @{$ldca->fetch_by_Slice($temp_slice, $pop)->get_all_ld_values};
  my @old_values = @{$ldca->fetch_by_VariationFeature($vf, $pop, $max_distance)->get_all_ld_values};
  
  my (@new_values, @other_vfs);
  
  foreach my $ld (@old_values) {
    next unless $ld->{'r2'}      >= $min_r2;
    next unless $ld->{'d_prime'} >= $min_d_prime;
    
    my $other_vf = $ld->{'variation1'}->dbID == $vf_dbID ? $ld->{'variation2'} : $ld->{'variation1'};
    
    $ld->{'other_vf'} = $other_vf;
    
    push @new_values, $ld;
    push @other_vfs,  $other_vf;
  }
  
  if (@new_values) {
    # get phenotype data
    foreach my $pf (@{$pfa->fetch_all_by_VariationFeature_list(\@other_vfs)}) {
      # filter on p-value
      next if $min_p_log > 0 && defined $pf->p_value && (-log($pf->p_value) / log(10)) <= $min_p_log;
      
      $_->{'pfs'}->{$pf->{'_phenotype_id'}} = $pf for grep $_->{'other_vf'}->{'_variation_id'} == $pf->{'_variation_id'}, @new_values;
    }
    
    my @sorted = 
      map  { $_->[0] }
      sort { $b->[0]{'r2'} <=> $a->[0]{'r2'} || $b->[0]{'d_prime'} <=> $a->[0]{'d_prime'} || $a->[1] <=> $b->[1] } 
      map  {[ $_, abs($_->{'other_vf'}->seq_region_start - $vf_start) ]}
      @new_values;
     
    foreach my $ld (@sorted) {
      next if $only_phenotypes && !defined $ld->{'pfs'};
      
      my $ld_vf          = $ld->{'other_vf'};
      my $variation_name = $ld_vf->variation_name;
      my $ld_vf_dbID     = $ld_vf->dbID;
      
      # switch start and end to avoid faff
      my ($start, $end) = ($ld_vf->seq_region_start, $ld_vf->seq_region_end);
         ($start, $end) = ($end, $start) if $start > $end;
      
      my $pf_string;
      
      # check if any VAs for this Variant
      if ($ld->{'pfs'}) {
        $pf_string .= '<table style="border:none;width:100%;padding:0;margin:0">';
        
        # iterate through all VAs
        foreach my $pf (values %{$ld->{'pfs'}}) {
          my $phenotype_description = $pf->phenotype->description;
          my $p_value               = $pf->p_value;
          
          my $pf_url = $hub->url({
            type           => 'Location',
            action         => 'Genome',
            ftype          => 'Phenotype',
            id             => $pf->{'_phenotype_id'},
            phenotype_name => $phenotype_description,
            v              => $variation_name,
            vf             => $ld_vf_dbID,
          });
          
          $pf_string .= sprintf '<tr><td style="padding:0;margin:0"><a href="%s">%s</a></td><td style="padding:0;margin:0;">', $pf_url, $pf->phenotype->name || $phenotype_description;
          
          # p value part
          if (defined $p_value) {
            my $p_scaled = sprintf '%.0f', (-log($p_value)/log(10)); # scale the p-value to an integer that might fall in @colour_scale
            my $colour   = $colour_scale[$p_scaled > $#colour_scale ? $#colour_scale : $p_scaled]; # set a colour
            
            $pf_string .= sprintf '<span style="float:right;color:#%s;white-space:nowrap">(%s)</span>', $colour, $p_value;
          }
            
          $pf_string .= '</td></tr>';
        }
        
        $pf_string .= '</table>';
      }
      
      # get genes
      my $gene_objs = $ld_vf->feature_Slice->get_all_Genes;
      
      my $genes = join ', ', map sprintf(
        '<a href="%s">%s</a>',
        $hub->url({
          type   => 'Gene',
          action => 'Summary',
          db     => 'core',
          r      => undef,
          g      => $_->stable_id,
          v      => $v,
          source => $source
        }),
        $_->external_name
      ), @{$gene_objs};

      # get genes phenotypes
      my %pgenes = map {
          $_->phenotype->dbID => $_->phenotype->description
        } map {
          @{$pfa->fetch_all_by_Gene($_)}
        } @$gene_objs;

      my @phe_gene_links = map { 
           sprintf(
             '<a href="%s">%s</a>',
             $hub->url({
               type   => 'Phenotype',
               action => 'Locations',
               ph     => $_
             }),
             $pgenes{$_}
           )
         } sort { lc($pgenes{$a}) cmp lc($pgenes{$b}) } keys(%pgenes); 

      my @phe_gene_texts = sort { lc($a) cmp lc($b) } values(%pgenes);
      
      my $pgene = $self->display_items_list($variation_name.'_gene_phe', 'phenotypess', 'phenotypes', \@phe_gene_links, \@phe_gene_texts);


      # build URLs
      my $var_url = $hub->url({
        type   => 'Variation',
        action => 'Explore',
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
        r2          => sprintf("%.3f", $ld->{'r2'}),
        d_prime     => sprintf("%.3f", $ld->{'d_prime'}),
        ctype       => $self->render_consequence_type($ld_vf,1),
        genes       => $genes     || '-',
        pfs         => $pf_string || '-',
        pgene       => $pgene     || '-',
      });
    }
  }
 
  return $table->has_rows ?
    $self->toggleable_table("Variants linked to $v in $pop_name", $pop_id, $table, 1, qq{<span style="float:right"><a href="#$self->{'id'}">[back to top]</a></span>}) :
    '<h3>No variants found</h3><br /><br />';
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
    my $pop_obj   = $object->pop_obj_from_id($_);
    my $name      = $pop_obj->{$_}{'Name'};
    my $super_pop = $object->extra_pop($pop_obj->{$_}{PopObject},"super");
    $pops{$name}{'id'} = $_;
    $pops{$name}{'super'} = $super_pop if ($super_pop);
  }
  
  return \%pops;
}

1;
