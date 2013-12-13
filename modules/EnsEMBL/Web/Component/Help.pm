=head1 LICENSE

Copyright [1999-2013] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Component::Help;

use strict;

use EnsEMBL::Web::Document::HTML::Movie;

use base qw( EnsEMBL::Web::Component);

sub embed_movie {
  my ($self, $movie) = @_;

  my $movie_html = EnsEMBL::Web::Document::HTML::Movie->new($self->hub)->render($movie);

  return sprintf '<h3>%s</h3>%s', $movie->{'title'}, $movie_html if $movie_html;

  return '<p>Sorry, this tutorial has not yet been added to our channel.</p>';
}

sub parse_help_html {
  ## Parses help content looking for embedded movie and images placeholders
  my ($self, $content, $adaptor) = @_;

  my $sd      = $self->hub->species_defs;
  my $img_url = $sd->ENSEMBL_STATIC_SERVER.$sd->ENSEMBL_HELP_IMAGE_ROOT;
  my $html;

  foreach my $line (split '\n', $content) {

    if ($line =~ /\[\[MOVIE::(\d+)/i) {
      $line = $self->embed_movie(@{$adaptor->fetch_help_by_ids([$1]) || []});
    }

    while ($line =~ /\[\[IMAGE::([^\s]+)\s*([^\]]+)?\s*\]\]/ig) {
      substr $line, $-[0], $+[0] - $-[0], qq(<img src="$img_url$1" alt="" $2 \/>); # replace square bracket tag with actual image
    }

    $html .= $line;
  }

  return $html;
}

sub help_feedback {
  my ($self, $id, %args) = @_;
  return ''; ## FIXME - this needs to be reenabled when we have time
  
  my $html = qq{
    <div style="text-align:right;margin-right:2em;">
      <form id="help_feedback_$id" class="std check _check" action="/Help/Feedback" method="get">
        <strong>Was this helpful?</strong>
        <input type="radio" class="autosubmit" name="help_feedback" value="yes" /><label>Yes</label>
        <input type="radio" class="autosubmit" name="help_feedback" value="no" /><label>No</label>
        <input type="hidden" name="record_id" value="$id" />
  };
  
  while (my ($k, $v) = each (%args)) {
    $html .= qq{
        <input type="hidden" name="$k" value="$v" />};
  }
  
  $html .= '
      </form>
    </div>';
  
  return $html;
}

1;
