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
    $self->{'_all_analysed_species'} = {map {$_->name => 1} @{$best_pt_mlss->species_set->genome_dbs}};
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
  my $species_name = $species_defs->GROUP_DISPLAY_NAME;
  my $strain_url   = $hub->is_strain ? "Strain_" : "";
  my $strain_param = $hub->is_strain ? ";strain=1" : ""; # initialize variable even if is_strain is false, to avoid warnings

  my @orthologues = (
    $object->get_homology_matches('ENSEMBL_ORTHOLOGUES', undef, undef, $cdb), 
  ); 

  my %orthologue_list;
  my %skipped;

  my %species_to_show = $self->_get_all_analysed_species($cdb);
  my $this_group      = $species_defs->STRAIN_GROUP;

  ## Skip current species
  delete $species_to_show{$species_defs->SPECIES_PRODUCTION_NAME};

  foreach my $homology_type (@orthologues) {
    foreach my $species (keys %$homology_type) {
      
      my $prod_name     = $species_defs->get_config($species, 'SPECIES_PRODUCTION_NAME');
      my $strain_group  = $species_defs->get_config($species, 'STRAIN_GROUP');

      ## On a strain-specific page, skip anything that doesn't belong to this group
      if ($hub->action =~ /^Strain_/) {
        unless ($strain_group && $strain_group eq $this_group) {
          delete $species_to_show{$prod_name};
          next;
        } 
      }
      else {
        ## Do not show any strain species on main species view
        if ($strain_group && $strain_group ne $prod_name) {
          delete $species_to_show{$prod_name};
          next;
        }
      } 

      $orthologue_list{$species} = {%{$orthologue_list{$species}||{}}, %{$homology_type->{$species}}};
      if($self->param('species_' . lc $species) eq 'off') {
        $skipped{$species}        += keys %{$homology_type->{$species}};
      }

      delete $species_to_show{$prod_name};
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
      <h3>
        Summary of orthologues of this gene
        <a title="Click to show or hide the table" rel="orthologues_summary_table" href="#" class="toggle_link toggle new_icon open _slide_toggle">Hide</a>
      </h3>
      <div class="toggleable orthologues_summary_table">
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
      my $species_selected = $set eq 'all' ? 'checked="checked"' : ''; # select all species by default

      my $none_title = $set_info->{'none'} ? sprintf('<a href="#list_no_ortho">%d</a>', $set_info->{'none'}) : 0;
      my $total = $set_info->{'all'} || 0;
      push @rows, {
        'set'       => "<strong>$set_info->{'title'}</strong> (<i>$total species</i>)<br />$set_info->{'desc'}",
        'show'      => qq{<input type="checkbox" class="table_filter" title="Check to show these species in table below" name="orthologues" value="$set" $species_selected />},
        '1:1'       => $set_info->{'1-to-1'}       || 0,
        '1:many'    => $set_info->{'1-to-many'}    || 0,
        'many:many' => $set_info->{'Many-to-many'} || 0,
        'none'      => $none_title,
      };
    }
    
    $html .= $self->new_table($columns, \@rows)->render;
    $html .= "</div>"; # Closing toggleable div
  }

  ##----------------------------- FULL TABLE -----------------------------------------

  if ($species_sets) {
    $html .= '<h3>
                Selected orthologues
                <a title="Click to show or hide the table" rel="selected_orthologues_table" href="#" class="toggle_link toggle new_icon open _slide_toggle">Hide</a>
              </h3>';
  }
  
  $columns = [
    { key => 'Species',    align => 'left', width => '10%', sort => 'html'                                                },
    { key => 'Type',       align => 'left', width => '10%', sort => 'html'                                            },   
    { key => 'identifier', align => 'left', width => '15%', sort => 'none', title => 'Orthologue'},      
    { key => 'Target %id', align => 'left', width => '5%',  sort => 'position_html', label => 'Target %id', help => "Percentage of the orthologous sequence matching the $species_name sequence" },
    { key => 'Query %id',  align => 'left', width => '5%',  sort => 'position_html', label => 'Query %id',  help => "Percentage of the $species_name sequence matching the sequence of the orthologue" },
    { key => 'goc_score',  align => 'left', width => '5%',  sort => 'position_html', label => 'GOC Score',  help => "<a href='/info/genome/compara/Ortholog_qc_manual.html/#goc'>Gene Order Conservation Score (values are 0-100)</a>" },
    { key => 'wgac',  align => 'left', width => '5%',  sort => 'position_html', label => 'WGA Coverage',  help => "<a href='/info/genome/compara/Ortholog_qc_manual.html/#wga'>Whole Genome Alignment Coverage (values are 0-100)</a>" },
    { key => 'confidence',  align => 'left', width => '5%',  sort => 'html', label => 'High Confidence', help => "<a href='/info/genome/compara/Ortholog_qc_manual.html/#hc'>Homology with high %identity and high GOC score or WGA coverage (as available), Yes or No.</a>"},
  ];
  
  push @$columns, { key => 'Gene name(Xref)',  align => 'left', width => '15%', sort => 'html', title => 'Gene name(Xref)'} if(!$self->html_format);
  
  @rows = ();

  my $pan_lookup = $hub->species_defs->multi_val('PAN_COMPARA_LOOKUP') || {};
  my $rev_lookup;
  if (keys %$pan_lookup) {
    while (my($prod_name, $info) = each(%$pan_lookup)) {
      $rev_lookup->{$info->{'species_url'}} = $prod_name;
    }
  } 
  
  foreach my $species (sort { ($a =~ /^<.*?>(.+)/ ? $1 : $a) cmp ($b =~ /^<.*?>(.+)/ ? $1 : $b) } keys %orthologue_list) {
    next if $skipped{$species};
    next unless $species;
    
    foreach my $stable_id (sort keys %{$orthologue_list{$species}}) {
      my $orthologue = $orthologue_list{$species}{$stable_id};
      my ($target, $query);
      
      # Add in Orthologue description
      my $orthologue_desc = $orthologue_map{$orthologue->{'homology_desc'}} || $orthologue->{'homology_desc'};

      # GOC Score, wgac and high confidence
      my $goc_score  = (defined $orthologue->{'goc_score'} && $orthologue->{'goc_score'} >= 0) ? $orthologue->{'goc_score'} : 'n/a';
      my $wgac       = (defined $orthologue->{'wgac'} && $orthologue->{'wgac'} >= 0) ? $orthologue->{'wgac'} : 'n/a';
      my $confidence = $orthologue->{'highconfidence'} eq '1' ? 'Yes' : $orthologue->{'highconfidence'} eq '0' ? 'No' : 'n/a';
      my $goc_class  = ($goc_score ne "n/a" && $goc_score >= $orthologue->{goc_threshold}) ? "box-highlight" : "";
      my $wga_class  = ($wgac ne "n/a" && $wgac >= $orthologue->{wga_threshold}) ? "box-highlight" : "";

      my $spp = $orthologue->{'spp'};
      my $base_url;

      if ($hub->function && $hub->function eq 'pan_compara') {
        my $prod_name = $rev_lookup->{$spp};
        my $site      = $pan_lookup->{$prod_name}{'division'};
        if ($site ne $hub->species_defs->DIVISION) {
          $site         = 'www' if $site eq 'vertebrates';
          $base_url     = "https://$site.ensembl.org";
        }
      }

      my $link_url = $base_url.$hub->url({
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
        action => $strain_url . ($cdb =~ /pan/ ? 'PanComparaTree' : 'Compara_Tree'),
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
        'Species'    => join('<br />(', split(/\s*\(/, $species_defs->species_label($species))),
        'Type'       => $self->html_format ? glossary_helptip($hub, ucfirst $orthologue_desc, ucfirst "$orthologue_desc orthologues").qq{<p class="top-margin"><a href="$tree_url">View Gene Tree</a></p>} : glossary_helptip($hub, ucfirst $orthologue_desc, ucfirst "$orthologue_desc orthologues") ,
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
  
  $html .= '<div class="toggleable selected_orthologues_table">' . $table->render . '</div>';
  
  if (scalar keys %skipped) {
    my $count;
    $count += $_ for values %skipped;
    
    $html .= '<br />' . $self->_info(
      'Orthologues hidden by configuration',
      sprintf(
        '<p>%d orthologues not shown in the table above from the following species. Use the "<strong>Configure this page</strong>" on the left to show them.<ul><li>%s</li></ul></p>',
        $count,
        join "</li>\n<li>", sort map {$species_defs->species_label($_)." ($skipped{$_})"} keys %skipped
      )
    );
  }   

  if (%species_to_show) {
    $html .= '<br /><a name="list_no_ortho"/>' . $self->_info(
      'Species without orthologues',
      sprintf(
        '<p><span class="no_ortho_count">%d</span> species are not shown in the table above because they don\'t have any orthologue with %s.<ul id="no_ortho_species">%s</ul></p> <input type="hidden" class="panel_type" value="ComparaOrtholog" />',
        scalar(keys %species_to_show),
        $self->object->Obj->stable_id,
        $self->get_no_ortho_species_html(\%species_to_show, $sets_by_species)
      ),
      undef,
      'no_ortho_message_pad'
    );
  }

  return $html;
}

sub export_options { return {'action' => 'Orthologs'}; }

sub get_no_ortho_species_html {
  my ($self, $species_to_show, $sets_by_species) = @_;
  my $hub = $self->hub;
  my $no_ortho_species_html = '';

  foreach (sort {lc $a cmp lc $b} keys %$species_to_show) {
    if ($sets_by_species->{$_}) {
      $no_ortho_species_html .= '<li class="'. join(' ', @{$sets_by_species->{$_}}) .'">'. $hub->species_defs->species_label($_) .'</li>';
    }
  }

  return $no_ortho_species_html;
}

sub get_export_data {
## Get data for export
  my ($self, $flag) = @_;
  my $hub          = $self->hub;
  my $object       = $self->object || $hub->core_object('gene');

  if ($flag eq 'sequence') {
    return $object->get_homologue_alignments;
  }
  else {
    my $cdb = $self->param('cdb');
    unless ($cdb) {
      $cdb = $hub->function =~ /pan_compara/ ? 'compara_pan_ensembl' : 'compara';
    }
    my ($homologies) = $object->get_homologies('ENSEMBL_ORTHOLOGUES', undef, undef, $cdb);

    my %ok_species;

    if($self->param('cdb') eq 'compara_pan_ensembl'){
      my @orthologues = (
        $object->get_homology_matches('ENSEMBL_ORTHOLOGUES', undef, undef, $self->param('cdb')), 
      );
      foreach my $homology_type (@orthologues) {
        foreach my $species (keys %$homology_type) {
          $ok_species{lc($species)} = 1;
        }
      }
    }

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
      'type'          => 'DataExport',
      'action'        => 'Orthologs',
      'data_type'     => 'Gene',
      'component'     => 'ComparaOrthologs',
      'data_action'   => $hub->action,
      'gene_name'     => $name,
      'cdb'           => $hub->function =~ /pan_compara/ ? 'compara_pan_ensembl' : 'compara'
    };

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
