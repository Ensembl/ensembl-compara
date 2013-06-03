package EnsEMBL::Web::Mailer;

## Wrapper around Mail::Mailer with added clean-up functionality

use strict;
use warnings;

use Mail::Mailer;
use EnsEMBL::Web::Exceptions;

sub new {
  my ($class, $hub, $data) = @_;

  my $sd = $hub->species_defs;

  return bless {
    'hub'           => $hub,
    'from'          => $sd->ENSEMBL_HELPDESK_EMAIL,
    'mail_server'   => $sd->ENSEMBL_MAIL_SERVER,
    'base_url'      => $sd->ENSEMBL_BASE_URL,
    'site_name'     => $sd->ENSEMBL_SITETYPE,
    %{$data || {}}
  }, $class;
}

sub url {
  ## Generates an email friendly (gmail friendly to be precise as it encodes ';' breaking the ensembl urls)
  ## @params Same as Hub->url
  ## @return URL stirng (absolute url)
  my $self  = shift;
  (my $url  = $self->hub->url(@_)) =~ s/\;/\&/g;
  $url      = $self->base_url . $url unless $url =~ /^http(s)?\:\/\//;
  return $url;
}

sub email_footer {
  ## Returns the generic email footer
  ## @return Text String
  return sprintf "\n\nMany thanks,\n\nThe %s web team\n\n%1\$s Privacy Statement: www.ensembl.org/info/about/legal/privacy.html\n\n", $_[0]->site_name;
}

sub hub         :lvalue { $_[0]->{'hub'};         }
sub to          :lvalue { $_[0]->{'to'};          }
sub from        :lvalue { $_[0]->{'from'};        }
sub reply       :lvalue { $_[0]->{'reply'};       }
sub subject     :lvalue { $_[0]->{'subject'};     }
sub message     :lvalue { $_[0]->{'message'};     }
sub mail_server :lvalue { $_[0]->{'mail_server'}; }
sub base_url    :lvalue { $_[0]->{'base_url'};    }
sub site_name   :lvalue { $_[0]->{'site_name'};   }

sub send {
  my $self = shift;

  my $mailer      = Mail::Mailer->new('smtp', 'Server' => $self->{'mail_server'});
  my @months      = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
  my @week_days   = qw(Sun Mon Tue Wed Thu Fri Sat Sun);
  my ($sec, $min, $hour, $day, $month, $year, $wday) = gmtime;
  $year          += 1900;
  my $time_string = sprintf '%s %s %s %s, %02d:%02d:%02d +0000', $week_days[$wday], $day, $months[$month], $year, $hour, $min, $sec;

  my $return    = 1;

  try {
    $mailer->open({
      'To'       => $self->{'to'},
      'From'     => $self->{'from'},
      'Reply-To' => $self->{'reply'},
      'Subject'  => $self->{'subject'},
      'X-URL'    => $self->{'base_url'},
      'Date'     => $time_string
    });

    print $mailer $self->{'message'};
    $mailer->close;
  } catch {
    $return = 0;
    warn $_;
  };
  
  return $return;
}

1;
