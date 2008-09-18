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

  my %sources_conf;
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
  my $config = $self->get_imageconfig( 'dasconfview' );
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
    $self->get_session->remove_das_source($_);
    delete($sources_conf{$_});
  }
  foreach (keys %urldas_del){
    delete($sources_conf{$_});
  }
  
  if (defined(my $dedit  = $self->param("DASedit"))) {
    $sources_conf{$dedit}->{conftype} = 'external_editing';
  }

  my @confkeys = qw( name type);
  my @allkeys = ('strand', 'labelflag', 'label', 'url', 'conftype', 'group', 'stylesheet', 'score', 'fg_merge', 'fg_grades', 'fg_data', 'fg_min', 'fg_max', 'caption', 'active', 'color', 'depth', 'help', 'linktext', 'linkurl', 'assembly' );
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
 
  if( $self->param("_das_submit") ){
    if ($self->param("DASsourcetype") eq 'das_url') {
      my $url = $self->param("DASurl") || ( warn( "_error_das_url: Need a url!") &&  $self->param( "_error_das_url", "Need a url!" ));
      my $das_name = "_URL_$urlnum"; 
      
      $sources_conf{$das_name}->{name} = $das_name;
      $sources_conf{$das_name}->{url} = $url;
      $sources_conf{$das_name}->{conftype} = 'url';
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
        my $shash = $self->getServerSources($self->param('DASdomain'));
 #       warn Dumper ($shash);
        foreach my $id ($self->param("DASdsns")) {
#	  warn "SRC: $id";
#	  warn Dumper $shash->{$id};
	  if (exists $shash->{$id} ) {
#	  	warn "E";
	  } else {
	    $shash->{$id} = {
            'id'  => $id,
            'url' => join ('/', $self->param('DASdomain'), $id),
            'url' => $self->param('DASdomain'),
            'dsn' => $id,
	    'name' => $id,
            };
	  }
	  
          foreach my $key( @confkeys, @allkeys){
            if (defined($self->param("DAS${key}"))) {
              $shash->{$id}->{$key} = $self->param("DAS${key}");
            }
          }
          push @das_sources, $shash->{$id};
	}
      }
# warn "FF:",Dumper(\@das_sources);

      foreach my $das_data (@das_sources) {
        my $das_name = $das_data->{'name'} or next;
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
	$das_data->{'name'} = $das_name;
	
        $das_data->{active} = 1; # Enable by default
    # Add to the conf list
        $das_data->{id} = $das_data->{name} if ($das_data->{name} ne $das_name);
        $das_data->{label} ||= $das_data->{name};
        $das_data->{caption} ||= $das_data->{name};
        @{$das_data->{enable}} = $self->param('DASenable');
        $das_data->{mapping} or @{$das_data->{mapping}} = grep { $_ } $self->param('DAStype');
        $das_data->{type} = 'mixed' if (scalar(@{$das_data->{mapping}}>1));
        $das_data->{conftype} = 'external';
        $das_data->{species} = $self->species;
        $sources_conf{$das_name} ||= {};
        foreach my $key( @confkeys, @allkeys, 'dsn', 'enable', 'mapping') {
          $sources_conf{$das_name}->{$key} = $das_data->{$key};
        }
#	warn "DATA ($das_name)";
#warn Dumper($das_data);
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
#warn Dumper($source_conf);
    push (@udaslist, "URL:$source_conf->{url}") if ($source_conf->{conftype} eq 'url');
    if( ! $source_conf->{url} and ! ( $source_conf->{protocol} && $source_conf->{domain} ) ){
      next;
    }
    $source_conf->{active} = defined ($DASsel{$source}) ? 1 : 0;
    $source_conf->{label} ||= $source_conf->{name};
    my $das_adapt = Bio::EnsEMBL::ExternalData::DAS::DASAdaptor->new( 
      -name       => $source,
      -timeout    => $self->species_defs->ENSEMBL_DAS_TIMEOUT,
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
      -assembly_version	  => $source_conf->{assembly} || '',
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
          : $realm eq 'HUGO_ID'       ? 'hgnc'
          : $realm eq 'HGNC_ID'       ? 'hgnc'
          : $realm eq 'MGI'           ? 'mgi_acc'
          : $realm eq 'MarkerSymbol'  ? 'mgi'
          : $realm eq 'MGISymbol'     ? 'mgi'
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

sub getServerSources {
  my $self = shift;
  my ($url) = @_;
  if (defined($self->{data}->{_das_sources}->{$url})) {
    return $self->{data}->{_das_sources}->{$url};
  }
  
#    next if ("@{$dassource->{capabilities}}" !~ /features/);
#    foreach my $cs (@{$dassource->{coordinateSystem}}) {
#      my ($smap, $sp) = $self->getEnsemblMapping($cs);

  my $spec = $ENV{ENSEMBL_SPECIES};

  my $filterT = sub { return 1; };
  my $filterM = sub { my $src = shift;  return 1 unless defined ($src->{species}); return 1 if ($src->{species} eq $spec);  return 0};
  my $keyText = $self->param('keyText');
  my $keyMapping = $self->param('keyMapping');

  if (defined (CGI::param('_apply_search=registry.x')) || defined ($self->param('_das_filter'))) {
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
          return 1 if ($self->getEnsemblCoordinateSystem($cs) eq $keyMapping);
          return 1 if ($self->getEnsemblCoordinateSystem($cs) =~ /^$keyMapping/);
        }
        return 0;
      };
    }
  }

  my $adaptor = Bio::EnsEMBL::ExternalData::DAS::DASAdaptor->new(
    -url  => $url, -timeout   => $self->species_defs->ENSEMBL_DAS_TIMEOUT,
    -proxy_url => $self->species_defs->ENSEMBL_WWW_PROXY
  );
  my $das = Bio::EnsEMBL::ExternalData::DAS::DAS->new ( $adaptor );
  my %dsnhash = map {$_->{id}, $_} grep {$filterT->($_) && $filterM->($_) } @{ $das->fetch_sources_info };
  if( %dsnhash ){
    $self->{data}->{_das_sources}->{$url} = \%dsnhash;
  } else {
    $self->param('_error_das_domain', 'No sources for domain');
  }
  return $self->{data}->{_das_sources}->{$url};
}


1;
