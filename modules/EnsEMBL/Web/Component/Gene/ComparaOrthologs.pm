=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

use base qw(EnsEMBL::Web::Component::Gene);

sub _init {
  my $self = shift;
  $self->cacheable(1);
  $self->ajaxable(1);
}

## Stub - implement in plugin if you want to display a summary table
## (see public-plugins/ensembl for an example data structure)
sub _species_sets {}

our %button_set = ('download' => 1, 'view' => 0);

sub content {
  my $self         = shift;
  my $hub          = $self->hub;
  my $object       = $self->object;
  my $species_defs = $hub->species_defs;
  my $cdb          = shift || $hub->param('cdb') || 'compara';
  my $availability = $object->availability;
  my $is_ncrna     = ($object->Obj->biotype =~ /RNA/);
  
  my @orthologues = (
    $object->get_homology_matches('ENSEMBL_ORTHOLOGUES', undef, undef, $cdb), 
  );

  my %orthologue_list;
  my %skipped;
  
  foreach my $homology_type (@orthologues) {
    foreach (keys %$homology_type) {
      (my $species = $_) =~ tr/ /_/;
      $orthologue_list{$species} = {%{$orthologue_list{$species}||{}}, %{$homology_type->{$_}}};
      $skipped{$species}        += keys %{$homology_type->{$_}} if $hub->param('species_' . lc $species) eq 'off';
    }
  }
  
  return '<p>No orthologues have been identified for this gene</p>' unless keys %orthologue_list;
  
  my %orthologue_map = qw(SEED BRH PIP RHS);
  my $alignview      = 0;
 
  my ($html, $columns, @rows);

  ##--------------------------- SUMMARY TABLE ----------------------------------------

  my ($species_sets, $sets_by_species, $set_order) = $self->_species_sets(\%orthologue_list, \%skipped, \%orthologue_map);

  if ($species_sets) {
    $html .= qq{
      <h3>Summary of orthologues of this gene</h3>
      <p class="space-below">Click on 'Show' to display the orthologues for one or more groups, or click on 'Configure this page' to choose a custom list of species</p>
    };
 
    $columns = [
      { key => 'set',       title => 'Species set',    align => 'left',    width => '20%' },
      { key => 'show',      title => 'Show details',   align => 'center',  width => '10%' },
      { key => '1:1',       title => '1:1',            align => 'center',  width => '20%' },
      { key => '1:many',    title => '1:many',         align => 'center',  width => '20%' },
      { key => 'many:many', title => 'many:many',      align => 'center',  width => '20%' },
      { key => 'none',      title => 'No orthologues', align => 'center',  width => '20%' },
    ];

    foreach my $set (@$set_order) {
      my $set_info = $species_sets->{$set};
      
      push @rows, {
        'set'       => "<strong>$set_info->{'title'}</strong><br />$set_info->{'desc'}",
        'show'      => qq{<input type="checkbox" class="table_filter" title="Check to show these species in table below" name="orthologues" value="$set" />},
        '1:1'       => $set_info->{'1-to-1'}       || 0,
        '1:many'    => $set_info->{'1-to-many'}    || 0,
        'many:many' => $set_info->{'Many-to-many'} || 0,
        'none'      => $set_info->{'none'}         || 0,
      };
    }
    
    $html .= $self->new_table($columns, \@rows)->render;
  }

  ##----------------------------- FULL TABLE -----------------------------------------

  $html .= '<h3>Selected orthologues</h3>' if $species_sets;

  my $column_name = $self->html_format ? 'Compare' : 'Description';
  
  my $columns = [
    { key => 'Species',    align => 'left', width => '10%', sort => 'html'                                                },
    { key => 'Type',       align => 'left', width => '5%',  sort => 'string'                                              },
    { key => 'dN/dS',      align => 'left', width => '5%',  sort => 'numeric'                                             },
    { key => 'identifier', align => 'left', width => '15%', sort => 'html', title => $self->html_format ? 'Ensembl identifier &amp; gene name' : 'Ensembl identifier'},    
    { key => $column_name, align => 'left', width => '10%', sort => 'none'                                                },
    { key => 'Location',   align => 'left', width => '20%', sort => 'position_html'                                       },
    { key => 'Target %id', align => 'left', width => '5%',  sort => 'numeric'                                             },
    { key => 'Query %id',  align => 'left', width => '5%',  sort => 'numeric'                                             },
  ];
  
  push @$columns, { key => 'Gene name(Xref)',  align => 'left', width => '15%', sort => 'html', title => 'Gene name(Xref)'} if(!$self->html_format);
  
  @rows = ();
  
  foreach my $species (sort { ($a =~ /^<.*?>(.+)/ ? $1 : $a) cmp ($b =~ /^<.*?>(.+)/ ? $1 : $b) } keys %orthologue_list) {
    next if $skipped{$species};
    
    foreach my $stable_id (sort keys %{$orthologue_list{$species}}) {
      my $orthologue = $orthologue_list{$species}{$stable_id};
      my ($target, $query);
      
      # (Column 2) Add in Orthologue description
      my $orthologue_desc = $orthologue_map{$orthologue->{'homology_desc'}} || $orthologue->{'homology_desc'};
      
      # (Column 3) Add in the dN/dS ratio
      my $orthologue_dnds_ratio = $orthologue->{'homology_dnds_ratio'} || 'n/a';
         
      # (Column 4) Sort out 
      # (1) the link to the other species
      # (2) information about %ids
      # (3) links to multi-contigview and align view
      (my $spp = $orthologue->{'spp'}) =~ tr/ /_/;
      my $link_url = $hub->url({
        species => $spp,
        action  => 'Summary',
        g       => $stable_id,
        __clear => 1
      });

      # Check the target species are on the same portal - otherwise the multispecies link does not make sense
      my $target_links = ($link_url =~ /^\// 
        && $cdb eq 'compara'
        && $availability->{'has_pairwise_alignments'}
      ) ? sprintf(
        '<ul class="compact"><li class="first"><a href="%s" class="notext">Region Comparison</a></li>',
        $hub->url({
          type   => 'Location',
          action => 'Multi',
          g1     => $stable_id,
          s1     => $spp,
          r      => undef,
          config => 'opt_join_genes_bottom=on',
        })
      ) : '';
      
      if ($orthologue_desc ne 'DWGA') {
        ($target, $query) = ($orthologue->{'target_perc_id'}, $orthologue->{'query_perc_id'});
       
        my $align_url = $hub->url({
            action   => 'Compara_Ortholog',
            function => 'Alignment' . ($cdb =~ /pan/ ? '_pan_compara' : ''),
            hom_id   => $orthologue->{'dbID'},
            g1       => $stable_id,
          });
        
        if ($is_ncrna) {
          $target_links .= sprintf '<li><a href="%s" class="notext">Alignment</a></li>', $align_url;
        } else {
          $target_links .= sprintf '<li><a href="%s" class="notext">Alignment (protein)</a></li>', $align_url;
          $target_links .= sprintf '<li><a href="%s" class="notext">Alignment (cDNA)</a></li>', $align_url.';seq=cDNA';
        }
        
        $alignview = 1;
      }
      
      $target_links .= sprintf(
        '<li><a href="%s" class="notext">Gene Tree (image)</a></li></ul>',
        $hub->url({
          type   => 'Gene',
          action => 'Compara_Tree' . ($cdb =~ /pan/ ? '/pan_compara' : ''),
          g1     => $stable_id,
          anc    => $orthologue->{'gene_tree_node_id'},
          r      => undef
        })
      );
      
      # (Column 5) External ref and description
      my $description = encode_entities($orthologue->{'description'});
         $description = 'No description' if $description eq 'NULL';
         
      if ($description =~ s/\[\w+:([-\/\w]+)\;\w+:(\w+)\]//g) {
        my ($edb, $acc) = ($1, $2);
        $description   .= sprintf '[Source: %s; acc: %s]', $edb, $hub->get_ExtURL_link($acc, $edb, $acc) if $acc;
      }
      
      my @external = (qq{<span class="small">$description</span>});
      
      if ($orthologue->{'display_id'}) {
        if ($orthologue->{'display_id'} eq 'Novel Ensembl prediction' && $description eq 'No description') {
          @external = ('<span class="small">-</span>');
        } else {
          unshift @external, $orthologue->{'display_id'};
        }
      }

      my $id_info = qq{<p class="space-below"><a href="$link_url">$stable_id</a></p>} . join '<br />', @external;

      ## (Column 6) Location - split into elements to reduce horizonal space
      my $location_link = $hub->url({
        species => $spp,
        type    => 'Location',
        action  => 'View',
        r       => $orthologue->{'location'},
        g       => $stable_id,
        __clear => 1
      });
      
      my $table_details = {
        'Species'    => join('<br />(', split /\s*\(/, $species_defs->species_label($species)),
        'Type'       => ucfirst $orthologue_desc,
        'dN/dS'      => $orthologue_dnds_ratio,
        'identifier' => $self->html_format ? $id_info : $stable_id,
        'Location'   => qq{<a href="$location_link">$orthologue->{'location'}</a>},
        $column_name => $self->html_format ? qq{<span class="small">$target_links</span>} : $description,
        'Target %id' => $target,
        'Query %id'  => $query,
        'options'    => { class => join(' ', 'all', @{$sets_by_species->{$species} || []}) }
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
        join "</li>\n<li>", map "$_ ($skipped{$_})", sort keys %skipped
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
    my $cdb = $flag || $hub->param('cdb') || 'compara';
    my ($homologies) = $object->get_homologies('ENSEMBL_ORTHOLOGUES', undef, undef, $cdb);
    my %ok_species;
    foreach (grep { /species_/ } $hub->param) {
      (my $sp = $_) =~ s/species_//;
      $ok_species{$sp} = 1 if $hub->param($_) eq 'yes';
    }
    if (keys %ok_species) {
      return [grep {$ok_species{$_->get_all_Members->[1]->genome_db->name}} @$homologies];
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
    foreach (grep { /^species_/ } $hub->param) {
      $params->{$_} = $hub->param($_);
    }

    push @buttons, {
                    'url'     => $hub->url($params),
                    'caption' => 'Download orthologues',
                    'class'   => 'export',
                    'modal'   => 1
                    };
  }

  if ($button_set{'view'}) {

    my $cdb = $hub->param('cdb') || 'compara';

    my $params = {
                  'action' => 'Compara_Ortholog',
                  'function' => 'Alignment'.($cdb =~ /pan/ ? '_pan_compara' : ''),
                  };

    push @buttons, {
                    'url'     => $hub->url($params),
                    'caption' => 'View sequence alignments',
                    'class'   => 'view',
                    'modal'   => 0
    };
  }
  return @buttons;
}

1;
