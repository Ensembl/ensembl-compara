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

package EnsEMBL::Web::Component::Help::Results;

use strict;
use warnings;
no warnings "uninitialized";

use EnsEMBL::Web::DBSQL::WebsiteAdaptor;

use base qw(EnsEMBL::Web::Component::Help);

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  0 );
  $self->configurable( 0 );
}

sub content {
  my $self = shift;
  my $hub = $self->hub;

  my $html = qq(<h2>Search Results</h2>);
  my @results = $hub->param('result');

  if (scalar(@results) && $results[0]) {

    my %header = (
      'faq'       =>  'Frequently Asked Questions',
      'glossary'  =>  'Glossary',
      'movie'     =>  'Video Tutorials',
      'view'      =>  'Page Help',
    );

    my $adaptor = EnsEMBL::Web::DBSQL::WebsiteAdaptor->new($self->hub);
    my @records = @{$adaptor->fetch_help_by_ids(\@results)};

    ## Now display results
    my ($title, $text); 
    my $prev_type = '';
    foreach my $help (@records) {
      if ($help->{'type'} ne $prev_type) {
        $html .= '<h3>'.$header{$help->{'type'}}."</h3>\n";
      }

      if ($help->{'type'} eq 'faq') {
        $title  = '<h4><strong>'.$help->{'question'}.'</strong></h4>';
        $text   = $self->wrap_in_p_tag($help->{'answer'});

        ## Add feedback form
        $text  .= $self->help_feedback($help->{'id'}, return_url => '/Help/Results', type => $help->{'type'});
      }
      elsif ($help->{'type'} eq 'glossary') {
        $title  = '<p><strong>'.$help->{'word'}.'</strong>: ';
        $text   = $help->{'meaning'}.'</p>';
      }
      elsif ($help->{'type'} eq 'view') {
        $title = '<h4>'.$help->{'ensembl_object'}.'/'.$help->{'ensembl_action'}.'</h4>';
        ## These entries can be quite long - strip the HTML and show just a short section
        (my $content = $help->{'content'}) =~ s/<[^>]*>//gs;
        $text = substr($content, 0, 500);
        $text .= ' <a href="/Help/View?id='.$help->{'id'}.'">More...</a>';
      }
      elsif ($help->{'type'} eq 'movie') {
        $title  = '<p><strong><a href="/Help/Movie?id='.$help->{'id'}.'" class="popup">'.$help->{'title'}.'</a></strong></p>';
      }
      if ($hub->param('hilite') eq 'yes') {
        $title  = $self->_keyword_hilite($title);
        $text   = $self->_keyword_hilite($text);
      }

      $html .= qq($title\n$text); 

      $prev_type = $help->{'type'};
    }
  } 
  else {
    $html = qq(<p>Sorry, no results were found in the help database matching your query.</p>
<ul>
<li><a href="/Help/Search" class="popup">Search again</a></li>
<li><a href="/info/" class="cp-external">Browse non-searchable pages</a></li>
</ul>);
  }

  return $html;
}

sub _keyword_hilite {
  ## @private
  ## Highlights the search keyword(s) in the text, omitting HTML tag contents
  my ($self, $content)  = @_;
  my $keyword           = $self->hub->param('string');

  $content =~ s/($keyword)(?![^<]*?>)/<span class="hilite">$1<\/span>/img if $keyword;

  return $content;
}

1;
