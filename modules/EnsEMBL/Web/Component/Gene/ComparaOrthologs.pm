=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2017] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Component::Gene::ComparaOrthologs;

use strict;

use HTML::Entities qw(encode_entities);

use EnsEMBL::Web::Utils::FormatText qw(glossary_helptip get_glossary_entry);

use base qw(EnsEMBL::Web::Component::Gene);

sub _init {
  my $self = shift;
  $self->cacheable(1);
  $self->ajaxable(1);
}

## Stub - implement in plugin if you want to display a summary table
## (see public-plugins/ensembl for an example data structure)
sub _species_sets {}

sub _get_all_analysed_species {
  my ($self, $cdb) = @_;
  if (!$self->{'_all_analysed_species'}) {
    $self->{"_mlss_adaptor_$cdb"} ||= $self->hub->get_adaptor('get_MethodLinkSpeciesSetAdaptor', $cdb);
    my $pt_mlsss = $self->{"_mlss_adaptor_$cdb"}->fetch_all_by_method_link_type('PROTEIN_TREES');
    my $best_pt_mlss;
    if (scalar(@$pt_mlsss) > 1) {
      ($best_pt_mlss) = grep {$_->species_set->name eq 'collection-default'} @$pt_mlsss;
    } else {
      $best_pt_mlss = $pt_mlsss->[0];
    }
    $self->{'_all_analysed_species'} = {map {ucfirst($_->name) => 1} @{$best_pt_mlss->species_set->genome_dbs}};
  }
  return %{$self->{'_all_analysed_species'}};
}

our %button_set = ('download' => 1, 'view' => 0);

