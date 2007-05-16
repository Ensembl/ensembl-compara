package EnsEMBL::Web::Mailer;

use strict;
use warnings;
no warnings "uninitialized";

use Mail::Mailer;
use EnsEMBL::Web::SpeciesDefs;

{

my %Email_of;
my %MailServer_of;
my %SiteName_of;
my %Reply_of;
my %From_of;
my %Subject_of;
my %Message_of;
my %BaseURL_of;
my %HelpEmail_of;

sub new {
  my ($class, %params) = @_;
  my $self = bless \my($scalar), $class;
  my $sd = EnsEMBL::Web::SpeciesDefs->new();
  $Email_of{$self}   = defined $params{email} ? $params{email} : "";
  $From_of{$self}   = defined $params{from} ? $params{from} : $sd->ENSEMBL_HELPDESK_EMAIL;
  $Reply_of{$self}   = defined $params{reply_to} ? $params{reply_to} : $sd->ENSEMBL_HELPDESK_EMAIL;
  $Subject_of{$self}   = defined $params{subject} ? $params{subject} : "";
  $SiteName_of{$self}   = defined $params{site_name} ? $params{site_name} : "";
  $BaseURL_of{$self}   = defined $params{base_url} ? $params{base_url} : $sd->ENSEMBL_BASE_URL;
  $MailServer_of{$self}   = defined $params{mail_server} ? $params{mail_server} : $sd->ENSEMBL_MAIL_SERVER;
  $HelpEmail_of{$self}   = defined $params{help_email} ? $params{help_email} : $sd->ENSEMBL_HELPDESK_EMAIL;
  if (!$SiteName_of{$self}) {
    my $sitetype = $sd->ENSEMBL_SITETYPE;
    $SiteName_of{$self} = $sitetype eq 'EnsEMBL' ? 'Ensembl' : $sitetype;
  }
  return $self;
}

sub email {
  ### a
  my $self = shift;
  $Email_of{$self} = shift if @_;
  return $Email_of{$self};
}

sub site_name {
  ### a
  my $self = shift;
  $SiteName_of{$self} = shift if @_;
  return $SiteName_of{$self};
}

sub reply_to {
  ### a
  my $self = shift;
  $Reply_of{$self} = shift if @_;
  return $Reply_of{$self};
}

sub mail_server {
  ### a
  my $self = shift;
  $MailServer_of{$self} = shift if @_;
  return $MailServer_of{$self};
}

sub from {
  ### a
  my $self = shift;
  $From_of{$self} = shift if @_;
  return $From_of{$self};
}

sub subject {
  ### a
  my $self = shift;
  $Subject_of{$self} = shift if @_;
  return $Subject_of{$self};
}

sub message {
  ### a
  my $self = shift;
  $Message_of{$self} = shift if @_;
  return $Message_of{$self};
}

sub base_url {
  ### a
  my $self = shift;
  $BaseURL_of{$self} = shift if @_;
  return $BaseURL_of{$self};
}

sub send {
  my $self = shift;
  my $mailer = new Mail::Mailer 'smtp', Server => $self->mail_server;
  my $time = localtime;
  $mailer->open({
                'To'      => $self->escape($self->email),
                'From'    => $self->escape($self->from),
                'Reply-To'=> $self->escape($self->reply_to),
                'Subject' => $self->subject,
                'Date'    => $time 
                });
  print $mailer $self->message;
  $mailer->close();
}

sub escape {
  my ($self, $value) = @_;
  $value =~ s/[\r\n].*$//sm;
  return $value;
}

sub DESTROY {
  ### d
  my $self = shift;
  delete $Email_of{$self};
  delete $Reply_of{$self};
  delete $From_of{$self};
  delete $Subject_of{$self};
  delete $Message_of{$self};
  delete $MailServer_of{$self};
  delete $BaseURL_of{$self};
}

}

1;
