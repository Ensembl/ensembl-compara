package EnsEMBL::Web::Configuration::DASCollection;

use EnsEMBL::Web::Document::Popup;
use EnsEMBL::Web::Document::Renderer::Apache;
use EnsEMBL::Web::Document::Panel::Information;
use EnsEMBL::Web::Form;
use EnsEMBL::Web::Document::Panel::SpreadSheet;
use EnsEMBL::Web::Configuration;
use Data::Dumper;

our @ISA = qw( EnsEMBL::Web::Configuration );

use CGI qw(header param);


sub dasconfview {
  my $self   = shift;
  my $obj    = $self->{'object'};
  my $document = $self->{'page'};
  my $script = $obj->param('conf_script') || 'geneview';
  my $confparams = '';
  foreach my $param (grep { !/^DAS|^_das/ } $obj->param()) {
    if (my @values = grep { $_ } $obj->param($param)) {
      foreach my $v (@values) {
        $confparams .= ";$param=$v";
      }
    }
  }

# for Edit and Delete buttons
  $obj->param("selfURL", "/$ENV{'ENSEMBL_SPECIES'}/dasconfview?$confparams");
  if (defined(my $wizard_stage = &display_wizard_status($document, $obj))) {
    my $panel = new EnsEMBL::Web::Document::Panel::SpreadSheet(
      'code'    => "daswizard", 'caption' => "DAS Wizard $wizard_stage", 'object'  => $obj
    );
    $panel->add_components(qw(das_wizard EnsEMBL::Web::Component::DASCollection::das_wizard));
    $document->content->add_panel($panel);        
  }

  my $flag = 'navigation';
  $document->menu->add_block( $flag, 'bulleted', 'Manage Sources');
  $document->menu->add_entry( $flag, 'text' => "Add Data Source", 'href' => "/$ENV{'ENSEMBL_SPECIES'}/dasconfview?_das_add=das_server$confparams" );
  $document->menu->add_entry( $flag, 'text' => "Upload your data", 'href' => "/$ENV{'ENSEMBL_SPECIES'}/dasconfview?_das_add=das_file$confparams" );
#    $document->menu->add_entry( $flag, 'text' => "Remove your data", 'href' => "/$ENV{'ENSEMBL_SPECIES'}/dasconfview?_das_remove=das_file$confparams" );
#    $document->menu->add_entry( $flag, 'text' => "Search DAS registry", 'href' => "/$ENV{'ENSEMBL_SPECIES'}/dasconfview?_das_add=das_registry$confparams" );
  my $panel2 = new EnsEMBL::Web::Document::Panel::SpreadSheet(
    'code'    => "daslist", 'caption' => "DAS sources", 'object'  => $obj,
    'null_data' => '<p>No DAS sources have been configured for this species</p>'
  );
  $panel2->add_components( qw(added_sources EnsEMBL::Web::Component::DASCollection::added_sources));
  $document->close->URL = "/$ENV{'ENSEMBL_SPECIES'}/$script?$confparams";
  $document->content->add_panel($panel2);
}

