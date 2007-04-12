package EnsEMBL::Web::Factory::DASCollection;
=head1 NAME

EnsEMBL::Web::Factory::DASCollection;

=head1 SYNOPSIS

Module to create EnsEMBL::Web::Factory::DASCollection objects.

=head1 DESCRIPTION

Example:

my $dasfact = EnsEMBL::Web::Proxy::Factory->new( 'DASCollection', { '_databases' => $dbc, '_input' => $input } );
$dasfact->createObjects();
my( $das_collection) = @{$dasfact->DataObjects};

Creates DASCollection Data objects to be used within the web_api.

=head1 LICENCE

This code is distributed under an Apache style licence:
Please see http://www.ensembl.org/code_licence.html for details

=head1 CONTACT

Eugene Kulesha - ek3@sanger.ac.uk

=cut

use strict;
use warnings;
no warnings "uninitialized";

use Bio::EnsEMBL::ExternalData::DAS::DASAdaptor;
use Bio::EnsEMBL::ExternalData::DAS::DAS;

use EnsEMBL::Web::Factory;
use EnsEMBL::Web::Problem;
use EnsEMBL::Web::Proxy::Object;
use SOAP::Lite;
use Data::Dumper;
use vars qw( @ISA );
@ISA = qw(  EnsEMBL::Web::Factory );

#----------------------------------------------------------------------

=head2 _createObjects

  Arg [1]   : none
  Function  : Creates EnsEMBL::Web::Data::DASCollection objects
              1. examines SpeciesDefs for DAS config
              2. examines Input for DAS config
  Returntype: 
  Exceptions: 
  Caller    : $self->createObjects
  Example   : $self->_createObjects

=cut

