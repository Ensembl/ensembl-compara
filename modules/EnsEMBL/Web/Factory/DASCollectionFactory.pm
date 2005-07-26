package EnsEMBL::Web::Factory::DASCollectionFactory;
=head1 NAME

EnsEMBL::Web::Factory::DASCollectionFactory;

=head1 SYNOPSIS

Module to create EnsEMBL::Web::Factory::DASCollection objects.

=head1 DESCRIPTION

Example:

my $dasfact = EnsEMBL::Web::Proxy::Factory->new( 'DASCollectionFactory', { '_databases' => $dbc, '_input' => $input } );
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
use EnsEMBL::Web::ExternalDAS;
use EnsEMBL::Web::Proxy::Object;
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

# Get the view that is requesting DASCollectionFactory
    my $conf_script = $self->param("conf_script") || $self->Input->script();

# Read the DAS config from the ini files
    my $das_conftype = "ENSEMBL_INTERNAL_DAS_SOURCES"; # combined GeneDAS and Internal DAS
    my %sources_conf;
    my $ini_confdata = $self->species_defs->$das_conftype() || {};
    ref( $ini_confdata ) eq 'HASH' or die("$das_conftype badly configured" );

    foreach my $source( keys %$ini_confdata ){
	my $source_confdata = $ini_confdata->{$source} || ( warn( "$das_conftype source $source not configured" ) && next );
	ref( $source_confdata ) eq 'HASH' || ( warn( "$das_conftype source $source badly configured" ) && next );
	
	# Is source enabled for this view?
	if (! defined($source_confdata->{enable})) {
	    @{$source_confdata->{enable}} = @{ $source_confdata->{on} || []}; # 
	}

	my %valid_scripts = map{ $_, 1 } @{$source_confdata->{enable}};
	$valid_scripts{$conf_script} || next;
	$source_confdata->{conftype} = 'internal'; # Denotes where conf is from
	$source_confdata->{type} ||= 'ensembl_location'; # 
	$source_confdata->{color} ||= $source_confdata->{col}; # 
	$source_confdata->{id} = $source;
	$source_confdata->{description} ||= $source_confdata->{label} ;
	$source_confdata->{stylesheet} ||= 'N';
	$source_confdata->{stylesheet} = 'Y' if ($source_confdata->{stylesheet} eq '1'); # 
	$source_confdata->{name} ||= $source;
	$source_confdata->{group} ||= 'N';
	$source_confdata->{group} = 'Y' if ($source_confdata->{group} eq '1'); # 
	
#	warn("ADD INTERNAL: $source");
#	warn(Dumper($source_confdata));
	$sources_conf{$source} = $source_confdata;
    }

# Add external sources (ones added by user)
    my $extdas = new EnsEMBL::Web::ExternalDAS();
    $extdas->getConfigs($conf_script, $conf_script);
    my %daslist = %{$extdas->{'das_storage'}->{'data'}};
	 
    for my $source ( keys %daslist ) {
	my %valid_scripts = map{ $_, 1 } @{$daslist{$source}->{enable} || [] };
	$valid_scripts{$conf_script} || next;
	
	my $das_species = $daslist{$source}->{'species'};
	next if( $das_species && $das_species ne '' && $das_species ne $ENV{'ENSEMBL_SPECIES'} );
	
	my $source_confdata = $daslist{$source};
	
#	warn("ADD EXTERNAL: $source");
#	warn(Dumper($source_confdata));
	$source_confdata->{conftype} ||= 'external';
	$sources_conf{$source} = $source_confdata;
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
	$sources_conf{$das_name}->{name} = $das_name;
	$sources_conf{$das_name}->{url} = $u;
	$sources_conf{$das_name}->{conftype} = 'url';
	$urlnum ++;
    }


# Get the sources selection, i.e which sources' annotation should be displayed
    my $uca    = $self->get_userconfig_adaptor();
    my $config = $uca->getUserConfig( 'dasconfview' );
    my $section = $conf_script;

    my @das_params = grep { $_ =~ /^:DASselect_/ } CGI::param();
    foreach my $p (@das_params) {
	( my $src = $p ) =~ s/^:DASselect_//;
	( my $sp = $p ) =~ s/^://;
	my $value = CGI::param($sp) || 0;

	if (CGI::param($sp)) {
	    $config->set($section, $src, "on", 1);
	} else {
	    $config->set($section, $src, "off", 1);
	}
    }
    $config->save( Apache->request );

    my @selection = ();

    foreach my $src (keys (%sources_conf)) {
	my $value = $config->get($section, $src) || 'undef';
	if ($value eq 'on') {
	    push(@selection, $src);
	}
    }

    $self->param("DASselect", \@selection);
    my %DASsel = map {$_ => 1} $self->param("DASselect");


