package EnsEMBL::Web::Object::Help;

use strict;
use warnings;
no warnings "uninitialized";
use CGI qw(escape);

use EnsEMBL::Web::Object;
our @ISA = qw(EnsEMBL::Web::Object);
use Mail::Mailer;

sub results     { return $_[0]->Obj->{'results'}; }
sub index       { return $_[0]->Obj->{'index'};   }
sub glossary    { return $_[0]->Obj->{'glossary'};   }
sub movie_list  { return $_[0]->Obj->{'movie_list'};   }
sub movie       { return $_[0]->Obj->{'movie'};   }

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

1;
