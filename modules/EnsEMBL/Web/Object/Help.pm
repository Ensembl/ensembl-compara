package EnsEMBL::Web::Object::Help;

use strict;
use warnings;
no warnings "uninitialized";
use CGI qw(escape);

use EnsEMBL::Web::Object;
use EnsEMBL::Web::Record::Help;
our @ISA = qw(EnsEMBL::Web::Object);
use Mail::Mailer;

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
  push @mail_attributes,
    [ 'Date',         $date ],
    [ 'Name',         $self->param('name') ],
    [ 'Email',        $email ],
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
  my $subject = $self->param('category') || "$sitename website Helpdesk";
  $mailer->open({ 'To' => $recipient, 'Subject' => $subject, 'From' => $self->param('email') });
  print $mailer $message;
  $mailer->close();
  return 1;
}

sub records {
  my ($self, $type) = @_;

  if (!$self->{'records'}) {
    my $records = [];
    my $result = $self->adaptor->fetch_records($type);
    foreach my $row (@$result) {
      my $r = EnsEMBL::Web::Record->new(
        'id'          => $row->{'help_record_id'},
        'type'        => $row->{'type'},
        'data'        => $row->{'data'},
        'created_by'  => $row->{'created_by'},
        'created_at'  => $row->{'created_at'},
        'modified_by' => $row->{'modified_by'},
        'modified_at' => $row->{'modified_at'},
      );
      push @$records, $r;
    }
    $self->{'records'} = $records;
  }
  return $self->{'records'};
}

sub get_record_by_id {
  my ($self, $id) = @_;
  my $record;

  if ($id) {
    my $data = $self->adaptor->fetch_record_by_id($id);
    $record = EnsEMBL::Web::Record->new(
        'id'          => $data->{'help_record_id'},
        'type'        => $data->{'type'},
        'data'        => $data->{'data'},
        'created_by'  => $data->{'created_by'},
        'created_at'  => $data->{'created_at'},
        'modified_by' => $data->{'modified_by'},
        'modified_at' => $data->{'modified_at'},
      );
  }
  return $record;
}

sub results {
  ### a
  ### Returns:
  my $self = shift;

  my $modular     = 0;
  ## Switch to this once modular articles are available
  #my $modular     = $self->modular;
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
  my $method = 'fetch_index_list';
  ## Switch to this once modular articles are available
  #my $method = $self->modular ? 'fetch_article_index' : 'fetch_index_list';
  return $self->adaptor->$method('live');
}

sub glossary {
  my $self = shift;
  if ($self->modular) {
    my $glossary = [];
    my $records = $self->records('glossary');
    foreach my $r (@$records) {
      my $data = $r->data_hash('word', 'acronym_for', 'meaning');
      push @$glossary, $data;
    }
    return $glossary;
  }
  else {
    return $self->adaptor->fetch_glossary('live');
  }
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
