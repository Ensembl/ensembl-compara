package EnsEMBL::Web::Command::Help::DoSearch;

# Searches the help_record table in the ensembl_website database 

use strict;
use warnings;

use EnsEMBL::Web::DBSQL::WebsiteAdaptor;

use base qw(EnsEMBL::Web::Command);

sub process {
  my $self = shift;
  my $hub = $self->hub;

  my $adaptor = EnsEMBL::Web::DBSQL::WebsiteAdaptor->new($hub);
  my $ids = $adaptor->search_help($hub->param('string'));

  my $new_param = {
    'result' => $ids,
  };
  if ($hub->param('hilite')) {
    $new_param->{'hilite'} = $hub->param('hilite');
    $new_param->{'string'} = $hub->param('string');
  }

  $self->ajax_redirect('/Help/Results', $new_param);
}

1;
