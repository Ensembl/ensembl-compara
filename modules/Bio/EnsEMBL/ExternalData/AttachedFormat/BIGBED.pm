package Bio::EnsEMBL::ExternalData::AttachedFormat::BIGBED;

use strict;
use warnings;
no warnings 'uninitialized';

use Bio::EnsEMBL::ExternalData::BigFile::BigBedAdaptor;

use base qw(Bio::EnsEMBL::ExternalData::AttachedFormat);

sub new {
  my $self = shift->SUPER::new(@_);
  return $self;
}

sub _bigbed_adaptor {
  my ($self,$bba) = @_;
  if (defined($bba)) {
    $self->{'_cache'}->{'bigbed_adaptor'} = $bba;
  } elsif (!$self->{'_cache'}->{'bigbed_adaptor'}) {
    $self->{'_cache'}->{'bigbed_adaptor'} = Bio::EnsEMBL::ExternalData::BigFile::BigBedAdaptor->new($self->{'url'});
  }
  return $self->{'_cache'}->{'bigbed_adaptor'};
}

sub check_data {
  my ($self) = @_;
  my $url = $self->{'url'};
  my $error = '';
  require Bio::DB::BigFile;

  if ($url =~ /^ftp:\/\//i && !$self->{'hub'}->species_defs->ALLOW_FTP_BIGWIG) {
    $error = "The BigBed file could not be added - FTP is not supported, please use HTTP.";
  }
  else {
    # try to open and use the bigbed file
    # this checks that the bigbed files is present and correct
    my $bigbed;
    eval {
      Bio::DB::BigFile->set_udc_defaults;
      $bigbed = Bio::DB::BigFile->bigBedFileOpen($url);
      my $chromosome_list = $bigbed->chromList;
    };
    warn $@ if $@;
    warn "Failed to open BigBed " . $url unless $bigbed;

    if ($@ or !$bigbed) {
      $error = "Unable to open remote BigBed file: $url<br>Ensure that your web/ftp server is accessible to the Ensembl site";
    }
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
    my $line_length = $self->_bigbed_adaptor->file_bedline_length;
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
