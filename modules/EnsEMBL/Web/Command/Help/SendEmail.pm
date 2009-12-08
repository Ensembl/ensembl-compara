package EnsEMBL::Web::Command::Help::SendEmail;

## Sends the contents of the helpdesk contact form (after checking for spam posting)

use strict;
use warnings;

use URI::Escape qw(uri_unescape);

use EnsEMBL::Web::Mailer;
use EnsEMBL::Web::RegObj;

use base qw(EnsEMBL::Web::Command);

sub process {
  my $self = shift;
  my $object = $self->object;
  my $url;

  if ($object->param('submit') eq 'Back') {
    my $param = {
      'name'    => $object->param('name'),
      'address' => $object->param('address'),
      'subject' => $object->param('subject'),
      'message'    => $object->param('message'),
    };
    $url = $self->url('/Help/Contact', $param);
  }
  else {
    my $mailer = EnsEMBL::Web::Mailer->new();
    my $spam;

    ## Check honeypot fields first
    if ($object->param('honeypot_1') || $object->param('honeypot_2')) {
      $spam = 1;
    }
    else {
    ## Check the user's input for spam _before_ we start adding all our crap!
#    my $filter = EnsEMBL::Web::Filter::Spam->new();
#    $spam = $filter->check($object->param('message'), 1);
    }

    unless ($spam) {
      my $species_defs = $ENSEMBL_WEB_REGISTRY->species_defs;

      my $subject = $object->param('subject') || $species_defs->ENSEMBL_SITETYPE.' Helpdesk';
      $subject .= ' - '.$species_defs->ENSEMBL_SERVERNAME;

      my @mail_attributes = ();
      my @T = localtime();
      my $date = sprintf "%04d-%02d-%02d %02d:%02d:%02d", $T[5]+1900, $T[4]+1, $T[3], $T[2], $T[1], $T[0];
      my $url = $species_defs->ENSEMBL_BASE_URL . uri_unescape($object->param('_referer'));
      $url = undef if $url =~ m#Help/SendEmail#; ## Compensate for auto-filling of _referer!
      push @mail_attributes, (
        [ 'Date',         $date ],
        [ 'Name',         $object->param('name') ],
        [ 'Referer',     $url || '-none-' ],
        [ 'Last Search',  $object->param('string')||'-none-' ],
        [ 'User agent',   $ENV{'HTTP_USER_AGENT'}],
      );
      my $message = 'Support question from '.$species_defs->ENSEMBL_SERVERNAME."\n\n";
      $message .= join "\n", map {sprintf("%-16.16s %s","$_->[0]:",$_->[1])} @mail_attributes;
      $message .= "\n\nComments:\n\n".$object->param('message')."\n\n";

      $mailer->set_mail_server('localhost');
      $mailer->set_from($object->param('address'));
      $mailer->set_to($species_defs->ENSEMBL_HELPDESK_EMAIL);
      $mailer->set_subject($subject);
      $mailer->set_message($message);

      $mailer->send({'spam_check' => 0});
    }

    $url = $self->url('/Help/EmailSent');
  }

  $self->ajax_redirect($url);
}

1;
