package EnsEMBL::Web::UserConfig;

use strict;
use Data::Dumper;
use Storable qw( nfreeze freeze thaw);
use Sanger::Graphics::TextHelper;
use Bio::EnsEMBL::Registry;
my $reg = "Bio::EnsEMBL::Registry";

#########
# 'general' settings contain defaults.
# 'user' settings are restored from cookie if available
# 'general' settings are overridden by 'user' settings
#

sub TRIM   { return sub { return $_[0]=~/(^[^\.]+)\./ ? $1 : $_[0] }; }

sub update_config_from_parameter {
  my( $self, $string ) = @_;
  my @array = split /\|/, $string;
  shift @array;
  return unless @array;
  foreach( @array ) {
    my( $key, $value ) = split ':';
    if( $key =~ /bump_(.*)/ ) {
      $self->set( $1, 'compact', $value eq 'on' ? 0 : 1 );
    } elsif( $key eq 'imagemap' || $key=~/^opt_/ ) {
      $self->set( '_settings', $key, $value eq 'on' ? 1: 0 );
    } elsif( $key =~ /managed_(.*)/ ) {
      $self->set( $key, 'on', $value, 1 );
    } else {
      $self->set( $key, 'on', $value );
    }
  }
  $self->save( );
}

sub add_track {
  my ($self, $code, %pars) = @_;
  ## Create drop down menu entry
  if( $pars{ '_menu'} ) {
    push @{ $self->{'general'}->{$self->{'type'}}{'_settings'}{$pars{'_menu'}} ||[] }, [ $code, $pars{'_menu_caption'} || $pars{'caption'} ];
    delete $pars{'_menu'};
    delete $pars{'_menu_caption'};
  }
  push @{$self->{'general'}->{$self->{'type'}}->{'_artefacts'}}, $code;
  $self->{'general'}->{$self->{'type'}}->{$code} = {%pars};
  ## Create configuration entry....
}

sub add_new_simple_track {
  my( $self, $code, $text_label, $colour, $pos, %pars ) = @_;
  #warn "$code - $text_label - $colour - $pos";
  $self->add_track( $code,
    'on'         => 'off',
    'pos'        => $pos,
    'col'        => $colour,
    'glyphset'   => 'generic_simplest',
    '_menu'      => 'features',
    'available'  => "features $code",
    'str'        => 'r',
    'label'      => $text_label,
    'caption'    => $text_label,
    'code'       => $code,
    %pars
  );
}
sub add_new_synteny_track {
  my( $self, $species, $short, $pos ) = @_;
  $self->add_track( "synteny_$species",
    "_menu" => 'compara',
    'height'    => 4,
    'glyphset'  => "generic_synteny",
    'label'     => "$short synteny",
    'caption'   => "$short synteny",
    'species'   => $species,
    'available' => "multi SYNTENY|$species",
    'on'        => 'on',
    'pos'       => $pos,
    'str'       => 'f',
    'dep'       => 20,
  );
}

sub add_new_track_transcript {
  my( $self, $code, $text_label, $colours, $pos, %pars ) = @_;
  my $available = $pars{'available'} || "features $code";
  delete( $pars{'available'} );
  $self->add_track( $code."_transcript",
    '_menu'       => 'features',
    'on'          => 'on',
    'colours'     => { $self->{'_colourmap'}->colourSet( $colours ) },
    'colour_set'  => $colours,
    'pos'         => $pos,
    'str'         => 'b',
    'compact'     => 0,
    'join'        => 0,
    'join_x'      => -10,
    'join_col'    => 'blue',
    'track_label' => $text_label,
	'label'       => $text_label,
    'caption'     => $text_label,
    'available'   => $available,
	'zmenu_caption' => $text_label,
    'author'      => $pars{'author'},
	'glyphset'    => $pars{'glyph'},
    %pars
  );
}

sub add_new_track_generictranscript{
  my( $self, $code, $text_label, $colour, $pos, %pars ) = @_;
  my $available = $pars{'available'} || "features $code";
  delete( $pars{'available'} );
  $self->add_track( $text_label,
    'glyphset'    => 'generic_transcript',
    'LOGIC_NAME'  => $code,
    '_menu'       => 'features',
    'on'          => 'on',
    'col'         => $colour,
    'pos'         => $pos,
    'str'         => 'b',
    'hi'          => 'highlight1',
    'compact'     => 0,
    'track_label' => $text_label,
    'caption'     => $text_label,
    'available'   => $available,
    %pars
  );
}

sub add_new_track_predictiontranscript {
  my( $self, $code, $text_label, $colour, $pos, $additional_zmenu, %pars ) = @_;
  $self->add_track( $code,
    'glyphset'    => 'prediction_transcript',
    'LOGIC_NAME'  => $code,
    '_menu'       => 'features',
    'on'          => 'on',
    'col'         => $colour,
    'pos'         => $pos,
    'str'         => 'b',
    'hi'          => 'highlight1',
    'compact'     => 0,
    'track_label' => $text_label,
    'caption'     => $text_label,
    'available'   => "features $code",
    'ADDITIONAL_ZMENU' => $additional_zmenu || {},
    %pars
  );
}

sub add_new_track_gene {
  my( $self, $code, $text_label, $colours, $pos, %pars ) = @_; 
  $self->add_track( "gene_$code",
    '_menu'       => 'features',
    'on'          => 'on',
    'colour_set'  => $colours,
    'gene_col'    => $code,
    'pos'         => $pos,
    'glyphset'    => 'generic_gene',
    'threshold'   => 2e6,
    'navigation_threshold' => 1e4,
    'navigation'  => 'on',
    'label_threshold' => 1e4,
    'database'    => '',
    'logic_name'  => $code,
    'available'   => "features $code",
    'caption'     => $text_label,
    'track_label' => $text_label,
    'label'       => $text_label,
    %pars
  );
}
sub add_new_track_cdna {
  my( $self, $code, $text_label, $pos, %pars ) = @_;
  $self->add_track( $code, 
    '_menu'       => 'features',
    'on'          => "on",
    'colour_set'  => 'cdna',
    'dep'         => '6',
    'str'         => 'b',
    'compact'     => 0,
    'glyphset'    => 'generic_match',
    'SUBTYPE'     => sub {$_[0] =~ /^NM_/ ? 'refseq' : ( $_[0] =~ /(RO|ZX|PX|ZA|PL)\d{5}[A-Z]\d{2}/ ? 'riken' : 'default') },
    'URL_KEY'     => { 'refseq' => 'REFSEQ', 'riken' => 'RIKEN', 'default' => 'EMBL', 'genoscope_ecotig' => 'TETRAODON_ECOTIG', 'genoscope' => 'TETRAODON_CDM' },
    'ID'          => { 'refseq' => TRIM },
    'ZMENU'       => {
                     'refseq'  => [ '###ID###', "REFSEQ: ###ID###" => '###HREF###' ],
                     'riken'   => [ '###ID###', "RIKEN:  ###ID###" => '###HREF###' ],
                     'genoscope_ecotig'   => [ '###ID###', "Genoscope Ecotig:  ###ID###" => '###HREF###' ],
                     'genoscope'          => [ '###ID###', "Genoscope:  ###ID###" => '###HREF###' ],
                     'default' => [ '###ID###', "EMBL:   ###ID###" => '###HREF###' ],
    },
    'pos'         => $pos, 
    'available'   => "features $code",
    'caption'     => $text_label,
    'TEXT_LABEL'  => $text_label,
    'FEATURES'    => $code,
    %pars
  )
}

sub add_new_track_mrna {
  my( $self, $code, $text_label, $pos, %pars ) = @_;
  $self->add_track( $code,
    '_menu'       => 'features',
    'on'          => "on",
    'colour_set'  => 'mrna',
    'dep'         => '6',
    'str'         => 'b',
    'compact'     => 0,
    'glyphset'    => 'generic_match',
    'SUBTYPE'     => sub { return 'default'; },
    'URL_KEY'     => 'EMBL',
    'ZMENU'       => [ '###ID###', "EMBL: ###ID###" => '###HREF###' ],
    'pos'         => $pos,
    'available'   => "features $code",
    'caption'     => $text_label,
    'TEXT_LABEL'  => $text_label,
    'FEATURES'    => $code,
    %pars
  )
}

