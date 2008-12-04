package EnsEMBL::Web::Controller::Command::Help::DoSearch;

## Searches the help_record table in the ensembl_website  database 

use strict;
use warnings;

use Class::Std;
use EnsEMBL::Web::RegObj;
use EnsEMBL::Web::Data::Help;

use base 'EnsEMBL::Web::Controller::Command';

{

sub BUILD {
  my ($self, $ident, $args) = @_;
}

sub process {
  my $self = shift;
  my $cgi = $self->action->cgi;

  my $new_param;
  if ($cgi->param('hilite')) {
    $new_param->{'hilite'} = $cgi->param('hilite');
    $new_param->{'string'} = $cgi->param('string');
  }

  my $help = EnsEMBL::Web::Data::Help->new;
  my @results;
  my %matches = %{ $help->search({'string'=>$cgi->param('string')}) };
  if (keys %matches) {
    while (my ($k, $v) = each (%matches)) {
      push @results, $v.'_'.$k;
    }
  }
  $new_param->{'result'} = \@results;
  $new_param->{'_referer'} = $cgi->param('_referer');

  $self->ajax_redirect($self->ajax_url('/Help/Results', %$new_param));
}

}

1;
