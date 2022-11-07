=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2022] EMBL-European Bioinformatics Institute

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

use EnsEMBL::Web::Utils::FormatText qw(glossary_helptip get_glossary_entry pluralise);

use base qw(EnsEMBL::Web::Component::Gene);

sub _init {
  my $self = shift;
  $self->cacheable(1);
  $self->ajaxable(1);
}

our %button_set = ('download' => 1, 'view' => 0);

sub content {
  my $self         = shift;
  my $hub          = $self->hub;
  my $object       = $self->object;
  my $species_defs = $hub->species_defs;
  my $cdb          = shift || $self->param('cdb') || 'compara';
  my $is_pan       = $cdb =~/compara_pan_ensembl/;
  my $availability = $object->availability;
  my $is_ncrna     = ($object->Obj->biotype =~ /RNA/);
  my $species_name = $species_defs->GROUP_DISPLAY_NAME;
  my $strain_url   = $hub->is_strain ? "Strain_" : "";
  my $strain_param = $hub->is_strain ? ";strain=1" : ""; # initialize variable even if is_strain is false, to avoid warnings

  my @orthologues = (
    $object->get_homology_matches('ENSEMBL_ORTHOLOGUES', undef, undef, $cdb), 
  ); 

  my %orthologue_list;
  foreach my $homology_type (@orthologues) {
    foreach my $species (sort keys %$homology_type) {
      $orthologue_list{$species} = {%{$orthologue_list{$species}||{}}, %{$homology_type->{$species}}};
    }
  }
  return '<p>No orthologues have been identified for this gene</p>' unless keys %orthologue_list;

  ## Get species info
  my $compara_species   = {};
  my $lookup            = {};
  my $pan_info          = {};
  if ($is_pan) {
    $pan_info      = $species_defs->multi_val('PAN_COMPARA_LOOKUP');
    foreach (keys %$pan_info) {
      $compara_species->{$_}  = 1;
      $lookup->{$_}           = $pan_info->{$_}{'species_url'};
    } 
  }
  else {
    $compara_species  = $species_defs->multi_hash->{'DATABASE_COMPARA'}{'COMPARA_SPECIES'};;
    $lookup           = $species_defs->prodnames_to_urls_lookup;
  }

  ## Work out which species we want to skip over, based on page type  and user's configuration
  my $this_group        = $species_defs->STRAIN_GROUP;
  my $species_not_shown = {}; 
  my $strains_not_shown = {};
  my $strain_refs       = {};
  my $hidden            = {};

  foreach my $prod_name (keys %$compara_species) {
    ## Use URL as hash key
    my $species = $lookup->{$prod_name};
    next if $species eq $hub->species; ## Ignore current species
    my $label = $species_defs->species_label($species);

    ## Should we be showing this orthologue on this pagpe by default?
    my $strain_group  = $species_defs->get_config($species, 'STRAIN_GROUP');
    my $related_taxon = $species_defs->get_config($species, 'RELATED_TAXON');
    if ($hub->action =~ /^Strain_/) {
      unless (($strain_group && $strain_group eq $this_group) || ($related_taxon && $related_taxon eq $species_defs->RELATED_TAXON)) {
        $species_not_shown->{$species} = $label;
        next;
      }
    }
    else {
      if ($strain_group) {
        if ($strain_group eq $prod_name) {
          $strain_refs->{$species} = $label;
        }
        else { 
          ## Do not show any strain species on main species view
          $strains_not_shown->{$species} = $label;
          next;
        }
      }
    }

    ## Do we even have an orthologue for this species?
    unless ($orthologue_list{$species}) {
      $species_not_shown->{$species} = $label;
      next;
    }
  
    ## Also hide anything turned off in config
    #my $show = $self->param('species_' . $prod_name);
    #warn ">>> SHOW $prod_name? $show";
    if ($self->param('species_' . $prod_name) eq 'off') {
      $hidden->{$label} = scalar keys %{$orthologue_list{$species}||{}};
    }
  }

  ##--------------------------- SUMMARY TABLE ----------------------------------------

  my %orthologue_map = qw(SEED BRH PIP RHS);
  my $alignview      = 0;
  my ($html, $columns, @rows);

  my ($species_sets, $sets_by_species, $set_order) = $self->species_sets(\%orthologue_list, \%orthologue_map, $cdb);

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
    { key => 'goc_score',  align => 'left', width => '5%',  sort => 'position_html', label => 'GOC Score',  help => "<a href='/info/genome/compara/Ortholog_qc_manual.html#goc'>Gene Order Conservation Score (values are 0-100)</a>" },
    { key => 'wgac',  align => 'left', width => '5%',  sort => 'position_html', label => 'WGA Coverage',  help => "<a href='/info/genome/compara/Ortholog_qc_manual.html#wga'>Whole Genome Alignment Coverage (values are 0-100)</a>" },
    { key => 'confidence',  align => 'left', width => '5%',  sort => 'html', label => 'High Confidence', help => "<a href='/info/genome/compara/Ortholog_qc_manual.html#hc'>Homology with high %identity and high GOC score or WGA coverage (as available), Yes or No.</a>"},
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
    next unless $species;
    next if $species_not_shown->{$species};
    next if $strains_not_shown->{$species};

    my ($species_label, $prodname);
    if ($is_pan) {
      $prodname = $rev_lookup->{$species};
      $species_label = $pan_lookup->{$prodname}{'display_name'};
    }
    else {
      $species_label = $species_defs->species_label($species);
    }

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

      my $base_url;

      if ($is_pan) {
        my $site      = $pan_lookup->{$prodname}{'division'};
        if ($site ne $hub->species_defs->DIVISION) {
          $site         = 'www' if $site eq 'vertebrates';
          $base_url     = "https://$site.ensembl.org";
        }
      }

      my $link_url = $base_url.$hub->url({
        species => $species,
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
          s1     => $species,
          r      => $hub->create_padded_region()->{'r'} || $self->param('r'),
          r1     => $orthologue->{'rparam'},
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
        species => $species,
        type    => 'Location',
        action  => 'View',
        r       => $orthologue->{'location'},
        g       => $stable_id,
        __clear => 1
      });


      my $table_details = {
        'Species'    => join('<br />(', split(/\s*\(/, $species_label)),
        'Type'       => $self->html_format ? glossary_helptip($hub, ucfirst $orthologue_desc, ucfirst "$orthologue_desc orthologues").qq{<p class="top-margin"><a href="$tree_url">View Gene Tree</a></p>} : glossary_helptip($hub, ucfirst $orthologue_desc, ucfirst "$orthologue_desc orthologues") ,
        'identifier' => $self->html_format ? $id_info : $stable_id,
        'Target %id' => qq{<span class="$target_class">}.sprintf('%.2f&nbsp;%%', $target).qq{</span>},
        'Query %id'  => qq{<span class="$query_class">}.sprintf('%.2f&nbsp;%%', $query).qq{</span>},
        'goc_score'  => qq{<span class="$goc_class">$goc_score</span>},
        'wgac'       => qq{<span class="$wga_class">$wgac</span>},
        'confidence' => $confidence,
        'options'    => { class => join(' ', @{$sets_by_species->{$species} || []}), data_table_config => {iDisplayLength => 25}  }
      };      
      $table_details->{'Gene name(Xref)'} = $orthologue->{'display_id'} if (!$self->html_format);

      push @rows, $table_details;
    }
  }
  
  my $table = $self->new_table($columns, \@rows, { data_table => 1, sorting => [ 'Species asc', 'Type asc' ], id => 'orthologues' });
  
  if ($alignview && keys %orthologue_list) {
    $button_set{'view'} = 1;
  }
  
  $html .= '<div class="toggleable selected_orthologues_table">' . $table->render . '</div>';
  
  if (scalar keys %$hidden) {
    my $count;
    $count += $_ for values %$hidden;
    
    $html .= '<br />' . $self->_info(
      'Orthologues hidden by configuration',
      sprintf(
        '<p>%d orthologues not shown in the table above from the following species. Use the "<strong>Configure this page</strong>" on the left to show them.<ul><li>%s</li></ul></p>',
        $count,
        join "</li>\n<li>", sort keys %$hidden
      )
    );
  }   

  if (($hub->action =~ /^Strain_/ && keys %$strains_not_shown)
    || ($hub->action !~ /^Strain_/ && keys %$species_not_shown)) {
    my ($total, $no_ortho_species, $strain_refs_html);
    if ($hub->action =~ /^Strain_/) {
      $total = scalar keys %$strains_not_shown; 
      $no_ortho_species = $self->get_no_ortho_species_html($strains_not_shown, $sets_by_species);
      $strain_refs_html = '';
    }
    else {
      $total = scalar keys %$species_not_shown; 
      unless ($is_pan) {
        $no_ortho_species = $self->get_no_ortho_species_html($species_not_shown, $sets_by_species);
        $strain_refs_html = $self->get_strain_refs_html($strain_refs, $species_not_shown);
      }
    }
    my $not_shown_list = $is_pan ? '' : sprintf('<ul id="no_ortho_species">%s</ul>', $no_ortho_species);
    $html .= '<br /><a name="list_no_ortho"/>' . $self->_info(
      'Species without orthologues',
      sprintf(
        qq(<p><span class="no_ortho_count">%d</span> species are not shown in the table above because they don't have any orthologue with %s.</p>
%s
%s
</p> <input type="hidden" class="panel_type" value="ComparaOrtholog" />), $total, $self->object->Obj->stable_id, $not_shown_list, $strain_refs_html),
      undef,
      'no_ortho_message_pad'
    );
  }

  return $html;
}

