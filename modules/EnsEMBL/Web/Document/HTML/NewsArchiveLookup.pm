package EnsEMBL::Web::Document::HTML::NewsArchiveLookup;

### This module outputs a form to select a news archive (Document::HTML::NewsArchive), 

use strict;
use warnings;
no warnings 'uninitialized';

use EnsEMBL::Web::RegObj;
use EnsEMBL::Web::Data::Release;

use base qw(EnsEMBL::Web::Document::HTML);

sub render {
  my $self = shift;
  my $html;
  
  my $species_defs = $ENSEMBL_WEB_REGISTRY->species_defs;
  my $sitename = $species_defs->ENSEMBL_SITETYPE;
  
  ## Form for selecting other releases
  my @releases = EnsEMBL::Web::Data::Release->find_all;
  if (@releases) {
    $html .= qq(
<form action="/info/website/news/archive.html" method="get">
<select name="id">);
    my @release_options;
    foreach my $r (sort {$b->id <=> $a->id} @releases) {
      next if $r->id > $species_defs->ENSEMBL_VERSION; ## Sanity check - mainly for dev sites!
      my $date = $self->pretty_date($r->date, 'short');
      next if $r->id == $species_defs->ENSEMBL_VERSION;
      $html .= '<option value="'.$r->id.'"';
      $html .= ' selected="selected"' if $r->id == $species_defs->ENSEMBL_VERSION;
      $html .= sprintf '>Release %s (%s)</option>', $r->number, $date;
    }
    $html .= qq(
</select> <input type="submit" name="submit" value="Go">
</form>
    );
  }

  return $html;
}


1;
