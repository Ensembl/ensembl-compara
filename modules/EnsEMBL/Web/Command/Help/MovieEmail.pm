package EnsEMBL::Web::Command::Help::MovieEmail;

### Sends the contents of the helpdesk movie feedback form (after checking for spam posting)

use strict;
use warnings;

# use EnsEMBL::Web::Filter::Spam;
use EnsEMBL::Web::Mailer;

use base qw(EnsEMBL::Web::Command);

sub process {
  my $self = shift;
  
  my $hub = $self->hub;
  my $spam;

   # Check honeypot fields first
  if ($hub->param('honeypot_1') || $hub->param('honeypot_2')) {
    $spam = 1;
  }  else {
    # Check the user's input for spam _before_ we start adding all our crap!
#    my $filter = EnsEMBL::Web::Filter::Spam->new;
#    $spam = $filter->check($hub->param('message'), 1);
  }

  
  if (!$spam) {
    my @mail_attributes;
    
    my $species_defs = $hub->species_defs;
    my $subject      = ($hub->param('subject') || $species_defs->ENSEMBL_SITETYPE . ' Helpdesk') . ' - ' . $species_defs->ENSEMBL_SERVERNAME;
    my @T            = localtime;
    my $date         = sprintf '%04d-%02d-%02d %02d:%02d:%02d', $T[5]+1900, $T[4]+1, $T[3], $T[2], $T[1], $T[0];
    my $url          = 'http://' . $species_defs->ENSEMBL_SERVERNAME . ':' . $species_defs->ENSEMBL_PORT if $species_defs->ENSEMBL_PORT != '80';
    
    $url = undef if $url =~ m#Help/SendEmail#; # Compensate for auto-filling of _referer
    
    push @mail_attributes, (
      [ 'Date',       $date ],
      [ 'Name',       $hub->param('name') ],
      [ 'Referer',    $url || '-none-' ],
      [ 'User agent', $ENV{'HTTP_USER_AGENT'} ]
    );
    
    my $message = 'Feedback from ' . $species_defs->ENSEMBL_SERVERNAME . "\n\n";
    $message .= join "\n", map { sprintf '%-16.16s %s', "$_->[0]:", $_->[1] } @mail_attributes;

    my $problems = {
      no_load   => 'Movie did not appear',
      playback  => 'Playback was jerky',
      no_sound  => 'No sound',
      bad_sound => 'Poor quality sound',
      other     => 'Other (please describe below)'
    };
    
    my @problems  = $hub->param('problem');
    my $title     = $hub->param('title');
    my $problem_text = "\n\nProblem with video $title:\n\n";
    
    if (@problems) {
      foreach my $p (@problems) {
        $problem_text .= "* $problems->{$p}\n";
      }
    }
    
    $message .= $problem_text;
    $message .= "\n\nComments:\n\n" . $hub->param('message') . "\n\n";
    
    my $mailer = EnsEMBL::Web::Mailer->new({
      mail_server => 'localhost',
      from        => $hub->param('email'),
      to          => $species_defs->ENSEMBL_HELPDESK_EMAIL,
      subject     => $subject,
      message     => $message
    });

    $mailer->send({ spam_check => 0 });
  }
  
  $self->ajax_redirect($self->url('/Help/EmailSent'));
}

1;
