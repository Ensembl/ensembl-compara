# $Id$

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

sub content {
  my $self          = shift;
  my $hub           = $self->hub;
  my $object        = $self->object;
  my $species_defs  = $hub->species_defs;
  my $cdb           = shift || $hub->param('cdb') || 'compara';
  
  my @orthologues = (
    $object->get_homology_matches('ENSEMBL_ORTHOLOGUES', undef, undef, $cdb), 
    $object->get_homology_matches('ENSEMBL_PARALOGUES', 'possible_ortholog', undef, $cdb)
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

  my ($species_sets, $set_order) = $self->_species_sets(\%orthologue_list, \%skipped, \%orthologue_map);

  if ($species_sets) {

    $html .= qq(<h3>Summary of orthologues of this gene</h3>
                <p class="space-below">Click on 'Show' to display the orthologues for one or more groups, or click on 'Configure this page' to choose a custom list of species</p>);
 
    $columns = [
      { key => 'set',       'title' => 'Species set', align => 'left',    width => '20%', sort => 'none' },
      { key => 'show',      'title' => '',                                width => '10%' },
      { key => '1:1',       'title' => '1:1',         align => 'center',  width => '20%', sort => 'none' },
      { key => '1:many',    'title' => '1:many',      align => 'center',  width => '20%', sort => 'none' },
      { key => 'many:many', 'title' => 'many:many',   align => 'center',  width => '20%', sort => 'none' },
      { key => 'none',      'title' => 'No orthologues', align => 'center',  width => '20%', sort => 'none' },
    ];

    foreach my $set (@$set_order) {
      #next unless ($set && ref($set) eq 'HASH');
      my $set_info = $species_sets->{$set};

      my $url = $self->ajax_url . ";set=$set;update_panel=1";
      my $show = qq{
        <a href="$url" class="ajax_add toggle closed" rel="$set">
          <span class="closed">Show</span><span class="open">Hide</span>
          <input type="hidden" class="url" value="$url" />
        </a>
      };

      my $url = $hub->url({'sets' => $set});
      push @rows, {
        'set'         => '<strong>'.$set_info->{'title'}.'</strong><br />'.$set_info->{'desc'},
        'show'        => $show,
        '1:1'         => $set_info->{'1-to-1'} || '0',
        '1:many'      => $set_info->{'1-to-many'} || '0',
        'many:many'   => $set_info->{'Many-to-many'} || '0',
        'none'        => $set_info->{'none'} || '0',
      };
    }

    my $summary = $self->new_table($columns, \@rows);
    $html .= $summary->render;
  }

  ##----------------------------- FULL TABLE -----------------------------------------

  my %selected_species;
  if ($species_sets) {
    my @selected_sets = $self->hub->param('set') || ('all');
    warn ">>> SETS @selected_sets";
    foreach my $set (@selected_sets) {
      foreach my $species (@{$species_sets->{$set}{'species'}}) {
        $selected_species{$species}++;
      }
    }
    $html .= qq(<h3>Selected orthologues</h3>);
  }
  else {
    %selected_species = %orthologue_list; 
  }
 
  $columns = [
    { key => 'Species',            align => 'left', width => '5%', sort => 'html'          },
  my $column_name =  $self->html_format ? 'Compare' : 'Description';
  
  my $columns = [
    { key => 'Species',            align => 'left', width => '10%', sort => 'html'          },
    { key => 'Type',               align => 'left', width => '5%',  sort => 'string'        },
    { key => 'dN/dS',              align => 'left', width => '5%',  sort => 'numeric'       },
    { key => 'Ensembl identifier &amp; gene name', align => 'left', width => '15%', sort => 'html'},
    { key => $column_name,         align => 'left', width => '10%', sort => 'none'          },
    { key => 'Location',           align => 'left', width => '20%', sort => 'position_html' },
    { key => 'Target %id',         align => 'left', width => '5%',  sort => 'numeric'       },
    { key => 'Query %id',          align => 'left', width => '5%',  sort => 'numeric'       },
  ];
  
  @rows = ();
  
  foreach my $species (
      sort { ($a =~ /^<.*?>(.+)/ ? $1 : $a) cmp ($b =~ /^<.*?>(.+)/ ? $1 : $b) } 
      keys %selected_species) {
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
      my $local_species = ($link_url =~ /^\//) ? 1 : 0;      

      my $target_links =  ($local_species && ($cdb eq 'compara')) ? sprintf(
        '<ul class="compact"><li class="first"><a href="%s" class="notext">Multi-species view</a></li>',
        $hub->url({
          type   => 'Location',
          action => 'Multi',
          g1     => $stable_id,
          s1     => $spp,
          r      => undef
        })
      ) : '';
   
      
      if ($orthologue_desc ne 'DWGA') {
        ($target, $query) = ($orthologue->{'target_perc_id'}, $orthologue->{'query_perc_id'});
       
        my $align_url = $hub->url({
            action   => 'Compara_Ortholog',
            function => "Alignment". ($cdb=~/pan/ ? '_pan_compara' : ''),
            g1       => $stable_id,
          });

        $target_links .= sprintf('<li><a href="%s" class="notext">Alignment (protein)</a></li>', $align_url);
        $align_url .= ';seq=cDNA';
        $target_links .= sprintf('<li><a href="%s" class="notext">Alignment (cDNA)</a></li>', $align_url);
        
        $alignview = 1;
      }
      
      $target_links .= sprintf(
        '<li><a href="%s" class="notext">Gene Tree (image)</a></li>',
        $hub->url({
          type   => 'Gene',
          action => "Compara_Tree". ($cdb=~/pan/ ? '/pan_compara' : ''),
          g1     => $stable_id,
          anc    => $orthologue->{'ancestor_node_id'},
          r      => undef
        })
      );
      
      # (Column 5) External ref and description
      my $object_stable_id_link = qq{<p class="space-below"><a href="$link_url">$stable_id</a></p>};

      my $description = encode_entities($orthologue->{'description'});
         $description = 'No description' if $description eq 'NULL';
         
      if ($description =~ s/\[\w+:([-\/\w]+)\;\w+:(\w+)\]//g) {
        my ($edb, $acc) = ($1, $2);
        $description   .= sprintf '[Source: %s; acc: %s]', $edb, $hub->get_ExtURL_link($acc, $edb, $acc) if $acc;
      }
      
      my @external = qq{<span class="small">$description</span>};
      unshift @external, $orthologue->{'display_id'} if $orthologue->{'display_id'};

      # Bug fix:  In othologues list, all orthologues with no description used to appear to be described as "novel ensembl predictions":
      @external = qq{<span class="small">-</span>} if (($description eq 'No description') && ($orthologue->{'display_id'} eq 'Novel Ensembl prediction'));  

      my $id_info = $object_stable_id_link.join('<br />', @external);

      ## (Column 6) Location - split into elements to reduce horizonal space
      my $location_link = $hub->url({
        species => $spp,
        type    => 'Location',
        action  => 'View',
        r       => $orthologue->{'location'},
        g       => $stable_id,
        __clear => 1
      });

      my ($chr, $coords, $strand) = split(/:/, $orthologue->{'location'});
      my ($start, $end)           = split(/-/, $coords);

      my $location_text = qq{Chr: <a href="$location_link">$chr</a><br />
        Start: $start<br />
        End: $end<br />
        Strand: $strand<br />
      };
      my $label    = join('<br />(', split /\s*\(/, $species_defs->species_label($species));
      
      @external = qq{<span class="small">-</span>} if (($description eq 'No description') && ($orthologue->{'display_id'} eq 'Novel Ensembl prediction'));
      
      push @rows, {
        'Species'            => $label,
        'Type'               => ucfirst $orthologue_desc,
        'dN/dS'              => $orthologue_dnds_ratio,
        'Ensembl identifier &amp; gene name' => $id_info,
        'Location'           => $location_text,
        $column_name         => $self->html_format ? qq{<span class="small">$target_links</span>} : "$description",
        'Target %id'         => $target,
        'Query %id'          => $query,
      };      
    }
  }
  
  my $table = $self->new_table($columns, \@rows, { data_table => 1, sorting => [ 'Species asc', 'Type asc' ] });
  
  if ($alignview && keys %orthologue_list) {
    $html .= sprintf(
      '<p><a href="%s">View sequence alignments of these homologues</a>.</p>', 
      $hub->url({ action => "Compara_Ortholog", function => "Alignment". ($cdb=~/pan/ ? '_pan_compara' : ''), })
    );
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

1;