sub add_new_track_rna {
  my( $self, $code, $text_label, $pos, %pars ) = @_;
  $self->add_track( $code,
    '_menu'       => 'features',
    'on'          => "on",
    'colour_set'  => 'rna',
    'dep'         => '6',
    'str'         => 'b',
    'compact'     => 0,
    'glyphset'    => 'generic_match',
    'SUBTYPE'     => $code,
    'URL_KEY'     => { 'miRNA_Registry' => 'MIRBASE', 'RFAM' => 'RFAM' },
    'ZMENU'       => {
      'miRNA_Registry' => [ '###ID###', "miRbase: ###ID###" => '###HREF###' ],
      'RFAM'           => [ '###ID###', "RFRAM: ###ID###" => '###HREF###' ]
    },
    'pos'         => $pos,
    'available'   => "features $code",
    'caption'     => $text_label,
    'TEXT_LABEL'  => $text_label,
    'FEATURES'    => $code,
    %pars
  )
}

sub add_new_track_protein {
  my( $self, $code, $text_label, $pos, %pars ) = @_;
  $self->add_track( $code,
    '_menu'       => 'features',
    'on'          => "on",
    'colour_set'  => 'protein',
    'CALL'        => 'get_all_ProteinAlignFeatures',
    'dep'         => '6',
    'str'         => 'b',
    'compact'     => 0,
    'glyphset'    => 'generic_match',
    'SUBTYPE'     => sub { $_[0] =~ /^NP_/ ? 'refseq' : 'default' } ,
    'URL_KEY'     => 'SRS_PROTEIN', 'ID' => TRIM, 'LABEL' => TRIM,
    'ZMENU'       => [ '###ID###' , 'Protein homology ###ID###', '###HREF###' ],
    'pos'         => $pos,
    'available'   => "features $code",
    'caption'     => $text_label,
    'TEXT_LABEL'  => $text_label,
    'FEATURES'    => $code,
    %pars
  )
}

sub add_new_track_est {
  my( $self, $code, $text_label, $pos, %pars ) = @_;
  $self->add_track( $code,
    '_menu'       => 'features',
    'on'          => "off",
    'colour_set'  => 'est',
    'dep'         => '6',
    'str'         => 'b',
    'compact'     => 0,
    'glyphset'    => 'generic_match',
    'SUBTYPE'     => sub { $_[0] =~ /^BX/ ? 'genoscope' : 'default' },
    'URL_KEY'     => 'EMBL',
    'pos'         => $pos,
    'available'   => "features $code",
    'caption'     => $text_label,
    'TEXT_LABEL'  => $text_label,
    'FEATURES'    => $code,
    'ZMENU'       => [ 'EST', "EST: ###ID###" => '###HREF###' ],
    %pars
  )
}

sub new {
  my $class   = shift;
  my $adaptor = shift;
  my $type    = $class =~/([^:]+)$/ ? $1 : $class;
  my $self = {
    '_colourmap' 	=> $adaptor->{'colourmap'},
    '_texthelper' 	=> new Sanger::Graphics::TextHelper,
    '_db'         	=> $adaptor->{'user_db'},
    'type'              => $type,
    'species'           => $ENV{'ENSEMBL_SPECIES'} || '', 
    'species_defs'      => $adaptor->{'species_defs'},
    'exturl'            => $adaptor->{'exturl'},
    'general'           => {},
    'user'        	=> {},
    '_managers'         => {}, # contains list of added features....
    '_useradded'        => {}, # contains list of added features....
    '_userdatatype_ID'	=> 0, 
    '_r'                => $adaptor->{'r'} || undef,
    'no_load'     	=> undef,
  };

  bless($self, $class);

		
  ########## init sets up defaults in $self->{'general'}
  $self->init( ) if($self->can('init'));
  $self->das_sources( @_ ) if(@_); # we have das sources!!

  ########## load sets up user prefs in $self->{'user'}
  $self->load() unless(defined $self->{'no_load'});
  return $self;
}

sub set_species {
  my $self = shift;
  $self->{'species'} = shift; 
}

sub artefacts { my $self = shift; return @{ $self->{'general'}->{$self->{'type'}}->{'_artefacts'}||[]} };

sub remove_artefacts {
  my $self = shift;
  my %artefacts = map { ($_,1) } @_;
  @{ $self->{'general'}->{$self->{'type'}}->{'_artefacts'} } = 
    grep { !$artefacts{$_} } $self->subsections( );
}
  
sub add_artefacts {
  my $self = shift;
  $self->_set( $_, 'on', 'on') foreach @_;
  push @{$self->{'general'}->{$self->{'type'}}->{'_artefacts'}}, @_;
}

# add general and artefact settings
sub add_settings {
    my $self = shift;
    my $settings = shift;
    foreach (keys %{$settings}) {
        $self->{'general'}->{$self->{'type'}}->{$_} = $settings->{$_};
    }
}

sub turn_on {
  my $self = shift;
  $self->_set( $_, 'on', 'on') foreach( @_ ? @_ : $self->subsections( 1 ) ); 
}

sub turn_off {
  my $self = shift;
  $self->_set( $_, 'on', 'off') foreach( @_ ? @_ : $self->subsections( 1 ) ); 
}

sub _set {
  my( $self, $entry, $key, $value ) = @_;
  $self->{'general'}->{$self->{'type'}}->{$entry}->{$key} = $value;
}

sub load {
  my ($self) = @_;
  #warn "LOADING.... ".$ENV{'ENSEMBL_FIRSTSESSION'}," ... $self->{'type'}";
  if($self->{'_db'}) {
    my $TEMP = $self->{'_db'}->getConfigByName( $ENV{'ENSEMBL_FIRSTSESSION'}, $self->{'type'} );
    eval {
      $self->{'user'} = Storable::thaw( $TEMP ) if $TEMP;
    };
  }
  return;
}

sub save {
    my ($self) = @_;
    $self->{'_db'}->setConfigByName(
    	$self->{'_r'}, $ENV{'ENSEMBL_FIRSTSESSION'}, $self->{'type'},
    	&Storable::nfreeze($self->{'user'})
    ) if($self->{'_db'});
    return;
}

sub reset {
  my ($self) = @_;
  my $script = $self->script();
  $self->{'user'}->{$script} = {}; 
  $self->save( );
  return;
}

sub dump {
    my ($self) = @_;
    print STDERR Dumper($self);
}

sub script {
    my ($self) = @_;
    my @keys = keys %{$self->{'general'}};
    return $keys[0];
}

#########
# return artefacts on scripts
#
sub subsections {
  my ($self,$flag) = @_;
  my @keys;
  @keys = grep { /^managed_/ } keys %{$self->{'user'}} if $flag==1;
  return @{$self->{'general'}->{$self->script}->{'_artefacts'}},@keys;
}

#########
# return available artefacts on scripts 
#
sub get_available_artefacts{
  my ($self) = @_;
  # Loop for all artefacts 
  my @available_artefacts;
  foreach( $self->subsections() ){
    # Test availability
    push( @available_artefacts, $_ ) if $self->is_available_artefact($_); 
  }
  # Return available only
  return( @available_artefacts );
}

sub required_databases {
  my $self = shift;
  my %databases;
  foreach my $a ( $self->get_available_artefacts ) {
    next unless $self->get( $a , 'on' ) eq 'on';
    # get databases based on 'available' condition
    my @test = split( ' ', $self->get( $a, 'available' ) );
    if( $test[0] eq 'database_tables' ) {
       my( $database, $table ) = split( '\.', $test[1] );
       $database = lc($1) if $database =~ /^ENSEMBL_(.*)$/;
       $databases{$database}=1;
    } elsif( $test[0] eq 'database_features' ) {
       my( $database, $logic_name) = split /\./, $test[1];
       $database = lc($1) if $database =~ /^ENSEMBL_(.*)$/;
       $databases{$database}=1;
    } elsif( $test[0] eq 'databases' ) {
       my $database = $test[1];
       $database = lc($1) if $database =~ /^ENSEMBL_(.*)$/;
       $databases{$database}=1;
    } elsif( $test[0] eq 'multi' ) {
       $databases{'compara'}=1;
    }
    # get additional configured databases
    map { $databases{$_} = 1 } split(/,/, $self->get($a, 'databases'));
  }
  return keys %databases;
}

