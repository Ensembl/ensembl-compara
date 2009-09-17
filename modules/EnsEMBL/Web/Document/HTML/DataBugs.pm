# $Id$

package EnsEMBL::Web::Document::HTML::DataBugs;

### This module outputs a selection of news headlines for the home page, 
### based on the user's settings or a default list

use strict;
use warnings;

use EnsEMBL::Web::RegObj;
use EnsEMBL::Web::Data::Bug;
use EnsEMBL::Web::Data::Species;
use EnsEMBL::Web::Data::Release;

use base qw(EnsEMBL::Web::Root);


{

sub render {
  my $self = shift;

  my $species_defs = $ENSEMBL_WEB_REGISTRY->species_defs;
  my $user = $EnsEMBL::Web::RegObj::ENSEMBL_WEB_REGISTRY->get_user;
  my $filtered = 0;
  my $html;

  my $current_release_id = $species_defs->ENSEMBL_VERSION;
  my $yearago_release_id = $current_release_id - 5;
  my @releases;
  for ($yearago_release_id..$current_release_id) {
    my $r = EnsEMBL::Web::Data::Release->new($_);
    push @releases, $r if $r;
  }

  my %species_lookup; 
  my @all_species = EnsEMBL::Web::Data::Species->find_all;
  foreach my $sp (@all_species) {
    $species_lookup{$sp->species_id} = $sp->name;
  }

  foreach my $release (reverse @releases) {

    my $criteria = {'release' => $release->id};

    my @bugs = EnsEMBL::Web::Data::Bug->fetch_bugs($criteria);

    if (scalar(@bugs) > 0) {

      my $release_date = $self->pretty_date($release->date);
      $html .= '<h2>Known bugs in Release '.$release->id." ($release_date)</h2>\n";

      foreach my $bug (@bugs) {

        ## sort out species names
        my @species = $bug->species; 
        my (@sp_ids, $sp_id, $sp_name, $sp_count);
        if (!scalar(@species)) {
          $sp_name = 'all species';
        }
        elsif (scalar(@species) > 5) {
          $sp_name = 'multiple species';
        }
        else {
          my @names;
          foreach my $sp (@species) {
            if ($sp->common_name =~ /\./) {
              push @names, '<i>'.$sp->common_name.'</i>';
            }
            else {
              push @names, $sp->common_name;
            } 
          }
          $sp_name = join(', ', @names);
        }
## generate HTML
        $html .= sprintf(qq(
<h3>%s (%s)</h3>
<p>%s</p>
),
              $bug->title, $sp_name, $bug->content);

      }
    }
  }

  return $html;
}

}

1;
