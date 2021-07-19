=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2021] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Document::HTML::MovieList;

### This module outputs a selection of news headlines for the home page, 
### based on the user's settings or a default list

use strict;

use EnsEMBL::Web::DBSQL::WebsiteAdaptor;
use EnsEMBL::Web::Document::Table;

use base qw(EnsEMBL::Web::Document::HTML);

sub render {
  my $self    = shift;
  my $hub     = $self->hub;
  my $adaptor = EnsEMBL::Web::DBSQL::WebsiteAdaptor->new($hub);
  
  my $table = EnsEMBL::Web::Document::Table->new([
    { key => 'title', title => 'Title',                  width => '60%', align => 'left' },
    { key => 'mins',  title => 'Running time (minutes)', width => '20%', align => 'left' },
  ]);

  $table->add_row({
    'title' => sprintf('<a href="%s" class="popup">%s</a>', $hub->url({'species' => 'Multi', 'type' => 'Help', 'action' => 'Movie', 'id' => $_->{'id'}}), $_->{'title'}),
    'mins'  => $_->{'length'}
  }) for grep $_->{'youtube_id'}, @{$adaptor->fetch_movies};
  
  return sprintf(qq{
    <p class="space-below">The tutorials listed below are Flash animations of some of our training presentations. We are gradually adding to the list, so please check back regularly.</p>
    <p>
      <a href="http://www.youtube.com/user/EnsemblHelpdesk"><img src="%s/img/youtube.png" height="54" width="85" alt="YouTube" title="Youtube" style="float:left;padding:0px 10px 10px 0px;" /></a>
      Note that we are now hosting all our tutorials on <a href="http://www.youtube.com/user/EnsemblHelpdesk">YouTube</a> 
      (and <a href="http://u.youku.com/Ensemblhelpdesk" title="YouKu">&#20248;&#37239;&#32593;</a> for users in China) for ease of maintenance. 
    </p>
    %s
  }, $hub->species_defs->ENSEMBL_STATIC_SERVER, $table->render);
}

1;
