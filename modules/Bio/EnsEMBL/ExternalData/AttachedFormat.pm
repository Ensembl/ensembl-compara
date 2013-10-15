package Bio::EnsEMBL::ExternalData::AttachedFormat;

use strict;
use warnings;
no warnings 'uninitialized';

use Text::ParseWords;

use EnsEMBL::Web::Tools::Misc qw(get_url_filesize);

sub new {
  my ($proto,$hub,$format,$url,$trackline) = @_;
  my $class = ref($proto) || $proto;
  my $self = {
    format => $format,
    hub => $hub,
    url => $url,
    trackline => $trackline,
  };
  bless $self,$class;
  return $self;
}

sub name  { shift->{'format'} }
sub trackline { shift->{'trackline'} }

sub extra_config_page { return undef; }

sub check_data {
  my ($self) = @_;
  my $error = '';
  my $options = {};

  my $url = $self->{'url'};
  $url = "http://$url" unless $url =~ /^http|^ftp/;

  ## Check file size
  my $feedback = get_url_filesize($url);

  if ($feedback->{'error'}) {
    if ($feedback->{'error'} eq 'timeout') {
      $error = 'No response from remote server';
    } elsif ($feedback->{'error'} eq 'mime') {
      $error = 'Invalid mime type';
    } else {
      $error = "Unable to access file. Server response: $feedback->{'error'}";
    }
  } elsif (defined $feedback->{'filesize'} && $feedback->{'filesize'} == 0) {
    $error = 'File appears to be empty';
  }
  else {
    $options = {'filesize' => $feedback->{'filesize'}};
  }
  return ($error, $options);
}

sub parse_trackline {
  my %out = map { ( split /=/ )[(0,1)] } quotewords('\s',0,$_[1]);
  $out{'chrom'} =~ s/^chr// if exists $out{'chrom'};
  $out{'description'} = $out{'name'} unless exists $out{'description'};
  return \%out;
}

1;