sub export_options { return {'action' => 'Orthologs'}; }

sub species_sets {
## Group species into set
  my ($self, $orthologue_list, $orthologue_map, $cdb) = @_;
  my $hub             = $self->hub;
  my $species_defs    = $hub->species_defs;

  return "" if $self->hub->action =~ /^Strain/; #No summary table needed for strains

  my ($set_order, $species_sets, $set_mappings) = $self->species_set_config;
  return "" unless $set_order;

  my $compara_spp     = $species_defs->multi_hash->{'DATABASE_COMPARA'}{'COMPARA_SPECIES'};
  my $lookup          = $species_defs->prodnames_to_urls_lookup;
  my %orthologue_map  = qw(SEED BRH PIP RHS);
  my $sets_by_species = {};
  my $ortho_type      = {};

  foreach (keys %$compara_spp) {
    my $species = $lookup->{$_};
    next if $self->hub->is_strain($species); #skip strain species

    my $orthologues = $orthologue_list->{$species} || {};
    my $no_ortho = 0;
    if (!$orthologue_list->{$species} && $species ne $self->hub->species) {
      $no_ortho = 1;
    }

    foreach my $stable_id (keys %$orthologues) {
      my $orth_info = $orthologue_list->{$species}{$stable_id};
      my $orth_desc = ucfirst($orthologue_map{$orth_info->{'homology_desc'}} || $orth_info->{'homology_desc'});
      $ortho_type->{$species}{$orth_desc} = 1;
    }

    if ($species ne $self->hub->species && !$ortho_type->{$species}{'1-to-1'} && !$ortho_type->{$species}{'1-to-many'}
          && !$ortho_type->{$species}{'Many-to-many'}) {
      $no_ortho = 1;
    }  

    my $taxon_group     = $species_defs->get_config($species, 'SPECIES_GROUP');
    my @compara_groups  = $set_mappings ? @{$set_mappings->{$taxon_group}||[]}
                                        : ($taxon_group);
    my $sets = [];

    foreach my $ss_name ('all', @compara_groups) {
      push @{$species_sets->{$ss_name}{'species'}}, $species;
      push @$sets, $ss_name;
      while (my ($k, $v) = each (%{$ortho_type->{$species}})) {
        $species_sets->{$ss_name}{$k} += $v;
      }
      $species_sets->{$ss_name}{'none'}++ if $no_ortho;
      $species_sets->{$ss_name}{'all'}++ if $species ne $self->hub->species;
    }
    $sets_by_species->{$species} = $sets;
  }

  return ($species_sets, $sets_by_species, $set_order);
}