sub createObjects {
  my $self = shift;
# Get the view that is requesting DASCollection Factory
  my $conf_script = $self->param("conf_script") || $self->script;

# Read the DAS config from the ini files
#  my $das_conftype = "ENSEMBL_INTERNAL_DAS_SOURCES"; # combined GeneDAS and Internal DAS
  my %sources_conf;
#  my $ini_confdata = $self->species_defs->$das_conftype() || {};
#  ref( $ini_confdata ) eq 'HASH' or die("$das_conftype badly configured" );
#  foreach my $source( keys %$ini_confdata ){
#    my $source_confdata = $ini_confdata->{$source} || ( warn( "$das_conftype source $source not configured" ) && next );
#    ref( $source_confdata ) eq 'HASH' || ( warn( "$das_conftype source $source badly configured" ) && next );
#
#  # Is source enabled for this view?
#    if (! defined($source_confdata->{enable})) {
#        @{$source_confdata->{enable}} = @{ $source_confdata->{on} || []}; # 
#    }
#
#    my $dsn = $source_confdata->{dsn};
#    $source_confdata->{url} .= "/$dsn" if ($source_confdata->{url} !~ /$dsn$/);
#    my %valid_scripts = map{ $_, 1 } @{$source_confdata->{enable}};
#    $valid_scripts{$conf_script} || next;
#    $source_confdata->{conftype} = 'internal'; # Denotes where conf is from
#    $source_confdata->{type} ||= 'ensembl_location'; # 
#    $source_confdata->{color} ||= $source_confdata->{col}; # 
#    $source_confdata->{id} = $source;
#    $source_confdata->{description} ||= $source_confdata->{label} ;
#    $source_confdata->{stylesheet} ||= 'N';
#    $source_confdata->{stylesheet} = 'Y' if ($source_confdata->{stylesheet} eq '1'); # 
#    $source_confdata->{score} ||= 'N';
#    $source_confdata->{fg_merge} ||= 'A';
#    $source_confdata->{fg_grades} ||= 20;
#    $source_confdata->{fg_data} ||= 'O';
#    $source_confdata->{fg_min} ||= 0;
#    $source_confdata->{fg_max} ||= 100;
#  
#    $source_confdata->{name} ||= $source;
#    $source_confdata->{group} ||= 'N';
#    $source_confdata->{group} = 'Y' if ($source_confdata->{group} eq '1'); # 
#    
#  #  warn("ADD INTERNAL: $source");
#  #  warn(Dumper($source_confdata));
#    $sources_conf{$source} = $source_confdata;
#  }
#
  my $daslist = $self->get_session->get_internal_das; 
  for my $source( keys %$daslist ) {
    my $source_config = $daslist->{$source}->get_data;
    my %valid_scripts = map{ $_, 1 } @{$source_config->{enable} || [] };
    $valid_scripts{$conf_script} || next;
    my $das_species = $source_config->{'species'};
    next if( $das_species && $das_species ne '' && $das_species ne $ENV{'ENSEMBL_SPECIES'} );
    $source_config->{conftype} ||= 'internal';
    $sources_conf{$source}    = $source_config;
  }
# Add external sources (ones added by user)
### THIS NOW NEEDS TO COME OUT OF THE session object.....
#    $extdas->getConfigs($conf_script, $conf_script);
  $daslist = $self->get_session->get_das;
   
  for my $source ( keys %$daslist ) {
    my $source_config = $daslist->{$source}->get_data;
    my %valid_scripts = map{ $_, 1 } @{$source_config->{enable} || [] };
    $valid_scripts{$conf_script} || next;
    my $das_species = $source_config->{'species'};
    next if( $das_species && $das_species ne '' && $das_species ne $ENV{'ENSEMBL_SPECIES'} );
    if( $source_config->{url} =~ /\/das$/ ) {
      $source_config->{url} .= "/$source_config->{dsn}";
    }
    $source_config->{type} = $source_config->{mapping}->[0] unless $source_config->{type};
    $source_config->{conftype} ||= 'external';
    $sources_conf{$source}    = $source_config;
  warn("ADD EXTERNAL: $source");
  warn(Dumper($source_config)) if ($source =~ /demo/i);
  }

# Get parameters of the view that has called upon dasconfview
  my %script_params = ();
  my @udas = ();
  my @conf_params = split('zzz', $self->param("conf_script_params") || '');

  foreach my $p (@conf_params) {
    next if ($p =~ /^=/);
    my @plist = split('=', $p);
    if ($plist[0] eq 'data_URL') {
      push(@udas, $plist[1]);
    } elsif ($plist[0] eq 'h' || $plist[0] eq 'highlight') {
      if (defined($plist[1])) {
        my @hlist = split(/\|/, $plist[1]);
        foreach my $h (@hlist) {
          if ($h =~ /URL:/) {
            $h =~ s/URL://;
            push(@udas, $h);
          } else {
            push(@{$script_params{$plist[0]}}, $plist[1] || '');
          }
        }
      }
    } else {
      push(@{$script_params{$plist[0]}}, $plist[1] || '');
    }
  }
  
# Add sources that are attached via URL
#  warn("URL SOURCES: @udas");
  my $urlnum = 1;
  foreach my $u (@udas) {
    my $das_name = "_URL_$urlnum";
#  warn ("ADD URL");
    $sources_conf{$das_name}->{name} = $das_name;
    $sources_conf{$das_name}->{url} = $u;
    $sources_conf{$das_name}->{conftype} = 'url';
    $urlnum ++;
  }

# Get the sources selection, i.e which sources' annotation should be displayed
  my $config = $self->get_userconfig( 'dasconfview' );
  my $section = $conf_script;

  $config->reset_subsection($section);
#    warn("DAS Select : ".join('*', $self->param('das_sources')));

    
  foreach my $src ( $self->param('das_sources')) {
    $config->set($section, $src, "on", 1);
  }
  $config->save( );

  my %DASsel = map {$_ => 1} $self->param('das_sources');

# Process the dasconfig form input - Get DAS sources to add/delete/edit;
  my %das_submit = map{$_,1} ($self->param( "_das_submit" ) || ());
  my %das_del    = map{$_,1} ($self->param( "_das_delete" ) || ());
  my %urldas_del = map{$_,1} ($self->param( "_urldas_delete" ) || ());
  my %das_edit   = map{$_,1} ($self->param( "_das_edit" ) || ());

  foreach (keys (%das_del)){
## Replace with session call
    $self->get_session->remove_das_source($_);
##    $extdas->delete_das_source($_);
    delete($sources_conf{$_});
  }
  foreach (keys %urldas_del){
    delete($sources_conf{$_});
  }
  
  if (defined(my $dedit  = $self->param("DASedit"))) {
    $sources_conf{$dedit}->{conftype} = 'external_editing';
  }

  my @confkeys = qw( name type);
  my @allkeys = ('strand', 'labelflag', 'label', 'url', 'conftype', 'group', 'stylesheet', 'score', 'fg_merge', 'fg_grades', 'fg_data', 'fg_min', 'fg_max', 'caption', 'active', 'color', 'depth', 'help', 'linktext', 'linkurl' );
  my @arr_keys = ('enable', 'mapping');

    # Add '/das' suffix to _das_domain param
  if( my $domain = $self->param( "DASdomain" ) ){
    if ($domain ne $self->species_defs->DAS_REGISTRY_URL) {
      $domain =~ s/(\/das)?\/?\s*$/\/das/;
      $self->param('DASdomain',$domain );
    }
  }
    
    # Have we got new DAS? If so, validate, and add to Input

  my $source_type = $self->param("DASsourcetype");
  $source_type = 'das_registry' if ( $self->param("DASdomain") eq $self->species_defs->DAS_REGISTRY_URL);

  if( $self->param("_das_submit") ){
    if ($self->param("DASsourcetype") eq 'das_url') {
      my $url = $self->param("DASurl") || ( warn( "_error_das_url: Need a url!") &&  $self->param( "_error_das_url", "Need a url!" ));
      my $das_name = "_URL_$urlnum"; 
      
      $sources_conf{$das_name}->{name} = $das_name;
      $sources_conf{$das_name}->{url} = $url;
      $sources_conf{$das_name}->{conftype} = 'url';
    } elsif ($source_type eq 'das_registry') {
      my $registry = $self->getRegistrySources();

      foreach my $id ($self->param("DASregistry")) {
        my $err = 0;
        my %das_data;
        $self->getSourceData($registry->{$id}, \%das_data);
        foreach my $key( @confkeys ){
          if (defined($self->param("DAS${key}"))) {
            $das_data{$key} = $self->param("DAS${key}");
          }
        }
        my $das_name = $das_data{name};
        if( exists( $sources_conf{$das_name} ) and  (! defined($sources_conf{$das_name}->{conftype}) or $sources_conf{$das_name}->{conftype} ne 'external_editing' )){ 
          my $das_name_ori = $das_name;
          for( my $i = 1; 1; $i++ ){
            $das_name = $das_name_ori ."_$i";
            if( ! exists( $sources_conf{$das_name} ) ){
              $das_data{name} =  $das_name;
              last;
            }
          }
        }
  # Add to the conf list
        $das_data{label} = $self->param('DASlabel') || $das_data{name};
        $das_data{caption} = $das_data{name};
        $das_data{stylesheet} = $self->param('DASstylesheet');
        $das_data{strand} = $self->param('DASstrand');
        $das_data{labelflag} = $self->param('DASlabelflag');
        $das_data{score} = $self->param('DASscore');
        $das_data{fg_merge} = $self->param('DASfg_merge');
        $das_data{fg_grades} = $self->param('DASfg_grades');
        $das_data{fg_data} = $self->param('DASfg_data');
        $das_data{fg_min} = $self->param('DASfg_min');
        $das_data{fg_max} = $self->param('DASfg_max');
        $das_data{group} = $self->param('DASgroup');
        @{$das_data{enable}} = $self->param('DASenable');
        $das_data{conftype} = 'external';
        $das_data{color} = $self->param("DAScolor");
        $das_data{depth} = $self->param("DASdepth");
        $das_data{help} = $self->param("DAShelp");
        $das_data{linktext} = $self->param("DASlinktext");
        $das_data{linkurl} = $self->param("DASlinkurl");
        $das_data{active} = 1; # Enable by default
        $sources_conf{$das_name} ||= {};
        foreach my $key( @confkeys, @allkeys, @arr_keys, 'conftype', 'active') {
          $sources_conf{$das_name}->{$key} = $das_data{$key};
        }
        $sources_conf{$das_name}->{'species'} = $self->species;
        $das_data{'species'} = $self->species;
## replace with session call
        $self->session->add_das_source_from_hashref(\%das_data);
        $DASsel{$das_name} = 1;
      }
    } elsif (my $das_name = $self->param("DASedit")) { # Edit source
      my $das_dsn = $self->param("DASdsns");
      my $das_data = $sources_conf{$das_name};
      foreach my $key( @confkeys, @allkeys){
        if (defined($self->param("DAS${key}"))) {
          $das_data->{$key} = $self->param("DAS${key}");
        }
      }
      $das_data->{active} = 1; # Enable by default
      # Add to the conf list
      $das_data->{name} = $das_name;
      $das_data->{label} ||= $das_data->{name};
      $das_data->{caption} ||= $das_data->{name};
      @{$das_data->{enable}} = $self->param('DASenable');
      @{$das_data->{mapping}} = grep { $_ } $self->param('DAStype');
      $das_data->{type} = 'mixed' if (scalar(@{$das_data->{mapping}}>1));

      $das_data->{conftype} = 'external';
      $sources_conf{$das_name} ||= {};

      foreach my $key( @confkeys, @allkeys, 'dsn', 'enable', 'mapping') {
        $sources_conf{$das_name}->{$key} = $das_data->{$key};
      }

#      warn("EDIT: ".Dumper($das_data));
## Replace with session call...
      $self->session->add_das_source_from_hashref($das_data);
      $DASsel{$das_name} = 1;
    } else {
      my $err = 0;
      my @das_sources;
      if (defined( my $usersrc = $self->param("DASuser_source") || undef)) {
        push @das_sources, {
          'url' => join('/','http:/',$self->species_defs->ENSEMBL_DAS_UPLOAD_SERVER,'das', $usersrc),
          'id' => $usersrc,
          'dsn' => $usersrc
        };
      } else {
        foreach my $id ($self->param("DASdsns")) {
          push @das_sources, {
            'id'  => $id,
            'url' => join ('/', $self->param('DASdomain'), $id),
            'url' => $self->param('DASdomain'),
            'dsn' => $id
          };
        }
      }
      foreach my $das_data (@das_sources) {
        my $das_name = $das_data->{'id'} or next;
        if( exists( $sources_conf{$das_name} ) and  (! defined($sources_conf{$das_name}->{conftype}) or $sources_conf{$das_name}->{conftype} ne 'external_editing' )){ 
          my $das_name_ori = $das_name;
          for( my $i = 1; 1; $i++ ){
            $das_name = $das_name_ori ."_$i";
            if( ! exists( $sources_conf{$das_name} ) ){
              $das_data->{name} =  $das_name;
              last;
            }
          }
        }
        foreach my $key( @confkeys, @allkeys){
          if (defined($self->param("DAS${key}"))) {
            $das_data->{$key} = $self->param("DAS${key}");
          }
        }
        $das_data->{active} = 1; # Enable by default
    # Add to the conf list
        $das_data->{name} = $das_name;
        $das_data->{label} ||= $das_data->{name};
        $das_data->{caption} ||= $das_data->{name};
        @{$das_data->{enable}} = $self->param('DASenable');
        @{$das_data->{mapping}} = grep { $_ } $self->param('DAStype');
        $das_data->{type} = 'mixed' if (scalar(@{$das_data->{mapping}}>1));
        $das_data->{conftype} = 'external';
        $das_data->{species} = $self->species;
        $sources_conf{$das_name} ||= {};
        foreach my $key( @confkeys, @allkeys, 'dsn', 'enable', 'mapping') {
          $sources_conf{$das_name}->{$key} = $das_data->{$key};
        }
## Replace with session calll
        $self->session->add_das_source_from_hashref($das_data);
        $DASsel{$das_name} = 1;
      }
    }
  }
    # Clean up any 'dangling' _das parameters
  if( $self->delete_param( "_das_delete" ) ){
    foreach my $key( @confkeys ){ $self->delete_param("DAS$key") }
  }
  
  my @udaslist = ();
  my @das_objs = ();
 
# Now we have a list of all active das sources - for each of them  create a DAS adaptor capable of retrieving das features 
  foreach my $source( sort keys %sources_conf ){
  # Create the DAS adaptor from the (valid) conf
    my $source_conf = $sources_conf{$source};
    push (@udaslist, "URL:$source_conf->{url}") if ($source_conf->{conftype} eq 'url');
    if( ! $source_conf->{url} and ! ( $source_conf->{protocol} && $source_conf->{domain} ) ){
      next;
    }
    $source_conf->{active} = defined ($DASsel{$source}) ? 1 : 0;
    my $das_adapt = Bio::EnsEMBL::ExternalData::DAS::DASAdaptor->new( 
      -name       => $source,
      -url        => $source_conf->{url}       || '',
      -type       => $source_conf->{type}      || '',
      -authority  => $source_conf->{authority} || '',
      -label      => $source_conf->{label}     || '',
      -labelflag  => $source_conf->{labelflag} || '',
      -caption    => $source_conf->{caption}   || '',
      -color      => $source_conf->{color} || $source_conf->{col} || '',
      -linktext   => $source_conf->{linktext}  || '',
      -linkurl    => $source_conf->{linkurl}   || '',
      -strand     => $source_conf->{strand}    || '',
      -depth      => $source_conf->{depth},
      -group      => $source_conf->{group}     || '',
      -stylesheet => $source_conf->{stylesheet}|| '',
      -score      => $source_conf->{score} || '',
      -fg_merge   => $source_conf->{fg_merge} || '',
      -fg_grades  => $source_conf->{fg_grades},
      -fg_data    => $source_conf->{fg_data} || '',
      -fg_min     => $source_conf->{fg_min},
      -fg_max     => $source_conf->{fg_max},
      -conftype   => $source_conf->{conftype}  || 'external',
      -active     => $source_conf->{active}    || 0, 
      -description=> $source_conf->{description}    || '', 
      -types      => $source_conf->{types} || [],
      -on         => $source_conf->{on}    || [],
      -enable     => $source_conf->{enable}    || [],
      -help       => $source_conf->{help}    || '',
      -mapping    => $source_conf->{mapping}    || [],
      -fasta      => $source_conf->{fasta} || [],
    );        
    if ($das_adapt) {
      $das_adapt->ensembldb( $self->DBConnection('core') );
      if( my $p = $self->species_defs->ENSEMBL_WWW_PROXY ){
        $das_adapt->proxy($p);
      }
  # Create the DAS object itself
      my $das_obj = Bio::EnsEMBL::ExternalData::DAS::DAS->new( $das_adapt );
      push @das_objs, $das_obj;
    } else {
      $DASsel{$source} = 0;
### Replace with sesssion call
      $self->get_session->remove_das_source( $source );
    }
  }
  my @selection = grep {$DASsel{$_}} keys %DASsel;
#    warn(join '*', 'SELCT:', @selection);
  $self->param('das_sources', @selection);
    # Create the collection object
  my $dataobject = EnsEMBL::Web::Proxy::Object->new( 'DASCollection', [@das_objs], $self->__data );
  $self->DataObjects( $dataobject );
  return 1; #success
}

