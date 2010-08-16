package EnsEMBL::Web::Component::Help::View;

use strict;
use warnings;
no warnings "uninitialized";
use HTML::Entities qw(encode_entities);
use base qw(EnsEMBL::Web::Component::Help);

use EnsEMBL::Web::DBSQL::WebsiteAdaptor;
use EnsEMBL::Web::Component::Help::Movie;

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  0 );
  $self->configurable( 0 );
}

sub content {
  my $self = shift;
  my $hub = $self->hub;

  my $adaptor = EnsEMBL::Web::DBSQL::WebsiteAdaptor->new($hub);

  my $html;

  my @records = @{$adaptor->fetch_help_by_ids([$hub->param('id')])};
  
  if (@records) {
    my $help = $records[0];
    my $content = $help->{'content'};
    ### Parse help looking for embedded movie placeholders
    foreach my $line (split('\n', $content)) {
      if ($line =~ /\[\[movie=(\d+)/i) {
        my $movies = $adaptor->fetch_help_by_ids([$1]) || [];
        $line = EnsEMBL::Web::Component::Help::Movie::embed_movie($movies->[0]);
      }
      
      $html .= $line;
    }
  }

  return $html;
}

1;
