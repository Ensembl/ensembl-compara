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

package EnsEMBL::Web::Component::Help;

use strict;

use List::Util qw(first);

use EnsEMBL::Web::Document::HTML::Movie;
use EnsEMBL::Web::Utils::FileHandler qw(file_get_contents);
use EnsEMBL::Web::Exceptions;

use base qw( EnsEMBL::Web::Component);

sub embed_movie {
  my ($self, $movie) = @_;

  my $movie_html = EnsEMBL::Web::Document::HTML::Movie->new($self->hub)->render($movie);

  return $movie_html ? sprintf('<h3>%s</h3>%s', $movie->{'title'}, $movie_html) : '';
}

sub parse_help_html {
  ## Parses help content looking for embedded movie and images placeholders
  my ($self, $content, $adaptor) = @_;

  my $sd      = $self->hub->species_defs;
  my $img_url = $sd->ENSEMBL_STATIC_SERVER.$sd->ENSEMBL_HELP_IMAGE_ROOT;
  my @html;

  foreach my $line (split '\n', $content) {

    while ($line =~ /\[\[IMAGE::(\w+\.\w{3,4})\s*([^\]]+)?\s*\]\]/ig) {
      substr $line, $-[0], $+[0] - $-[0], qq(<img src="$img_url$1" alt="" $2 \/>); # replace square bracket tag with actual image
    }

    if ($line =~ /\[\[MOVIE::(\d+)\]\]/i) {
      substr $line, $-[0], $+[0] - $-[0], $self->embed_movie(@{$adaptor->fetch_help_by_ids([$1]) || []});
    } elsif ($line =~ /\[\[HTML::(.+)\]\]/) {
      substr $line, $-[0], $+[0] - $-[0],  $self->embed_html_file($1, $adaptor);
    }

    push @html, $line;
  }

  if (scalar @html) {
    return join "\n", @html;
  }
  else {
    return '<p>Sorry, this tutorial is not currently available.</p>';
  }
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

sub embed_html_file {
  my ($self, $file_name, $adaptor) = @_;

  if (!$self->{'_htdocs'}) {
    my $sd = $self->hub->species_defs;
    $self->{'_htdocs'} = [ map "$_/htdocs", grep(!m/\:\:/, @{$sd->ENSEMBL_PLUGINS}), $sd->ENSEMBL_WEBROOT ];
  }

  my $file_path = first { -e $_ } map "$_$file_name", @{$self->{'_htdocs'}};

  return "<p><i>Error: File $file_name not found.</i></p>" unless $file_path;

  my $file  = $self->parse_help_html(file_get_contents($file_path) =~ s/^(.+)<\s*body\s*>//sr =~ s/<\s*\/\s*body\s*>(.+)$//sr, $adaptor); # this will parse any tags in the html doc itself
  my $div   = $self->dom->create_element('div');

  my @replacements;

  try {
    while ($file =~ /(<a\s+[^>]+>)/g) {
      $div->inner_HTML("$1</a>", 1);

      my $link  = $div->first_child;
      my $href  = $link->get_attribute('href');

      unshift @replacements, { 'offset' => $-[1], 'length' => $+[1] - $-[1], 'link' => $link };

      if ($href !~ /^(\/|#)/) {
        if ($href =~ /^(ht|f)tp(s)?:\/\//) {
          $link->set_attribute('rel', 'external') unless $link->get_attribute('rel');
        } else {
          my @relative_path = split /\//, $href;
          my @absolute_path = split /\//, $file_name;
          pop @absolute_path;                                                           # remove the actual file name from the path
          shift @relative_path and pop @absolute_path while $relative_path[0] eq '..';  # adjust the path considering the '..' to step down one level
          $link->set_attribute('href', join '/', @absolute_path, @relative_path);       # change the href now to the new absolute path
        }
      } elsif ($href =~ /^$file_name(#.+)/) {
        $link->set_attribute('href', $1);
      }
    }
  } catch {
    $file = undef;
  };

  substr $file, $_->{'offset'}, $_->{'length'}, $_->{'link'}->render =~ s/<[^<]+>$//r for @replacements; # render return closing tag too - remove the closing tag before replacing the link

  return defined $file ? $file : "<p><i>Error: File $file_name contains one or more invalid links.</i></p>";
}

1;