sub getEnsemblMapping {
  my ($self, $cs) = @_;
  my ($realm, $base, $species) = ($cs->{name}, $cs->{category}, $cs->{organismName});
  my $smap ='unknown';
  if ($base =~ /Chromosome|Clone|Contig|Scaffold/) {
    $smap = 'ensembl_location_'.lc($base);
  } elsif ($base eq 'NT_Contig') {
    $smap = 'ensembl_location_supercontig';
  } elsif ($base eq 'Gene_ID') {
    $smap = $realm eq 'Ensembl'       ? 'ensembl_gene'
          : $realm eq 'HUGO_ID'       ? 'hugo'
          : $realm eq 'MGI'           ? 'mgi'
          : $realm eq 'MarkerSymbol'  ? 'markersymbol'
          : $realm eq 'MGISymbol'     ? 'markersymbol'
          : $realm eq 'EntrezGene'    ? 'entrezgene_acc'
          : $realm eq 'IPI_Accession' ? 'ipi_acc'
          : $realm eq 'IPI_ID'        ? 'ipi_id'
          :                             'unknown'
          ;
  } elsif ($base eq 'Protein Sequence') {
    $smap = $realm eq 'UniProt'       ? 'uniprot/swissprot_acc'
          : $realm eq 'TrEMBL'        ? 'uniprot/sptrembl'
          : $realm =~ /Ensembl/       ? 'ensembl_peptide'
          :                             'unknown'
          ;
  }

  $species or $species = '.+';
#    warn "B:$cs#".join('*', $realm, $base, $species)."#$smap";
  return wantarray ? ($smap, $species) : $smap;
}

