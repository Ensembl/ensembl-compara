package EnsEMBL::Web::Command::UserData::RunRegionTool;

use strict;

use EnsEMBL::Web::TmpFile::Text;
use Digest::MD5 qw(md5_hex);

use base qw(EnsEMBL::Web::Command::UserData);

sub process {
  my $self    = shift;
  my $hub     = $self->hub;
  my $session = $hub->session;
  my $data    = $session->get_data(code => $hub->param('code'));

  my $root    = $hub->species_defs->ENSEMBL_SERVERROOT;
  my $script  = $root.'/ensembl-tools/scripts/region_reporter/region_report.pl';
  my $libs    = join(',', @SiteDefs::ENSEMBL_LIB_DIRS);

  my $oneliner = 'perl ';
  foreach (@SiteDefs::ENSEMBL_LIB_DIRS) {
    $oneliner .= " -I$_";
  }
  $oneliner .= " $script --species=".$data->{'species'};

  my $file = new EnsEMBL::Web::TmpFile::Text(filename => $data->{'filename'}, extension => $data->{'extension'});
  my $filename = $file->filename;
  my $fullpath = $file->tmp_dir.'/'.$file->prefix.'/'.$filename;
  $oneliner .= " --input=$fullpath";

  ## Which features are required? Should already have been converted to string by
  ## E::W::Command::UserData::CheckRegions
  if ($hub->param('include')) {
    $oneliner .= ' --include='.$hub->param('include');
  }

  ## Output format
  $oneliner .= $hub->param('output_format') eq 'gff3' ? ' --gff3' : ' --report';

  ## Set database connection
  $oneliner .= sprintf(' --host=%s --port=%s --db_version=%s --user=%s', 
                        $hub->species_defs->DATABASE_HOST,
                        $hub->species_defs->DATABASE_HOST_PORT,
                        $hub->species_defs->ENSEMBL_VERSION,
                        $hub->species_defs->DATABASE_DBUSER,
                      );
  $oneliner .= sprintf(' --password=%s', $hub->species_defs->DATABASE_DBPASS) if $hub->species_defs->DATABASE_DBPASS;

  ## Allow for ontology db maybe being on different server
  $oneliner .= sprintf(' --secondaryhost=%s --secondaryport=%s --db_version=%s --secondaryuser=%s', 
                       $hub->species_defs->multidb->{'DATABASE_GO'}{'HOST'},
                       $hub->species_defs->multidb->{'DATABASE_GO'}{'PORT'},
                       $hub->species_defs->ENSEMBL_VERSION,
                       $hub->species_defs->multidb->{'DATABASE_GO'}{'USER'},
                     );
  $oneliner .= sprintf(' --secondarypassword=%s',$hub->species_defs->multidb->{'DATABASE_GO'}{'PASS'}) if $hub->species_defs->multidb->{'DATABASE_GO'}{'PASS'};

  ## Pipe straight to output file, to conserve memory
  my $output    = $self->temp_file_name;
  my $extension = $hub->param('output_format') eq 'gff3' ? 'gff' : 'txt';
  my $path      = $hub->species_defs->ENSEMBL_TMP_DIR.'/download';
  my $directory = $self->make_directory($path.'/'.$filename);

  $oneliner .= " --output=$path/$output.$extension";

  #warn ">>> $oneliner";

  my $response = system($oneliner);
  my %return = (
                1 => 'no_features',
                2 => 'location_unknown',
              );

  my $param = {'action' => 'RegionReportOutput'};

  if ($response) {
    my $exitcode = $? >>8;
    $param->{'error_code'} = $return{$exitcode};
    $param->{'code'} = $hub->param('code');
    warn "!!! REGION REPORT ERROR ".$param->{'error_code'};
  }
  else {
    ## Create new session record for output file 
    my $session = $hub->session;
    my $code    = join '_', md5_hex($output), $session->session_id;

    ## Attach data species to session
    my $new_data = $session->add_data(
          type      => 'upload',
          filename  => $output,
          code      => $code,
          md5       => md5_hex($output),
          name      => 'Region report',
          species   => $data->{'species'},
          format    => $hub->param('output_format'),
          timestamp => time,
          extension => $extension,
          prefix    => 'download',
    );

    $session->configure_user_data('upload', $new_data);
    $param->{'code'} = $code;

    ## Remove uploaded file record
    $session->purge_data('code' => $hub->param('code'));
  }

  $self->file_uploaded($param);
}

1;
