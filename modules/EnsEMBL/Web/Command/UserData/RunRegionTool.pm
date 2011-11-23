package EnsEMBL::Web::Command::UserData::RunRegionTool;

use strict;

use EnsEMBL::Web::TmpFile::Text;

use base qw(EnsEMBL::Web::Command);

sub process {
  my $self    = shift;
  my $hub     = $self->hub;
  my $session = $hub->session;
  my $data    = $session->get_data(code => $hub->param('code'));

  my $url     = $hub->species_path($hub->data_species) . '/UserData/RegionReportOutput';
  my $param;

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
  $oneliner .= sprintf('--password=%s', $hub->species_defs->DATABASE_DBPASS) if $hub->species_defs->DATABASE_DBPASS;

  ## Pipe straight to output file, to conserve memory
  my $filename  = $self->temp_file_name.'.txt';
  my $path      = $hub->species_defs->ENSEMBL_TMP_DIR."/region_report";
  my $directory = $self->make_directory($path.'/'.$filename);

  $oneliner .= " --output=$path/$filename";

  #warn ">>> $oneliner";

  my $error = system($oneliner);

  if ($error) {
    $param->{'filter_module'} = 'Regions';
    $param->{'filter_code'} = 'script_fail';
    warn ">>> REGION REPORT ERROR $?";
  }
  else {
    $param->{'code'} = $hub->param('code');
  }  
  warn ">>> URL $url";

  $self->ajax_redirect($url, $param);
}

1;
