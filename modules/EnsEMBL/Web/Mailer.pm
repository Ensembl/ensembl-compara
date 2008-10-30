package EnsEMBL::Web::Mailer;

## Wrapper around Mail::Mailer with added clean-up functionality

use strict;
use warnings;
no warnings "uninitialized";

use Class::Std;
use Mail::Mailer;
use EnsEMBL::Web::RegObj;

{

my %To            :ATTR(:set<to>             :get<to>) ;
my %From          :ATTR(:set<from>           :get<from>);
my %Reply         :ATTR(:set<reply>          :get<reply>);
my %Subject       :ATTR(:set<subject>        :get<subject>);
my %Message       :ATTR(:set<message>        :get<message>);
my %MailServer    :ATTR(:set<mail_server>    :get<mail_server>);
my %SpamThreshold :ATTR(:set<spam_threshold> :get<spam_threshold>);
my %SiteName      :ATTR(:set<site_name>      :get<site_name>) ;
my %BaseUrl       :ATTR(:set<baseurl>        :get<baseurl>) ;

sub BUILD {
  my ($self, $ident, $args) = @_;
  my $sd = $ENSEMBL_WEB_REGISTRY->species_defs;
  $From{$ident}           = $args->{from}           || $sd->ENSEMBL_HELPDESK_EMAIL;
  $Reply{$ident}          = $args->{reply}          || $sd->ENSEMBL_HELPDESK_EMAIL;
  $MailServer{$ident}     = $args->{mail_server}    || $sd->ENSEMBL_MAIL_SERVER;
  $SpamThreshold{$ident}  = $args->{spam_threshold} || 60;
  $SiteName{$ident}       = $sd->ENSEMBL_SITETYPE;
  $BaseUrl{$ident}        = $sd->ENSEMBL_BASE_URL;
}

sub spam_check {
  my ($self, $content) = @_;
  (my $check = $content) =~ s/<a\s+href=.*?>.*?<\/a>//smg;
  $check =~ s/\[url=.*?\].*?\[\/url\]//smg;
  $check =~ s/\[link=.*?\].*?\[\/link\]//smg;
  $check =~ s/https?:\/\/\S+//smg;
  if( length($check)<length($content)/$self->get_spam_threshold ) {
    warn "MAIL FILTERED DUE TO BLOG SPAM.....";
    return 1;
  }
  $check =~ s/\s+//gsm;
  if( $check eq '' ) {
    warn "MAIL FILTERED DUE TO ZERO CONTENT!";
    return 1;
  }
  return 0;
}

sub sanitize_email {
  my ($self, $email) = @_;
  $email =~ s/[\r\n].*$//sm;
  $email =~ s/"//g;
  $email =~ s/''/'/g;
  return $email;
}

sub send {
  my ($self, $options) = @_;

  ## Sanitize input and fill in any missing values
  $self->set_message( $self->spam_check( $self->get_message  )  ) unless $options->{'spam_check'} == 0;
  $self->set_from(    $self->sanitize_email( $self->get_from )  );
  $self->set_to(      $self->sanitize_email( $self->get_to   )  );
  $self->set_reply(   $self->sanitize_email( $self->get_reply || $self->get_from ) );

  my $mailer   = new Mail::Mailer 'smtp', Server => $self->get_mail_server;
  my @months   = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
  my @weekDays = qw(Sun Mon Tue Wed Thu Fri Sat Sun);
  my ($sec, $min, $hour, $day, $month, $year) = gmtime();
  $year += 1900;
  my $time_string = sprintf('%s %s %s %s, %02d:%02d:%02d +0000', $weekDays[$day], $day, $months[$month], $year, $hour, $min, $sec); 

  $mailer->open({
    'To'      => $self->get_to,
    'From'    => $self->get_from,
    'Reply-To'=> $self->get_reply,
    'Subject' => $self->get_subject,
    'X-URL'   => $self->get_baseurl,
    'Date'    => $time_string,
  });
  
  print $mailer $self->get_message;
  $mailer->close()
    or die "couldn't send whole message: $!\n";
}

}

1;
