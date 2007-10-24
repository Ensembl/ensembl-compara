package EnsEMBL::Web::Object::Help;

use strict;
use warnings;
no warnings "uninitialized";
use CGI qw(unescape);

use EnsEMBL::Web::Object;
use EnsEMBL::Web::Object::Data::Article;
use EnsEMBL::Web::Object::Data::Category;
use EnsEMBL::Web::Record::Help;
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
  $self->{'data'}{'_results'} = $self->adaptor->$method( $keywords );
  return $self->results;
}

sub results :lvalue { $_[0]->{'data'}{'_results'}; }

sub records {
  my ($self, $criteria) = @_;

  if (!$self->{'records'}) {
    my $records = [];
    my $result = $self->adaptor->fetch_records($criteria);
    foreach my $row (@$result) {
      my $r = EnsEMBL::Web::Record::Help->new(
        'id'          => $row->{'help_record_id'},
        'type'        => $row->{'type'},
        'keyword'     => $row->{'keyword'},
        'data'        => $row->{'data'},
        'status'      => $row->{'status'},
        'helpful'     => $row->{'helpful'},
        'not_helpful' => $row->{'not_helpful'},
        'created_by'  => $row->{'created_by'},
        'created_at'  => $row->{'created_at'},
        'modified_by' => $row->{'modified_by'},
        'modified_at' => $row->{'modified_at'},
        'adaptor'     => $self->adaptor,
      );
      push @$records, $r;
    }
    $self->{'records'} = $records;
  }
  return $self->{'records'};
}

sub views {
  my $self = shift;
  my $articles = [];

  my $params = [['status','in_use']];
  if ($self->param('kw')) {
    push @$params, ['keyword',$self->param('kw')];
  }

  #my $modular = $self->modular;
  my $modular = 0;
  ## Check to see if there are any records of type 'view'
  if ($modular) {
    push @$params, ['type','view'];
    if ($self->param('id')) {
      push @$params, ['help_record_id',$self->param('id')];
    }
    $articles = $self->records($params);
    pop @$params; ## remove type parameter since it doesn't exist in old table
  }
  else {
    if ($self->param('id')) {
      push @$params, ['article_id',$self->param('id')];
    }
  }
  ## Default help
  if (!$self->param('id') && !$self->param('kw')) {
    push @$params, ['keyword','helpview'];
  }
    
  ## Check old database and convert to records
  ## NB - convert to else block once EnsEMBL is fully migrated?
  my $results = $self->adaptor->fetch_articles($params);
  foreach my $row (@$results) {
    my %fields = (
        'title'     => $row->{'title'},
        'keyword'   => $row->{'keyword'},
        'content'   => $row->{'content'},
        'category'  => $row->{'category_name'},
      );
    my $temp_fields = {};
    foreach my $key (keys %fields ) {
      $temp_fields->{$key} = $fields{$key};
      $temp_fields->{$key} =~ s/'/\\'/g;
    }
    my $data = Dumper($temp_fields);
    $data =~ s/^\$VAR1 = //;

    my $r = EnsEMBL::Web::Record::Help->new(
        'id'          => $row->{'article_id'},
        'type'        => 'view',
        'keyword'     => $row->{'keyword'},
        'data'        => $data,
        'adaptor'     => $self->adaptor,
    );
    push @$articles, $r; 
  }
  return $articles;
}


sub articles {
  ### a
  ### Returns:
  my $self = shift;

  my $keywords    = $self->param( 'kw' );
  my $ids         = $self->param( 'ids' );
  my ($method_se, $method_kw, $method_id, $results);

  #if ($self->modular) {
  #  $method_se = 'fetch_article_by_keyword';
  #  $method_kw = 'fetch_scores_by_string';
  #  $method_id = 'fetch_summaries_by_scores';
  #}
  #else {
    $method_se = 'fetch_all_by_keyword';
    $method_kw = 'fetch_all_by_string';
    $method_id = 'fetch_all_by_scores';
  #}

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
  return $self->adaptor->fetch_index_list('live');
}

sub glossary {
  my $self = shift;
  if ($self->modular) {
    return $self->records([['type','glossary'],['status','live']]);
  }
  else {
    ## Fake records!
    my $glossary = [];
    my $results = $self->adaptor->fetch_glossary('live');
    foreach my $row (@$results) {
      my %fields = (
          'word'    => $row->{'word'},
          'expanded' => $row->{'acronym'},
          'meaning' => $row->{'meaning'},
        );
      my $temp_fields = {};
      foreach my $key (keys %fields ) {
        $temp_fields->{$key} = $fields{$key};
        $temp_fields->{$key} =~ s/'/\\'/g;
      }
      my $data = Dumper($temp_fields);
      $data =~ s/^\$VAR1 = //;

      my $r = EnsEMBL::Web::Record::Help->new(
        'id'          => $row->{'word_id'},
        'type'        => 'glossary',
        'data'        => $data,
        'adaptor'     => $self->adaptor,
      );
      push @$glossary, $r; 
    }
    return $glossary;
  }
}

sub movie_list {
  my $self = shift;
  return $self->records([['type','movie'],['status','live']]);
}

sub movie {
  my $self = shift;
  my $records = $self->records([['help_record_id',$self->param('id')]]);
  return $records->[0];
}


1;
