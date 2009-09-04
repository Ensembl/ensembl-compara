package EnsEMBL::Web::Component::Gene::ComparaOrthologs;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Gene);

sub _init {
  my $self = shift;
  $self->cacheable( 1 );
  $self->ajaxable(  1 );
}

sub caption {
  return undef;
}

sub content {
  my $self = shift;
  my $gene = $self->object;
  my $db   = $gene->get_db() ;
  my $html;
  my $orthologue = $gene->get_homology_matches('ENSEMBL_ORTHOLOGUES');
  my $betweens = $gene->get_homology_matches('ENSEMBL_PARALOGUES','between_species_paralog');
  my %orthologue_list = (%{$orthologue},%{$betweens});

  if (keys %orthologue_list) {
# Find the selected method_link_set
    $html = q(
    <table class="orthologues">
      <tr>
        <th>Species</th>
        <th>Type</th>
        <th>dN/dS</th>
        <th>Ensembl identifier</th>
        <th>External ref.</th>
      </tr>);
    my %orthologue_map = qw(SEED BRH PIP RHS);

    my %SPECIES;
    my $STABLE_ID = $gene->stable_id; my $C = 1;
    my $ALIGNVIEW = 0;
    my $matching_orthologues = 0;
    my %SP = ();
    my $multicv_link = sprintf "/%s/Location/Multimulticontigview?gene=%s;context=10000", $gene->species, $gene->stable_id;
#    my $FULL_URL     = $multicv_link;
    my $orthologues_skipped_count   = 0;
    my @orthologues_skipped_species = ();
    foreach my $species (sort keys %orthologue_list) {
      (my $spp = $species) =~ tr/ /_/ ;
      my $label = $gene->species_defs->species_label( $spp );

      if( $gene->param('species_'.lc($spp) ) eq 'no' ) {
        $orthologues_skipped_count += keys %{$orthologue_list{$species}};
        push @orthologues_skipped_species, $label;
        next;
      }
      my $C_species = 1;
      my $rowspan = scalar(keys %{$orthologue_list{$species}});
#      $rowspan++ if $rowspan > 1;
      $html .= sprintf( qq(
      <tr>
        <th rowspan="$rowspan">%s</th>), $label );
      my $start = '';
#      my $mcv_species = $multicv_link;
      foreach my $stable_id (sort keys %{$orthologue_list{$species}}) {
        my $OBJ = $orthologue_list{$species}{$stable_id};
        $matching_orthologues = 1;
        $html .= $start;
        $start = qq(
      <tr>);
## (Column 2) Add in Orthologue description...
        my $orthologue_desc = $orthologue_map{ $OBJ->{'homology_desc'} } || $OBJ->{'homology_desc'};
## (Column 3) Add in the dN/dS ratio...
        my $orthologue_dnds_ratio = $OBJ->{'homology_dnds_ratio'} || 'na';
           $orthologue_dnds_ratio = '&nbsp;' unless defined $orthologue_dnds_ratio;
## (Column 4) Sort out (1) the link to the other species
##                     (2) information about %ids
##                     (3) links to multi-contigview and align view
        (my $spp = $OBJ->{'spp'}) =~ tr/ /_/ ;
	my $link = qq(/$spp/Gene/Summary?g=$stable_id;db=$db);   ### USE _url
	my $gene_stable_id_link = sprintf '<a href="%s">%s</a>', $link, $stable_id;
        my $percent_ids  = '';
	my $multicv_link = $gene->_url({
	  'type'   => 'Location',
	  'action' => 'Multi',
	  'g1'     => $stable_id,
	});
        my $target_links = qq(<br /><span class="small">[<a href="$multicv_link">Multi-species comp.</a>]</span>);
        if( $orthologue_desc ne 'DWGA' ) {
          my $url = $gene->_url({ 'action' => 'Compara_Ortholog/Alignment', 'g1' => $stable_id });
	  $target_links .= qq(
	  <span class="small">[<a href="$url">Align</a>]</span> );
          $percent_ids = qq(<br />
	  <span class="small">Target &#37id: $OBJ->{'target_perc_id'}; Query &#37id: $OBJ->{'query_perc_id'}</span>);
	  $ALIGNVIEW = 1;
        }
## (Column 5) External ref and description...

        my $description = $OBJ->{'description'};
           $description = "No description" if $description eq "NULL";
           $description = CGI::escapeHTML( $description );
        if( $description =~ s/\[\w+:([-\/\w]+)\;\w+:(\w+)\]//g ) {
          my ($edb, $acc) = ($1, $2);
          if( $acc ) {
            $description .= "[Source: $edb; acc: ".$gene->get_ExtURL_link($acc, $edb, $acc)."]";
          }
        }
	my @external = ();
	push @external, $OBJ->{'display_id'} if $OBJ->{'display_id'};
        push @external, qq(<span class="small">$description</span>);
	my $external = join "<br />\n          ", @external;

        $html .= qq(
        <td>$orthologue_desc</td>
        <td>$orthologue_dnds_ratio</td>
        <td>
	  $gene_stable_id_link$percent_ids$target_links
	</td>
        <td>
	  $external
	</td>
      </tr>);
      }
    }
    $html .= '
    </table>';

    $html = sprintf q(
    <p>
      The following gene(s) have been identified as putative
      orthologues:
    </p>
    <p>(N.B. The type "<b>paralogue (between species)</b>" is not a definitive ortholog prediction, but it is provided as the closest prediction in this gene tree. Please view the <a href="%s">gene tree info</a> to see more.)</p>%s),
      $gene->_url({'action'=>'Compara_Tree'}), $html;
    if( $ALIGNVIEW && keys %orthologue_list ) {
      my $url = $gene->_url({ 'action' => 'Compara_Ortholog/Alignment' });
      $html .= qq(
    <p><a href="$url">View sequence alignments of all homologues</a>.</p>);
    }
    if( $orthologues_skipped_count ) {
      $html .= $self->_warning( 'Orthologues hidden by configuration', sprintf '
  <p>
    %d orthologues not shown in the table above from the following species: %s. Use the "<strong>Configure this page</strong>" on the left to show them.
  </p>%s', $orthologues_skipped_count, join (', ', sort map { "<i>$_</i>" } @orthologues_skipped_species )
      )
    }
  } else {
    $html .= qq(
    <p>No orthologues have been identified for this gene</p>);
  }

  return $html;
}

1;


