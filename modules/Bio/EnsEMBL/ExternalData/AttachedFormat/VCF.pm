package Bio::EnsEMBL::ExternalData::AttachedFormat::VCF;

use strict;
use warnings;
no warnings 'uninitialized';

use base qw(Bio::EnsEMBL::ExternalData::AttachedFormat);

sub check_data {
  my ($self) = @_;
  my $url = $self->{'url'};
  my $error = '';
  require Bio::EnsEMBL::ExternalData::VCF::VCFAdaptor;

  if ($url =~ /^ftp:\/\//i && !$self->{'hub'}->species_defs->ALLOW_FTP_VCF) {
    $error = "The VCF file could not be added - FTP is not supported, please use HTTP.";
  } 
  else {
    # try to open and use the VCF file
    # this checks that the VCF and index files are present and correct, 
    # and should also cause the index file to be downloaded and cached in /tmp/ 
    my ($dba, $index);
    eval {
      $dba =  Bio::EnsEMBL::ExternalData::VCF::VCFAdaptor->new($url);
      $dba->fetch_variations(1, 1, 10);
    };
    warn $@ if $@;
    warn "Failed to open VCF $url\n $@\n " if $@; 
    warn "Failed to open VCF $url\n $@\n " unless $dba;
          
    if ($@ or !$dba) {
      $error = qq{
        Unable to open/index remote VCF file: $url
        <br />Ensembl can only display sorted, indexed VCF files
        <br />Ensure you have sorted and indexed your file and that your web server is accessible to the Ensembl site 
        <br />For more information on the type of file expected please see the large file format <a href="/info/website/upload/large.html">documentation.</a>
      };
    }
  }
  return $error;
}

1;

