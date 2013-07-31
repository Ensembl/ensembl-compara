package EnsEMBL::Web::Document::HTML::Movie;

### This module outputs the embedding code for a movie, based on user location

use strict;
use warnings;

use EnsEMBL::Web::DBSQL::WebsiteAdaptor;

use base qw(EnsEMBL::Web::Document::HTML);

sub render {
  my ($self, $movie) = @_;
  
  my $hub = $self->hub;

  $movie = shift @{EnsEMBL::Web::DBSQL::WebsiteAdaptor->new($hub)->fetch_help_by_ids([ $movie ]) || []} unless ref $movie; #if movie id is provided
  
  return unless $movie;

  my ($embed, $channel, $logo, $alt);
  if (($self->requesting_country || '') eq 'CN') {  ## Select YouKu for visitors within China
    $channel  = 'http://u.youku.com/Ensemblhelpdesk';
    $alt      = 'Youku &#20248;&#37239;&#32593; channel';
    if ($movie->{'youku_id'}) {
      $embed    = sprintf('<embed src="http://player.youku.com/player.php/sid/%s/v.swf" allowFullScreen="true" quality="high" width="640" height="480" align="middle" allowScriptAccess="always" type="application/x-shockwave-flash"></embed>', $movie->{'youku_id'});
      $logo     = $hub->species_defs->ENSEMBL_STATIC_SERVER.'/img/youku.png';
    }
  }
  else {
    $embed    = sprintf('<iframe width="640" height="480" src="http://www.youtube-nocookie.com/embed/%s" frameborder="0" allowfullscreen="allowfullscreen" style="margin:0 auto"></iframe>', $movie->{'youtube_id'});
    $channel  = 'http://www.youtube.com/user/EnsemblHelpdesk';
    $logo     = $hub->species_defs->ENSEMBL_STATIC_SERVER.'/img/youtube.png';
    $alt      = 'YouTube channel';
  }

  return sprintf '<p>%s</p><p><a href="%s"><img alt="%s" src="%s" /></a></p>', $embed, $channel, $alt, $logo;
}

1;