sub content {
  my $self         = shift;
  my $hub          = $self->hub;
  my $object       = $self->object;
  my $species_defs = $hub->species_defs;
  my $cdb          = shift || $self->param('cdb') || 'compara';
  my $availability = $object->availability;
  my $is_ncrna     = ($object->Obj->biotype =~ /RNA/);
  my $species_name = $species_defs->DISPLAY_NAME;
  my $strain_url   = $species_defs->IS_STRAIN_OF ? "Strain_" : "";
  my $strain_param = ";strain=1" if($self->is_strain);
  
  my @orthologues = (
    $object->get_homology_matches('ENSEMBL_ORTHOLOGUES', undef, undef, $cdb), 
  );
  
  my %orthologue_list;
  my %skipped;

  my %not_seen = $self->_get_all_analysed_species($cdb);
  
  delete $not_seen{ucfirst($species_defs->get_config($hub->species, 'SPECIES_PRODUCTION_NAME'))}; #deleting current species
  
  for (keys %not_seen) {
    #do not show non-strain species on strain view
    if ($self->is_strain && !$species_defs->get_config($species_defs->production_name_mapping($_), 'RELATED_TAXON')) { delete $not_seen{$_}; }

    #do not show strain species on main species view
    if(!$self->is_strain && $species_defs->get_config($species_defs->production_name_mapping($_), 'IS_STRAIN_OF')) { delete $not_seen{$_}; }
  }
  
  foreach my $homology_type (@orthologues) {
    foreach (keys %$homology_type) {
      (my $species = $_) =~ tr/ /_/;

      #do not show strain species on main species view
      if ((!$self->is_strain && $species_defs->get_config($species_defs->production_name_mapping($species), 'IS_STRAIN_OF')) || ($self->is_strain && !$species_defs->get_config($species_defs->production_name_mapping($species), 'RELATED_TAXON'))) {
        delete $not_seen{$species};
        next;
      }

      $orthologue_list{$species} = {%{$orthologue_list{$species}||{}}, %{$homology_type->{$_}}};
      $skipped{$species}        += keys %{$homology_type->{$_}} if $self->param('species_' . lc $species) eq 'off';
      delete $not_seen{$species};
    }
  }
  
  return '<p>No orthologues have been identified for this gene</p>' unless keys %orthologue_list;

  my %orthologue_map = qw(SEED BRH PIP RHS);
  my $alignview      = 0;
 
  my ($html, $columns, @rows);

  ##--------------------------- SUMMARY TABLE ----------------------------------------

  my ($species_sets, $sets_by_species, $set_order) = $self->_species_sets(\%orthologue_list, \%skipped, \%orthologue_map, $cdb);

  if ($species_sets) {
    $html .= qq{
      <h3>Summary of orthologues of this gene</h3>
      <p class="space-below">Click on 'Show details' to display the orthologues for one or more groups of species. Alternatively, click on 'Configure this page' to choose a custom list of species.</p>
    };
 
    $columns = [
      { key => 'set',       title => 'Species set',    align => 'left',    width => '26%' },
      { key => 'show',      title => 'Show details',   align => 'center',  width => '10%' },
      { key => '1:1',       title => 'With 1:1 orthologues',       align => 'center',  width => '16%', help => 'Number of species with 1:1 orthologues<em>'.get_glossary_entry($hub, '1-to-1 orthologues').'</em>' },
      { key => '1:many',    title => 'With 1:many orthologues',    align => 'center',  width => '16%', help => 'Number of species with 1:many orthologues<em>'.get_glossary_entry($hub, '1-to-many orthologues').'</em>' },
      { key => 'many:many', title => 'With many:many orthologues', align => 'center',  width => '16%', help => 'Number of species with many:many orthologues<em>'.get_glossary_entry($hub, 'Many-to-many orthologues').'</em>' },
      { key => 'none',      title => 'Without orthologues',        align => 'center',  width => '16%', help => 'Number of species without orthologues' },
    ];

    foreach my $set (@$set_order) {
      my $set_info = $species_sets->{$set};
      
      my $none_title = $set_info->{'none'} ? sprintf('<a href="#list_no_ortho">%d</a>', $set_info->{'none'}) : 0;
      push @rows, {
        'set'       => "<strong>$set_info->{'title'}</strong> (<i>$set_info->{'all'} species</i>)<br />$set_info->{'desc'}",
        'show'      => qq{<input type="checkbox" class="table_filter" title="Check to show these species in table below" name="orthologues" value="$set" />},
        '1:1'       => $set_info->{'1-to-1'}       || 0,
        '1:many'    => $set_info->{'1-to-many'}    || 0,
        'many:many' => $set_info->{'Many-to-many'} || 0,
        'none'      => $none_title,
      };
    }
    
    $html .= $self->new_table($columns, \@rows)->render;
  }

  ##----------------------------- FULL TABLE -----------------------------------------

  $html .= '<h3>Selected orthologues</h3>' if $species_sets; 
  
  $columns = [
    { key => 'Species',    align => 'left', width => '10%', sort => 'html'                                                },
    { key => 'Type',       align => 'left', width => '10%', sort => 'html'                                            },   
    { key => 'identifier', align => 'left', width => '15%', sort => 'none', title => 'Orthologue'},      
    { key => 'dN/dS',      align => 'left', width => '5%',  sort => 'html'                                             },
    { key => 'Target %id', align => 'left', width => '5%',  sort => 'position_html', label => 'Target %id', help => "Percentage of the orthologous sequence matching the $species_name sequence" },
    { key => 'Query %id',  align => 'left', width => '5%',  sort => 'position_html', label => 'Query %id',  help => "Percentage of the $species_name sequence matching the sequence of the orthologue" },
    { key => 'goc_score',  align => 'left', width => '5%',  sort => 'position_html', label => 'GOC Score',  help => "<a href='/info/genome/compara/Ortholog_qc_manual.html/#goc'>Gene Order Conservation Score (values are 0-100)</a>" },
    { key => 'wgac',  align => 'left', width => '5%',  sort => 'position_html', label => 'WGA Coverage',  help => "<a href='/info/genome/compara/Ortholog_qc_manual.html/#wga'>Whole Genome Alignment Coverage (values are 0-100)</a>" },
    { key => 'confidence',  align => 'left', width => '5%',  sort => 'html', label => 'High Confidence', help => "<a href='/info/genome/compara/Ortholog_qc_manual.html/#hc'>Homology with high %identity and high GOC score or WGA coverage (as available), Yes or No.</a>"},
  ];
  
  push @$columns, { key => 'Gene name(Xref)',  align => 'left', width => '15%', sort => 'html', title => 'Gene name(Xref)'} if(!$self->html_format);
  
  @rows = ();
  
  foreach my $species (sort { ($a =~ /^<.*?>(.+)/ ? $1 : $a) cmp ($b =~ /^<.*?>(.+)/ ? $1 : $b) } keys %orthologue_list) {
    next if $skipped{$species};
    
    foreach my $stable_id (sort keys %{$orthologue_list{$species}}) {
      my $orthologue = $orthologue_list{$species}{$stable_id};
      my ($target, $query);
      
      # Add in Orthologue description
      my $orthologue_desc = $orthologue_map{$orthologue->{'homology_desc'}} || $orthologue->{'homology_desc'};
      
      # Add in the dN/dS ratio
      my $orthologue_dnds_ratio = $orthologue->{'homology_dnds_ratio'} || 'n/a';
      my $dnds_class  = ($orthologue_dnds_ratio ne "n/a" && $orthologue_dnds_ratio >= 1) ? "box-highlight" : "";
      
      # GOC Score, wgac and high confidence
      my $goc_score  = (defined $orthologue->{'goc_score'} && $orthologue->{'goc_score'} >= 0) ? $orthologue->{'goc_score'} : 'n/a';
      my $wgac       = (defined $orthologue->{'wgac'} && $orthologue->{'wgac'} >= 0) ? $orthologue->{'wgac'} : 'n/a';
      my $confidence = $orthologue->{'highconfidence'} eq '1' ? 'Yes' : $orthologue->{'highconfidence'} eq '0' ? 'No' : 'n/a';
      my $goc_class  = ($goc_score ne "n/a" && $goc_score >= $orthologue->{goc_threshold}) ? "box-highlight" : "";
      my $wga_class  = ($wgac ne "n/a" && $wgac >= $orthologue->{wga_threshold}) ? "box-highlight" : "";
         
      (my $spp = $orthologue->{'spp'}) =~ tr/ /_/;
      $spp = $species_defs->production_name_mapping($spp);
      my $link_url = $hub->url({
        species => $spp,
        action  => 'Summary',
        g       => $stable_id,
        __clear => 1
      });

      # Check the target species are on the same portal - otherwise the multispecies link does not make sense
      my $region_link = ($link_url =~ /^\// 
        && $cdb eq 'compara'
        && $availability->{'has_pairwise_alignments'}
        && !$self->is_strain
      ) ?
        sprintf('<a href="%s">Compare Regions</a>&nbsp;('.$orthologue->{'location'}.')',
        $hub->url({
          type   => 'Location',
          action => 'Multi',
          g1     => $stable_id,
          s1     => $spp,
          r      => $hub->create_padded_region()->{'r'} || $self->param('r'),
          config => 'opt_join_genes_bottom=on',
        })
      ) : $orthologue->{'location'};
      
      my ($alignment_link, $target_class, $query_class);
      if ($orthologue_desc ne 'DWGA') {
        ($target, $query) = ($orthologue->{'target_perc_id'}, $orthologue->{'query_perc_id'});
         $target_class    = ($target && $target <= 10) ? "bold red" : "";
         $query_class     = ($query && $query <= 10) ? "bold red" : "";
       
        my $page_url = $hub->url({
          type    => 'Gene',
          action  => $hub->action,
          g       => $self->param('g'), 
        });
          
        my $zmenu_url = $hub->url({
          type    => 'ZMenu',
          action  => 'ComparaOrthologs',
          g1      => $stable_id,
          dbID    => $orthologue->{'dbID'},
          cdb     => $cdb,
        });

        if ($is_ncrna) {
          $alignment_link .= sprintf '<li><a href="%s" class="notext">Alignment</a></li>', $hub->url({action => $strain_url.'Compara_Ortholog', function => 'Alignment' . ($cdb =~ /pan/ ? '_pan_compara' : ''), hom_id => $orthologue->{'dbID'}, g1 => $stable_id});
        } else {
          $alignment_link .= sprintf '<a href="%s" class="_zmenu">View Sequence Alignments</a><a class="hidden _zmenu_link" href="%s%s"></a>', $page_url ,$zmenu_url, $strain_param;          
        }
        
        $alignview = 1;
      }      
     
      my $tree_url = $hub->url({
        type   => 'Gene',
        action => $strain_url.'Compara_Tree' . ($cdb =~ /pan/ ? '/pan_compara' : ''),
        g1     => $stable_id,
        anc    => $orthologue->{'gene_tree_node_id'},
        r      => undef
      });

      # External ref and description
      my $description = encode_entities($orthologue->{'description'});
         $description = 'No description' if $description eq 'NULL';
         
      if ($description =~ s/\[\w+:([-\/\w]+)\;\w+:(\w+)\]//g) {
        my ($edb, $acc) = ($1, $2);
        $description   .= sprintf '[Source: %s; acc: %s]', $edb, $hub->get_ExtURL_link($acc, $edb, $acc) if $acc;
      }
      
      my $id_info;
      if ($orthologue->{'display_id'}) {
        if ($orthologue->{'display_id'} eq 'Novel Ensembl prediction') {
          $id_info = qq{<p class="space-below"><a href="$link_url">$stable_id</a></p>};
        } else {
          $id_info = qq{<p class="space-below">$orthologue->{'display_id'}&nbsp;&nbsp;<a href="$link_url">($stable_id)</a></p>};
        }
      } else {
 	$id_info = qq{<p class="space-below"><a href="$link_url">$stable_id</a></p>};	
      }
 
      $id_info .= qq{<p class="space-below">$region_link</p><p class="space-below">$alignment_link</p>};

      ##Location - split into elements to reduce horizonal space
      my $location_link = $hub->url({
        species => $spp,
        type    => 'Location',
        action  => 'View',
        r       => $orthologue->{'location'},
        g       => $stable_id,
        __clear => 1
      });
 
      my $table_details = {
        'Species'    => join('<br />(', split /\s*\(/, $species_defs->species_label($species_defs->production_name_mapping($species))),
        'Type'       => $self->html_format ? glossary_helptip($hub, ucfirst $orthologue_desc, ucfirst "$orthologue_desc orthologues").qq{<p class="top-margin"><a href="$tree_url">View Gene Tree</a></p>} : glossary_helptip($hub, ucfirst $orthologue_desc, ucfirst "$orthologue_desc orthologues") ,
        'dN/dS'      => qq{<span class="$dnds_class">$orthologue_dnds_ratio</span>},
        'identifier' => $self->html_format ? $id_info : $stable_id,
        'Target %id' => qq{<span class="$target_class">}.sprintf('%.2f&nbsp;%%', $target).qq{</span>},
        'Query %id'  => qq{<span class="$query_class">}.sprintf('%.2f&nbsp;%%', $query).qq{</span>},
        'goc_score'  => qq{<span class="$goc_class">$goc_score</span>},
        'wgac'       => qq{<span class="$wga_class">$wgac</span>},
        'confidence' => $confidence,
        'options'    => { class => join(' ', @{$sets_by_species->{$species} || []}) }
      };      
      $table_details->{'Gene name(Xref)'}=$orthologue->{'display_id'} if(!$self->html_format);
      
      push @rows, $table_details;
    }
  }
  
  my $table = $self->new_table($columns, \@rows, { data_table => 1, sorting => [ 'Species asc', 'Type asc' ], id => 'orthologues' });
  
  if ($alignview && keys %orthologue_list) {
    $button_set{'view'} = 1;
  }
  
  $html .= $table->render;
  
  if (scalar keys %skipped) {
    my $count;
    $count += $_ for values %skipped;
    
    $html .= '<br />' . $self->_info(
      'Orthologues hidden by configuration',
      sprintf(
        '<p>%d orthologues not shown in the table above from the following species. Use the "<strong>Configure this page</strong>" on the left to show them.<ul><li>%s</li></ul></p>',
        $count,
        join "</li>\n<li>", sort map {$species_defs->species_label($species_defs->production_name_mapping($_))." ($skipped{$_})"} keys %skipped
      )
    );
  }   
      
  if (%not_seen) {
    $html .= '<br /><a name="list_no_ortho"/>' . $self->_info(
      'Species without orthologues',
      sprintf(
        '<p>%d species are not shown in the table above because they don\'t have any orthologue with %s.<ul><li>%s</li></ul></p>',
        scalar(keys %not_seen),
        $self->object->Obj->stable_id,
        join "</li>\n<li>", sort map {$species_defs->species_label($species_defs->production_name_mapping($_))} keys %not_seen,
      )
    );
  }

  return $html;
}

sub export_options { return {'action' => 'Orthologs'}; }

sub get_export_data {
## Get data for export
  my ($self, $flag) = @_;
  my $hub          = $self->hub;
  my $object       = $self->object || $hub->core_object('gene');

  if ($flag eq 'sequence') {
    return $object->get_homologue_alignments;
  }
  else {
    my $cdb = $flag || $self->param('cdb') || 'compara';
    my ($homologies) = $object->get_homologies('ENSEMBL_ORTHOLOGUES', undef, undef, $cdb);

    my %ok_species;
    foreach (grep { /species_/ } $self->param) {
      (my $sp = $_) =~ s/species_//;
      $ok_species{$sp} = 1 if $self->param($_) eq 'yes';      
    }
   
    if (keys %ok_species) {
      # It's the lower case species url name which is passed through the data export URL
      return [grep {$ok_species{lc($hub->species_defs->production_name_mapping($_->get_all_Members->[1]->genome_db->name))}} @$homologies];
    }
    else {
      return $homologies;
    }
  }
}

sub buttons {
  my $self    = shift;
  my $hub     = $self->hub;
  my @buttons;

  if ($button_set{'download'}) {

    my $gene    =  $self->object->Obj;

    my $dxr  = $gene->can('display_xref') ? $gene->display_xref : undef;
    my $name = $dxr ? $dxr->display_id : $gene->stable_id;

    my $params  = {
                  'type'        => 'DataExport',
                  'action'      => 'Orthologs',
                  'data_type'   => 'Gene',
                  'component'   => 'ComparaOrthologs',
                  'data_action' => $hub->action,
                  'gene_name'   => $name,
                };

    ## Add any species settings
    foreach (grep { /^species_/ } $self->param) {
      $params->{$_} = $self->param($_);
    }

    push @buttons, {
                    'url'     => $hub->url($params),
                    'caption' => 'Download orthologues',
                    'class'   => 'export',
                    'modal'   => 1
                    };
  }

  return @buttons;
}

1;
