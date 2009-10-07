package EnsEMBL::Web::Component::Gene::ComparaOrthologs;

use strict;
use warnings;
no warnings "uninitialized";

use CGI qw(escapeHTML);

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
  
  my $object = $self->object;
  
#  my @orthologues = (
#    $object->get_homology_matches('ENSEMBL_ORTHOLOGUES'), 
#    $object->get_homology_matches('ENSEMBL_PARALOGUES', 'between_species_paralog')
#  );
  my @orthologues = $object->get_homology_matches('ENSEMBL_ORTHOLOGUES');
  
  my %orthologue_list;
  my %skipped;
  
  foreach my $homology_type (@orthologues) {
    foreach (keys %$homology_type) {
      (my $species = $_) =~ tr/ /_/;
      my $label = $object->species_defs->species_label($species);
      
      $orthologue_list{$label} = {%{$orthologue_list{$label}||{}}, %{$homology_type->{$_}}};
      
      $skipped{$label} += keys %{$homology_type->{$_}} if $object->param('species_' . lc $species) eq 'off';
    }
  }
  
  return '<p>No orthologues have been identified for this gene</p>' unless keys %orthologue_list;
  
  my %orthologue_map = qw(SEED BRH PIP RHS);
  my $alignview      = 0;
  
  my $html = '
  <table class="orthologues">
    <tr>
      <th>Species</th>
      <th>Type</th>
      <th>dN/dS</th>
      <th>Ensembl identifier</th>
      <th>External ref.</th>
    </tr>';
  
  foreach my $species (sort { ($a =~ /^<.*?>(.+)/ ? $1 : $a) cmp ($b =~ /^<.*?>(.+)/ ? $1 : $b) } keys %orthologue_list) {
    next if $skipped{$species};
    
    $html .= sprintf('
      <tr>
        <th rowspan="%s">%s</th>',
        scalar keys %{$orthologue_list{$species}},
        $species
    );
    
    my $start;
    
    foreach my $stable_id (sort keys %{$orthologue_list{$species}}) {
      my $orthologue = $orthologue_list{$species}{$stable_id};
      my $percent_ids;
      
      # (Column 2) Add in Orthologue description
      my $orthologue_desc = $orthologue_map{$orthologue->{'homology_desc'}} || $orthologue->{'homology_desc'};
      
      # (Column 3) Add in the dN/dS ratio
      my $orthologue_dnds_ratio = $orthologue->{'homology_dnds_ratio'} || 'na';
         
      # (Column 4) Sort out (1) the link to the other species
      #                     (2) information about %ids
      #                     (3) links to multi-contigview and align view
      (my $spp = $orthologue->{'spp'}) =~ tr/ /_/;
      
      my $object_stable_id_link = sprintf(
        '<a href="%s">%s</a>',
        $object->_url({
          species => $spp,
          action  => 'Summary',
          g       => $stable_id
        }),
        $stable_id
      );
      
      my $target_links = sprintf(
        '<br /><span class="small">[<a href="%s">Multi-species view</a>] </span>',
        $object->_url({
          type   => 'Location',
          action => 'Multi',
          g1     => $stable_id,
          s1     => $spp,
          r      => undef
        })
      );
      
      if ($orthologue_desc ne 'DWGA') {
        $alignview = 1;
        
        $percent_ids = qq{<br /><span class="small">Target %id: $orthologue->{'target_perc_id'}; Query %id: $orthologue->{'query_perc_id'}</span>};
        $target_links .= sprintf(
          '<span class="small">[<a href="%s">Align</a>]</span>',
          $object->_url({
            action   => 'Compara_Ortholog', 
            function => 'Alignment',
            g1       => $stable_id
          })
        );
      }
      
      # (Column 5) External ref and description
      my $description = escapeHTML($orthologue->{'description'});
         $description = 'No description' if $description eq 'NULL';
         
      if ($description =~ s/\[\w+:([-\/\w]+)\;\w+:(\w+)\]//g) {
        my ($edb, $acc) = ($1, $2);
        $description .= "[Source: $edb; acc: " . $object->get_ExtURL_link($acc, $edb, $acc) . ']' if $acc;
      }
      
      my @external;
      
      push @external, $orthologue->{'display_id'} if $orthologue->{'display_id'};
      push @external, qq{<span class="small">$description</span>};
      
      my $ext = join '<br />', @external;
      
      $html .= qq{
        $start
          <td>$orthologue_desc</td>
          <td>$orthologue_dnds_ratio</td>
          <td>
            $object_stable_id_link$percent_ids$target_links
          </td>
          <td>
            $ext
          </td>
        </tr>
      };
      
      $start = '<tr>';
    }
  }
  
  $html .= '
  </table>';

  $html = sprintf(
    qq{<p>
      The following gene(s) have been identified as putative
      orthologues:
    </p>
    <p>
      (N.B. If you don't find a homologue here, it may be a "between-species paralogue". Please view the <a href="%s">gene tree info</a> to see more.)
    </p>
    %s},
    $object->_url({ action => 'Compara_Tree' }), 
    $html
  );
  
  if ($alignview && keys %orthologue_list) {
    $html .= sprintf(
      '<p><a href="%s">View sequence alignments of all homologues</a>.</p>', 
      $object->_url({ action => 'Compara_Ortholog', function => 'Alignment' })
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


