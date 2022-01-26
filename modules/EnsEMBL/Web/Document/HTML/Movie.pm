=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2022] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

package EnsEMBL::Web::Document::HTML::Movie;

### This module outputs the embedding code for a movie, based on user location

use strict;
use warnings;

use EnsEMBL::Web::DBSQL::WebsiteAdaptor;

use base qw(EnsEMBL::Web::Document::HTML);

sub render {
  my ($self, $movie) = @_;

  return unless $movie;

  my $hub = $self->hub;

  if (!ref $movie) {
    my ($movie_id, @movie_params) = split /\s+/, $movie;
    $movie = shift @{EnsEMBL::Web::DBSQL::WebsiteAdaptor->new($hub)->fetch_help_by_ids([ $movie_id ]) || []};
  }

  return unless $movie;

  my ($embed, $channel, $logo, $alt);
  if (($self->requesting_country || '') eq 'CN') {  ## Select YouKu for visitors within China
    $channel  = 'http://u.youku.com/Ensemblhelpdesk';
    $alt      = 'Youku &#20248;&#37239;&#32593; channel';
    if ($movie->{'youku_id'}) {
      $embed    = sprintf('<embed src="https://player.youku.com/player.php/sid/%s/v.swf" allowFullScreen="true" quality="high" width="640" height="480" align="middle" allowScriptAccess="always" type="application/x-shockwave-flash"></embed>', $movie->{'youku_id'});
      $logo     = $hub->species_defs->ENSEMBL_STATIC_SERVER.'/img/youku.png';
    }
  }
  else {
    $embed    = sprintf('<iframe width="640" height="480" src="https://www.youtube.com/embed/%s" frameborder="0" allowfullscreen="allowfullscreen" style="margin:0 auto"></iframe>', $movie->{'youtube_id'});
    $channel  = 'http://www.youtube.com/user/EnsemblHelpdesk';
    $logo     = $hub->species_defs->ENSEMBL_STATIC_SERVER.'/img/youtube.png';
    $alt      = 'YouTube channel';
  }

  return sprintf '<p>%s</p><p><a href="%s"><img alt="%s" src="%s" /></a></p>', $embed, $channel, $alt, $logo;
}

1;
