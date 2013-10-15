package Bio::EnsEMBL::ExternalData::AttachedFormat::BIGWIG;

use strict;
use warnings;
no warnings 'uninitialized';

use base qw(Bio::EnsEMBL::ExternalData::AttachedFormat);

sub extra_config_page { return "ConfigureBigWig"; }

sub check_data {
  my ($self) = @_;
  my $url = $self->{'url'};
  my $error = '';
  require Bio::DB::BigFile;

  if ($url =~ /^ftp:\/\//i && !$self->{'hub'}->species_defs->ALLOW_FTP_BIGWIG) {
    $error = "The BigWig file could not be added - FTP is not supported, please use HTTP.";
  }
  else {
    # try to open and use the bigwig file
    # this checks that the bigwig files is present and correct
    my $bigwig;
    eval {
      Bio::DB::BigFile->set_udc_defaults;
      $bigwig = Bio::DB::BigFile->bigWigFileOpen($url);
      my $chromosome_list = $bigwig->chromList;
    };
    warn $@ if $@;
    warn "Failed to open BigWig " . $url unless $bigwig;

    if ($@ or !$bigwig) {
      $error = "Unable to open remote BigWig file: $url<br>Ensure that your web/ftp server is accessible to the Ensembl site";
    }
  }
  return $error;
}


1;