sub display_wizard_status {
  my ($document, $object) = @_;
  return if (defined($object->param('_das_submit')));
  my %source_conf = ();        
  my @confkeys = qw( assembly_version stylesheet fg_merge fg_grades fg_data fg_min fg_max score strand label caption type depth domain group name protocol labelflag color help url linktext linkurl);
  my $step;
  if (defined(my $new_das = $object->param('_das_add'))) {
    $step = 1;
    $source_conf{sourcetype} = $new_das;
  } elsif (defined(my $src = $object->param('_das_edit'))) {
    $step = 3;
    $source_conf{sourcetype} = 'das_server';
    my $das_collection = $object->get_DASCollection;
    my @das_objs = @{$das_collection};
    my $das_adapt;
    foreach my $das_obj (@das_objs) {
      $das_adapt = $das_obj->adaptor;
      last if ($das_adapt->name eq $src);
    } 
#    warn(Dumper($das_adapt));
    foreach my $key (@confkeys) {
      my $hkey ="DAS${key}";
      $object->param( "$hkey", $das_adapt->$key);
#warn("S: $hkey :". $das_adapt->$key);
    }
    $object->param("DASenable", @{$das_adapt->enable});
    $object->param("DAStype", @{$das_adapt->mapping});
    $object->param("DASdsns", $das_adapt->dsn);
    $object->param("DASregistry", undef);
    $object->param("DASsourcetype", 'das_server');
    $object->param("DASedit", $src);
    $source_conf{sourcetype} = 'das_server';
  }
  if (! defined($step)) {
    $step = $object->param('DASWizardStep');
  }
  return unless (defined ($step));
  if (my $sd = $object->param('_das_Step')) {
    if ($sd eq 'Next') {
      $step ++;
    } elsif ($sd eq 'Back') {
      $step --;
    }
  }
  my %DASTypeLabel = (
    'das_url'       => 'URL based source',
    'das_file'      => 'Data upload', 
    'das_server'    => 'Annotation server', 
    'das_registry'  => 'DAS Registry'
  );
  my $das_type = $source_conf{sourcetype} || $object->param("DASsourcetype") || return;
  foreach my $key (@confkeys) {
    my $hkey = "DAS$key";
    $source_conf{$key} = $object->param($hkey);
  }

  if (defined( my $usersrc = $object->param("DASuser_source") || undef)) {
    $source_conf{domain} = $object->species_defs->ENSEMBL_DAS_UPLOAD_SERVER.'/das';
    $source_conf{domain} = "http://$source_conf{domain}" if ($source_conf{domain} !~ m!^\w+://!);
    $object->param('DASdomain', $source_conf{domain});
    $source_conf{dsn} = $usersrc;
    $source_conf{user_source} = $usersrc;
  }

  push @{$source_conf{enable}} , $object->param("DASenable");
  push @{$source_conf{mapping}} , $object->param("DAStype");
  my (@source_type, @data_location, @display_config) = ();
  push @source_type, {"text"=>$DASTypeLabel{$das_type}};
  if ($das_type eq 'das_file') {
    $source_conf{domain} = $object->species_defs->ENSEMBL_DAS_UPLOAD_SERVER.'/das';
    $source_conf{domain} = "http://$source_conf{domain}" if ($source_conf{domain} !~ m!^\w+://!);
    $object->param('DASdomain', $source_conf{domain});
  }
  my $scount = 0;
  if($das_type eq 'das_url') {
    if (defined(my $murl = $source_conf{url})) {
      push @data_location, {"text" => "URL:", "href" => $murl};
    }
  } else {
    if ( my $domain = $object->param('DASdomain')) {
      if ($domain eq $object->species_defs->DAS_REGISTRY_URL) {
        my $dreg = $object->getRegistrySources();
        my $dassource;
        foreach my $src ($object->param('DASregistry')) {
          $dassource = $dreg->{$src};
          if ($dassource->{url} =~ /(https?:\/\/)(.+das)\/(.+)/) {
            ($prot, $url, $dsn) = ($1, $2, $3);
            $dsn =~ s/\///;
            push @data_location, {"text" => "Server: $url"};
            push @data_location, {"text" => "DSN: $dsn"};
          }
          $scount ++;
        }
        if ($scount > 1) {
          $source_conf{name} = $source_conf{label} = '*As nickname*';
        } else {
          $source_conf{name} = $object->param('DASname') || $dassource->{nickname};
          $source_conf{label} = $object->param('DASlabel') || $dassource->{nickname};
        }
      } else {
        push @data_location, {"text" => "Server: $domain"};
        my $id;
        if (defined( my $usersrc = $object->param("DASuser_source") || undef)) {
          $id = $usersrc;
          push @data_location, {"text" => "DSN: $id"};
        } else {
          foreach my $dsn ($object->param('DASdsns')) {
            $id = $dsn if (! $scount);
            push @data_location, {"text" => "DSN: $dsn"};
            $scount ++;
          }
        }
        if ($scount > 1) {
          $source_conf{name} = '*As DSN*';
          $source_conf{label} = '*As DSN*';
        } else {
          $source_conf{name} = $object->param('DASname') || $id;
          $source_conf{label} = $object->param('DASlabel') || $id;
        }
      }
    }
  }
  if (@data_location) {
    if (defined(my $mmapping = $source_conf{type})) {
      my $cs = join('+ ', map {$object->getCoordinateSystem($_)} grep {$_} @{$source_conf{mapping}});
      push @data_location, {"text" => "Coordinate system: $cs"};
    }
  } else {
    push  @data_location, { "text"=>"Not yet initialised" };
  }
# Diplay configuration options
  my %LabelStr  = ( 'o' => 'On feature',    'u' => 'Under feature',   'n' => 'No label' );
  my %StrandStr = ( 'b' => 'Both strands',  'f' => 'Forward strand',  'r' => 'Reverse strand' );
  my %ScoreStr = (  'n' => 'No',            'h' => 'Histogram' );
  if (defined $object->param('DASenable')) {
    my $dsw_color = $source_conf{color} || 'blue';
    my $dsw_name = $source_conf{name};
    my $dsw_label = $source_conf{label};
    my @dsw_enable = @{$source_conf{enable}};
    my $dsw_help = $source_conf{help} || '';
    my $dsw_linktext = $source_conf{linktext} || '';
    my $dsw_linkurl = $source_conf{linkurl} || '';
    my $dsw_group = $source_conf{group} eq 'y' ? 'Yes' : 'No';
    my $dsw_strand = $StrandStr{$source_conf{strand} || 'b'};
    my $dsw_depth = $source_conf{depth} || '10';
    my $dsw_labelflag = $LabelStr{$source_conf{labelflag} || 'u'};
    my $dsw_stylesheet = $source_conf{stylesheet} eq 'y' ? 'Yes' : 'No';
    my $dsw_score = $ScoreStr{$source_conf{score}} || 'No';
    push @display_config,
      {"text"=>"Enable on: @dsw_enable"}, {"text"=>"Name: $dsw_name"},  {"text"=>"Track label: $dsw_label"},
      {"text"=>"Help: $dsw_help"},     {"text"=>"LinkText: $dsw_linktext"},     {"text"=>"LinkURL: $dsw_linkurl"},     
      {"text"=>"Colour: $dsw_color"},     {"text"=>"Group: $dsw_group"},     
      {"text"=>"Display on: $dsw_strand"}, {"text"=>"Depth: $dsw_depth rows"}, {"text"=>"Label: $dsw_labelflag"},
      {"text"=>"Stylesheet: $dsw_stylesheet"}, {"text"=>"Use score: $dsw_score"} ;
  } else {
    push  @display_config, { "text"=>"Not yet initialised" };
  }
  $document->menu->add_block( 'status', 'bulleted', "Summary" );
  $document->menu->add_entry( 'status', 'text' => "Source type", "options" => \@source_type, "popup"=> "no");
  $document->menu->add_entry( 'status', 'text' => "Data Location", "options"=>\@data_location, "popup"=>"no");
  $document->menu->add_entry( 'status', 'text' => "Data Display", "options"=>\@display_config, "popup"=>"no");
  my %stages = (
    1 => 'Data location', 
    2 => 'Data appearance', 
    3 => 'Display configuration', 
  );

  my $snum = $das_type eq 'das_url'  ? 1 : 3;
  my $title = $stages{$step} || '';
  return "Step $step of $snum: $title";
}

1;
