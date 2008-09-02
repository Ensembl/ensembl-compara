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
        <th>Gene identifier</th>
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
      $html .= sprintf( qq(
        <tr>
          <th rowspan="$rowspan"><em>%s</em></th>), $species );
      my $start = '';
      my $mcv_species = $multicv_link;
      foreach my $stable_id (sort keys %{$orthologue_list{$species}}) {
        my $OBJ = $orthologue_list{$species}{$stable_id};
        $html .= $start;
        $start = qq(
        <tr>);
        $matching_orthologues = 1;
        my $description = $OBJ->{'description'};
           $description = "No description" if $description eq "NULL";
        my $orthologue_desc = $orthologue_map{ $OBJ->{'homology_desc'} } || $OBJ->{'homology_desc'};
        my $orthologue_dnds_ratio = $OBJ->{'homology_dnds_ratio'};
           $orthologue_dnds_ratio = '&nbsp;' unless (defined $orthologue_dnds_ratio);
        my ($last_col, $EXTRA2);
        if(exists( $OBJ->{'display_id'} )) {
          (my $spp = $OBJ->{'spp'}) =~ tr/ /_/ ;
          my $EXTRA = qq(<span class="small">[<a href="$multicv_link;s1=$spp;g1=$stable_id">MultiContigView</a>]</span>);
          if( $orthologue_desc ne 'DWGA' ) {
            $EXTRA .= qq(&nbsp;<span class="small">[<a href="/@{[$gene->species]}/Gene/HomologAlignment?g=$STABLE_ID;g1=$stable_id">Align</a>]</span> );
            $EXTRA2 = qq(<br /><span class="small">[Target &#37id: $OBJ->{'target_perc_id'}; Query &#37id: $OBJ->{'query_perc_id'}]</span>);
            $ALIGNVIEW = 1;
          }
          $mcv_species .= ";s$C_species=$spp;g$C_species=$stable_id";
          $FULL_URL    .= ";s$C=$spp;g$C=$stable_id";
          $C_species++;
          $C++;
          my $link = qq(/$spp/Gene/Summary?g=$stable_id;db=$db);
          if( $description =~ s/\[\w+:(\w+)\;\w+:(\w+)\]//g ) {
            my ($edb, $acc) = ($1, $2);
            if( $acc ) {
              $description .= "[".$gene->get_ExtURL_link("Source: $edb ($acc)", $edb, $acc)."]";
            }
          }
          $last_col = qq(<a href="$link">$stable_id</a> (@{[$OBJ->{'display_id'}]}) $EXTRA<br />).
                    qq(<span class="small">$description</span> $EXTRA2);
        } 
        else {
          $last_col = qq($stable_id<br /><span class="small">$description</span> $EXTRA2);
        }
        $html .= sprintf( qq(
            <td>$orthologue_desc</td>
            <td>$orthologue_dnds_ratio</td>
            <td>$last_col</td>
          </tr>));
      }
      if( $rowspan > 1) {
        $html .= qq(<tr><td>&nbsp;</td><td>&nbsp;</td><td><a href="$mcv_species">MultiContigView showing all $species orthologues</a></td></tr>);
      }
    }
    $html .= qq(\n      </table>);
    if( $ALIGNVIEW &&  keys %orthologue_list ) {
      $html .= qq(\n      <p><a href="/@{[$gene->species]}/Gene/HomologAlignment?g=$STABLE_ID">View sequence alignments of all homologues</a>.</p>);
    }
  }
  else {
    $html .= qq(<p>No orthologues have been identified for this gene</p>);
  }

  return $html;
}
1;

