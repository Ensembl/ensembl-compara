package EnsEMBL::Web::Document::HTML::MovieList;

### This module outputs a selection of news headlines for the home page, 
### based on the user's settings or a default list

use strict;
use warnings;

use EnsEMBL::Web::RegObj;
use EnsEMBL::Web::Data::Movie;
use EnsEMBL::Web::Document::SpreadSheet;

use base qw(EnsEMBL::Web::Root);


{

sub render {
  my $self = shift;

  my $html;
  my @movies = sort {
                $a->list_position <=> $b->list_position
                || $a->title cmp $b->title
                } EnsEMBL::Web::Data::Movie->search({'status'=>'live'});

  $html .= qq(<p class="space-below">The tutorials listed below are Flash animations of some of our training presentations. We are gradually adding to the list, so please check back regularly.</p>
<p>Note that we are now hosting all our tutorials on <a href="http://www.youtube.com/user/EnsemblHelpdesk">YouTube</a> 
for ease of maintenance</a>. If you are unable to access YouTube, please accept our apologies 
- a selection of tutorials is available on the 
<a href="http://www.ebi.ac.uk/2can/evideos/index.html">EBI E-Video website</a>);

  my $table = EnsEMBL::Web::Document::SpreadSheet->new();

  $table->add_columns(
      {'key' => "title", 'title' => 'Title', 'width' => '60%', 'align' => 'left' },
      {'key' => "mins", 'title' => 'Running time (minutes)', 'width' => '20%', 'align' => 'left' },
  );

  foreach my $movie (@movies) {
    next unless $movie->url;
    my $title_link = sprintf(qq(<a href="%s" rel="external">%s</a>\n), $movie->url, $movie->title);
    $table->add_row( { 'title'  => $title_link, 'mins' => $movie->length } );

  }
  $html .= $table->render;

  return $html;
}

}

1;
