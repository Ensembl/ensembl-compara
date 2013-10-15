package Bio::EnsEMBL::ExternalData::AttachedFormat::BAM;

use strict;
use warnings;
no warnings 'uninitialized';

use base qw(Bio::EnsEMBL::ExternalData::AttachedFormat);

sub check_data {
  my ($self) = @_;
  my $url = $self->{'url'};
  my $error = '';
  require Bio::DB::Sam;

  if ($url =~ /^ftp:\/\//i && !$self->{'hub'}->species_defs->ALLOW_FTP_BAM) {
    $error = "The bam file could not be added - FTP is not supported, please use HTTP.";
  } 
  else {
    # try to open and use the bam file and its index -
    # this checks that the bam and index files are present and correct, 
    # and should also cause the index file to be downloaded and cached in /tmp/ 
    my ($sam, $bam, $index);
    eval {
      # Note the reason this uses Bio::DB::Sam->new rather than Bio::DB::Bam->open is to allow set up
      # of default cache dir (which happens in Bio::DB:Sam->new)
      $sam = Bio::DB::Sam->new( -bam => $url);
      #$bam = Bio::DB::Bam->open($url);
      $bam = $sam->bam;
      $index = Bio::DB::Bam->index($url,0);
      my $header = $bam->header;
      my $region = $header->target_name->[0];
      my $callback = sub {return 1};
      $index->fetch($bam, $header->parse_region("$region:1-10"), $callback);
    };
    warn $@ if $@;
    warn "Failed to open BAM " . $url unless $bam;
    warn "Failed to open BAM index for " . $url unless $index;

    if ($@ or !$bam or !$index) {
        $error = "Unable to open/index remote BAM file: $url<br>Ensembl can only display sorted, indexed BAM files.<br>Please ensure that your web server is accessible to the Ensembl site and that both your .bam and .bai files are present, named consistently, and have the correct file permissions (public readable).";
    }
  }
  return $error;
}

1;

