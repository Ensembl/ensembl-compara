package EnsEMBL::Web::Document::HTML::NewsArchiveLookup;

### This module outputs a form to select a news archive (Document::HTML::NewsArchive), 

use strict;
use warnings;
no warnings 'uninitialized';

use EnsEMBL::Web::Hub;
use EnsEMBL::Web::DBSQL::WebsiteAdaptor;

use base qw(EnsEMBL::Web::Document::HTML);

sub render {
  my $self = shift;
  my $html;
  
  my $hub = new EnsEMBL::Web::Hub;
  my $species_defs = $hub->species_defs;
  my $sitename = $species_defs->ENSEMBL_SITETYPE;
  
  ## Form for selecting other releases
  my $adaptor = EnsEMBL::Web::DBSQL::WebsiteAdaptor->new($hub);
  my @releases = $adaptor->fetch_releases;
  if (@releases) {
    $html .= qq(
<form action="/info/website/news/archive.html" method="get">
<select name="id">);
    my @release_options;
    foreach my $r (@releases) {
      next if $r->{'id'} > $species_defs->ENSEMBL_VERSION; ## Sanity check - mainly for dev sites!
      my $date = $self->pretty_date($r->date, 'short');
      next if $r->id == $species_defs->ENSEMBL_VERSION;
      $html .= '<option value="'.$r->{'id'}.'"';
      $html .= ' selected="selected"' if $r->{'id'} == $species_defs->ENSEMBL_VERSION;
      $html .= sprintf '>Release %s (%s)</option>', $r->{'id'}, $date;
    }
    $html .= qq(
</select> <input type="submit" name="submit" value="Go">
</form>
    );
  }

  return $html;
}


1;