sub getRegistrySources {
  my $self = shift;
  if (defined($self->{data}->{_das_registry})) {
    return $self->{data}->{_das_registry};
  }
  my $filterT = sub { return 1; };
  my $filterM = sub { return 1; };
  my $keyText = $self->param('keyText');
  my $keyMapping = $self->param('keyMapping');

  if (defined (my $dd = CGI::param('_apply_search=registry.x'))) {
    if ($keyText) {
      $filterT = sub { 
        my $src = shift; 
        return 1 if ($src->{url} =~ /$keyText/); 
        return 1 if ($src->{nickname} =~ /$keyText/); 
        return 1 if ($src->{description} =~ /$keyText/); 
        return 0;
      };
    }
    if ($keyMapping ne 'any') {
      $filterM = sub { 
        my $src = shift; 
        foreach my $cs (@{$src->{coordinateSystem}}) {
          return 1 if ($self->getEnsemblMapping($cs) eq $keyMapping);
          return 1 if ($self->getEnsemblMapping($cs) =~ /^$keyMapping/);
        }
        return 0;
      };
    }
  }
  my $das_url = $self->species_defs->DAS_REGISTRY_URL;
  my $source_arr = SOAP::Lite->service("${das_url}/services/das:das_directory?wsdl")->listServices();
  my $i = 0;
  my %registryHash = ();
  my $spec = $ENV{ENSEMBL_SPECIES};
  $spec =~ s/\_/ /g;
  while(ref $source_arr->[$i]){
    my $dassource = $source_arr->[$i++];
    next if ("@{$dassource->{capabilities}}" !~ /features/);
    foreach my $cs (@{$dassource->{coordinateSystem}}) {
      my ($smap, $sp) = $self->getEnsemblMapping($cs);
      if ($smap ne 'unknown' && ($spec =~ /$sp/) && $filterT->($dassource) && $filterM->($dassource)) {
        my $id = $dassource->{id};
        $registryHash{$id} = $dassource; 
        last;
      }
    }
  }
  $self->{data}->{_das_registry} = \%registryHash;
  return $self->{data}->{_das_registry};
}


sub getSourceData {
  my ($self, $dassource, $dasconf) = @_;

  if ($dassource->{url} =~ m!(\w+)://(.+/das)/([\w\-]+)/?!) {
    ($dasconf->{protocol}, $dasconf->{domain}, $dasconf->{dsn}) = ($1, $2, $3);
    my ($smap, $species);
    foreach my $cs (@{$dassource->{coordinateSystem}}) {
      ($smap, $species) = $self->getEnsemblMapping($cs);
      push (@{$dasconf->{mapping}}, $smap) if ($smap ne 'unknown' && (! grep {$_ eq $smap} @{$dasconf->{mapping}}));
    }
    $dasconf->{name} = $dassource->{nickname};
    ($dasconf->{url} = $dassource->{url}) =~ s!/$!!;
    $dasconf->{type} = scalar(@{$dasconf->{mapping}}) > 1 ? 'mixed' : $smap;
  }
}

1;
