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

package EnsEMBL::Web::Component::Help::Movie;

use strict;

use EnsEMBL::Web::DBSQL::WebsiteAdaptor;
use EnsEMBL::Web::Document::HTML::MovieList;

use base qw(EnsEMBL::Web::Component::Help);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(0);
  $self->configurable(0);
}

sub content {
  my $self    = shift;
  my $hub     = $self->hub;
  my $adaptor = EnsEMBL::Web::DBSQL::WebsiteAdaptor->new($hub);
  my @ids     = $hub->param('id') || $hub->param('feedback');
  my $html;
  my @movies;
  
  if (scalar @ids && $ids[0]) {
    @movies = @{$adaptor->fetch_help_by_ids(\@ids)};
  } else {
    @movies = @{$adaptor->fetch_movies};
  }

  if (scalar @movies == 1 && $movies[0]) {
    my $movie = $movies[0];
    
    $html .= $self->embed_movie($movie);

    ## Feedback
    if ($hub->param('feedback')) {
      $html .= qq{<p>Thank you for your feedback.</p>};
    } else {
      ## Feedback form
      $html .= $self->help_feedback($movie->{'id'}, return_url => '/Help/Movie', type => 'Movie');

      ## Link to movie-specific feedback form
      $html .= qq(<p>If you have problems viewing this movie, we would be grateful if you could <a href="/Help/MovieFeedback?title=$movie->{'title'}" class="popup">provide feedback</a> that will help us improve our service.</p><p>Thank you.</p>);
    }

  } elsif (scalar @movies > 0 && $movies[0]) {
    $html .= EnsEMBL::Web::Document::HTML::MovieList->new($self->hub)->render;
  } else {
    $html .= '<p>Sorry, we have no video tutorials at the moment, as they are being updated for the new site design. Please try again after the next release.</p>';
  }

  return $html;
}

1;
