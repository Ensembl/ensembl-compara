=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2022] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

package EnsEMBL::Web::Mailer;

## Wrapper around Mail::Mailer with added clean-up functionality

use strict;
use warnings;

use Mail::Mailer;
use MIME::Base64 qw(encode_base64);
use EnsEMBL::Web::Exceptions;

sub new {
  my ($class, $hub, $data) = @_;

  my $sd = $hub->species_defs;

  return bless {
    'hub'           => $hub,
    'from'          => $sd->ENSEMBL_HELPDESK_EMAIL,
    'mail_server'   => $sd->ENSEMBL_MAIL_SERVER,
    'base_url'      => $sd->ENSEMBL_PROXY_PROTOCOL.":".$sd->ENSEMBL_BASE_URL,
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
  my $self = shift;
 
  my $footer = sprintf "\n\n\nMany thanks,\n\nThe %s web team\n\n\n", $self->site_name;

  if ($self->hub->species_defs->GDPR_POLICY_URL) {
    $footer .= sprintf "%s Privacy Statement: %s\n\n", $self->site_name, $self->hub->species_defs->GDPR_POLICY_URL;
  }

  $footer .= "http://".$self->hub->species_defs->ENSEMBL_SERVERNAME."\n\n";;

  my $address = $self->hub->species_defs->SITE_OWNER_ADDRESS;
  $footer .= "$address\n\n" if $address;

  return $footer;
}

sub hub         :lvalue { $_[0]->{'hub'};         }
sub to          :lvalue { $_[0]->{'to'};          }
sub from        :lvalue { $_[0]->{'from'};        }
sub reply       :lvalue { $_[0]->{'reply'};       }
sub subject     :lvalue { $_[0]->{'subject'};     }
sub message     :lvalue { $_[0]->{'message'};     }
sub attachment  :lvalue { $_[0]->{'attachment'};  }
sub mail_server :lvalue { $_[0]->{'mail_server'}; }
sub base_url    :lvalue { $_[0]->{'base_url'};    }
sub site_name   :lvalue { $_[0]->{'site_name'};   }

sub send {
  my $self = shift;

  my @months      = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
  my @week_days   = qw(Sun Mon Tue Wed Thu Fri Sat Sun);
  my ($sec, $min, $hour, $day, $month, $year, $wday) = gmtime;
  $year          += 1900;
  my $time_string = sprintf '%s, %s %s %s %02d:%02d:%02d +0000', $week_days[$wday], $day, $months[$month], $year, $hour, $min, $sec;

  my $mailer;
  my $return    = 1;

  if ($self->{'attachment'}) {
    ## Message with attached file
    my $boundary;
    my @chars=('a'..'z','A'..'Z','0'..'9','_');
    for (1..10) {
      $boundary .= $chars[rand @chars];
    }
    $mailer      = Mail::Mailer->new();
    try {
      $mailer->open({
        'To'       => $self->{'to'},
        'From'     => $self->{'from'},
        'Reply-To' => $self->{'reply'},
        'Subject'  => $self->{'subject'},
        'X-URL'    => $self->{'base_url'},
        'Date'     => $time_string,
        'Content-type' => qq(multipart/mixed; boundary="$boundary"),
      });
      binmode($mailer,':utf8');

      print {$mailer} "This is a multi-part message in MIME format.

--$boundary
Content-Type: text/plain; chartset=UTF-8
Content-Transfer-Encoding: 8bit

";

      print {$mailer} $self->{'message'};

      my $fh        = $self->hub->input->upload('attachment');
      my $file_name = $self->{'attachment'};
      my $file_info = $self->hub->input->uploadInfo($file_name);

      print {$mailer} qq(
--$boundary
Content-Type: $file_info->{'Content-Type'}; name="$file_name"
Content-Transfer-Encoding: base64
Content-Disposition: attachment; filename="$file_name"

);

      print {$mailer} encode_base64(do{local $/ = undef; <$fh>; });

      print {$mailer} qq(
--$boundary--);

      $mailer->close;
    } catch {
      $return = 0;
      warn $self->log_message($time_string, $_);
    };
  }
  else {
    ## Simple text message
    $mailer      = Mail::Mailer->new('smtp', 'Server' => $self->{'mail_server'});

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
      warn $self->log_message($time_string, $_);
      warn 'MAILER ERROR: '.$_;
    };
  }
  return $return;
}

sub log_message {
  my ($self, $time_string, $error) = @_;

  my $message = "MAILER ERROR: \n";
  $message .= 'To: '.$self->{'to'}."\n";
  $message .= 'From: '.$self->{'from'}."\n";
  $message .= 'Reply-To: '.$self->{'reply'}."\n";
  $message .= 'Subject: '.$self->{'subject'}."\n";
  $message .= 'X-URL: '.$self->{'base_url'}."\n";
  $message .= 'Date: '.$time_string."\n";
  $message .= $error."\n\n";
  return $message;
}

1;
