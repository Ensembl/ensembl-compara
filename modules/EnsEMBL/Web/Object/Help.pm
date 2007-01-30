package EnsEMBL::Web::Object::Help;

use strict;
use warnings;
no warnings "uninitialized";
use CGI qw(escape);

use EnsEMBL::Web::Object;
our @ISA = qw(EnsEMBL::Web::Object);
use Mail::Mailer;

sub adaptor     { return $_[0]->Obj->{'adaptor'}; }
sub modular     { return $_[0]->Obj->{'modular'};   }

sub send_email {
  my $self = shift;
  my @mail_attributes = ();
  my @T = localtime();
  my $date = sprintf "%04d-%02d-%02d %02d:%02d:%02d", $T[5]+1900, $T[4]+1, $T[3], $T[2], $T[1], $T[0];
  push @mail_attributes,
    [ 'Date',         $date ],
    [ 'Name',         $self->param('name') ],
    [ 'Email',        $self->param('email') ],
    [ 'Referrer',     $self->referer ],
    [ 'Last Keyword', $self->param('kw')||'-none-' ],
    [ 'Problem',      $self->param('category')],
    [ 'User agent',   $ENV{'HTTP_USER_AGENT'}],
    [ 'Request URI',  $ENV{'REQUEST_URI'}];
  my $message = '';
  $message .= join "\n", map {sprintf("%-16.16s %s","$_->[0]:",$_->[1])} @mail_attributes;
  $message .= "\n\nComments:\n\n@{[$self->param('comments')]}\n\n";
  my $mailer = new Mail::Mailer 'smtp', Server => "localhost";
  my $recipient = $self->species_defs->ENSEMBL_HELPDESK_EMAIL;
  my $sitetype = $self->species_defs->ENSEMBL_SITETYPE;
  my $sitename = $sitetype eq 'EnsEMBL' ? 'Ensembl' : $sitetype;
  $mailer->open({ 'To' => $recipient, 'Subject' => "$sitetype website Helpdesk", 'From' => $self->param('email') });
  print $mailer $message;
  $mailer->close();
  return 1;
}

## Methods needed for backwards compatibility

sub results {
  ### a
  ### Returns:
  my $self = shift;

  my $keywords    = $self->param( 'kw' );
  my $ids         = $self->param( 'ids' );
  my ($method_se, $method_kw, $method_id, $results);

  if ($self->modular) {
    $method_se = 'fetch_article_by_keyword';
    $method_kw = 'fetch_scores_by_string';
    $method_id = 'fetch_summaries_by_scores';
  }
  else {
    $method_se = 'fetch_all_by_keyword';
    $method_kw = 'fetch_all_by_string';
    $method_id = 'fetch_all_by_scores';
  }

  ## get list of help articles by appropriate method
  if( $self->param('se') ) {
    $results = $self->adaptor->$method_se( $keywords );
  }
  elsif ($self->param('kw')) {
    $results = $self->adaptor->$method_kw( $keywords );
  }
  elsif ( $self->param('results')) {
    ## messy, but makes sure we get the results in order!
    my $ids = [];
    my @articles = split('_', $self->param('results'));
    foreach my $article (@articles) {
      my @bits = split('-', $article);
      push(@$ids, {'id'=>$bits[0], 'score'=>$bits[1]});
    }
    $results = $self->adaptor->$method_id( $ids );
  }
  return $results;
}

sub index { 
  my $self = shift;
  my $index = $self->modular ? 'fetch_article_index' : 'fetch_index_list';
  return $self->adaptor->$index('live');
}

sub glossary {
  my $self = shift;
  $self->adaptor->fetch_glossary('live');
}

sub movie_list {
  my $self = shift;
  return $self->adaptor->fetch_movies('live');
}

sub movie {
  my $self = shift;
  return $self->adaptor->fetch_movie_by_id($self->param('movie'));
}


1;
