package EnsEMBL::Web::Command::Help::SendEmail;

## Sends the contents of the helpdesk contact form (after checking for spam posting)

use strict;
use warnings;

# use EnsEMBL::Web::Filter::Spam;
use EnsEMBL::Web::Mailer;

use base qw(EnsEMBL::Web::Command);

sub process {
  my $self = shift;
  my $hub = $self->hub;
  my $url;

  if ($hub->param('submit') eq 'Back') {
    my $param = {
      name    => $hub->param('name'),
      address => $hub->param('address'),
      subject => $hub->param('subject'),
      message => $hub->param('message')
    };
    
    $url = $self->url('/Help/Contact', $param);
  } else {
    my $spam;

    # Check honeypot fields first
    #will prob need a list of these blacklisted addresses, but do this for now to fix Vega spam
    $spam = 1 if $hub->param('address') eq 'neverdiespike@hanmail.net';

    if ($hub->param('honeypot_1') || $hub->param('honeypot_2')) {
      $spam = 1;
    }  else {
      # Check the user's input for spam _before_ we start adding all our crap!
#     my $filter = EnsEMBL::Web::Filter::Spam->new;
#     $spam = $filter->check($hub->param('message'), 1);
    }

    if (!$spam) {
      my @mail_attributes;
      
      my $species_defs = $hub->species_defs;
      my $subject      = ($hub->param('subject') || $species_defs->ENSEMBL_SITETYPE . ' Helpdesk') . ' - ' . $species_defs->ENSEMBL_SERVERNAME;
      my @T            = localtime;
      my $date         = sprintf '%04d-%02d-%02d %02d:%02d:%02d', $T[5]+1900, $T[4]+1, $T[3], $T[2], $T[1], $T[0];
      my $url          = $species_defs->ENSEMBL_BASE_URL;
      
      $url = undef if $url =~ m#Help/SendEmail#; # Compensate for auto-filling of _referer
      
      push @mail_attributes, (
        [ 'Date',        $date ],
        [ 'Name',        $hub->param('name') ],
        [ 'Referer',     $url || '-none-' ],
        [ 'Last Search', $hub->param('string')||'-none-' ],
        [ 'User agent',  $ENV{'HTTP_USER_AGENT'} ]
      );
      
      my $message = 'Support question from ' . $species_defs->ENSEMBL_SERVERNAME . "\n\n";
      $message .= join "\n", map { sprintf '%-16.16s %s', "$_->[0]:", $_->[1] } @mail_attributes;
      $message .= "\n\nComments:\n\n" . $hub->param('message') . "\n\n";

      my $mailer = EnsEMBL::Web::Mailer->new({
        mail_server => 'localhost',
        from        => $hub->param('address'),
        to          => $species_defs->ENSEMBL_HELPDESK_EMAIL,
        subject     => $subject,
        message     => $message
      });
      
      $mailer->send({ spam_check => 0 });
    }

    $url = $self->url('/Help/EmailSent');
  }

  $self->ajax_redirect($url);
}

1;