# Process the dasconfig form input - Get DAS sources to add/delete/edit;
    my %das_submit = map{$_,1} ($self->param( "_das_submit" ) || ());
    my %das_del    = map{$_,1} ($self->param( "_das_delete" ) || ());
    my %urldas_del = map{$_,1} ($self->param( "_urldas_delete" ) || ());
    my %das_edit   = map{$_,1} ($self->param( "_das_edit" ) || ());
    
    foreach (keys (%das_del)){
#	warn("DELETE : $_");
	$extdas->delete_das_source($_);
	delete($sources_conf{$_});
    }
    
    foreach (keys %urldas_del){
#	warn("DELETE1 : $_");
	delete($sources_conf{$_});
    }
  
    foreach (keys %das_edit){
#	warn("EDIT : $_");
	$sources_conf{$_}->{conftype} = 'external_editing';
    }

  
    # Add '/das' suffix to _das_domain param
    if( my $domain = $self->param( "DASdomain" ) ){
	$domain =~ s/(\/das)?\/?\s*$/\/das/;
	$self->param('DASdomain',[ $domain ] );
    }
    
    # Have we got new DAS? If so, validate, and add to Input
    my @confkeys = qw( name protocol domain dsn type strand labelflag);
    
    if( $self->param("_das_submit") ){
	if ($self->param("DASsourcetype") eq 'das_url') {
	    my $url = $self->param("DASurl") || ( warn( "_error_das_url: Need a url!") &&  $self->param( "_error_das_url", ["Need a url!"] ));
	    my $das_name = "_URL_$urlnum"; 
	    
	    $sources_conf{$das_name}->{name} = $das_name;
	    $sources_conf{$das_name}->{url} = $url;
	    $sources_conf{$das_name}->{conftype} = 'url';
	} else {
	    my $err = 0;
	    my %das_data;
	    foreach my $key( @confkeys ){
		$das_data{$key} = $self->param("DAS${key}") || ( warn( "_error_das_$key: Need a $key!") &&  $self->param( "_error_das_$key", ["Need a $key!"] ) && $err++ );
	    }
	    
	    if( ! $err ){
		# Check if new name exists, and not source edit. If so, make new name.
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
		$das_data{group} = $self->param('DASgroup');
		$das_data{url} = $das_data{protocol}.'://'.$das_data{domain};
		@{$das_data{enable}} = $self->param('DASenable');
		$das_data{conftype} = 'external';
		$das_data{color} = $self->param("DAScolor");
		$das_data{depth} = $self->param("DASdepth");
		$das_data{help} = $self->param("DAShelp");
		$das_data{active} = 1; # Enable by default
					 
		foreach my $key( @confkeys, 'label', 'url', 'conftype', 'group', 'stylesheet', 'enable', 'caption', 'active', 'color', 'depth', 'help' ) {
		    $sources_conf{$das_name} ||= {};
		    $sources_conf{$das_name}->{$key} = $das_data{$key};
		}
		$extdas->add_das_source(\%das_data);
		$DASsel{$das_name} = 1;
	    }
				
	}
    }
    # Clean up any 'dangling' _das parameters
    if( $self->Input->delete( "_das_delete" ) ){
	foreach my $key( @confkeys ){ $self->Input->delete("DAS$key") }
    }
  
    my @udaslist = ();
    my @das_objs = ();
 
# Now we have a list of all active das sources - for each of them  create a DAS adaptor capable of retrieving das features 
    foreach my $source( sort keys %sources_conf ){
#        warn ("create adaptor for $source ");
	# Create the DAS adaptor from the (valid) conf
	my $source_conf = $sources_conf{$source};
	push (@udaslist, "URL:$source_conf->{url}") if ($source_conf->{conftype} eq 'url');
		  
	$source_conf->{active} = defined ($DASsel{$source}) ? 1 : 0;

#    warn (Dumper($source_conf)) if ($source_conf->{conftype} ne 'internal');

	if( ! $source_conf->{url} and ! ( $source_conf->{protocol} && $source_conf->{domain} ) ){
	    next;
	}
	my $das_adapt = Bio::EnsEMBL::ExternalData::DAS::DASAdaptor->new
	    ( 
	      -name       => $source,
	      -url        => $source_conf->{url}       || '',
	      -protocol   => $source_conf->{protocol}  || '',
	      -domain     => $source_conf->{domain}    || '',
	      -dsn        => $source_conf->{dsn}       || '',
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
	      -conftype   => $source_conf->{conftype}  || 'external',
	      -active     => $source_conf->{active}    || 0, 
	      -description => $source_conf->{description}    || '', 
	      -types      => $source_conf->{types} || [],
	      -on         => $source_conf->{on}    || [],
	      -enable     => $source_conf->{enable}    || [],
	      -help     => $source_conf->{help}    || '',
	      -fasta      => $source_conf->{fasta} || [],
	      );				
	$das_adapt->ensembldb( $self->DBConnection('core') );
	if( my $p = $self->species_defs->ENSEMBL_WWW_PROXY ){
	    $das_adapt->proxy($p);
	}

	# Create the DAS object itself
	my $das_obj = Bio::EnsEMBL::ExternalData::DAS::DAS->new( $das_adapt );
	push @das_objs, $das_obj;
    }

    my $conf_params = '';

    push(@{$script_params{h}}, @udaslist);  
    
    foreach (keys (%script_params)) {
	my $v = join('|', @{$script_params{$_}});  
	$conf_params .= "zzz$_=$v";
    }
    
    $conf_params =~ s/^zzz//;
    $self->param('conf_script_params', [$conf_params]);
    
    
    # Create the collection object
    my $dataobject = EnsEMBL::Web::Proxy::Object->new( 'DASCollection', [@das_objs], $self->__data );
    $self->DataObjects( $dataobject );
    
  return 1; #success
}

