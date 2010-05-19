package EnsEMBL::Web::Component::Gene::ComparaOrthologs;

use strict;

use HTML::Entities qw(encode_entities);

use EnsEMBL::Web::Document::SpreadSheet;

use base qw(EnsEMBL::Web::Component::Gene);

sub _init {
  my $self = shift;
  $self->cacheable(1);
  $self->ajaxable(1);
}

sub caption {
  return undef;
}

sub content {
  my $self = shift;
  my $cdb = shift || $self->object->param('cdb') || 'compara';
  (my $ckey = $cdb) =~ s/compara//;  

  my $object = $self->object;
  
  my @orthologues = (
    $object->get_homology_matches('ENSEMBL_ORTHOLOGUES', undef, undef, $cdb), 
    $object->get_homology_matches('ENSEMBL_PARALOGUES', 'possible_ortholog', undef, $cdb)
  );
  
  my %orthologue_list;
  my %skipped;
  
  foreach my $homology_type (@orthologues) {
    foreach (keys %$homology_type) {
      (my $species = $_) =~ tr/ /_/;
      my $label    = $object->species_defs->species_label($species);
      $orthologue_list{$label} = {%{$orthologue_list{$label}||{}}, %{$homology_type->{$_}}};
      $skipped{$label}        += keys %{$homology_type->{$_}} if $object->param('species_' . lc $species) eq 'off';
    }
  }
  
  return '<p>No orthologues have been identified for this gene</p>' unless keys %orthologue_list;
  
  my %orthologue_map = qw(SEED BRH PIP RHS);
  my $alignview      = 0;
  
  my $columns = [
    { key => 'Species',            align => 'left', width => '10%', sort => 'html'          },
    { key => 'Type',               align => 'left', width => '5%',  sort => 'string'        },
    { key => 'dN/dS',              align => 'left', width => '5%',  sort => 'numeric'       },
    { key => 'Ensembl identifier', align => 'left', width => '20%', sort => 'html'          },
    { key => 'Location',           align => 'left', width => '20%', sort => 'position_html' },
    { key => 'Target %id',         align => 'left', width => '5%',  sort => 'numeric'       },
    { key => 'Query %id',          align => 'left', width => '5%',  sort => 'numeric'       },
    { key => 'External ref.',      align => 'left', width => '30%', sort => 'none'          }
  ];
  
  my @rows;
  
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
      my $link_url = $object->_url({
          species => $spp,
          action  => 'Summary',
          g       => $stable_id,
          r       => undef
	  });

      my $object_stable_id_link = sprintf(
        '<a href="%s">%s</a>',
	$link_url,				  
        $stable_id
      );

      # Check the target species are on the same portal - otherwise the multispecies link does not make sense
      my $local_species =  ($link_url =~ /^\//) ? 1 : 0;      

      my $target_links =  ($local_species && ($cdb eq 'compara')) ? sprintf(
        '<a href="%s">Multi-species view</a>',
        $object->_url({
          type   => 'Location',
          action => 'Multi',
          g1     => $stable_id,
          s1     => $spp,
          r      => undef
        })
      )  : '';
   
      
      my $location_link = $object->_url({
        species => $spp,
        type    => 'Location',
        action  => 'View',
        r       => $orthologue->{'location'},
        g       => $stable_id
      });
      
      if ($orthologue_desc ne 'DWGA') {
        ($target, $query) = ($orthologue->{'target_perc_id'}, $orthologue->{'query_perc_id'});
        
        $target_links .= sprintf(
          '<br /><a href="%s">Alignment</a>',
          $object->_url({
            action   => 'Compara_Ortholog', 
            function => "Alignment$ckey",
            g1       => $stable_id,
          })
        );
        
        $alignview = 1;
      }
      
      $target_links .= sprintf(
        '<br /><a href="%s">Gene Tree (image)</a>',
        $object->_url({
          type   => 'Gene',
          action => "Compara_Tree$ckey",
          g1     => $stable_id,
          anc    => $orthologue->{'ancestor_node_id'},
          r      => undef
        })
      );
      
      # (Column 5) External ref and description
      my $description = encode_entities($orthologue->{'description'});
         $description = 'No description' if $description eq 'NULL';
         
      if ($description =~ s/\[\w+:([-\/\w]+)\;\w+:(\w+)\]//g) {
        my ($edb, $acc) = ($1, $2);
        $description   .= sprintf '[Source: %s; acc: %s]', $edb, $object->get_ExtURL_link($acc, $edb, $acc) if $acc;
      }
      
      my @external = qq{<span class="small">$description</span>};
      unshift @external, $orthologue->{'display_id'} if $orthologue->{'display_id'};
      
      push @rows, {
        'Species'            => join('<br />(', split /\s*\(/, $species),
        'Type'               => ucfirst $orthologue_desc,
        'dN/dS'              => $orthologue_dnds_ratio,
        'Ensembl identifier' => qq{$object_stable_id_link<br /><span class="small">$target_links</span>},
        'Location'           => qq{<a href="$location_link">$orthologue->{'location'}</a>},
        'Target %id'         => $target,
        'Query %id'          => $query,
        'External ref.'      => join('<br />', @external)
      };
    }
  }
  
  my $table = new EnsEMBL::Web::Document::SpreadSheet($columns, \@rows, { data_table => 1, sorting => [ 'Species asc', 'Type asc' ] });
  
  my $html = '<p>The following gene(s) have been identified as putative orthologues:</p>' . $table->render;
  
  if ($alignview && keys %orthologue_list) {
    $html .= sprintf(
      '<p><a href="%s">View sequence alignments of these homologues</a>.</p>', 
      $object->_url({ action => "Compara_Ortholog$ckey", function => 'Alignment' })
    );
  }
  
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
