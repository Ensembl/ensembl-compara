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
  my @movies = sort {$a->title cmp $b->title} EnsEMBL::Web::Data::Movie->find_all;

  $html .= qq(<p class="space-below">The tutorials listed below are Flash animations of some of our training presentations. We are gradually adding to the list, so please check back regularly.</p>
<p class="space-below">Please note that files can be large, so if you are on a dialup connection or a long way from the UK, playback may be jerky.</p>);

  my $table = EnsEMBL::Web::Document::SpreadSheet->new();

  $table->add_columns(
      {'key' => "title", 'title' => 'Title', 'width' => '60%', 'align' => 'left' },
      {'key' => "size", 'title' => 'File size (MB)', 'width' => '20%', 'align' => 'left' },
      {'key' => "mins", 'title' => 'Running time (minutes)', 'width' => '20%', 'align' => 'left' },
  );

  foreach my $movie (@movies) {

    my $title_link = sprintf(qq(<a href="/Help/Movie?id=%s;_referer=/info/website/tutorials/index.html" class="modal_link">%s</a>\n), $movie->help_record_id, $movie->title);
    $table->add_row( { 'title'  => $title_link, 'size' => $movie->filesize, 'mins' => $movie->length } );

  }
  $html .= $table->render;
  return $html;
}

}

1;
