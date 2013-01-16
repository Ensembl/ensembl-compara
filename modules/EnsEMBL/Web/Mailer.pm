package EnsEMBL::Web::Mailer;

## Wrapper around Mail::Mailer with added clean-up functionality

use strict;
use warnings;
no warnings 'uninitialized';

use Mail::Mailer;
# use Website::StopIPs;

# use EnsEMBL::Web::Filter::Spam;
# use EnsEMBL::Web::Filter::Sanitize;
use EnsEMBL::Web::RegObj;

sub new {
  my ($class, $data) = @_;
  
  my $sd = $ENSEMBL_WEB_REGISTRY->species_defs;
  
  my $self = {
    from           => $sd->ENSEMBL_HELPDESK_EMAIL,
    mail_server    => $sd->ENSEMBL_MAIL_SERVER,
    spam_threshold => 60,
    base_url       => $sd->ENSEMBL_BASE_URL,
    site_name      => $sd->ENSEMBL_SITETYPE,
    %{$data || {}}
  };
  
  bless $self, $class;
  return $self;
}

sub to          :lvalue { $_[0]->{'to'};          }
sub from        :lvalue { $_[0]->{'from'};        }
sub reply       :lvalue { $_[0]->{'reply'};       }
sub subject     :lvalue { $_[0]->{'subject'};     }
sub message     :lvalue { $_[0]->{'message'};     }
sub mail_server :lvalue { $_[0]->{'mail_server'}; }
sub base_url    :lvalue { $_[0]->{'base_url'};    }
sub site_name   :lvalue { $_[0]->{'site_name'};   }

sub send {
  my ($self, $object, $options) = @_;
  
  ## Sanitize input and fill in any missing values
  if ($object) {
#    my $spamfilter = new EnsEMBL::Web::Filter::Spam({ object => $object, threshold => $self->{'spam_threshold'} });
#    my $sanitizer  = new EnsEMBL::Web::Filter::Sanitize({ object => $object });
#    my $IPcheck    = new Website::StopIPs($object->species_defs->ENSEMBL_CHECK_SPAM);

#    $self->message = $spamfilter->check($self->message)) unless $options->{'spam_check'} == 0;

#    $self->from  = $sanitizer->clean($self->from));
#    $self->to    = $sanitizer->clean($self->to));
#    $self->reply = $sanitizer->clean($self->reply || $self->from));
  }  else {
    warn '!!! PROXY OBJECT NOT PASSED TO MAILER - CANNOT CHECK FOR SPAM, ETC';
    warn '!!! MESSAGE NOT SENT';
    return undef;
  }


  my $mailer   = new Mail::Mailer('smtp', Server => $self->mail_server);
  my @months   = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
  my @weekDays = qw(Sun Mon Tue Wed Thu Fri Sat Sun);
  my ($sec, $min, $hour, $day, $month, $year) = gmtime;
  $year += 1900;
  my $time_string = sprintf '%s %s %s %s, %02d:%02d:%02d +0000', $weekDays[$day], $day, $months[$month], $year, $hour, $min, $sec; 

  $mailer->open({
    'To'       => $self->to,
    'From'     => $self->from,
    'Reply-To' => $self->reply,
    'Subject'  => $self->subject,
    'X-URL'    => $self->base_url,
    'Date'     => $time_string
  });
 
  print $mailer $self->message;
  $mailer->close or die "couldn't send whole message: $!\n";
}

1;
