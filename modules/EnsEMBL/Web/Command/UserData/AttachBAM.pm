package EnsEMBL::Web::Command::UserData::AttachBAM;

use strict;
use warnings;

use Bio::DB::Sam;
use EnsEMBL::Web::Tools::Misc qw(get_url_filesize);
use base qw(EnsEMBL::Web::Command);

sub process {

  my $self     = shift;
  my $hub      = $self->hub;
  my $session  = $hub->session;
  my $redirect = $hub->species_path($hub->data_species) . '/UserData/';
  my $name     = $hub->param('name');
  my $param    = {};

  if (!$name) {
    my @path = split('/', $hub->param('url'));
    $name = $path[-1];
  }

  if (my $url = $hub->param('url')) {
    
    if ($url =~ /^ftp:\/\//i && !$SiteDefs::BAM_ALLOW_FTP) {
     $session->add_data(
        'type'  => 'message',
        'code'  => 'AttachBAM',
        'message' => "The bam file could not be added - FTP is not supported, please use HTTP.",
        function => '_error'
      );
      $redirect .= 'ManageData';
    } else {
    
      # try to open and use the bam file and it's index -
      # this checks that the bam and index files are present and correct, 
      # and should also cause the index file to be downloaded and cached in /tmp/ 
      my ($bam, $index);
      eval {
        $bam = Bio::DB::Bam->open($url);
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
         ## Set message in session
        $session->add_data(
          'type'  => 'message',
          'code'  => 'AttachBAM',
          'message' => "Unable to open/index remote BAM file: $url<br>Ensembl can only display sorted, indexed BAM files.<br>Please ensure that your web server is accessible to the Ensembl site and that both your .bam and .bai files are present, named consistently, and have the correct file permissions (public readable).",
          function => '_error'
        );
        $redirect .= 'ManageData';
      } else {
        my $data = $session->add_data(
          type      => 'bam',
          url       => $url,
          name      => $name,
          species   => $hub->data_species,
        );
        if ($hub->param('save')) {
          $self->object->move_to_user('type' => 'bam', 'code' => $data->{'code'});
        }
        $redirect .= 'BAMFeedback';
        $session->configure_bam_views($data);
        $session->store; 
      }
    }
  } else {
    $redirect .= 'SelectBAM';
    $param->{'filter_module'} = 'Data';
    $param->{'filter_code'} = 'no_bam';
  }

  $self->ajax_redirect($redirect, $param); 
}

1;
