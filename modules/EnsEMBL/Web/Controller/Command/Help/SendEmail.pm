package EnsEMBL::Web::Controller::Command::Help::SendEmail;

## Sends the contents of the helpdesk contact form (after checking for spam posting)

use strict;
use warnings;

use Class::Std;
use EnsEMBL::Web::Mailer;
use EnsEMBL::Web::RegObj;

use base 'EnsEMBL::Web::Controller::Command';

{

sub BUILD {
  my ($self, $ident, $args) = @_;
}

sub process {
  my $self = shift;
  my $cgi = $self->action->cgi;

  my $mailer = EnsEMBL::Web::Mailer->new();

  my $comments = $cgi->param('comments');
  my $spam = $mailer->spam_check($comments);

  unless ($spam) {
    my $species_defs = $ENSEMBL_WEB_REGISTRY->species_defs;

    my $subject = $cgi->param('subject') || $species_defs->ENSEMBL_SITETYPE.' Helpdesk';
    $subject .= ' - '.$species_defs->ENSEMBL_SERVERNAME;

    my @mail_attributes = ();
    my @T = localtime();
    my $date = sprintf "%04d-%02d-%02d %02d:%02d:%02d", $T[5]+1900, $T[4]+1, $T[3], $T[2], $T[1], $T[0];
    my $url = CGI::unescape($cgi->param('_referer'));
    $url = undef if $url =~ m#Help/SendEmail#; ## Compensate for auto-filling of _referer!
    push @mail_attributes, (
      [ 'Date',         $date ],
      [ 'Name',         $cgi->param('name') ],
      [ 'Referer',     $url || '-none-' ],
      [ 'Last Search',  $cgi->param('string')||'-none-' ],
      [ 'User agent',   $ENV{'HTTP_USER_AGENT'}],
    );
    my $message = 'Support question from '.$species_defs->ENSEMBL_SERVERNAME."\n\n";
    $message .= join "\n", map {sprintf("%-16.16s %s","$_->[0]:",$_->[1])} @mail_attributes;
    $message .= "\n\nComments:\n\n$comments\n\n";

    $mailer->set_mail_server('localhost');
    $mailer->set_from($cgi->param('email'));
    $mailer->set_to($species_defs->ENSEMBL_HELPDESK_EMAIL);
    $mailer->set_subject($subject);
    $mailer->set_message($message);

    $mailer->send({'spam_check' => 0});
  }

  my $new_param = {};
  my $url = $self->url('/Help/EmailSent', $new_param);
  $self->ajax_redirect($url);
}

}

1;
