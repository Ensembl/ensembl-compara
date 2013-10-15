package Bio::EnsEMBL::ExternalData::AttachedFormat::DATAHUB;

use strict;
use warnings;
no warnings 'uninitialized';

use Bio::EnsEMBL::ExternalData::DataHub::SourceParser;

use base qw(Bio::EnsEMBL::ExternalData::AttachedFormat);

sub new {
  my $self = shift->SUPER::new(@_);
  $self->{'datahub_adaptor'} = Bio::EnsEMBL::ExternalData::DataHub::SourceParser->new({ 
    timeout => 10,
    proxy   => $self->{hub}->species_defs->ENSEMBL_WWW_PROXY,
  });
  return $self;
}

sub check_data {
  my ($self) = @_;
  my $url = $self->{'url'};
  my $error = '';

  # try to open and use the datahub file
  # this checks that the datahub files is present and correct
  my $datahub;
  eval {
    my $base_url = $url;
    my $hub_file = 'hub.txt';

    if ($url =~ /.txt$/) {
      $base_url =~ s/(.*\/).*/$1/;
      ($hub_file = $url) =~ s/.*\/(.*)/$1/;
    }
  
    $datahub = $self->{'datahub_adaptor'}->get_hub_info($base_url, $hub_file);
  };
  warn $@ if $@;
  warn "Failed to open Data Hub " . $url unless $datahub;

  if ($@ or !$datahub) {
    $error = "Unable to open remote Data Hub file: $url<br>Ensure that your web/ftp server is accessible to the Ensembl site";
  }
  return $error;
}

sub style {
  my $self = shift;
  return $self->{'_cache'}->{'style'} ||= $self->_calc_style();
}

sub _calc_style {
  my $self = shift;
  
  my $tl_score = 0;
  my $trackline = $self->{'trackline'};
  if($trackline) {
    $trackline = $self->parse_trackline($trackline) || {};
    $tl_score = $trackline->{'useScore'} || 0;
  }

  # WORK OUT HOW TO CONFIGURE FEATURES FOR RENDERING
  # Explicit: Check if mode is specified on trackline
  if($tl_score == 2) {
    return 'score';
  } elsif($tl_score == 1) {
    return 'colour';
  } elsif($tl_score == 4) {
    return 'wiggle';
  } elsif($tl_score == 0) {
    # Implicit: No help from trackline, have to work it out
    my $line_length = $self->{'datahub_adaptor'}->file_bedline_length;
    if($line_length >= 8) {
      return 'colour';      
    } elsif($line_length >= 5) {
      return 'score';
    } else {
      return 'plain';
    }
  }
}

1;
