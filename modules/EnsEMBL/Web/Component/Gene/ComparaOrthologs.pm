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
  my %orthologue_list = %{$orthologue};

  if (keys %orthologue_list) {
# Find the selected method_link_set
    $html = qq(
    <p>
      The following gene(s) have been identified as putative
      orthologues:
    </p>
    <p>(N.B. If you don't find a homologue here, it may be a 'between-species paralogue'.
Please view the <a href="/#.$gene->species.'/genetreeview?gene='.$gene->stable_id.qq#">gene tree info</a> or export between-species
paralogues with BioMart to see more.)</p>
    <table width="100%" cellpadding="4">
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
    my $multicv_link = sprintf "/%s/multicontigview?gene=%s;context=10000", $gene->species, $gene->stable_id;
    my $FULL_URL     = $multicv_link;

    foreach my $species (sort keys %orthologue_list) {
      my $C_species = 1;
      my $rowspan = scalar(keys %{$orthologue_list{$species}});
      $rowspan++ if $rowspan > 1;
      (my $spp = $species) =~ tr/ /_/ ;
      my $common_name = $gene->species_defs->other_species($spp,'SPECIES_COMMON_NAME');
      unless($common_name){
        my ($OBJ) = values %{$orthologue_list{$species}};
        $common_name = $OBJ->{'sp_common'};
      }
      $html .= sprintf( qq(
      <tr>
        <th rowspan="$rowspan">%s<em>%s</em></th>), ucfirst( $common_name ? "$common_name<br />":"" ),$species );
      my $start = '';
      my $mcv_species = $multicv_link;
      foreach my $stable_id (sort keys %{$orthologue_list{$species}}) {
        my $OBJ = $orthologue_list{$species}{$stable_id};
        $matching_orthologues = 1;
        $html .= $start;
        $start = qq(
      <tr>);
## (Column 2) Add in Orthologue description...
        my $orthologue_desc = $orthologue_map{ $OBJ->{'homology_desc'} } || $OBJ->{'homology_desc'};
## (Column 3) Add in the dN/dS ratio...
        my $orthologue_dnds_ratio = $OBJ->{'homology_dnds_ratio'};
           $orthologue_dnds_ratio = '&nbsp;' unless defined $orthologue_dnds_ratio;
## (Column 4) Sort out (1) the link to the other species
##                     (2) information about %ids
##                     (3) links to multi-contigview and align view
        (my $spp = $OBJ->{'spp'}) =~ tr/ /_/ ;
	my $link = qq(/$spp/Gene/Summary?g=$stable_id;db=$db);   ### USE _url
	my $gene_stable_id_link = sprintf '<a href="%s">%s</a>', $link, $stable_id;
        my $percent_ids  = '';
        my $target_links = qq(<br />
          <span class="small">[<a href="$multicv_link;s1=$spp;g1=$stable_id">MultiContigView</a>]</span>);
          $mcv_species .= ";s$C_species=$spp;g$C_species=$stable_id";
          $FULL_URL    .= ";s$C=$spp;g$C=$stable_id";
          $C_species++;
          $C++;
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
      if( $rowspan > 1) {
        $html .= qq(
      <tr>
        <td colspan="2">&nbsp;</td>
	<td colspan="2"><a href="$mcv_species">MultiContigView showing all $species orthologues</a></td>
      </tr>);
      }
    }
    $html .= '
    </table>';
    if( $ALIGNVIEW && keys %orthologue_list ) {
      my $url = $gene->_url({ 'action' => 'Compara_Ortholog/Alignment' });
      $html .= qq(
    <p><a href="$url">View sequence alignments of all homologues</a>.</p>);
    }
  }
  else {
    $html .= qq(
    <p>No orthologues have been identified for this gene</p>);
  }

  return $html;
}
1;

