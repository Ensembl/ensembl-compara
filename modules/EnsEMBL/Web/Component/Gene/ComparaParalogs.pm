package EnsEMBL::Web::Component::Gene::ComparaParalogs;

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
  my $gene   = $self->object;

## call table method here
  my $db              = $gene->get_db() ;
  my $paralogue = $gene->get_homology_matches('ENSEMBL_PARALOGUES', 'within_species_paralog');
  my $html;
  if (keys %{$paralogue}) {
    my %paralogue_list = %{$paralogue};
    $html = qq(
      <p>
        The following gene(s) have been identified as putative paralogues (within species):
      </p>
      <table>);
    $html .= qq(
      <tr>
        <th>Taxonomy Level</th><th>dN/dS</th><th>Gene identifier</th>
      </tr>);
    my %paralogue_map = qw(SEED BRH PIP RHS);

    my $STABLE_ID = $gene->stable_id; my $C = 1;
    my $FULL_URL  = qq(/@{[$gene->species]}/multicontigview?gene=$STABLE_ID);
    my $ALIGNVIEW = 0;
    my $EXTRA2;
    my $matching_paralogues = 0;
    foreach my $species (sort keys %paralogue_list){
      foreach my $stable_id (sort {$paralogue_list{$species}{$a}{'order'} <=> $paralogue_list{$species}{$b}{'order'}} keys %{$paralogue_list{$species}}){
        my $OBJ = $paralogue_list{$species}{$stable_id};
        my $matching_paralogues = 1;
        my $description = $OBJ->{'description'};
           $description = "No description" if $description eq "NULL";
        my $paralogue_desc = $paralogue_map{ $OBJ->{'homology_desc'} } || $OBJ->{'homology_desc'};
        my $paralogue_subtype = $OBJ->{'homology_subtype'};
           $paralogue_subtype = "&nbsp;" unless (defined $paralogue_subtype);
        my $paralogue_dnds_ratio = $OBJ->{'homology_dnds_ratio'};
        $paralogue_dnds_ratio = "&nbsp;" unless ( defined $paralogue_dnds_ratio);
        if($OBJ->{'display_id'}) {
          (my $spp = $OBJ->{'spp'}) =~ tr/ /_/ ;
          my $EXTRA = qq(<span class="small">[<a href="/@{[$gene->species]}/multicontigview?gene=$STABLE_ID;s1=$spp;g1=$stable_id;context=1000">MultiContigView</a>]</span>);
          if( $paralogue_desc ne 'DWGA' ) {
            $EXTRA .= qq(&nbsp;<span class="small">[<a href="/@{[$gene->species]}/Gene/HomologAlignment?g=$STABLE_ID;g1=$stable_id">Align</a>]</span>);
            $EXTRA2 = qq(<br /><span class="small">[Target &#37id: $OBJ->{'target_perc_id'}; Query &#37id: $OBJ->{'query_perc_id'}]</span>);
            $ALIGNVIEW = 1;
          }
          $FULL_URL .= ";s$C=$spp;g$C=$stable_id";$C++;
          my $link = qq(/$spp/geneview?gene=$stable_id;db=$db);
          if( $description =~ s/\[\w+:(\w+)\;\w+:(\w+)\]//g ) {
            my ($edb, $acc) = ($1, $2);
            if( $acc ) {
              $description .= "[".$gene->get_ExtURL_link("Source: $edb ($acc)", $edb, $acc)."]";
            }
          }
          $html .= qq(
        <tr>
          <td>$paralogue_subtype</td>
          <td> $paralogue_dnds_ratio</td>
          <td><a href="$link">$stable_id</a> (@{[ $OBJ->{'display_id'} ]}) $EXTRA<br />
            <span class="small">$description</span>$EXTRA2</td>
        </tr>);
        } else {
          $html .= qq(
        <tr>
          <td>$paralogue_subtype</td>
          <td>$stable_id <br /><span class="small">$description</span>$EXTRA2</td>
        </tr>);
        }
      }
    }
    $html .= qq(</table>);
    if( $ALIGNVIEW && keys %paralogue_list ) {
      $html .= qq(\n      <p><a href="/@{[$gene->species]}/Gene/HomologAlignment?g=$STABLE_ID">View sequence alignments of all homologues</a>.</p>);
    }
  }
  else {
    $html .= qq(<p>No paralogues have been identified for this gene</p>);
  }
  return $html;
}

1;