########
# tests whether a given artifact is available.
# data availability test for a feature is defined in the
# appropriate WebUserConfig file  
# IN: self, artifact
# OUT: 999 (no test found)
#      1   (data available)
#      0   (test failed)
sub is_available_artefact {
  my $self = shift;
  my $artefact = shift || return undef();
  my $DEBUG = shift;
  my $settings = $self->values($artefact);
  return 0 unless $settings && %$settings;
  return $self->_is_available_artefact( $settings->{available} );
}
 
sub _is_available_artefact{
  my $self     = shift;
  my $available = shift;

  my @test = split( ' ', $available );
  if( ! $test[0] ){ return 999; } # No test found - return pass.

  my( $success, $fail ) = ($test[0] =~ s/^!//) ? ( 0, 1 ) : ( 1, 0 );

  if( $test[0] eq 'database_tables' ){ # Then test using get_table_size
    my( $database, $table ) = split( '\.', $test[1] );
    return $self->{'species_defs'}->get_table_size(
          { -db    => $database, -table => $table },
          $self->{'species'}
      ) ? $success : $fail;
  } elsif( $test[0] eq 'multi' ) { # See whether the traces database is specified
    my( $type,$species ) = split /\|/,$test[1],2;
    my %species = $self->{'species_defs'}->multi($type, $self->{'species'});
    return $success if exists( $species{$species} );
    return $fail;
  } elsif( $test[0] eq 'database_features' ){ # See whether the given database is specified
    my $ft = $self->{'species_defs'}->other_species($self->{'species'},'DB_FEATURES') || {};
    return $fail unless $ft->{uc($test[1])};
    return $success;
  } elsif( $test[0] eq 'databases' ){ # See whether the given database is specified
    my $db = $self->{'species_defs'}->other_species($self->{'species'},'databases')  || {};
    return $fail unless $db->{$test[1]}       ;
    return $fail unless $db->{$test[1]}{NAME} ;
    return $success;
  } elsif( $test[0] eq 'features' ){ # See whether the given db feature is specified
    my $ft = $self->{'species_defs'}->other_species($self->{'species'},'DB_FEATURES') || {};
    return $fail unless $ft->{uc($test[1])}   ;
    return $success;
  } elsif( $test[0] eq 'any_feature' ){ # See whether any of the given db features is specified
    my $ft = $self->{'species_defs'}->other_species($self->{'species'},'DB_FEATURES') || {};
    shift @test;
    foreach (@test) {
      return $success if $ft->{uc($_)};
    }
    return $fail;
  } elsif( $test[0] eq 'species') {
    if($reg->get_alias($self->{'species'},"no throw") ne $reg->get_alias($test[1],"no throw")){
      return $fail;
    }
  } elsif( $test[0] eq 'das_source' ){ # See whether the given DAS source is specified
    my $source = $self->{'species_defs'}->ENSEMBL_INTERNAL_DAS_SOURCES || {};
    return $fail unless $source->{$test[1]}   ;
    return $success;
  }

  return $success; # Test not found - assume a pass anyway!
}

#########
# return a list of the available options for this set of artefacts
#
sub options {
  my ($self) = @_;
  my $script = $self->script();
  return @{$self->{'general'}->{$script}->{'_options'}};
}

sub is_setting {
  my ($self,$key) = @_;
  my $script = $self->script();
  return exists $self->{'general'}{$script}{'_settings'}{$key};
}
#########
# return a hashref of settings (user XOR general) for artefacts on scripts
#
sub values {
  my ($self, $subsection) = @_;
  my $userref;
  my $genref;
  my $hashref;

  my $script = $self->script();
  return {} unless(defined $self->{'general'}->{$script});
  return {} unless(defined $self->{'general'}->{$script}->{$subsection});

  $userref = $self->{'user'}->{$script}->{$subsection};
  $genref  = $self->{'general'}->{$script}->{$subsection};
    
  for my $key (keys %{$genref}) {
	$$hashref{$key} = $$userref{$key} || $$genref{$key}; 
  }
  return $hashref;
}

sub canset {
    my ($self, $subsection, $key) = @_;
    my $script = $self->script();

    return 1 if($self->useraddedsource( $subsection ));
    return 1 if(defined $self->{'general'}->{$script}->{$subsection}->{$key});
    return undef;
}

sub useraddedsource {
    my ( $self, $subsection ) = @_;
    my $useradded = $self->{'_useradded'};
    return exists $useradded->{$subsection};
}

sub set {
    my ($self, $subsection, $key, $value, $force) = @_;
    my $script = $self->script();
    return unless(defined $key && defined $script && defined $subsection);
    if( $force == 1 ) {
	$self->{'user'}->{$script}->{$subsection} ||= {}; 
    } else {
    	return unless(defined $self->{'general'}->{$script});
    	return unless(defined $self->{'general'}->{$script}->{$subsection});
    	return unless(defined $self->{'general'}->{$script}->{$subsection}->{$key});
    }
    $self->{'user'}->{$script}->{$subsection}->{$key} = $value;
}

sub get {
    my ($self, $subsection, $key) = @_;
    my $script = $self->script();

    return unless(defined $key && defined $script && defined $subsection);
    my $user_pref = undef;
    if(defined $self->{'user'}->{$script} &&
       defined $self->{'user'}->{$script}->{$subsection}) {
	$user_pref = $self->{'user'}->{$script}->{$subsection}->{$key};
    }
    return $user_pref if(defined $user_pref);

    return unless(defined $self->{'general'}->{$script});
    return unless(defined $self->{'general'}->{$script}->{$subsection});
    return unless(defined $self->{'general'}->{$script}->{$subsection}->{$key});

    my $default   = $self->{'general'}->{$script}->{$subsection}->{$key};
    return $default;
}

sub species_defs { return  $_[0]->{'species_defs'}; }
sub colourmap {
    my ($self) = @_;
    return $self->{'_colourmap'};
}

sub image_width {
    my ($self, $script) = @_;
    return $self->{'panel_width'} || $self->get('_settings','width');
}

sub image_height {
    my ($self, $height) = @_;
    $self->{'_height'} = $height if (defined $height);
    return $self->{'_height'};
}

sub bgcolor {
    my ($self, $script) = @_;
    return $self->get('_settings','bgcolor');
}

sub bgcolour {
    my ($self, $script) = @_;
    return $self->bgcolor($script);
}

sub texthelper {
    my ($self) = @_;
    return $self->{'_texthelper'};
}

sub scalex {
    my ($self, $val) = @_;
    if(defined $val) {
    	$self->{'_scalex'} = $val;
	    $self->{'_texthelper'}->scalex($val);
    }
    return $self->{'_scalex'};
}

sub set_width {
  my( $self, $val ) = @_;
  $self->set( '_settings', 'width', $val );
}
sub container_width {
    my ($self, $val) = @_;
    if(defined $val) {
        $self->{'_containerlength'} = $val;
	
	my $width = $self->image_width();
	$self->scalex($width/$val);
    }
    return $self->{'_containerlength'};
}

sub transform {
    my ($self) = @_;
    return $self->{'transform'};
}

#----------------------------------------------------------------------
=head2 das_sources

  Arg [1]   : Hashref - representation of das sources;
              {$key=>{label=>$label, on=>$on_or_off, ...}}
  Function  : Adds a track to the config for each das source representation
              - Adds track to '_artefacts'
              - Adds manager of type 'das'
  Returntype: Boolean
  Exceptions:
  Caller    :
  Example   :

=cut

sub das_sources {
    my( $self, $das_sources) = @_;

    $self->{'_das_offset'} ||= 2000;
    (my $NAME = ref($self) ) =~s/.*:://;
    my $cmap = $self->{'_colourmap'};

    foreach( sort { 
	$das_sources->{$a}->{'label'} cmp $das_sources->{$b}->{'label'} 
      } keys %$das_sources ) {

	my $das_source = $das_sources->{$_};

        my $on = 'off';
        if($das_source->{'on'} eq 'on') {
            $on = 'on';
        } elsif( ref($das_source->{'on'}) eq 'ARRAY' ) {
            foreach my $S (@{$das_source->{'on'}}) {
                $on = 'on' if $S eq $NAME;
            }
        }

        my $col = $das_source->{'col'};
	$col = $cmap->add_hex($col) unless $cmap->is_defined($col);
	my $manager = $das_source->{'manager'}    || 'das';

        $self->{'general'}->{$NAME}->{$_} = {
            'on'         => $on,
            'pos'        => $self->{'_das_offset'},
            'col'        => $col,
            'manager'    => $manager,
            'group'      => $das_source->{'group'}      || 0,
            'dep'        => $das_source->{'depth'}      || 0,
            'stylesheet' => $das_source->{'stylesheet'} || 'N',
            'str'        => $das_source->{'strand'}     || 'b',
            'labelflag'  => $das_source->{'labelflag'}  || 'N',
            'fasta'      => $das_source->{'fasta'}      || [],
        };

        push @{$self->{'general'}->{$NAME}->{'_artefacts'}}, $_;
	$self->{'_managers'}->{$manager} ||= [];
        $self->{'_das_offset'}++;
    }

    return 1;
}

sub ADD_ALL_DNA_FEATURES {
  my $self = shift;
  my $POS  = shift || 2300;
  $self->add_new_track_mrna( 'unigene', 'Unigene', $POS++, 'URL_KEY' => 'UNIGENE', 'ZMENU'       => [ '###ID###' , 'Unigene cluster ###ID###', '###HREF###' ], @_ );
  $self->add_new_track_mrna( 'vertrna', 'EMBL mRNAs', $POS++, @_ );
  $self->add_new_track_mrna( 'celegans_mrna', 'C.elegans mRNAs', $POS++, @_ );
  $self->add_new_track_mrna( 'cbriggsae_mrna', 'C.briggsae mRNAs', $POS++, @_ );

  $POS = shift || 2400;
  $self->add_new_track_cdna( 'human_cdna', 'Human cDNAs',   $POS++, @_ );
  $self->add_new_track_cdna( 'dog_cdna',   'Dog cDNAs',     $POS++, @_ );
  $self->add_new_track_cdna( 'rat_cdna',   'Rat cDNAs',     $POS++, @_ );
  $self->add_new_track_cdna( 'zfish_cdna', 'D.rerio cDNAs', $POS++,
        'SUBTYPE'    => sub { return $_[0] =~ /WZ/ ? 'WZ' : ( $_[0] =~ /IMCB/ ? 'IMCB_HOME' : 'EMBL' ) },
        'ID'         => sub { return $_[0] =~ /WZ(.*)/ ? $1 : $_[0] },
        'LABEL'      => sub { return $_[0] },
        'ZMENU'      => [ 'EST cDNA', "EST: ###LABEL###" => '###HREF###' ],
        'URL_KEY'    => { 'WZ' => 'WZ', 'IMCB_HOME' => 'IMCB_HOME', 'EMBL' => 'EMBL' },
                             ,@_ );
  $self->add_new_track_cdna( 'Exonerate_cDNA', 'Ciona cDNAs', $POS++, @_ );
  $self->add_new_track_cdna( 'Btaurus_Exonerate_cDNA',   'Cow cDNAs', $POS++, @_ );
  $self->add_new_track_cdna( 'Cow_cDNAs',   'Cow cDNAs', $POS++, @_ );
  $self->add_new_track_cdna( 'chicken_cdna', 'G.gallus cDNAs', $POS++, @_ );
  $self->add_new_track_cdna( 'macaque_cdna', 'Macaque cDNAs', $POS++, @_ );
  $self->add_new_track_cdna( 'fugu_cdnas', 'F.rubripes cDNAs', $POS++, @_ );
  $self->add_new_track_cdna( 'mouse_cdna', 'Mouse cDNAs',   $POS++, @_ );
  $self->add_new_track_cdna( 'other_cdna', 'Other cDNAs',   $POS++, @_ );
## now the tetraodon tracks...
  $self->add_new_track_cdna( 'cdm', 'Tetraodon cDNAs',   $POS++, 'SUBTYPE'     => 'genoscope', 'on' => 'off', @_ );
  $self->add_new_track_cdna( 'xlaevis_cDNA', 'X.laevis cDNAs',   $POS++, @_ );
  $self->add_new_track_cdna( 'xtrop_cDNA', 'X.trop cDNAs',   $POS++, @_ );
  $self->add_new_track_cdna( 'ep3_h', 'Ecotig (Human prot)',   $POS++, 'SUBTYPE'     => 'genoscope_ecotig', 'on' => 'off', @_ );
  $self->add_new_track_cdna( 'ep3_s', 'Ecotig (Mouse prot)',   $POS++, 'SUBTYPE'     => 'genoscope_ecotig', 'on' => 'off', @_ );
  $self->add_new_track_cdna( 'eg3_h', 'Ecotig (Human DNA)',   $POS++, 'SUBTYPE'     => 'genoscope_ecotig', 'on' => 'off', @_ );
  $self->add_new_track_cdna( 'eg3_s', 'Ecotig (Mouse DNA)',   $POS++, 'SUBTYPE'     => 'genoscope_ecotig', 'on' => 'off', @_ );
  $self->add_new_track_cdna( 'eg3_f', 'Ecotig (Fugu DNA)',   $POS++,  'SUBTYPE'     => 'genoscope_ecotig', 'on' => 'off', @_ );
  $self->add_new_track_cdna( 'cdna_update',     'CDNAs',         $POS++,
                            'FEATURES'  => 'UNDEF', 'available' => 'databases ENSEMBL_CDNA',
                            'THRESHOLD' => 0,       'DATABASE'  => 'cdna', @_ );
  $self->add_new_track_cdna( 'fly_gold_cdna',  'Fly Gold CDNAs', $POS++,
                            'FEATURES'  => 'drosophila_gold_cdna', 'available' => 'database_features ENSEMBL_EST.drosophila_gold_cdna',
                            'THRESHOLD' => 0, 'DATABASE' => 'est', @_ );
  $self->add_new_track_cdna( 'fly_cdna_all',  'All Fly CDNAs', $POS++,
                            'FEATURES'  => 'drosophila_cdna_all', 'available' => 'database_features ENSEMBL_EST.drosophila_cdna_all',
                            'THRESHOLD' => 0, 'DATABASE' => 'est', @_ );
  return $POS;
}

sub ADD_ALL_EST_FEATURES {
  my $self = shift;
  my $POS  = shift || 2350;
  $self->add_new_track_est( 'BeeESTAlignmentEvidence', 'Bee EST evid.', $POS++, @_ );
  $self->add_new_track_est( 'est_rna',      'ESTs (RNA)',      $POS++, 'available' => 'features RNA',      'FEATURES' => 'RNA', @_ );
  $self->add_new_track_est( 'est_rnabest',  'ESTs (RNA best)', $POS++, 'available' => 'features RNA_BEST', 'FEATURES' => 'RNA_BEST', @_ );
  $self->add_new_track_est( 'celegans_est', 'C. elegans ESTs', $POS++, @_ );
  $self->add_new_track_est( 'cbriggsae_est', 'C. elegans ESTs', $POS++, @_ );
  $self->add_new_track_est( 'scerevisiae_est', 'S. cerevisiae ESTs', $POS++, @_ );
  $self->add_new_track_est( 'chicken_est',  'G.gallus ESTs',   $POS++, @_ );
  $self->add_new_track_est( 'macaque_est',  'Macaque ESTs',   $POS++, @_ );
  $self->add_new_track_est( 'human_est',    'Human ESTs',      $POS++, @_ );
  $self->add_new_track_est( 'mouse_est',    'Mouse ESTs',      $POS++, @_ );
  $self->add_new_track_est( 'zfish_est',    'D.rerio ESTs',    $POS++, @_ );
  $self->add_new_track_est( 'Btaurus_Exonerate_EST',    'B.taurus ESTs',    $POS++, @_ );
  $self->add_new_track_est( 'Cow_ESTs',    'B.taurus ESTs',    $POS++, @_ );
  $self->add_new_track_est( 'Exonerate_EST_083',    'Ciona ESTs',    $POS++, @_ );
  $self->add_new_track_est( 'xlaevis_EST', 'X.laevis ESTs',   $POS++, @_ );
  $self->add_new_track_est( 'xtrop_cluster','X.trop EST clust', 
							$POS++, 'URL_KEY' => 'XTROP_CLUSTER',
							'SUBTYPE' => 'default',
							@_);
  $self->add_new_track_est( 'ciona_dbest_align',     'dbEST align', $POS++, @_ );
  $self->add_new_track_est( 'ciona_est_3prim_align', "3' EST-align. (Kyoto)", $POS++, @_ );
  $self->add_new_track_est( 'ciona_est_5prim_align', "5' EST-align. (Kyoto)", $POS++, @_ );
  $self->add_new_track_est( 'ciona_cdna_align',      'cDNA-align. (Kyoto)', $POS++, @_ );

  my @EST_DB_ESTS = (
    [ 'bee_est',               'Bee EST' ],
    [ 'chicken_est_exonerate', 'Chicken EST (ex.)' ],
    [ 'human_est_exonerate',   'Human EST (ex.)' ],
    [ 'ciona_est',             'Ciona EST' ],
    [ 'drosophila_est',        'Fly EST' ],
    [ 'drosophila_est',        'Fly EST' ],
    [ 'fugu_est',              'Fugu EST' ],
    [ 'RNA',                   'Mosquito EST' ],
    [ 'mouse_est',             'Mouse EST' ],
    [ 'rat_est',               'Rat EST' ],
    [ 'xtrop_EST',             'X.trop EST' ],
    [ 'zfish_EST',             'Zfish EST' ]
  );
  foreach ( @EST_DB_ESTS ) {
    $self->add_new_track_est( "est_$_->[0]",  $_->[1], $POS++,
                              'FEATURES'  => $_->[0], 'available' => "database_features ENSEMBL_EST.$_->[0]",
                              'THRESHOLD' => 0, 'DATABASE' => 'est', @_ );
  }
  $self->add_new_track_est( 'other_est',    'Other ESTs',      $POS++, @_ );
  $self->add_new_track_est( 'drerio_estclust', 'EST clusters', $POS++,
							'available'  => 'any_feature EST_cluster_WashU EST_cluster_IMCB EST2genome_clusters Est2genome_clusters',
							'FEATURES'   => 'EST_Cluster_WashU EST_cluster_IMCB EST2genome_clusters Est2genome_clusters',
							'SUBTYPE'    => sub { return $_[0] =~ /WZ/i ? 'WZ' : 'IMCB_HOME' },
							'ID'         => sub { return $_[0] =~ /WZ(.*)/i ? $1 : $_[0] },
							'LABEL'      => sub { return $_[0] },
							'ZMENU'      => [ 'EST', "EST: ###LABEL###" => '###HREF###' ],
							'URL_KEY'    => { 'WZ' => 'WZ', 'IMCB_HOME' => 'IMCB_HOME' },
							@_);
#ESTs for Vega
  $self->add_new_track_est( 'est2genome_all', 'ESTs', $POS++,
							'available' => 'any_feature Est2genome_human Est2genome_mouse Est2genome_other Est2genome_fish',
							'FEATURES' => 'Est2genome_human Est2genome_mouse Est2genome_other Est2genome_fish',
                            'src' => 'all', 
							@_);
  return $POS;
}

sub ADD_ALL_RNA_FEATURES {
  my $self = shift;
  my $POS  = shift || 2180;
  $self->add_new_track_rna( 'miRNA_Registry',  'miRbase RNAs', $POS++, @_ );
  $self->add_new_track_rna( 'RFAM',            'RFAM RNAs',    $POS++, @_ );
}

sub ADD_ALL_PROTEIN_FEATURES {
  my $self = shift;
  my $POS  = shift || 2200;
  $self->add_new_track_protein( 'swall',               'Proteins',       $POS++, @_ );
  $self->add_new_track_protein( 'swall_blastx',        'Proteins',       $POS++, @_ );
  $self->add_new_track_protein( 'uniprot',             'UniProt',       $POS++, @_ );
  $self->add_new_track_protein( 'Uniprot_mammal',      'UniProt (mammal)',       $POS++, @_ );
  $self->add_new_track_protein( 'Uniprot_non_mammal',  'UniProt (non-mammal)',       $POS++, @_ );
  $self->add_new_track_protein( 'drosophila-peptides', 'Dros. peptides', $POS++, @_ );
  $self->add_new_track_protein( 'swall_high_sens',     'UniProt', $POS++, @_ );
  $self->add_new_track_protein( 'anopheles_peptides',  'Mos. peptides',  $POS++,
    'SUBTYPE'     => 'default' ,
    'URL_KEY'     => 'ENSEMBL_ANOPHELES_ESTTRANS', 'ID' => TRIM, 'LABEL' => TRIM,
  @_ );
  $self->add_new_track_protein( 'chicken_protein',     'G.gallus pep', $POS++, @_ );
  $self->add_new_track_protein( 'BeeProteinSimilarity','Bee pep. evid.',  $POS++, @_ );
  $self->add_new_track_protein( 'riken_prot',          'Riken proteins', $POS++, @_ );
  $self->add_new_track_protein( 'wormpep',             'Worm proteins',  $POS++, @_ );
  $self->add_new_track_protein( 'human_protein',       'Human proteins', $POS++, @_ );
  $self->add_new_track_protein( 'human_refseq',        'Human RefSeqs', $POS++, @_ );
  $self->add_new_track_protein( 'dog_protein',         'Dog proteins', $POS++, @_ );
  $self->add_new_track_protein( 'Btaurus_Exonerate_Protein',         'Cow proteins', $POS++, @_ );
  $self->add_new_track_protein( 'Cow_Proteins',         'Cow proteins', $POS++, @_ );
  $self->add_new_track_protein( 'macaque_protein',     'Macaque proteins', $POS++, @_ );
  $self->add_new_track_protein( 'mouse_protein',       'Mouse proteins', $POS++, @_ );
  $self->add_new_track_protein( 'mouse_refseq',        'Mouse RefSeqs', $POS++, @_ );
  $self->add_new_track_protein( 'rodent_protein',      'Rodent proteins',$POS++, @_ );
  $self->add_new_track_protein( 'mammal_protein',      'Mammal proteins', $POS++, @_ );
  $self->add_new_track_protein( 'other_protein',       'Other proteins', $POS++, @_ );
  $self->add_new_track_protein( 'GenomeUniprotBlast',          'Genome UniP.Bl.',   $POS++, @_ );
  $self->add_new_track_protein( 'GenscanPeptidesUniprotBlast', 'Gen.Pep. UniP.BL.', $POS++, @_ );
  $self->add_new_track_protein( 'BeeProteinBlast',             'Bee Protein blast', $POS++, @_ );
  $self->add_new_track_protein( 'human_ensembl_peptides', 'Human e! peptides',  $POS++, 'URL_KEY' => 'HUMAN_PROTVIEW', @_ );
  $self->add_new_track_protein( 'ciona_jgi_v1',            'JGI 1.0 model', $POS++, @_ );
  $self->add_new_track_protein( 'ciona_kyotograil_2004',   "Kyotograil '04 model", $POS++, @_ );
  $self->add_new_track_protein( 'ciona_kyotograil_2005',   "Kyotograil '05 model", $POS++, @_ );
  return $POS;
}

sub ADD_ALL_PREDICTIONTRANSCRIPTS {
  my $self = shift;
  my $POS  = shift || 2100;
  $self->add_new_track_predictiontranscript( 'genscan',   'Genscan',    'lightseagreen',   $POS ++, {}, @_ );
  $self->add_new_track_predictiontranscript( 'genefinder','Genefinder', 'darkolivegreen4', $POS ++, {}, @_ );
  $self->add_new_track_predictiontranscript( 'snap',      'SNAP',       'darkseagreen4',   $POS ++, {}, @_ );
  $self->add_new_track_predictiontranscript( 'snap_ciona','SNAP (Ciona)','darkseagreen4',   $POS ++, {}, @_ );
  $self->add_new_track_predictiontranscript( 'slam',      'SLAM',       'darkgreen',       $POS ++, {}, @_ );
  $self->add_new_track_predictiontranscript( 'gsc',       'Genscan',    'lightseagreen',   $POS ++, { 'Genoscope' => 'TETRAODON_ABINITIO' }, @_ );
  $self->add_new_track_predictiontranscript( 'gid',       'Gene id','red',$POS ++, { 'Genoscope' => 'TETRAODON_ABINITIO' }, @_ );
  $self->add_new_track_predictiontranscript( 'gws_h','Genewise (Human)','orange',$POS ++, { 'Genoscope' => 'TETRAODON_GENEWISE' }, @_ );
  $self->add_new_track_predictiontranscript( 'gws_s','Genewise (Mouse)','orange',$POS ++, { 'Genoscope' => 'TETRAODON_GENEWISE' }, @_ );
#for vega 
  $self->add_new_track_predictiontranscript( 'fgenesh', 'Fgenesh', 'darkkhaki', $POS ++, {}, @_ ); # 'available' => 'features Fgenesh', @_ ); # , 'glyphset'=>'fgenesh', @_);
  $self->add_new_track_predictiontranscript( 'vega_genscan', 'Genscan', 'lightseagreen', $POS ++, {}, 
											 'glyphset'=>'genscan', @_);
  return $POS;
}

sub ADD_SYNTENY_TRACKS {
  my $self = shift;
  my $POS = shift || 99900;
  foreach( sort @{$self->{'species_defs'}->ENSEMBL_SPECIES} ) {
    $self->add_new_synteny_track( $_, $self->{'species_defs'}->other_species( $_, 'SPECIES_COMMON_NAME' ), $POS++, @_ );
  }
}

sub ADD_ALL_TRANSCRIPTS {
  my $self = shift;
  my $POS  = shift || 2000;
  $self->add_new_track_transcript( 'evega',     'Vega genes',      'vega_gene',      $POS++, 'available' => 'databases ENSEMBL_VEGA',    @_ );
  $self->add_new_track_transcript( 'ensembl',   'Ensembl genes',   'ensembl_gene',   $POS++, @_ );
  $self->add_new_track_transcript( 'flybase',   'Flybase genes',   'flybase_gene',   $POS++, @_ );
  $self->add_new_track_transcript( 'wormbase',  'Wormbase genes',  'wormbase_gene',  $POS++, @_ );
  $self->add_new_track_transcript( 'sgd',       'SGD genes',  'sgd_gene',  $POS++, @_ );
  $self->add_new_track_transcript( 'genebuilderbeeflymosandswall',
                                                'Bee genes',       'bee_gene',       $POS++, @_ );
  $self->add_new_track_transcript( 'gsten',     'Genoscope genes', 'genoscope_gene', $POS++, @_ );
  $self->add_new_track_transcript( 'rna',       'ncRNA genes',     'rna_gene',       $POS++, 'available' => 'features NCRNA',            @_ );
  $self->add_new_track_transcript( 'erna',       'e! ncRNA genes',     'rna_gene',       $POS++, 'available' => 'features ensembl_ncRNA',            @_ );
  $self->add_new_track_transcript( 'est',       'EST genes',       'est_gene',       $POS++, 'available' => 'databases ENSEMBL_EST', @_ );
  $self->add_new_track_transcript( 'rprot',     'Rodent proteins', 'prot_gene',      $POS++, @_ );
  $self->add_new_track_transcript( 'refseq',    'Refseq proteins', 'refseq_gene',    $POS++, @_ );
  $self->add_new_track_transcript( 'cow_proteins',   'Cow genes',   'cow_protein',   $POS++, @_ );
  $self->add_new_track_transcript( 'homology_low', 'Bee genes',    'bee_pre_gene',   $POS++, @_ );
#trancripts for Vega
  $self->add_new_track_transcript('vega_havana', 'Havana trans.', 'vega_gene', $POS++,
								  'author'=>'Havana', 'glyph' => 'vega_transcript', 
								  'available'=>'features LITE_TRANSCRIPT_HAVANA', @_);
  $self->add_new_track_transcript('vega_genoscope', 'Genoscope trans.', 'vega_gene', $POS++,
								  'author'=>'Genoscope','glyph' => 'vega_transcript',
								  'available'=>'features LITE_TRANSCRIPT_GENOSCOPE', @_);
  $self->add_new_track_transcript('vega_collins', 'Sanger trans.', 'vega_gene', $POS++,
								  'author'=>'Sanger', 'glyph' => 'vega_transcript',
								  'available'=>'features LITE_TRANSCRIPT_SANGER', @_);
  $self->add_new_track_transcript('vega_washu', 'WashU trans.', 'vega_gene', $POS++,
								  'author'=>'WashU', 'glyph' => 'vega_transcript',
								  'available'=>'features LITE_TRANSCRIPT_WASHU', @_ );
  $self->add_new_track_transcript('vega_broad', 'Broad trans.', 'vega_gene', $POS++,
								  'author'=>'Broad', 'glyph' => 'vega_transcript',
								  'available'=>'features LITE_TRANSCRIPT_BROAD', @_ );
  $self->add_new_track_transcript('vega_jgi', 'JGI trans.', 'vega_gene', $POS++,
								  'author'=>'JGI', 'glyph' => 'vega_transcript',
								  'available'=>'features LITE_TRANSCRIPT_JGI', @_ );
  $self->add_new_track_transcript('vega_zfish', 'Zfish trans.', 'vega_gene', $POS++, 
								  'author'=>'Zfish', 'glyph' => 'vega_transcript',
								  'available'=>'features LITE_TRANSCRIPT_ZFISH', @_ );
  return $POS;
}

sub ADD_ALL_AFFY_TRACKS {
  my $self = shift;
  my $POS  = shift || 4000;
  my @AFFY = map { sort keys %{ $self->{'species_defs'}{'_storage'}->{$_}{'AFFY'}||{} } } keys %{$self->{'species_defs'}{'_storage'}};
#    qw( Canine ),    # Dog
#    qw( Zebrafish ), # Zfish
#    qw( Chicken ),   # Chicken
#    qw( HG-Focus HG-U133A HG-U133A_2 HG-U133B HG-U133_Plus_2
#        HG-U95Av2 HG-U95B HG-U95C HG-U95D HG-U95E
#        U133_X3P ),  # Human
#    qw( MG-U74Av2 MG-U74Bv2 MG-U74Cv2
#        Mouse430A_2 Mouse430_2 Mu11KsubA Mu11KsubB ), # Mouse
#    qw( Rat230_2 RG-U34A RG-U34B RG-U34C ),           # Rat
#  );
  foreach my $chipset (@AFFY) {
    ( my $T = lc($chipset) ) =~ s/\W/_/g;
    ( my $T2 = $chipset ) =~ s/Plus_/+/i;
    $self->add_track(
      $T, 'on' => 'off', 'pos' => $POS++, 'str' => 'b', '_menu' => 'features', 
          'caption' => "AFFY $T2",
          'dep' => 6,
      'col' => 'springgreen4',
      'compact'   => 0,
      'available' => "features affy_$T",
      'glyphset'  => 'generic_microarray',
      'FEATURES'  => $chipset,
    );
  }
  return $POS;
}

sub ADD_SIMPLE_TRACKS {
  my $self = shift;
  my $POS  = shift || 7500;
  $self->add_new_simple_track( 'abberation_junction',      'Abberation junction', 'red', $POS++, @_ );
  $self->add_new_simple_track( 'enhancer',                 'Enhancer',            'red', $POS++, @_ ); 
  $self->add_new_simple_track( 'transcription_start_site', 'Transcription start site', 'red', $POS++, @_ );
  $self->add_new_simple_track( 'regulatory_region',        'Regulatory region', 'red', $POS++, @_ );
  $self->add_new_simple_track( 'mature_peptide',           'Mature peptide',      'red', $POS++, @_ );
  $self->add_new_simple_track( 'insertion_site',           'Insertion site',      'red', $POS++, @_ );
  $self->add_new_simple_track( 'protein_binding_site',     'Protein binding site','red', $POS++, @_ );
  $self->add_new_simple_track( 'scaffold',                 'Scaffold',            'red', $POS++, @_ );
  $self->add_new_simple_track( 'allele',                   'Allele',              'red', $POS++, @_ );
  $self->add_new_simple_track( 'transposable_element_insertion_site', 'Transposable element insertion site', 'red', $POS++, @_ );
  $self->add_new_simple_track( 'transposable_element',     'Transposable element','red', $POS++, @_ );
  $self->add_new_simple_track( 'rescue_fragment',          'Rescue fragment',     'red', $POS++, @_ );
  $self->add_new_simple_track( 'signal_peptide',           'Signal peptide',      'red', $POS++, @_ );
}

sub ADD_GENE_TRACKS {
  my $self = shift;
  my $POS  = shift || 2000;
  $self->add_new_track_gene( 'ensembl', 'Ensembl Genes', 'ensembl_gene', $POS++,
   'gene_label'           => sub { return $_[0]->type eq 'bacterial_contaminant' ? 'Bac. cont.' : ( $_[0]->type eq 'pseudogene' ? 'Pseudogene' : ( $_[0]->external_name || 'NOVEL' ) ) },
   'gene_col'             => sub { return $_[0]->type eq 'bacterial_contaminant' ? '_BACCOM'    : ( $_[0]->type eq 'pseudogene' ? '_PSEUDO'    : '_'.$_[0]->external_status          ) },
   'logic_name'           => 'ensembl psuedogene', @_
  );
  $self->add_new_track_gene( 'flybase', 'Flybase Genes', 'flybase_gene', $POS++,
    'gene_label'           => sub { return $_[0]->type eq 'bacterial_contaminant' ? 'Bac. cont.' : ( $_[0]->type eq 'pseudogene' ? 'Pseudogene' : ( $_[0]->external_name || 'NOVEL' ) ) },
    'gene_col'             => sub { return $_[0]->type eq 'bacterial_contaminant' ? '_BACCOM'    : ( $_[0]->type eq 'pseudogene' ? '_PSEUDO'    : '_'.$_[0]->external_status          ) },
    'logic_name'           => 'flybase psuedogene', @_
  );
  $self->add_new_track_gene( 'wormbase', 'Wormbase Genes', 'wormbase_gene', $POS++,
    'gene_label'           => sub { return $_[0]->type eq 'bacterial_contaminant' ? 'Bac. cont.' : ( $_[0]->type eq 'pseudogene' ? 'Pseudogene' : ( $_[0]->external_name || 'NOVEL' ) ) },
    'gene_col'             => sub { return $_[0]->type eq 'bacterial_contaminant' ? '_BACCOM'    : ( $_[0]->type eq 'pseudogene' ? '_PSEUDO'    : '_'.$_[0]->external_status          ) },
    'logic_name'           => 'wormbase psuedogene', @_
  );
  $self->add_new_track_gene( 'genebuilderbeeflymosandswall', 'Bee Genes', 'bee_gene', $POS++,
    'gene_label'           => sub { return $_[0]->type eq 'bacterial_contaminant' ? 'Bac. cont.' : ( $_[0]->type eq 'pseudogene' ? 'Pseudogene' : ( $_[0]->external_name || 'NOVEL' ) ) },
    'gene_col'             => sub { return $_[0]->type eq 'bacterial_contaminant' ? '_BACCOM'    : ( $_[0]->type eq 'pseudogene' ? '_PSEUDO'    : '_'.$_[0]->external_status          ) },
    @_
  );
  $self->add_new_track_gene( 'SGD', 'SGD Genes', 'sgd_gene', $POS++,
    'gene_label'           => sub { return $_[0]->type eq 'bacterial_contaminant' ? 'Bac. cont.' : ( $_[0]->type eq 'pseudogene' ? 'Pseudogene' : ( $_[0]->external_name || 'NOVEL' ) ) },
    'gene_col'             => sub { return $_[0]->type eq 'bacterial_contaminant' ? '_BACCOM'    : ( $_[0]->type eq 'pseudogene' ? '_PSEUDO'    : '_'.$_[0]->external_status          ) },
    @_
  );
  $self->add_new_track_gene( 'Homology_low', 'Bee Genes', 'bee_pre_gene', $POS++,
    'gene_col'   => sub { return $_[0]->analysis->logic_name },
    'gene_label' => sub { return $_[0]->stable_id },
    'logic_name' => 'Homology_low Homology_medium Homology_high BeeProtein'
  );
  $self->add_new_track_gene( 'gsten', 'Genoscope Genes', 'genoscope_gene', $POS++,
    'gene_label'           => sub { return $_[0]->stable_id },
    'gene_col'             => sub { return $_[0]->type eq 'Genoscope_predicted' ? '_GSTEN'    : '_HOX' },
    'logic_name'           => 'gsten hox cyt', @_
  );
  $self->add_new_track_gene( 'Cow_proteins', 'Cow proteins', 'cow_protein', $POS++,
    'gene_label'           => sub { return $_[0]->stable_id },
    'gene_col'             => 'cow_protein' 
  );
  $self->add_new_track_gene( 'ncrna', 'ncRNA Genes', 'rna_gene', $POS++,
                             'gene_col' => sub { return $_[0]->type =~ /pseudo/i ? 'rna-pseudo' : 'rna-real' }, @_ );
  $self->add_new_track_gene( 'ensembl_ncrna', 'e! ncRNA Genes', 'rna_gene', $POS++,
                             'gene_col' => sub { return $_[0]->type =~ /pseudo/i ? 'rna-pseudo' : 'rna-real' }, @_ );
  $self->add_new_track_gene( 'refseq', 'RefSeq Genes', 'refseq_gene', $POS++, 'gene_col' => '_refseq',  @_ );
  $self->add_new_track_gene( 'estgene', 'EST Genes', 'est_gene', $POS++,
                             'database' => 'est', 'available' => 'databases ENSEMBL_EST',
                             'logic_name' => 'genomewise estgene', 'on' => 'off',
                             'gene_col' => 'estgene', @_ );
  $self->add_new_track_gene( 'otter', 'Vega Genes', 'vega_gene', $POS++,
                             'database' => 'vega', 'available' => 'databases ENSEMBL_VEGA',
                            # 'gene_col'             => sub { ( my $T = $_[0]->type ) =~s/HUMACE-//; return $T; },
                             'gene_col'             => sub { return $_[0]->biotype.'_'.$_[0]->confidence; },
                             'gene_label'           => sub { $_[0]->external_name || $_[0]->stable_id; }, @_ );
#for genes in Vega
  $self->add_new_track_gene( 'havana_gene', 'Havana Genes', 'vega_gene', $POS++,
							 'available' => 'features LITE_TRANSCRIPT_HAVANA', 'glyphset' => 'vega_gene',
							 'logic_name' => 'otter', 'author' => 'Havana', 'gene_col' => 'vega_gene', @_);
  $self->add_new_track_gene( 'genoscope_gene', 'Genoscope Genes', 'vega_gene', $POS++, 
							 'available' => 'features LITE_TRANSCRIPT_GENOSCOPE', 'glyphset' => 'vega_gene',
							 'logic_name' => 'otter', 'author' => 'Genoscope', 'gene_col' => 'vega_gene', @_);
  $self->add_new_track_gene( 'sanger_gene', 'Sanger Genes', 'vega_gene', $POS++,
							 'available' => 'features LITE_TRANSCRIPT_SANGER', 'glyphset' => 'vega_gene',
							 'logic_name' => 'otter', 'author' => 'Sanger', 'gene_col' => 'vega_gene', @_);
  $self->add_new_track_gene( 'wasu_gene', 'WashU Genes',  'vega_gene', $POS++,
							 'available' => 'features LITE_TRANSCRIPT_WASHU', 'glyphset' => 'vega_gene',
							 'logic_name' => 'otter', 'author' => 'WashU', 'gene_col' => 'vega_gene', @_);
  $self->add_new_track_gene( 'vega_broad', 'Broad trans.', 'vega_gene', $POS++,
 			                 'available'=>'features LITE_TRANSCRIPT_BROAD', 'glyphset' => 'vega_gene',
			                 'logic_name' =>'otter', 'author'=>'Broad', 'gene_col' => 'vega_gene', @_);
  $self->add_new_track_gene( 'vega_jgi', 'JGI trans.', 'vega_gene', $POS++,
	             		     'available'=>'features LITE_TRANSCRIPT_JGI', 'glyphset' => 'vega_gene',
			                 'logic_name' => 'otter', 'author'=>'JGI', 'gene_col' => 'vega_gene', @_ );
  $self->add_new_track_gene( 'zfish_gene', 'Zfish Genes', 'vega_gene', $POS++, 
		             	     'available' => 'features LITE_TRANSCRIPT_ZFISH', 'glyphset' => 'vega_gene',
			                'logic_name' => 'otter', 'author' => 'Zfish', 'gene_col' => 'vega_gene', @_);

  $self->add_new_track_gene( 'ciona_dbest_ncbi', "3/5' EST genes (dbEST)", 'estgene', $POS++, 'on' => 'off', 
                             'gene_label' => sub { return $_[0]->stable_id }, 'gene_col' => sub { return $_[0]->biotype }, @_ );
  $self->add_new_track_gene( 'ciona_est_seqc',   "3' EST genes (Kyoto)", 'estgene', $POS++, 'on' => 'off',
                             'gene_label' => sub { return $_[0]->stable_id }, 'gene_col' => sub { return $_[0]->biotype }, @_ );
  $self->add_new_track_gene( 'ciona_est_seqn',   "5' EST genes (Kyoto)",  'estgene',$POS++, 'on' => 'off',
                             'gene_label' => sub { return $_[0]->stable_id } , 'gene_col' => sub { return $_[0]->biotype }, @_ );
  $self->add_new_track_gene( 'ciona_est_seqs',   "full insert cDNA clone",  'estgene',$POS++, 'on' => 'off',
                             'gene_label' => sub { return $_[0]->stable_id }, 'gene_col' => sub { return $_[0]->biotype }, @_ );
  $self->add_new_track_gene( 'ciona_jgi_v1',     "JGI 1.0 models", 'ciona_gene',  $POS++,
                             'gene_label' => sub { return $_[0]->stable_id }, 'gene_col' => sub { return $_[0]->biotype }, @_ );
  $self->add_new_track_gene( 'ciona_kyotograil_2004',  "Kyotograil '04 model", 'ciona_gene',  $POS++,
                             'gene_label' => sub { return $_[0]->stable_id }, 'gene_col' => sub { return $_[0]->biotype }, @_ );
  $self->add_new_track_gene( 'ciona_kyotograil_2005',  "Kyotograil '05 model",  'ciona_gene', $POS++,
                             'gene_label' => sub { return $_[0]->stable_id }, 'gene_col' => sub { return $_[0]->biotype }, @_ );
  return $POS;
}

sub ADD_ALL_AS_TRANSCRIPTS {
    my $self = shift;
    my $POS  = shift || 2000;
    $self->add_new_track_transcript( 'ensembl',   'Ensembl genes',   'ensembl_gene',   $POS++, @_ );
    $self->add_new_track_transcript( 'evega',     'Vega genes',      'vega_gene',      $POS++, 'available' => 'databases ENSEMBL_VEGA',    @_ );
    $self->add_new_track_transcript( 'est',       'EST genes',       'est_gene',       $POS++, 'available' => 'databases ENSEMBL_ESTGENE', @_ );
    
    return $POS;
}

sub ADD_AS_GENE_TRACKS {
    my $self = shift;
    my $POS  = shift || 2000;
    $self->add_new_track_gene( 'ensembl', 'Ensembl Genes', 'ensembl_gene', $POS++,
			       'gene_label'           => sub { return $_[0]->type eq 'bacterial_contaminant' ? 'Bac. cont.' : ( $_[0]->type eq 'pseudogene' ? 'Pseudogene' : ( $_[0]->external_name || 'NOVEL' ) ) },
			       'gene_col'             => sub { return $_[0]->type eq 'bacterial_contaminant' ? '_BACCOM'    : ( $_[0]->type eq 'pseudogene' ? '_PSEUDO'    : '_'.$_[0]->external_status          ) },
			       'logic_name'           => 'ensembl psuedogene', @_
			       );
    $self->add_new_track_gene( 'flybase', 'Flybase Genes', 'flybase_gene', $POS++,
     'gene_label'           => sub { return $_[0]->type eq 'bacterial_contaminant' ? 'Bac. cont.' : ( $_[0]->type eq 'pseudogene' ? 'Pseudogene' : ( $_[0]->external_name || 'NOVEL' ) ) },
			       'gene_col'             => sub { return $_[0]->type eq 'bacterial_contaminant' ? '_BACCOM'    : ( $_[0]->type eq 'pseudogene' ? '_PSEUDO'    : '_'.$_[0]->external_status          ) },
     'logic_name'           => 'flybase psuedogene', @_
			       );
    $self->add_new_track_gene( 'wormbase', 'Wormbase Genes', 'wormbase_gene', $POS++,
			       'gene_label'           => sub { return $_[0]->type eq 'bacterial_contaminant' ? 'Bac. cont.' : ( $_[0]->type eq 'pseudogene' ? 'Pseudogene' : ( $_[0]->external_name || 'NOVEL' ) ) },
			       'gene_col'             => sub { return $_[0]->type eq 'bacterial_contaminant' ? '_BACCOM'    : ( $_[0]->type eq 'pseudogene' ? '_PSEUDO'    : '_'.$_[0]->external_status          ) },
			       'logic_name'           => 'wormbase psuedogene', @_
			       );
    $self->add_new_track_gene( 'genebuilderbeeflymosandswall', 'Bee Genes', 'bee_gene', $POS++,
			       'gene_label'           => sub { return $_[0]->type eq 'bacterial_contaminant' ? 'Bac. cont.' : ( $_[0]->type eq 'pseudogene' ? 'Pseudogene' : ( $_[0]->external_name || 'NOVEL' ) ) },
			       'gene_col'             => sub { return $_[0]->type eq 'bacterial_contaminant' ? '_BACCOM'    : ( $_[0]->type eq 'pseudogene' ? '_PSEUDO'    : '_'.$_[0]->external_status          ) },
			       @_
			       );
    $self->add_new_track_gene( 'SGD', 'SGD Genes', 'sgd_gene', $POS++,
			       'gene_label'           => sub { return $_[0]->type eq 'bacterial_contaminant' ? 'Bac. cont.' : ( $_[0]->type eq 'pseudogene' ? 'Pseudogene' : ( $_[0]->external_name || 'NOVEL' ) ) },
			       'gene_col'             => sub { return $_[0]->type eq 'bacterial_contaminant' ? '_BACCOM'    : ( $_[0]->type eq 'pseudogene' ? '_PSEUDO'    : '_'.$_[0]->external_status          ) },
			       @_
			       );
    $self->add_new_track_gene( 'gsten', 'Genoscope Genes', 'genoscope_gene', $POS++,
			       'gene_label'           => sub { return $_[0]->stable_id },
			       'gene_col'             => sub { return $_[0]->type eq 'Genoscope_predicted' ? '_GSTEN'    : '_HOX' },
			       'logic_name'           => 'gsten hox cyt', @_
			       );
    
    #for genes in Vega
    $self->add_new_track_gene( 'havana_gene', 'Havana Genes', 'vega_gene', $POS++,
			       'available' => 'features LITE_TRANSCRIPT_HAVANA', 'glyphset' => 'vega_gene',
			       'logic_name' => 'otter', 'author' => 'Havana', 'gene_col' => 'vega_gene', @_);
    $self->add_new_track_gene( 'genoscope_gene', 'Genoscope Genes', 'vega_gene', $POS++,
			       'available' => 'features LITE_TRANSCRIPT_GENOSCOPE', 'glyphset' => 'vega_gene',
			       'logic_name' => 'otter', 'author' => 'Genoscope', 'gene_col' => 'vega_gene', @_);
    $self->add_new_track_gene( 'sanger_gene', 'Sanger Genes', 'vega_gene', $POS++,
			       'available' => 'features LITE_TRANSCRIPT_SANGER', 'glyphset' => 'vega_gene',
			       'logic_name' => 'otter', 'author' => 'Sanger', 'gene_col' => 'vega_gene', @_);
   $self->add_new_track_gene( 'wasu_gene', 'WashU Genes',  'vega_gene', $POS++,
			      'available' => 'features LITE_TRANSCRIPT_WASHU', 'glyphset' => 'vega_gene',
			      'logic_name' => 'otter', 'author' => 'WashU', 'gene_col' => 'vega_gene', @_);
    $self->add_new_track_gene( 'zfish_gene', 'Zfish Genes', 'vega_gene', $POS++,
			       'available' => 'features LITE_TRANSCRIPT_ZFISH', 'glyphset' => 'vega_gene',
			       'logic_name' => 'otter', 'author' => 'Zfish', 'gene_col' => 'vega_gene', @_);
    return $POS;
}


1;
