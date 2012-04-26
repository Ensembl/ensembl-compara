# $Id$

package EnsEMBL::Web::Document::HTML::MovieList;

### This module outputs a selection of news headlines for the home page, 
### based on the user's settings or a default list

use strict;

use EnsEMBL::Web::Hub;
use EnsEMBL::Web::DBSQL::WebsiteAdaptor;
use EnsEMBL::Web::Document::Table;

use base qw(EnsEMBL::Web::Document::HTML);

sub render {
  my $self    = shift;
  my $hub     = new EnsEMBL::Web::Hub;
  my $adaptor = new EnsEMBL::Web::DBSQL::WebsiteAdaptor($hub);
  
  my $table = new EnsEMBL::Web::Document::Table([
    { key => 'title', title => 'Title',                  width => '60%', align => 'left' },
    { key => 'mins',  title => 'Running time (minutes)', width => '20%', align => 'left' },
  ]);

  $table->add_row({ title => sprintf('<a href="/Help/Movie?id=%s" class="popup">%s</a>', $_->{'id'}, $_->{'title'}), mins => $_->{'length'} }) for grep $_->{'youtube_id'}, @{$adaptor->fetch_movies};
  
  return sprintf(qq{
    <p class="space-below">The tutorials listed below are Flash animations of some of our training presentations. We are gradually adding to the list, so please check back regularly.</p>
    <p>
      <a href="http://www.youtube.com/user/EnsemblHelpdesk"><img src="%s/img/youtube.png" height="54" width="85" alt="YouTube" title="Youtube" style="float:left;padding:0px 10px 10px 0px;" /></a>
      Note that we are now hosting all our tutorials on <a href="http://www.youtube.com/user/EnsemblHelpdesk">YouTube</a> 
      (and <a href="http://u.youku.com/Ensemblhelpdesk" title="YouKu">&#20248;&#37239;&#32593;</a> for users in China) for ease of maintenance. 
      A selection of tutorials is also available on the <a href="http://www.ebi.ac.uk/2can/evideos/index.html">EBI E-Video website</a>.
    </p>
    %s
  }, $hub->species_defs->ENSEMBL_STATIC_SERVER, $table->render);
}

1;