sub species_set_config {} # Stub, as it's clade-specific - implement in plugins

sub get_strain_refs_html {
  my ($self, $strain_refs, $species_not_shown) = @_;
  return '' unless keys %{$strain_refs||{}};

  my $species_defs = $self->hub->species_defs;
  my $count = 0;
  my ($list, %strain_types);

  foreach (sort {lc $strain_refs->{$a} cmp lc $strain_refs->{$b}} keys %$strain_refs) {
    next if $species_not_shown->{$_}; ## Don't mention if reference has no orthologues
    $strain_types{$species_defs->get_config($_, 'STRAIN_TYPE')}++;
    $list .= sprintf '<li>%s</li>', $strain_refs->{$_};
    $count++;
  }
  return '' if $count == 0;

  ## Select the most common strain type for this site
  my @ordered_types = sort {$strain_types{$b} <=> $strain_types{$a}} keys %strain_types;
  my $type = $ordered_types[0];

  my $html = sprintf '<p>Additionally, %s of %s species are not shown in this table. %s orthologues can be found on the gene pages of these reference species:</p><ul>%s</ul>', pluralise($type), $count, ucfirst($type), $list;
  return $html;
}

sub get_no_ortho_species_html {
  my ($self, $species_not_shown, $sets_by_species) = @_;
  my $hub = $self->hub;
  my $html = '';

  foreach (sort {lc $a cmp lc $b} keys %$species_not_shown) {
    my $class = $sets_by_species->{$_} ? sprintf(' class="%s"',  join(' ', @{$sets_by_species->{$_}})) : '';
    $html .= sprintf '<li%s>%s</li>', $class, $species_not_shown->{$_};
  }

  return $html;
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
      my $lookup = $hub->species_defs->prodnames_to_urls_lookup;
      return [grep {$ok_species{lc($lookup->{$_->get_all_Members->[1]->genome_db->name})}} @$homologies];
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
