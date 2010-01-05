package EnsEMBL::Web::Command::Help::MovieEmail;

### Sends the contents of the helpdesk movie feedback form (after checking for spam posting)

use strict;
use warnings;

# use EnsEMBL::Web::Filter::Spam;
use EnsEMBL::Web::Mailer;

use base qw(EnsEMBL::Web::Command);

sub process {
  my $self = shift;
  
  my $object = $self->object;
  my $spam;

   # Check honeypot fields first
  if ($object->param('honeypot_1') || $object->param('honeypot_2')) {
    $spam = 1;
  }  else {
    # Check the user's input for spam _before_ we start adding all our crap!
#    my $filter = new EnsEMBL::Web::Filter::Spam;
#    $spam = $filter->check($object->param('message'), 1);
  }

  
  if (!$spam) {
    my @mail_attributes;
    
    my $species_defs = $object->species_defs;
    my $subject      = ($object->param('subject') || $species_defs->ENSEMBL_SITETYPE . ' Helpdesk') . ' - ' . $species_defs->ENSEMBL_SERVERNAME;
    my @T            = localtime;
    my $date         = sprintf '%04d-%02d-%02d %02d:%02d:%02d', $T[5]+1900, $T[4]+1, $T[3], $T[2], $T[1], $T[0];
    my $url          = 'http://' . $species_defs->ENSEMBL_SERVERNAME . ':' . $species_defs->ENSEMBL_PORT if $species_defs->ENSEMBL_PORT != '80';
    
    $url = undef if $url =~ m#Help/SendEmail#; # Compensate for auto-filling of _referer
    
    push @mail_attributes, (
      [ 'Date',       $date ],
      [ 'Name',       $object->param('name') ],
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
    
    my @problems     = $object->param('problem');
    my $problem_text = "\n\nProblems:\n\n";
    
    if (@problems) {
      foreach my $p (@problems) {
        $problem_text .= "* $problems->{$p}\n";
      }
    }
    
    $message .= $problem_text;
    $message .= "\n\nComments:\n\n" . $object->param('message') . "\n\n";
    
    my $mailer = new EnsEMBL::Web::Mailer({
      mail_server => 'localhost',
      from        => $object->param('email'),
      to          => $species_defs->ENSEMBL_HELPDESK_EMAIL,
      subject     => $subject,
      message     => $message
    });

    $mailer->send({ spam_check => 0 });
  }
  
  $self->ajax_redirect($self->url('/Help/EmailSent'));
}

1;
