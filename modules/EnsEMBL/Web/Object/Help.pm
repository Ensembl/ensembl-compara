package EnsEMBL::Web::Object::Help;

use strict;
use warnings;
no warnings "uninitialized";
use CGI qw(unescape);

use EnsEMBL::Web::Object;
use EnsEMBL::Web::Data::Article;
use EnsEMBL::Web::Data::Category;
use EnsEMBL::Web::Data::View;
use EnsEMBL::Web::Data::Glossary;

use Mail::Mailer;
use Data::Dumper;

our @ISA = qw(EnsEMBL::Web::Object);

our $SPAM_THRESHOLD_PARAMETER = 60;

sub adaptor     { return $_[0]->Obj->{'adaptor'}; }
sub modular     { return $_[0]->Obj->{'modular'}; }

sub send_email {
  my $self = shift;
  my @mail_attributes = ();
  my @T = localtime();
  my $date = sprintf "%04d-%02d-%02d %02d:%02d:%02d", $T[5]+1900, $T[4]+1, $T[3], $T[2], $T[1], $T[0];
  my $email = $self->param('email');
  ## Do some email address sanitation!
  $email =~ s/"//g;
  $email =~ s/''/'/g;
  my $server = $self->species_defs->ENSEMBL_SERVERNAME;
  my $url = CGI::unescape($self->param('ref'));
  push @mail_attributes, (
    [ 'Date',         $date ],
    [ 'Name',         $self->param('name') ],
    [ 'Email',        $email ],
    [ 'Referrer',     $url ],
    [ 'Last Keyword', $self->param('kw')||'-none-' ],
    [ 'User agent',   $ENV{'HTTP_USER_AGENT'}],
  );
  my $comments = $self->param('comments');
## HACK OUT BLOG SPAM!
  my $recipient = $self->species_defs->ENSEMBL_HELPDESK_EMAIL;

  (my $check = $comments) =~ s/<a\s+href=".*?"\s*>.*?<\/a>//smg;
  $check =~ s/\[url=.*?\].*?\[\/url\]//smg;
  $check =~s/\s+//gsm;
  if( $check eq '' || length($check)<length($comments)/$SPAM_THRESHOLD_PARAMETER ) {
    warn "MAIL FILTERED DUE TO BLOG SPAM.....";
    return 1;
  } 
  my $message = "Support question from $server\n\n";
  $message .= join "\n", map {sprintf("%-16.16s %s","$_->[0]:",$_->[1])} @mail_attributes;
  $message .= "\n\nComments:\n\n@{[$self->param('comments')]}\n\n";
  my $mailer = new Mail::Mailer 'smtp', Server => "localhost";
  my $sitetype = $self->species_defs->ENSEMBL_SITETYPE;
  my $sitename = $sitetype eq 'EnsEMBL' ? 'Ensembl' : $sitetype;
  my $subject = $self->param('category') || "$sitename Helpdesk";
  $subject .= " - $server";
  $mailer->open({ 'To' => $recipient, 'Subject' => $subject, 'From' => $self->param('email') });
  print $mailer $message;
  $mailer->close();
  return 1;
}

sub search {
  ### a
  ### Returns:
  my $self = shift;

  my $keywords    = $self->param( 'kw' );

  ## Switch to this once modular articles are available
  #my $modular     = $self->modular;
  my $modular     = 0;

  my $method = 'fetch_scores_by_string';
  if (!$modular) {
    $method = 'search_articles';
  }

  ## get list of help articles by appropriate method
  $self->{'data'}{'_results'} = EnsEMBL::Web::Data::Article->$method( $keywords );
  return $self->results;
}

sub results :lvalue { $_[0]->{'data'}{'_results'}; }

sub records {
  my ($self, $criteria) = @_;

  $self->{'records'} = [ EnsEMBL::Web::Data::View->find_all($criteria) ]
    unless $self->{'records'};

  return $self->{'records'};
}


sub views {
  my $self = shift;
  ## TODO: clean up entire help system
  #my $articles = [];

  my $params = {status => 'in_use'};
  $params->{keyword} = $self->param('kw')
    if $self->param('kw');

  #my $modular = $self->modular;
  my $modular = 0;
  ## Check to see if there are any records of type 'view'
  if ($modular) {
    $params->{type} = 'view';
    $params->{help_record_id} = $self->param('id');
    ## TODO: clean up entire help system
    #$articles = $self->records($params);

    delete $params->{type}; ## remove type parameter since it doesn't exist in old table
  } elsif ($self->param('id')) {
    $params->{article_id} = $self->param('id');
  }

  ## Default help
  if (!$self->param('id') && !$self->param('kw')) {
    $params->{keyword} = 'helpview';
  }
    
  ## Check old database and convert to records
  ## NB - convert to else block once EnsEMBL is fully migrated?
  my @articles = EnsEMBL::Web::Data::Article->search($params);

  return @articles;
}

sub index { 
  my $self = shift;
  return EnsEMBL::Web::Data::Article->fetch_index_list('live');
}

sub glossary {
  my $self = shift;
  if ($self->modular) {
    return $self->records({type => 'glossary', status => 'live'});
  } else {
    ## Fake records!

    my $glossary = EnsEMBL::Web::Data::Glossary->search(
      {status => 'live'},
      {
        order_by => 'word ASC',
      }
    );

    return $glossary;
  }
}

sub movie_list {
  my $self = shift;
  return $self->records({type => 'movie', status => 'live'});
}

sub movie {
  my $self = shift;
  my $records = $self->records({help_record_id => $self->param('id')});
  return $records->[0];
}


1;
