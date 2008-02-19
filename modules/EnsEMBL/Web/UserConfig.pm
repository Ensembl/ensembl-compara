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

sub new {
  my $class   = shift;
  my $adaptor = shift;
  my $type    = $class =~/([^:]+)$/ ? $1 : $class;
  my $style   = $adaptor->get_species_defs->ENSEMBL_STYLE || {};
  my $self = {
    '_colourmap' 	=> $adaptor->colourmap,
    '_font_face'        => $style->{GRAPHIC_FONT} || 'Arial',
    '_font_size'        => ( $style->{GRAPHIC_FONTSIZE} *
                             $style->{GRAPHIC_LABEL} ) || 20,
    '_texthelper' 	=> new Sanger::Graphics::TextHelper,
    '_db'         	=> $adaptor->get_adaptor,
    'type'              => $type,
    'species'           => $ENV{'ENSEMBL_SPECIES'} || '', 
    'species_defs'      => $adaptor->get_species_defs,
    'exturl'            => $adaptor->exturl,
    'general'           => {},
    'user'        	=> {},
    '_managers'         => {}, # contains list of added features....
    '_useradded'        => {}, # contains list of added features....
    '_userdatatype_ID'	=> 0, 
    '_r'                => undef, # $adaptor->{'r'} || undef,
    'no_load'     	=> undef,
    'storable'          => 1,
    'altered'           => 0
  };

  bless($self, $class);

		
  ########## init sets up defaults in $self->{'general'}
  $self->init( ) if($self->can('init'));
  $self->das_sources( @_ ) if(@_); # we have das sources!!

  ########## load sets up user prefs in $self->{'user'}
#  $self->load() unless(defined $self->{'no_load'});
  return $self;
}

sub storable :lvalue {
### a
### Set whether this ScriptConfig is changeable by the User, and hence needs to
### access the database to set storable do $script_config->storable = 1; in SC code...
  $_[0]->{'storable'};
}
sub altered :lvalue {
### a
### Set to one if the configuration has been updated...
  $_[0]->{'altered'};
}

sub TRIM   { return sub { return $_[0]=~/(^[^\.]+)\./ ? $1 : $_[0] }; }

sub update_config_from_parameter {
  my( $self, $string ) = @_;
  my @array = split /\|/, $string;
  shift @array;
  return unless @array;
  foreach( @array ) {
    my( $key, $value ) = /^(.*):(.*)$/;
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
  my $type_config = $self->{'general'}->{$self->{'type'}};
  if( $pars{ '_menu'} ) {
    $type_config->{'_settings'}{$pars{'_menu'}} ||= [];
    push( @{ $type_config->{'_settings'}{$pars{'_menu'}}},
          [ $code, $pars{'_menu_caption'} || $pars{'caption'} ] );
    delete $pars{'_menu'};
    delete $pars{'_menu_caption'};
  }
  push @{$type_config->{'_artefacts'}}, $code;
  $type_config->{$code} = {%pars};
  ## Create configuration entry....
}

sub add_GSV_protein_domain_track {
  my( $self, $code, $text_label, $pos, %pars ) = @_;
  $self->add_track( $code,
    'on'         => 'on',
    'pos'        => $pos,
    'glyphset'   => 'GSV_generic_domain',
    '_menu'      => 'features',
    'available'  => "features $code",
    'logic_name' => $code,
    'caption'    => $text_label,
    'dep'        => 20,
    'url_key'    => uc($code),
    'colours'    => { $self->{'_colourmap'}->colourSet( 'protein_features' ) },
    %pars
  );
}

sub add_protein_domain_track {
  my( $self, $code, $text_label, $pos, %pars ) = @_;
  $self->add_track( $code,
    'on'         => 'on',
    'pos'        => $pos,
    'glyphset'   => 'P_domain',
    '_menu'      => 'features',
    'available'  => "features $code",
    'logic_name' => $code,
    'caption'    => $text_label,
    'dep'        => 20,
    'url_key'    => uc($code),
    'colours'    => { $self->{'_colourmap'}->colourSet( 'protein_features' ) },
    %pars
  );
}

sub add_protein_feature_track {
  my( $self, $code, $text_label, $pos, %pars ) = @_;
  $self->add_track( $code,
    'on'         => 'on',
    'pos'        => $pos,
    'glyphset'   => 'P_feature',
    '_menu'      => 'features',
    'available'  => "features $code",
    'logic_name' => $code,
    'caption'    => $text_label,
    'colours'    => { $self->{'_colourmap'}->colourSet( 'protein_features' ) },
    %pars
  );
}

sub add_new_simple_track {
  my( $self, $code, $text_label, $colour, $pos, %pars ) = @_;
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
  my( $self, $species, $short, $pos) = @_;
  $self->add_track( "synteny_$species",
    "_menu" => 'compara',
    'height'    => 4,
    'glyphset'  => "generic_synteny",
    'label'     => "$short synteny",
    'caption'   => "$short synteny",
    'species'   => $species,
    'available' => "multi SYNTENY|$species",
    'on'        => 'off',
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
    'db'          => 'core',
    'logic_name'  => $code, 
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
    'on'          => 'off',
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
    'on'          => 'off',
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
    'on'          => "off",
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
    'on'          => "off",
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
    'on'          => "off",
    'colour_set'  => 'rna',
    'dep'         => '6',
    'str'         => 'b',
    'compact'     => 0,
    'glyphset'    => 'generic_match',
    'SUBTYPE'     => $code,
    'URL_KEY'     => uc( $code ),
    'ZMENU'       => [ '###ID###', "$text_label: ###ID###" => '###HREF###' ],
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
    'on'          => "off",
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

sub add_new_track_est_protein {
  my( $self, $code, $text_label, $pos, %pars ) = @_;
  $self->add_track( $code,
    '_menu'       => 'features',
    'on'          => "off",
    'colour_set'  => 'est',
    'dep'         => '6',
    'str'         => 'b',
    'compact'     => 0,
    'glyphset'    => 'generic_match',
    'CALL'        => 'get_all_ProteinAlignFeatures',
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

sub add_clone_track {
  my( $self, $code, $track_label, $pos, %pars ) = @_;
  $self->add_track( "cloneset_$code",
    '_menu'                => 'options',
    'on'                   => 'off',
    'dep'                  => 9999,
    'str'                  => 'r',
    'glyphset'             => 'generic_clone',
    'pos'                  => $pos,
    'navigation'           => 'on',
    'outline_threshold'    => '350000',
    'colour_set'           => 'clones',
    'FEATURES'             => $code,
    'label'                => $track_label,
    'caption'              => $track_label,
    'available'            => 'features MAPSET_'.uc($code),
    'threshold_array'      => { 100000 => { 'navigation' => 'off', 'height' => 4 }, %{$pars{'thresholds'}||{}} },
    %pars,
  );
}

sub set_species {
  my $self = shift;
  $self->{'species'} = shift; 
}

sub get_user_settings {
  my $self = shift;
  return $self->{'user'};
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
warn "UserConfig->load - Deprecated call now handled by session";
  return;
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
warn "UserConfig->save - Deprecated call now handled by session";
  return;
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
  $self->altered = 1;
  return;
}

sub reset_subsection {
  my ($self, $subsection) = @_;
  my $script = $self->script();
  return unless(defined $subsection);

  $self->{'user'}->{$script}->{$subsection} = {}; 
  $self->altered = 1;
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
  return $self->{'species_defs'}->_is_available_artefact( $self->{'species'}, @_ );
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
  my($package, $filename, $line) = caller;
  return if $self->{'user'}->{$script}->{$subsection}->{$key} eq $value;
  $self->altered = 1;
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
	$self->scalex($width/$val) if $val;
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

  ## BACends - configured elsewhere, not gene style features
  ## Full_dbSTS - in r40, leftover from Vega, don't display
  $self->add_new_track_mrna( 'unigene', 'Unigene', $POS++, 'URL_KEY' => 'UNIGENE', 'ZMENU'       => [ '###ID###' , 'Unigene cluster ###ID###', '###HREF###' ], @_ );
  $self->add_new_track_mrna( 'vertrna', 'EMBL mRNAs', $POS++, @_ );
  $self->add_new_track_mrna( 'caenorhabditus_mrna', 'Worm mRNAs', $POS++, @_ );
  $self->add_new_track_mrna( 'celegans_mrna', 'C.elegans mRNAs', $POS++, @_ );
  $self->add_new_track_mrna( 'cbriggsae_mrna', 'C.briggsae mRNAs', $POS++, @_ );

  $self->add_new_track_rna( 'BlastmiRNA', 'MiRNA', $POS++, @_ );
  $self->add_new_track_rna( 'RfamBlast',  'rFam', $POS++, @_ );
  $self->add_new_track_rna( 'mirbase',  'MiRBase', $POS++, @_ );
  $self->add_new_track_rna( 'miRNA_Registry',  'miRbase RNAs', $POS++, @_ );
  $self->add_new_track_rna( 'RFAM',            'RFAM RNAs',    $POS++, @_ );

  $self->add_new_track_cdna( 'jgi_v1',            'JGI 1.0 model', $POS++, @_ );

  $POS = shift || 2400;
  $self->add_new_track_cdna( 'Harvard_manual', 'Manual annot.', $POS++, 'URL_KEY' => 'NULL', 'ZMENU' => [ '###ID###', 'Internal identifier', '' ], @_ );

  $self->add_new_track_cdna( 'medaka_cdna',    'Medaka cDNAs',    $POS++, @_ );

  $self->add_new_track_cdna( 'human_cdna', 'Human cDNAs',   $POS++, @_ );
  $self->add_new_track_cdna( 'chimp_cdna', 'Chimp cDNAs',     $POS++, @_ );
  $self->add_new_track_cdna( 'horse_cdna',    'Horse cDNAs',      $POS++, @_ );
  $self->add_new_track_cdna( 'orangutan_cdna',    'Orangutan cDNAs',      $POS++, @_ );
  $self->add_new_track_cdna( 'lamprey_cdna', 'Lamprey cDNAs', $POS++, @_ );
  $self->add_new_track_cdna( 'orangutan_cdna',    'Orangutan cDNAs',      $POS++, @_ );
  $self->add_new_track_cdna( 'pig_cdna',    'Pig cDNAs',      $POS++, @_ );
  $self->add_new_track_cdna( 'dog_cdna',   'Dog cDNAs',     $POS++, @_ );
  $self->add_new_track_cdna( 'rat_cdna',   'Rat cDNAs',     $POS++, @_ );
  $self->add_new_track_cdna( 'platypus_cdnas', 'Platypus cDNAs',   $POS++, @_ );
  $self->add_new_track_cdna( 'platypus_cdna', 'Platypus cDNAs',   $POS++, @_ );

  $self->add_new_track_cdna( 'zfish_cdna', 'D.rerio cDNAs', $POS++,
        'SUBTYPE'    => sub { return $_[0] =~ /WZ/ ? 'WZ' : ( $_[0] =~ /IMCB/ ? 'IMCB_HOME' : 'EMBL' ) },
        'ID'         => sub { return $_[0] =~ /WZ(.*)/ ? $1 : $_[0] },
        'LABEL'      => sub { return $_[0] },
        'ZMENU'      => [ 'EST cDNA', "EST: ###LABEL###" => '###HREF###' ],
        'URL_KEY'    => { 'WZ' => 'WZ', 'IMCB_HOME' => 'IMCB_HOME', 'EMBL' => 'EMBL' },
                             ,@_ );
  $self->add_new_track_cdna( 'Exonerate_cDNA',           'Exonerate cDNAs', $POS++, @_ );
  $self->add_new_track_cdna( 'Btaurus_Exonerate_cDNA',   'Cow cDNAs', $POS++, @_ );
  $self->add_new_track_cdna( 'Cow_cDNAs',   'Cow cDNAs', $POS++, @_ );
  $self->add_new_track_cdna( 'cow_cdna',   'Cow cDNAs', $POS++, @_ );
  $self->add_new_track_cdna( 'chicken_cdna', 'G.gallus cDNAs', $POS++, @_ );
  $self->add_new_track_cdna( 'macaque_cdna', 'Macaque cDNAs', $POS++, @_ );
  $self->add_new_track_cdna( 'fugu_cdnas', 'T.rubripes cDNAs', $POS++, @_ );
  $self->add_new_track_cdna( 'fugu_cdna', 'T.rubripes cDNAs', $POS++, @_ );
  $self->add_new_track_cdna( 'duck_cdna', 'Duck cDNAs', $POS++, @_ );
  $self->add_new_track_cdna( 'mouse_cdna', 'Mouse cDNAs',   $POS++, @_ );
  $self->add_new_track_cdna( 'other_cdna', 'Other cDNAs',   $POS++, @_ );
  $self->add_new_track_cdna( 'opossum_cdna', 'Opossum cDNAs',   $POS++, @_ );
  $self->add_new_track_cdna( 'refseq_mouse', 'RefSeqs', $POS++, 'SUBTYPE' => 'refseq', @_);
## now the tetraodon tracks...
  $self->add_new_track_cdna( 'cdm', 'Tetraodon cDNAs',   $POS++, 'SUBTYPE'     => 'genoscope', @_ );
  $self->add_new_track_cdna( 'xlaevis_cDNA', 'X.laevis cDNAs',   $POS++, @_ );
  $self->add_new_track_cdna( 'xtrop_cDNA', 'X.trop cDNAs',   $POS++, @_ );
  $self->add_new_track_cdna( 'ep3_h', 'Ecotig (Human prot)',   $POS++, 'SUBTYPE'     => 'genoscope_ecotig', @_ );
  $self->add_new_track_cdna( 'ep3_s', 'Ecotig (Mouse prot)',   $POS++, 'SUBTYPE'     => 'genoscope_ecotig', @_ );
  $self->add_new_track_cdna( 'eg3_h', 'Ecotig (Human DNA)',   $POS++, 'SUBTYPE'     => 'genoscope_ecotig', @_ );
  $self->add_new_track_cdna( 'eg3_s', 'Ecotig (Mouse DNA)',   $POS++, 'SUBTYPE'     => 'genoscope_ecotig', @_ );
  $self->add_new_track_cdna( 'eg3_f', 'Ecotig (Fugu DNA)',   $POS++,  'SUBTYPE'     => 'genoscope_ecotig', @_ );
  $self->add_new_track_cdna( 'cdna_update',     'CDNAs',         $POS++,
                            'FEATURES'  => 'UNDEF', 'available' => 'databases ENSEMBL_CDNA',
                            'THRESHOLD' => 0,       'DATABASE'  => 'cdna', @_ );
  $self->add_new_track_cdna( 'cdna_all',  'All CDNAs', $POS++, 'SUBTYPE' => 'cdna_all' , @_ );
  $self->add_new_track_cdna( 'washu_contig', 'WashU contig', $POS++, 'SUBTYPE' => 'washuc_conitg', @_ );
  $self->add_new_track_cdna( 'nembase_contig', 'NemBase contig', $POS++, 'SUBTYPE' => 'nembase_conitg', @_ );

  # Otherfeatures db
  my @EST_DB_CDNA = (
    [ 'drosophila_cdna_all',   'Fly cDNA (all)',  'URL_KEY' => 'DROSOPHILA_EST', 'ZMENU' => [ '###ID###', "Fly cDNA: ###ID###" => '###HREF###' ] ],
    [ 'drosophila_gold_cdna',  'Fly cDNA (gold)', 'URL_KEY' => 'DROSOPHILA_EST', 'ZMENU' => [ '###ID###', "Fly cDNA: ###ID###" => '###HREF###' ] ],
    [ 'kyotograil_2004',  "Kyotograil '04" ],
    [ 'kyotograil_2005',  "Kyotograil '05" ],
    [ 'platypus_454_cdna', "Platypus 454 cDNAs" ],
    [ 'platypus_cdna', "Platypus cDNAs (OF)" ],
    [ 'sheep_bac_ends',   "Sheep BAC ends", "URL_KEY" => 'TRACE', 'ZMENU' => [ '###ID###', 'Sheep BAC trace: ###ID###' => '###HREF###']  ],
    [ 'stickleback_cdna',   "Stickleback cDNAs" ], # subset of these in core but don't draw those

    # Duplicated tracks (same logic name used core and otherfeatures). Not ideal!
    [ 'human_cdna',            'Human cDNAs' ],
    [ 'macaque_cdna',          'Macaque cDNAs' ],
    [ 'mouse_cdna',            'Mouse cDNAs' ],
    [ 'rat_cdna',              'Rat cDNAs' ],
  );

  foreach ( @EST_DB_CDNA ) {
    my($A,$B,@T) = @$_;
    $self->add_new_track_cdna( "otherfeatures_$A",  $B, $POS++,
                              'FEATURES'  => $A, 'available' => "database_features ENSEMBL_OTHERFEATURES.$A",
                              'THRESHOLD' => 0, 'DATABASE' => 'otherfeatures', @T, @_ );
  }

  $self->add_new_track_cdna( 'community_models', 'Community models',    $POS++, @_ );
  $self->add_new_track_cdna( 'manual_models',    'Manual models',    $POS++, @_ );

  return $POS;
}



sub ADD_ALL_EST_FEATURES {
  my $self = shift;
  my $POS  = shift || 2350;
  $self->add_new_track_est( 'arraymap_e2g',   'ARRAY_MMC1_ests', $POS++, @_ );
  $self->add_new_track_est( 'BeeESTAlignmentEvidence', 'Bee EST evid.', $POS++, @_ );
  $self->add_new_track_est( 'est_rna',      'ESTs (RNA)',      $POS++, 'available' => 'features RNA',      'FEATURES' => 'RNA', @_ );
  $self->add_new_track_est( 'est_rnabest',  'ESTs (RNA best)', $POS++, 'available' => 'features RNA_BEST', 'FEATURES' => 'RNA_BEST', @_ );
  $self->add_new_track_est( 'ost', 'OSTs', $POS++, @_ );
  $self->add_new_track_est( 'caenorhabditis_est', 'Worm ESTs', $POS++, @_ );
  $self->add_new_track_est( 'celegans_est', 'C. elegans ESTs', $POS++, @_ );
  $self->add_new_track_est( 'cbriggsae_est', 'C. elegans ESTs', $POS++, @_ );
  $self->add_new_track_est( 'scerevisiae_est', 'S. cerevisiae ESTs', $POS++, @_ );
  $self->add_new_track_est( 'chicken_est',  'G.gallus ESTs',   $POS++, @_ );
  $self->add_new_track_est( 'dog_est_part2',  'C.familiaris ESTs',   $POS++, @_ );
  $self->add_new_track_est( 'macaque_est',  'Macaque ESTs',   $POS++, @_ );
  $self->add_new_track_est( 'yeast_est',  'Yeast ESTs',   $POS++, @_ );
  $self->add_new_track_est( 'human_est',    'Human ESTs',      $POS++, @_ );
  $self->add_new_track_est( 'medaka_est',    'Medaka ESTs',    $POS++, @_ );
  $self->add_new_track_est( 'horse_est',    'Horse ESTs',      $POS++, @_ );
  $self->add_new_track_est( 'orangutan_est',    'Orangutan ESTs',      $POS++, @_ );
  $self->add_new_track_est( 'pig_est',    'Pig ESTs',      $POS++, @_ );
  $self->add_new_track_est( 'platypus_ests', 'Platypus ESTs',   $POS++, @_ );

  $self->add_new_track_est( 'species_est',  'Dog ESTs',      $POS++, @_ );
  $self->add_new_track_est( 'mouse_est',    'Mouse ESTs',      $POS++, @_ );
  $self->add_new_track_est( 'fugu_est',    'T.rubripes ESTs',      $POS++, @_ );
  $self->add_new_track_est( 'lamprey_est',    'Lamprey ESTs',      $POS++, @_ );
  $self->add_new_track_est( 'zfish_est',    'D.rerio ESTs',    $POS++, @_ );
  $self->add_new_track_est( 'Btaurus_Exonerate_EST',    'B.taurus ESTs',    $POS++, @_ );
  $self->add_new_track_est( 'Cow_ESTs',    'B.taurus ESTs',    $POS++, @_ );
  $self->add_new_track_est( 'Exonerate_EST_083',    'Ciona ESTs',    $POS++, @_ );
  $self->add_new_track_est( 'xlaevis_EST', 'X.laevis ESTs',   $POS++, @_ );
  $self->add_new_track_est( 'xtrop_cluster','X.trop EST clust', 
							$POS++, 'URL_KEY' => 'XTROP_CLUSTER',
							'SUBTYPE' => 'default',
							@_);
  $self->add_new_track_est( 'xtrop_EST_clusters','X.trop EST clust',
                                                        $POS++, 'URL_KEY' => 'XTROP_CLUSTER',
                                                        'SUBTYPE' => 'default',
                                                        @_);

  $self->add_new_track_est( 'anopheles_cdna_est',    'EST support',           $POS++, @_ );
  $self->add_new_track_est( 'ciona_dbest_align',     'dbEST align',           $POS++, @_ );
  $self->add_new_track_est( 'ciona_est_3prim_align', "3' EST-align. (Kyoto)", $POS++, @_ );
  $self->add_new_track_est( 'ciona_est_5prim_align', "5' EST-align. (Kyoto)", $POS++, @_ );
  $self->add_new_track_est( 'ciona_cdna_align',      'cDNA-align. (Kyoto)',   $POS++, @_ );
  $self->add_new_track_est( 'cint_est',              'Ciona ESTs',            $POS++, @_ );
  #$self->add_new_track_est( 'savignyi_est',          "C.savigyi EST",         $POS++, @_ );  # added to OTHERFEATURES
  $self->add_new_track_est( 'expression_pattern',    'Expression pattern', $POS++, 'URL_KEY' => 'EXPRESSION_PATTERN', 'SUBTYPE' => 'default', @_ );
  $self->add_new_track_est( 'other_est',    'Other ESTs',      $POS++, @_ );
  $self->add_new_track_est( 'cDNA_exonerate',    'ESTs',      $POS++, @_ );

  my @EST_DB_ESTS = (
    [ 'anopheles_cdna_est',    'RNA (BEST)'],      # subset of these in core but don't draw those
    [ 'estgene',               'ESTs' ],
    [ 'bee_est',               'Bee EST' ],
    [ 'chicken_ests',          'Chicken EST' ],
    [ 'est_embl',              "C.savigyi EST" ],  # subset of these in core but don't draw those
    [ 'chicken_est_exonerate', 'Chicken EST (ex.)' ],
    [ 'human_est',   'Human EST' ],
    [ 'human_est_exonerate',   'Human EST (ex.)' ],
    [ 'est_exonerate',         'EST (ex.)' ],
    [ 'ciona_est',             'Ciona EST' ],
    [ 'drosophila_est',        'Fly EST' ],
    [ 'cow_est',               'Cow EST' ],
    [ 'fugu_est',              'Fugu EST' ],
    [ 'RNA',                   'Mosquito EST' ],
    [ 'mouse_est',             'Mouse EST' ],
    [ 'rat_est',               'Rat EST' ],
    [ 'xlaevis_EST',           'X.laevis EST' ],
    [ 'xtrop_EST',             'X.trop EST' ],
    [ 'zfish_EST',             'Zfish EST' ],
    [ 'anopheles_cdna_est_all','RNA (ALL)' ],
    [ 'est_bestn_5prim',       "EST BestN 5'" ],
    [ 'est_bestn_3prim',       "EST Bestn 3'" ],
    [ 'stickleback_est',       "Stickleback EST" ],   # subset of these in core but don't draw those
    [ 'est_3prim_savi',        "C.savigyi EST 3'"],   # subset of these in core but don't draw those
    [ 'est_5prim_savi',        "C.savigyi EST 5'"],   # subset of these in core but don't draw those
    [ 'cint_cdna',             'Ciona EST' ],
    [ 'savignyi_est',          "C.savigyi EST"],      # subset of these in core but don't draw those

    # Duplicated tracks (same logic name used core and otherfeatures). Not ideal!
    [ 'platypus_est',          'Platypus ESTs (OF)' ],
    [ 'macaque_est',           'Macaque ESTs' ],
  );


  foreach ( @EST_DB_ESTS ) {
    my($A,$B,@T) = @$_;
    $self->add_new_track_est( "otherfeatures_$A",  $B, $POS++,
                              'FEATURES'  => $A, 'available' => "database_features ENSEMBL_OTHERFEATURES.$A",
                              'THRESHOLD' => 0, 'DATABASE' => 'otherfeatures', @T, @_ );
  }


  # Hacky ones
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
  $self->add_new_track_est( 'est2clones',   'ARRAY_MMC1_reporters', $POS++, 'URL_KEY' => 'VECTORBASE_REPORTER', 'str' => 'r', 'SUBTYPE' => 'mmc',  'ZMENU' => [ 'Reporter ###LABEL###', '###LABEL###' => '###HREF###' ], @_ );
  return $POS;
}

sub ADD_ALL_CLONE_TRACKS {
  my $self = shift;
  my $POS = shift || 2500;
  $self->add_clone_track( 'MAPTP_set_v1', 'MAPTP clone set',   $POS++, @_ );
  $self->add_clone_track( '10Mb_set', '10Mb clone set',   $POS++, @_ );
  $self->add_clone_track( '0_5MB_cloneset', '0.5Mb clones',   $POS++, @_ );
  $self->add_clone_track( '1MB_cloneset',   '1Mb clones',     $POS++, @_ );
  $self->add_clone_track( 'cloneset_1mb',   '1Mb clones',     $POS++, @_ );
  $self->add_clone_track( 'cloneset_30k',   '30k TPA clones', $POS++, @_ );
  $self->add_clone_track( 'cloneset_32k',   '32k clones',     $POS++, @_ );
  $self->add_clone_track( 'acc_bac_map',    'Acc. BAC map',   $POS++, @_ );
  $self->add_clone_track( 'pig_acc_bac_map',    'Acc. BAC map',  
    $POS++, 'LINKS' => [[ 'Sequenced clone', 'pig_seq_clone', '/Sus_scrofa/cytoview?misc_feature=###ID###' ]], @_ );
  $self->add_clone_track( 'seq_bac_map',    'Sequenced BAC map',   $POS++, @_ );
  $self->add_clone_track( 'bac_map',        'BAC map',        $POS++, 'thresholds' => { 20000 => {'FEATURES'=>'acc_bac_map seq_bac_map'}}, @_ );
  $self->add_clone_track( 'pig_bac_map',        'BAC map',        $POS++,      'LINKS' => [[ 'Sequenced clone', 'pig_seq_clone', '/Sus_scrofa/cytoview?misc_feature=###ID###' ]],
        'thresholds' => { 20000 => {'FEATURES'=>'pig_acc_bac_map'}}, @_ );
  $self->add_clone_track( 'BAC',            'BAC map',        $POS++, 'LINKS' => [[ 'Clone map', 'clone_name', '/Sus_scrofa_map/cytoview?misc_feature=###ID###' ]], @_ );
  $self->add_clone_track( 'bacs',           'BACs',           $POS++, @_ );
  $self->add_clone_track( 'bacs_bands',     'Band BACs',      $POS++, @_ );
  $self->add_clone_track( 'bacends',        'BAC ends',       $POS++, @_ );
  $self->add_clone_track( 'extra_bacs',     'Extra BACs',     $POS++, 'thresholds' => { 20000 => { 'navigation' => 'off', 'height' => 4, 'threshold' => 50000 } }, @_ );
  $self->add_clone_track( 'ex_bac_map',        'BAC map',     $POS++, 'FEATURES' => 'bac_map', 'DATABASE' => 'otherfeatures', 'available' => 'database_tables ENSEMBL_OTHERFEATURES.misc_set',  @_ );
  $self->add_clone_track( 'tilepath_cloneset', 'Mouse Tilepath', $POS++, 'on' => 'on', @_ );
  $self->add_clone_track( 'tilepath',       'Human tilepath clones', $POS++, 'on' => 'on', @_ );
  $self->add_clone_track( 'fosmid_map',     'Fosmid map',     $POS++, 'colour_set' => 'fosmids', 'thresholds' => { 20000 => { 'navigation' => 'off', 'height' => 4, 'threshold' => 50000 }}, @_ );
}

sub ADD_ALL_PROTEIN_FEATURES {
  my $self = shift;
  my $POS  = shift || 2200;
  $self->add_new_track_protein( 'my_prots',            'My protiens',    $POS++, 'SUBTYPE' => 'my_prot', @_ );
  $self->add_new_track_protein( 'swall',               'Proteins',       $POS++, @_ );
  $self->add_new_track_protein( 'swall_blastx',        'Proteins',       $POS++, @_ );
  $self->add_new_track_protein( 'uniprot',             'UniProtKB',      $POS++, @_ );
  $self->add_new_track_protein( 'uniprot_SW',          'UniProtKB_SW',   $POS++, @_ );
  $self->add_new_track_protein( 'uniprot_TR',          'UniProtKB_TR',   $POS++, @_ );
  $self->add_new_track_protein( 'Uniprot_wublastx',    'UniProtKB (v. genscans)',       $POS++, @_ );
  $self->add_new_track_protein( 'Uniprot_mammal',      'UniProtKB (mammal)',       $POS++, @_ );
  $self->add_new_track_protein( 'Uniprot_non_mammal',  'UniProtKB (non-mammal)',       $POS++, @_ );
  $self->add_new_track_protein( 'uniprot_vertebrate_mammal',  'UniProtKB (mammal)',       $POS++, @_ );
  $self->add_new_track_protein( 'uniprot_vertebrate_non_mammal',  'UniProtKB (non-mammal)',       $POS++, @_ );
  $self->add_new_track_protein( 'uniprot_non_vertebrate',         'UniProtKB (non-vertebrate)',    $POS++, @_ );
  $self->add_new_track_protein( 'drosophila-peptides', 'Dros. peptides', $POS++, @_ );
  $self->add_new_track_protein( 'swall_high_sens',     'UniProtKB', $POS++, @_ );
  $self->add_new_track_protein( 'anopheles_peptides',  'Mos. peptides',  $POS++,
    'SUBTYPE'     => 'default' ,
    'URL_KEY'     => 'ENSEMBL_ANOPHELES_ESTTRANS', 'ID' => TRIM, 'LABEL' => TRIM,
  @_ );
  $self->add_new_track_protein( 'chicken_protein',     'G.gallus pep', $POS++, @_ );
  $self->add_new_track_protein( 'BeeProteinSimilarity','Bee pep. evid.',  $POS++, @_ );
  $self->add_new_track_protein( 'riken_prot',          'Riken proteins', $POS++, @_ );
  $self->add_new_track_protein( 'wormpep',             'Worm proteins',  $POS++, @_ );
  $self->add_new_track_protein( 'remaneipep',          'C.remanei proteins',  $POS++, @_ );
  $self->add_new_track_protein( 'brigpep',             'C.briggsae proteins',  $POS++, @_ );
  $self->add_new_track_protein( 'human-ipr',           'Human IPR',  $POS++, @_ );
  $self->add_new_track_protein( 'Swissprot',           'UniProtKB/Swissprot',  $POS++, @_ );
  $self->add_new_track_protein( 'TrEMBL',              'UniProtKB/TrEMBL',  $POS++, @_ );
  $self->add_new_track_protein( 'flybase',             'FlyBase proteins',  $POS++, @_ );
  $self->add_new_track_protein( 'sgd',                 'SGD proteins',  $POS++, @_ );
  $self->add_new_track_protein( 'human_protein',       'Human proteins', $POS++, @_ );

  $self->add_new_track_protein( 'human_refseq',        'Human RefSeqs', $POS++, @_ );
  $self->add_new_track_protein( 'species_protein',     'Dog proteins', $POS++, @_ );
  $self->add_new_track_protein( 'platypus_protein', 'Platypus Proteins',   $POS++, @_ );

  $self->add_new_track_protein( 'Btaurus_Exonerate_Protein',         'Cow proteins', $POS++, @_ );
  $self->add_new_track_protein( 'cow_proteins',        'Cow proteins', $POS++, @_ );
  $self->add_new_track_protein( 'aedes_protein',       'Aedes proteins', $POS++, @_ );
  $self->add_new_track_protein( 'cow_protein',         'Cow proteins', $POS++, @_ );
  $self->add_new_track_protein( 'horse_protein',    'Horse proteins',      $POS++, @_ );
  $self->add_new_track_protein( 'orangutan_protein',   'Orangutan proteins',      $POS++, @_ );
  $self->add_new_track_protein( 'medaka_protein',      'Medaka proteins', $POS++, @_ );
  $self->add_new_track_protein( 'fugu_protein',        'Fugu proteins', $POS++, @_ );
  $self->add_new_track_protein( 'fish_protein',        'Fish proteins', $POS++, @_ );
  $self->add_new_track_protein( 'macaque_protein',     'Macaque proteins', $POS++, @_ );
  $self->add_new_track_protein( 'macaque_refseq',      'Macaque RefSeqs', $POS++, @_ );
  $self->add_new_track_protein( 'mouse_protein',       'Mouse proteins', $POS++, @_ );
  $self->add_new_track_protein( 'mouse_refseq',        'Mouse RefSeqs', $POS++, @_ );
  $self->add_new_track_protein( 'opossum_protein',     'Opossum proteins',$POS++, @_ );
  $self->add_new_track_protein( 'rodent_protein',      'Rodent proteins',$POS++, @_ );
  $self->add_new_track_protein( 'stickleback_protein', 'Stickleback proteins', $POS++, @_);
  $self->add_new_track_protein( 'lamprey_protein',        'Lamprey proteins', $POS++, @_ );
  $self->add_new_track_protein( 'mammal_protein',      'Mammal proteins', $POS++, @_ );
  $self->add_new_track_protein( 'other_protein',       'Other proteins', $POS++, @_ );
  $self->add_new_track_protein( 'other_proteins',      'Other proteins', $POS++, @_ );
  $self->add_new_track_protein( 'GenomeUniprotBlast',  'Genome UniP.Bl.',   $POS++, @_ );
  $self->add_new_track_protein( 'GenscanPeptidesUniprotBlast', 'Gen.Pep. UniP.BL.', $POS++, @_ );
  $self->add_new_track_protein( 'BeeProteinBlast',     'Bee Protein blast', $POS++, @_ );
  $self->add_new_track_protein( 'human_ensembl_peptides', 'Human e! peptides',  $POS++, 'URL_KEY' => 'HUMAN_PROTVIEW', @_ );
  $self->add_new_track_protein( 'human_ensembl_proteins', 'Human e! proteins',  $POS++, 'URL_KEY' => 'HUMAN_PROTVIEW', @_ );
  #$self->add_new_track_protein( 'ciona_jgi_v1',            'JGI 1.0 model', $POS++, @_ );
  #$self->add_new_track_protein( 'ciona_kyotograil_2004',   "Kyotograil '04 model", $POS++, @_ );
  #$self->add_new_track_protein( 'ciona_kyotograil_2005',   "Kyotograil '05 model", $POS++, @_ );
  $self->add_new_track_protein( 'blastx',              'BLASTx', $POS++, @_ );
  $self->add_new_track_protein( 'blastp',              'BLASTp', $POS++, @_ );
  #$self->add_new_track_protein( 'kyotograil_2004',    "Kyotograil '04 model", $POS++, @_ );
  #$self->add_new_track_protein( 'kyotograil_2005',    "Kyotograil '05 model", $POS++, @_ );
#/* aedes additions */
  $self->add_new_track_protein( 'Similarity_Diptera',   "Similarity Diptera", $POS++, @_ );
  $self->add_new_track_protein( 'Similarity_Arthropoda',"Similarity Arthropoda", $POS++, @_ );
  $self->add_new_track_protein( 'Similarity_Metazoa',   "Similarity Metazoa", $POS++, @_ );
  $self->add_new_track_protein( 'Similarity_Eukaryota', "Similarity Eukaryota", $POS++, @_ );

  $self->add_new_track_protein( 'AedesBlast',      "BLAST Aedes",$POS++, 'URL_KEY' => 'AEDESBLAST',  @_ );
  $self->add_new_track_protein( 'DrosophilaBlast',      "BLAST Drosophila", $POS++, 'URL_KEY' => 'DROSOPHILABLAST', @_ );
  $self->add_new_track_protein( 'UniprotBlast',         "BLAST UniProtKB", $POS++, @_ );
  $self->add_new_track_protein( 'anopheles_protein',    "Anopheles protein", $POS++, @_ );
  $self->add_new_track_protein( 'drosophila_protein',   "Dros. protein", $POS++, 'URL_KEY' => 'DROSOPHILABLAST',@_ );

  $self->add_new_track_protein( 'DipteraBlast',    "BLAST Diptera", $POS++, @_ );
  $self->add_new_track_protein( 'ArthropodaBlast', "BLAST Arthropoda", $POS++, @_ );
  $self->add_new_track_protein( 'MetazoaBlast',    "BLAST Metazoa", $POS++, @_ );
  $self->add_new_track_protein( 'EukaryotaBlast',  "BLAST Eukaryota", $POS++, @_ );
  $self->add_new_track_protein( 'EverythingBlast', "BLAST All", $POS++, @_ );

  my @EST_DB_ESTS_PROT = (
    [ 'jgi_v1',        'JGI V1' ],
    [ 'jgi_v2',        'JGI V2' ],
  );
  foreach ( @EST_DB_ESTS_PROT ) {
    my($A,$B,@T) = @$_;
    $self->add_new_track_est_protein( "otherfeatures_$A",  $B, $POS++,
                              'FEATURES'  => $A, 'available' => "database_features ENSEMBL_OTHERFEATURES.$A",
                              'THRESHOLD' => 0, 'DATABASE' => 'otherfeatures', @T, @_ );
  }



  return $POS;
}

sub ADD_ALL_PREDICTIONTRANSCRIPTS {
  my $self = shift;
  my $POS  = shift || 2100;
  $self->add_new_track_predictiontranscript( 'fgenesh',   'Fgenesh',     'darkkhaki',       $POS ++, {}, @_ );
  $self->add_new_track_predictiontranscript( 'augustus',  'Augustus',    'darkseagreen4',   $POS ++, {}, @_ );
  $self->add_new_track_predictiontranscript( 'genscan',   'Genscan',     'lightseagreen',   $POS ++, {}, @_ );
  $self->add_new_track_predictiontranscript( 'genefinder','Genefinder',  'darkolivegreen4', $POS ++, {}, @_ );
  $self->add_new_track_predictiontranscript( 'snap',      'SNAP',        'darkseagreen4',   $POS ++, {}, @_ );
  $self->add_new_track_predictiontranscript( 'snap_ciona','SNAP (Ciona)','darkseagreen4',   $POS ++, {}, @_ );
  $self->add_new_track_predictiontranscript( 'slam',      'SLAM',        'darkgreen',       $POS ++, {}, @_ );
  $self->add_new_track_predictiontranscript( 'gsc',       'Genscan',     'lightseagreen',   $POS ++, { 'Genoscope' => 'TETRAODON_ABINITIO' }, @_ );
  $self->add_new_track_predictiontranscript( 'gid',       'Gene id',     'red',             $POS ++, { 'Genoscope' => 'TETRAODON_ABINITIO' }, @_ );
  $self->add_new_track_predictiontranscript( 'gws_h',     'Genewise (Human)', 'orange',     $POS ++, { 'Genoscope' => 'TETRAODON_GENEWISE' }, @_ );
  $self->add_new_track_predictiontranscript( 'gws_s',     'Genewise (Mouse)', 'orange',     $POS ++, { 'Genoscope' => 'TETRAODON_GENEWISE' }, @_ );

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
  $self->add_new_track_transcript( 'ensembl',   'Ensembl genes',   'ensembl_gene',   $POS++, 'logic_name' => 'havana ensembl_havana_gene ensembl' );
  $self->add_new_track_transcript( 'ensembl_projection',   'Ensembl proj. genes',   'ensembl_projection',   $POS++, @_ );
  $self->add_new_track_transcript( 'ensembl_segment',      'Ig segments',           'ensembl_segment',   $POS++, @_ );
  $self->add_new_track_transcript( 'evega',         'Vega Havana gene',      'vega_gene_havana',    $POS++, 'glyph' => 'evega_transcript', 'db' => 'vega', 'logic_name' => 'otter', 'available' => 'database_features ENSEMBL_VEGA.OTTER',  'on' => 'off',   @_ );
  $self->add_new_track_transcript( 'evega_external','Vega External gene',    'vega_gene_external',  $POS++, 'glyph' => 'evega_transcript', 'db' => 'vega', 'logic_name' => 'otter_external', 'available' => 'database_features ENSEMBL_VEGA.OTTER_EXTERNAL', 'on' => 'off',    @_ );
  $self->add_new_track_transcript( 'flybase',   'Flybase genes',   'flybase_gene',   $POS++, @_ );
  $self->add_new_track_transcript( 'vectorbase', 'Vectorbase genes', 'vectorbase_gene',   $POS++, @_ );
  $self->add_new_track_transcript( 'wormbase',  'Wormbase genes',  'wormbase_gene',  $POS++, @_ );
  $self->add_new_track_transcript( 'sgd',       'SGD genes',  'sgd_gene',  $POS++, @_ );
  $self->add_new_track_transcript( 'genebuilderbeeflymosandswall',
                                                'Bee genes',       'bee_gene',       $POS++, @_ );
  $self->add_new_track_transcript( 'gsten',     'Genoscope genes', 'genoscope_gene', $POS++, 'logic_name' => 'gsten hox ctt', @_ );
  $self->add_new_track_transcript( 'rna',       'ncRNA genes',     'rna_gene',       $POS++, 'available' => 'features NCRNA|MIRNA|TRNA|SNLRNA|SNORNA|SNRNA|RRNA','logic_name' => 'ncrna mirna trna snlrna snorna snrna rrna' ,  'compact' => 1,   @_ );
  $self->add_new_track_transcript( 'erna',       'e! ncRNA genes', 'rna_gene',   $POS++, 'available' => 'features ensembl_ncRNA', 'logic_name' => 'ensembl_ncrna',  'legend_type' => 'rna',  'compact' => 1,      @_ );

  $self->add_new_track_transcript( 'ciona_dbest_ncbi', "3/5' EST genes (dbEST)", 'estgene', $POS++, @_) ;
  $self->add_new_track_transcript( 'ciona_est_seqc',   "3' EST genes (Kyoto)", 'estgene', $POS++, @_) ;
  $self->add_new_track_transcript( 'ciona_est_seqn',   "5' EST genes (Kyoto)",  'estgene',$POS++, @_) ;
  $self->add_new_track_transcript( 'ciona_est_seqs',   "full insert cDNA clone",  'estgene',$POS++, @_) ;
  $self->add_new_track_transcript( 'ciona_jgi_v1',     "JGI 1.0 models", 'ciona_gene',  $POS++, @_) ;
  $self->add_new_track_transcript( 'ciona_kyotograil_2004',  "Kyotograil '04 model", 'ciona_gene',  $POS++, @_) ;
  $self->add_new_track_transcript( 'ciona_kyotograil_2005',  "Kyotograil '05 model",  'ciona_gene', $POS++, @_) ;

  $self->add_new_track_transcript( 'rprot',     'Rodent proteins', 'prot_gene', $POS++, 'available' => 'features rodent_protein','logic_name' => 'rodent_protein',  @_ );
  $self->add_new_track_transcript( 'mouse_protein',    'Refseq proteins', 'prot_gene',    $POS++, @_ );
  $self->add_new_track_transcript( 'targettedgenewise',    'Targetted genewise genes', 'prot_gene',    $POS++, @_ );
  $self->add_new_track_transcript( 'cdna_all',             'cNDA genes', 'prot_gene',    $POS++, @_ );
  $self->add_new_track_transcript( 'refseq',    'Refseq proteins', 'refseq_gene',    $POS++, @_ );
  $self->add_new_track_transcript( 'rprot',     'Rodent proteins', 'prot_gene',      $POS++, @_ );
  $self->add_new_track_transcript( 'jamboree_cdnas',   'X.trop. jambo. genes',   'prot_gene',   $POS++, @_ );
  $self->add_new_track_transcript( 'oxford_genes', 'Oxford Genes', 'oxford_genes', $POS++, @_ );
  $self->add_new_track_transcript( 'oxford_fgu', 'Oxford FGU Genes', 'oxford_fgu', $POS++, @_ );
  $self->add_new_track_transcript( 'platypus_olfactory_receptors', 'Olfactory receptor Genes', 'olfactory', $POS++, @_ );
#  $self->add_new_track_transcript( 'platypus_protein', 'Platypus/Other Genes', 'platypus_protein', $POS++, @_ );
#  $self->add_new_track_transcript( 'medaka_protein',   'Medaka genes',   'medaka_gene',   $POS++, @_ );
  $self->add_new_track_transcript( 'fugu_protein', 'T.rubripes protein', 'fugu_protein', $POS++,  @_ );
  $self->add_new_track_transcript( 'lamprey_protein', 'Lamprey protein', 'lamprey_protein', $POS++,  @_ );
  $self->add_new_track_transcript( 'gff_prediction',   'MGP genes',   'medaka_gene',   $POS++, @_ );

  $self->add_new_track_transcript( 'dog_protein',   'Dog genes',   'dog_protein',   $POS++, @_ );
  $self->add_new_track_transcript( 'species_protein', 'Dog protein',       'prot_gene', $POS++,  @_ );
  $self->add_new_track_transcript( 'horse_protein', 'Horse protein', 'horse_protein', $POS++,  @_ );
  $self->add_new_track_transcript( 'orangutan_protein', 'Orangutan protein', 'orangutan_protein', $POS++,  @_ );
  $self->add_new_track_transcript( 'human_one2one_mus_orth', 'Hs/Mm orth', 'prot_gene', $POS++,  @_ );
  $self->add_new_track_transcript( 'human_one2one_mouse_cow_orth', 'Hs/Mm orth', 'prot_gene', $POS++,  @_ );
  $self->add_new_track_transcript( 'human_ensembl_proteins',   'Human genes',   'human_ensembl_proteins_gene',   $POS++, @_ );
  $self->add_new_track_transcript( 'mus_one2one_human_orth', 'Ms/Hs orth', 'prot_gene', $POS++,  @_ );

  $self->add_new_track_transcript( 'cow_proteins',   'Cow genes',   'cow_protein',   $POS++, @_ );
 # $self->add_new_track_transcript( 'vectorbase_0_5',   'VectorBase genes',   'vectorbase_0_5',   $POS++, @_ );
  $self->add_new_track_transcript( 'tigr_0_5',   'TIGR genes',   'tigr_0_5',   $POS++, @_ );
  $self->add_new_track_transcript( 'homology_low', 'Bee genes',    'bee_pre_gene',   $POS++, @_ );
  # trancripts for Vega
  $self->add_new_track_transcript('vega_eucomm', 'KO genes (EUCOMM)', 'vega_gene_eucomm',
    $POS++, 'glyph' => 'vega_transcript', 'logic_name' => 'otter_eucomm',
    'available'=>'features VEGA_GENES_OTTER_EUCOMM', @_);
  $self->add_new_track_transcript('vega_komp', 'KO genes (KOMP)', 'vega_gene_komp',
    $POS++, 'glyph' => 'vega_transcript', 'logic_name' => 'otter_komp',
    'available'=>'features VEGA_GENES_OTTER_KOMP', @_);
  $self->add_new_track_transcript('vega', 'Havana genes', 'vega_gene_havana',
    $POS++, 'glyph' => 'vega_transcript', 'logic_name' => 'otter',
    'available'=>'features VEGA_GENES_OTTER', @_);
  $self->add_new_track_transcript('vega_corf', 'CORF genes', 'vega_gene_corf',
    $POS++, 'glyph' => 'vega_transcript', 'logic_name' => 'otter_corf',
    'available'=>'features VEGA_GENES_OTTER_CORF', @_);
   $self->add_new_track_transcript('vega_external', 'External genes', 'vega_gene_external',
    $POS++, 'glyph' => 'vega_transcript', 'logic_name' => 'otter_external',
    'available'=>'features VEGA_GENES_OTTER_EXTERNAL', @_);
## OTHER FEATURES DATABASE TRANSCRIPTS....
  $self->add_new_track_transcript( 'est',       'EST genes',       'est_gene', $POS++,'db' => 'otherfeatures',
    'available' => 'database_features ENSEMBL_OTHERFEATURES.estgene',  'compact'     => 1,  @_ );

  $self->add_new_track_transcript( 'oxford_fgu_ext', 'Oxford FGU Genes', 'oxford_fgu', $POS++, 'db' => 'otherfeatures', 
    'available' => "database_features ENSEMBL_OTHERFEATURES.oxford_fgu", @_ );
  $self->add_new_track_transcript( 'medaka_transcriptcoalescer', 'EST Genes',     'medaka_genes',$POS++, 'db' => 'otherfeatures',
    'available' => "database_features ENSEMBL_OTHERFEATURES.medaka_transcriptcoalescer" , @_ );
  $self->add_new_track_transcript( 'medaka_genome_project', 'MGP Genes',     'medaka_genes',$POS++,'db' => 'otherfeatures',
    'available' => "database_features ENSEMBL_OTHERFEATURES.medaka_genome_project", @_ );
  $self->add_new_track_transcript( 'singapore_est', 'Singapore EST Genes', 'est_gene', $POS++, 'db' => 'otherfeatures',
     'available' => "database_features ENSEMBL_OTHERFEATURES.singapore_est", @_ );
  $self->add_new_track_transcript( 'singapore_protein', 'Singapore Protein Genes', 'prot_gene', $POS++, 'db' => 'otherfeatures',
     'available' => "database_features ENSEMBL_OTHERFEATURES.singapore_protein", @_ );
  $self->add_new_track_transcript( 'chimp_cdna', 'Chimp cDNA Genes', 'chimp_genes', $POS++, 'db' => 'otherfeatures',
     'available' => "database_features ENSEMBL_OTHERFEATURES.chimp_cdna", @_ );
  $self->add_new_track_transcript( 'human_cdna', 'Human cDNA Genes', 'chimp_genes', $POS++, 'db' => 'otherfeatures',
     'available' => "database_features ENSEMBL_OTHERFEATURES.human_cdna", @_ );
  $self->add_new_track_transcript( 'chimp_est', 'Chimp EST Genes', 'chimp_genes', $POS++,'db' => 'otherfeatures',
     'available' => "database_features ENSEMBL_OTHERFEATURES.chimp_est", @_ );
  return $POS;
}

sub ADD_ALL_OLIGO_TRACKS {
  my $self = shift;
  my $POS  = shift || 4000;
  my %T = map { %{ $self->{'species_defs'}{'_storage'}->{$_}{'OLIGO'}||{} } }
          keys %{$self->{'species_defs'}{'_storage'}};
#  foreach (keys %{$self->{'species_defs'}{'_storage'}}) {
#    warn "$_\n  ",join "\n  ", keys %{ $self->{'species_defs'}{'_storage'}->{$_}{'OLIGO'} };
#  }
  my @OLIGO = sort keys %T;
  foreach my $chipset (@OLIGO) {
    ( my $T = lc($chipset) ) =~ s/\W/_/g;
    ( my $T2 = $chipset ) =~ s/Plus_/+/i;
    $self->add_track(
      $T, 'on' => 'off', 'pos' => $POS++, 'str' => 'b', '_menu' => 'features', 
          'caption' => "OLIGO $T2",
          'dep' => 6,
      'col' => 'springgreen4',
      'compact'   => 0,
      'available' => "features oligo_$T",
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
  $self->add_new_simple_track( 'regulatory_search_region',  'Regulatory search region', 'red', $POS++, @_ );
  $self->add_new_simple_track( 'mature_peptide',           'Mature peptide',      'red', $POS++, @_ );
  $self->add_new_simple_track( 'insertion_site',           'Insertion site',      'red', $POS++, @_ );
  $self->add_new_simple_track( 'protein_binding_site',     'Protein binding site','red', $POS++, @_ );
  $self->add_new_simple_track( 'scaffold',                 'Scaffold',            'red', $POS++, @_ );
  $self->add_new_simple_track( 'allele',                   'Allele',              'red', $POS++, @_ );
#  $self->add_new_simple_track( 'RNAi',                     'RNAi',              'red', $POS++, @_ );
  $self->add_new_simple_track( 'fosmid',                   'Fosmid',              'red', $POS++, @_ );
  $self->add_new_simple_track( 'transposable_element_insertion_site', 'Transposable element insertion site', 'red', $POS++, @_ );
  $self->add_new_simple_track( 'transposable_element',     'Transposable element','red', $POS++, @_ );
  $self->add_new_simple_track( 'rescue_fragment',          'Rescue fragment',     'red', $POS++, @_ );
  $self->add_new_simple_track( 'signal_peptide',           'Signal peptide',      'red', $POS++, @_ );
  $self->add_new_simple_track( 'MMC2_probes',              'MMC2 probes',         'red', $POS++, @_ );
  $self->add_new_simple_track( 'oligo',                    'Oligo',               'red', $POS++, @_ );

  # some simple features are configured in contigview
}


sub ADD_GENE_TRACKS {
  my $self = shift;
  my $POS  = shift || 2000;
  $self->add_new_track_gene( 'ensembl', 'Ensembl Genes', 'ensembl_gene', $POS++,
    'gene_label'           => sub { return $_[0]->biotype eq 'bacterial_contaminant' ? 'Bac. cont.' : ( $_[0]->biotype eq 'pseudogene' ? 'Pseudogene' : ( $_[0]->external_name || 'NOVEL' ) ) },
    'gene_col'             => sub { return $_[0]->biotype eq 'bacterial_contaminant' ? '_BACCOM'    : $_[0]->analysis->logic_name.'_'.$_[0]->biotype.'_'.$_[0]->status          },
    'logic_name'           => 'ensembl psuedogene havana ensembl_havana_gene', @_
  );
  $self->add_new_track_gene( 'otter', 'Vega Havana Genes', 'vega_gene_havana', $POS++,
                             'database' => 'vega', 'available' => 'database_features ENSEMBL_VEGA.OTTER',
                             'gene_col'             => sub { return $_[0]->biotype.'_'.$_[0]->status; },
                             'gene_label'           => sub { $_[0]->external_name || $_[0]->stable_id; },
                             'glyphset' => 'evega_gene', 'label_threshold' => 500, 'on' => 'off', 
                               @_ );
  $self->add_new_track_gene( 'otter_external', 'Vega External Genes', 'vega_gene_external', $POS++,
                             'database' => 'vega', 'available' => 'database_features ENSEMBL_VEGA.OTTER_EXTERNAL',
                              'gene_col'            => sub { return $_[0]->biotype.'_'.$_[0]->status; },
                             'gene_label'           => sub { $_[0]->external_name || $_[0]->stable_id; },
                             'glyphset' => 'evega_gene', 'label_threshold' => 500, 'on' => 'off', 
                              @_ );
  $self->add_new_track_gene( 'flybase', 'Flybase Genes', 'flybase_gene', $POS++,
    'gene_label'           => sub { return $_[0]->biotype eq 'bacterial_contaminant' ? 'Bac. cont.' : ( $_[0]->biotype eq 'pseudogene' ? 'Pseudogene' : ( $_[0]->external_name || 'NOVEL' ) ) },
    'gene_col'             => sub { return $_[0]->biotype eq 'bacterial_contaminant' ? '_BACCOM'    : $_[0]->analysis->logic_name.'_'.$_[0]->biotype.'_'.$_[0]->status          },
    'logic_name'           => 'flybase pseudogene', @_
  );
  $self->add_new_track_gene( 'vectorbase', 'Vectorbase Genes', 'vectorbase_gene', $POS++,
    'gene_label'           => sub { return $_[0]->biotype eq 'bacterial_contaminant' ? 'Bac. cont.' : ( $_[0]->biotype eq 'pseudogene' ? 'Pseudogene' : ( $_[0]->external_name || 'NOVEL' ) ) },
    'gene_col'             => sub { return $_[0]->biotype eq 'bacterial_contaminant' ? '_BACCOM'    : $_[0]->analysis->logic_name.'_'.$_[0]->biotype.'_'.$_[0]->status          },
    'logic_name'           => 'vectorbase pseudogene', @_
  );
  $self->add_new_track_gene( 'wormbase', 'Wormbase Genes', 'wormbase_gene', $POS++,
    'gene_label'           => sub { return $_[0]->biotype eq 'bacterial_contaminant' ? 'Bac. cont.' : ( $_[0]->biotype eq 'pseudogene' ? 'Pseudogene' : ( $_[0]->external_name || 'NOVEL' ) ) },
    'gene_col'             => sub { return $_[0]->biotype eq 'bacterial_contaminant' ? '_BACCOM'    : $_[0]->analysis->logic_name.'_'.$_[0]->biotype.'_'.$_[0]->status          },
    'logic_name'           => 'wormbase pseudogene', @_
  );
  $self->add_new_track_gene( 'genebuilderbeeflymosandswall', 'Bee Genes', 'bee_gene', $POS++,
    'gene_label'           => sub { return $_[0]->biotype eq 'bacterial_contaminant' ? 'Bac. cont.' : ( $_[0]->biotype eq 'pseudogene' ? 'Pseudogene' : ( $_[0]->external_name || 'NOVEL' ) ) },
    'gene_col'             => sub { return $_[0]->biotype eq 'bacterial_contaminant' ? '_BACCOM'    : $_[0]->analysis->logic_name.'_'.$_[0]->biotype.'_'.$_[0]->status          },
    @_
  );
  $self->add_new_track_gene( 'SGD', 'SGD Genes', 'sgd_gene', $POS++,
    'gene_label'           => sub { return $_[0]->biotype eq 'bacterial_contaminant' ? 'Bac. cont.' : ( $_[0]->biotype eq 'pseudogene' ? 'Pseudogene' : ( $_[0]->external_name || 'NOVEL' ) ) },
    'gene_col'             => sub { return $_[0]->biotype eq 'bacterial_contaminant' ? '_BACCOM'    : $_[0]->analysis->logic_name.'_'.$_[0]->biotype.'_'.$_[0]->status          },
    @_
  );
  $self->add_new_track_gene( 'human_ensembl_proteins', 'Human Genes', 'human_ensembl_proteins_gene', $POS++,
    'gene_label'           => sub { return $_[0]->biotype eq 'bacterial_contaminant' ? 'Bac. cont.' : ( $_[0]->biotype eq 'pseudogene' ? 'Pseudogene' : ( $_[0]->external_name || 'NOVEL' ) ) },
    'gene_col'             => sub { return $_[0]->biotype eq 'bacterial_contaminant' ? '_BACCOM'    : $_[0]->analysis->logic_name.'_'.$_[0]->biotype.'_'.$_[0]->status          },
    @_
  );

  $self->add_new_track_gene( 'Homology_low', 'Bee Genes', 'bee_pre_gene', $POS++,
    'gene_col'   => sub { return $_[0]->analysis->logic_name },
    'gene_label' => sub { return $_[0]->stable_id },
    'logic_name' => 'Homology_low Homology_medium Homology_high BeeProtein'
  );
  $self->add_new_track_gene( 'oxford_FGU', 'Oxford FGU Genes', 'oxford_fgu', $POS++,
    'gene_col'   => 'oxford_fgu',
    'gene_label' => sub { return $_[0]->stable_id }, @_
  );
  $self->add_new_track_gene( 'platypus_olfactory_receptors', 'Olfactory Recep Genes', 'olfactory', $POS++,
    'gene_col'   => 'olfactory',
    'gene_label' => sub { return $_[0]->stable_id }, @_
  );

  $self->add_new_track_gene( 'gsten', 'Genoscope Genes', 'genoscope_gene', $POS++,
    'gene_label'           => sub { return $_[0]->stable_id },
    'gene_col'             => sub { return $_[0]->biotype eq 'Genoscope_predicted' ? '_GSTEN'    : '_HOX' },
    'logic_name'           => 'gsten hox cyt', @_
  );
  $self->add_new_track_gene( 'dog_protein', 'Dog proteins', 'dog_protein', $POS++,
    'gene_label'           => sub { return $_[0]->stable_id },
    'gene_col'             => 'dog_protein' , @_
  );

  $self->add_new_track_gene( 'ensembl_projection', 'Ensmebl projection', 'ensembl_projection', $POS++,
    'gene_label'           => sub { return $_[0]->external_name || $_[0]->stable_id },
    'gene_col'             => sub { return 'ensembl_projection_'.$_[0]->biotype.'_'.$_[0]->status; },
    @_
  );

  $self->add_new_track_gene( 'ensembl_segment', 'Ensembl segment', 'ensembl_segment', $POS++,
    'gene_label'           => sub { return $_[0]->external_name || $_[0]->stable_id },
    'gene_col'             => sub { return 'ensembl_segment_'.$_[0]->biotype.'_'.$_[0]->status; },
    @_
  );

  $self->add_new_track_gene( 'Cow_proteins', 'Cow proteins', 'cow_protein', $POS++,
    'gene_label'           => sub { return $_[0]->stable_id },
    'gene_col'             => 'cow_protein', @_
  );
  $self->add_new_track_gene( 'horse_protein', 'Horse proteins', 'horse_protein', $POS++,
    'gene_label'           => sub { return $_[0]->stable_id },
    'gene_col'             => 'horse_protein' , @_
  );
  $self->add_new_track_gene( 'orangutan_protein', 'Orangutan proteins', 'orangutan_protein', $POS++,
    'gene_label'           => sub { return $_[0]->stable_id },
    'gene_col'             => 'orangutan_protein' , @_
  );
  $self->add_new_track_gene( 'oxford_genes', 'Oxford Genes', 'oxford_genes', $POS++,
    'gene_label'           => sub { return $_[0]->stable_id },
    'gene_col'             => 'oxford', @_
  );
   $self->add_new_track_gene( 'fugu_protein', 'T.rubripes proteins', 'fugu_protein', $POS++,
     'gene_label'           => sub { return $_[0]->stable_id },
     'gene_col'             => 'fugu_protein' , @_
   );
   $self->add_new_track_gene( 'lamprey_protein', 'Lamprey proteins', 'lamprey_protein', $POS++,
     'gene_label'           => sub { return $_[0]->stable_id },
     'gene_col'             => 'lamprey_protein' , @_
   );

#  $self->add_new_track_gene( 'platypus_protein', 'Platypus/Other Genes', 'platypus_protein', $POS++,
#    'logic_name'           => 'platypus_protein other_protein',
#    'gene_label'           => sub { return $_[0]->stable_id },
#    'gene_col'             => sub { return $_[0]->analysis->logic_name }, @_
#  );


#  $self->add_new_track_gene( 'VectorBase_0_5', 'VectorBase proteins', 'vectorbase_0_5', $POS++,
#    'gene_label'           => sub { return $_[0]->stable_id },
#    'gene_col'             => 'vectorbase_0_5', @_
#  );

  $self->add_new_track_gene( 'TIGR_0_5', 'TIGR proteins', 'tigr_0_5', $POS++,
    'gene_label'           => sub { return $_[0]->stable_id },
    'gene_col'             => 'tigr_0_5', @_
  );

  $self->add_new_track_gene( 'medaka_protein',  "Medaka protein",  'medaka_gene', $POS++, 'gene_col' => 'medaka_protein' , @_ );
  $self->add_new_track_gene( 'gff_prediction',  "MGP genes",       'medaka_gene', $POS++, 'gene_col' => 'gff_prediction', @_ );

  $self->add_new_track_gene( 'species_protein', 'Dog protein', 'prot_gene', $POS++, @_ );
  $self->add_new_track_gene( 'human_one2one_mus_orth', 'Hs/Mm orth', 'prot_gene', $POS++, @_ );
  $self->add_new_track_gene( 'human_one2one_mouse_cow_orth', 'Hs/Mm orth', 'prot_gene', $POS++, @_ );
  $self->add_new_track_gene( 'mus_one2one_human_orth', 'Ms/Hs orth', 'prot_gene', $POS++, @_ );

  $self->add_new_track_gene( 'jamboree_cdnas',  "X.trop. Jambo",  'prot_gene', $POS++,
                             'gene_label' => sub { return $_[0]->stable_id }, 'gene_col' => sub { return $_[0]->biotype }, @_ );

  $self->add_new_track_gene( 'ncrna', 'ncRNA Genes', 'rna_gene', $POS++,
                             'logic_name' => 'miRNA tRNA ncRNA snRNA snlRNA snoRNA rRNA',
                             'available' => 'features ncrna|miRNA', 'label_threshold' => 100,
                             'gene_col' => sub { return ($_[0]->biotype =~ /pseudo/i ? 'rna-pseudo' : 'rna-real').($_[0]->status) }, @_ );
  $self->add_new_track_gene( 'ensembl_ncrna', 'e! ncRNA Genes', 'rna_gene', $POS++, 'legend_type' => 'gene_ncrna',
                             'gene_col' => sub { return $_[0]->biotype =~ /pseudo/i ? 'rna-pseudo' : 'rna-real' }, @_ );
  $self->add_new_track_gene( 'refseq', 'RefSeq Genes', 'refseq_gene', $POS++, 'gene_col' => '_refseq',  @_ );
  $self->add_new_track_gene( 'mouse_protein', 'Mouse Protein Genes', 'prot_gene', $POS++, 'gene_col' => '_col',  @_ );
  $self->add_new_track_gene( 'targettedgenewise', 'Targetted Genewise Genes', 'prot_gene', $POS++, 'gene_col' => '_col',  @_ );
  $self->add_new_track_gene( 'cdna_all', 'cDNA Genes', 'prot_gene', $POS++, 'gene_col' => '_col',  @_ );
  $self->add_new_track_gene( 'medaka_transcriptcoalescer', 'EST Genes',     'medaka_genes',
    $POS++, 'database' => 'otherfeatures', 'gene_col' => 'transcriptcoalescer',
    'available' => "database_features ENSEMBL_OTHERFEATURES.medaka_transcriptcoalescer" ,
    'label_threshold' => 500,
    @_ );
  $self->add_new_track_gene( 'medaka_genome_project', 'MGP Genes',     'medaka_genes',
    $POS++, 'database' => 'otherfeatures', 'gene_col' => 'genome_project',
    'available' => "database_features ENSEMBL_OTHERFEATURES.medaka_genome_project",
    'label_threshold' => 500,
     @_ );
  $self->add_new_track_gene( 'oxford_fgu_ext', 'Oxford FGU Genes', 'oxford_fgu', $POS++,
    'gene_col'   => 'oxford_fgu', 'gene_label' => sub { return $_[0]->stable_id },
    'database' => 'otherfeatures', 'logic_name' => 'oxford_fgu',
    'available' => "database_features ENSEMBL_OTHERFEATURES.oxford_fgu",
    @_
  );
  $self->add_new_track_gene( 'singapore_est', 'Singapore EST Genes', 'est_gene', $POS++,
     'database' => 'otherfeatures', 'gene_col' => 'estgene', 
     'available' => "database_features ENSEMBL_OTHERFEATURES.singapore_est",
     'label_threshold' => 500,
     @_ );
  $self->add_new_track_gene( 'singapore_protein', 'Singapore Protein Genes', 'prot_gene',
     $POS++, 'database' => 'otherfeatures', 'gene_col' => '_col', 
     'available' => "database_features ENSEMBL_OTHERFEATURES.singapore_protein",
     'label_threshold' => 500,
     @_ );
  $self->add_new_track_gene( 'chimp_cdna', 'Chimp cDNA Genes', 'chimp_genes', $POS++,
     'database' => 'otherfeatures', 'gene_col' => 'chimp_cdna', 
     'available' => "database_features ENSEMBL_OTHERFEATURES.chimp_cdna",
     'label_threshold' => 500,
     @_ );
  $self->add_new_track_gene( 'chimp_cdna', 'Human cDNA Genes', 'chimp_genes', $POS++,
     'database' => 'otherfeatures', 'gene_col' => 'human_cdna', 
     'available' => "database_features ENSEMBL_OTHERFEATURES.human_cdna",
     'label_threshold' => 500,
     @_ );
  $self->add_new_track_gene( 'chimp_est', 'Chimp EST Genes', 'chimp_genes', $POS++,
     'database' => 'otherfeatures', 'gene_col' => 'chimp_est', 
     'available' => "database_features ENSEMBL_OTHERFEATURES.chimp_est",
     'label_threshold' => 500,
     @_ );
  $self->add_new_track_gene( 'estgene', 'EST Genes', 'est_gene', $POS++,
                             'database' => 'otherfeatures',
                             'available' => 'database_features ENSEMBL_OTHERFEATURES.estgene',
                             'logic_name' => 'genomewise estgene', 'label_threshold' => 500, # 'on' => 'off',
                             'gene_col' => 'estgene', 'on'=>'off',@_ );

#for genes in Vega
  $self->add_new_track_gene('vega_eucomm_gene', 'KO genes (EUCOMM)', 'vega_gene_eucomm', $POS++,
    'available' => 'features VEGA_GENES_OTTER_EUCOMM', 'glyphset' => 'vega_gene',
    'logic_name' => 'otter_eucomm', 'gene_col' => 'vega_gene', @_);
  $self->add_new_track_gene('vega_komp_gene', 'KO genes (KOMP)', 'vega_gene_komp', $POS++,
    'available' => 'features VEGA_GENES_OTTER_EUCOMM', 'glyphset' => 'vega_gene',
    'logic_name' => 'otter_komp', 'gene_col' => 'vega_gene', @_);
  $self->add_new_track_gene( 'vega_gene', 'Havana Genes', 'vega_gene_havana', $POS++,
    'available' => 'features VEGA_GENES_OTTER', 'glyphset' => 'vega_gene',
    'logic_name' => 'otter', 'gene_col' => 'vega_gene', @_);
  $self->add_new_track_gene( 'vega_corf_gene', 'CORF Genes', 'vega_gene_corf', $POS++,
    'available' => 'features VEGA_GENES_OTTER_CORF', 'glyphset' => 'vega_gene',
    'logic_name' => 'otter_corf', 'gene_col' => 'vega_gene', @_);
  $self->add_new_track_gene( 'vega_external_gene', 'External Genes', 'vega_gene_external', $POS++,
    'available' => 'features VEGA_GENES_OTTER_EXTERNAL', 'glyphset' => 'vega_gene',
    'logic_name' => 'otter_external', 'gene_col' => 'vega_gene', @_);
   $self->add_new_track_gene( 'ciona_dbest_ncbi', "3/5' EST genes (dbEST)", 'estgene', $POS++, 'on' => 'off', 
                             'gene_label' => sub { return $_[0]->stable_id }, 'gene_col' => sub { return $_[0]->biotype }, @_ );
  $self->add_new_track_gene( 'targettedgenewise', "Targetted genewise", 'prot_gene', $POS++, 'available' => 'features TargettedGenewise', 'logic_name' => 'TargettedGenewise', 'gene_col' => '_col', @_ );
  $self->add_new_track_gene( 'cdna_all', "Aligned genes", 'prot_gene', $POS++, 'gene_col' => 'cdna_all', @_ );

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
    $self->add_new_track_transcript( 'evega',         'Vega Havana gene',      'vega_gene_havana',    $POS++, 'glyph' => 'evega_transcript', 'logic_name' => 'otter', 'available' => 'database_features ENSEMBL_VEGA.OTTER',    @_ );
    $self->add_new_track_transcript( 'evega_external','Vega External gene',    'vega_gene_external',  $POS++, 'glyph' => 'evega_transcript', 'logic_name' => 'otter_external', 'available' => 'database_features ENSEMBL_VEGA.OTTER_EXTERNAL',    @_ );
    return $POS;
}

sub ADD_AS_GENE_TRACKS {
    my $self = shift;
    my $POS  = shift || 2000;
    $self->add_new_track_gene( 'ensembl', 'Ensembl Genes', 'ensembl_gene', $POS++,
			       'gene_label'           => sub { return $_[0]->biotype eq 'bacterial_contaminant' ? 'Bac. cont.' : ( $_[0]->biotype eq 'pseudogene' ? 'Pseudogene' : ( $_[0]->external_name || 'NOVEL' ) ) },
			       'gene_col'             => sub { return $_[0]->biotype eq 'bacterial_contaminant' ? '_BACCOM'    : ( $_[0]->biotype eq 'pseudogene' ? '_PSEUDO'    : '_'.$_[0]->external_status          ) },
			       'logic_name'           => 'ensembl psuedogene', @_
			       );

    $self->add_new_track_gene( 'flybase', 'Flybase Genes', 'flybase_gene', $POS++,
     'gene_label'           => sub { return $_[0]->biotype eq 'bacterial_contaminant' ? 'Bac. cont.' : ( $_[0]->biotype eq 'pseudogene' ? 'Pseudogene' : ( $_[0]->external_name || 'NOVEL' ) ) },
			       'gene_col'             => sub { return $_[0]->biotype eq 'bacterial_contaminant' ? '_BACCOM'    : ( $_[0]->biotype eq 'pseudogene' ? '_PSEUDO'    : '_'.$_[0]->external_status          ) },
     'logic_name'           => 'flybase psuedogene', @_
			       );

     $self->add_new_track_gene( 'vectorbase', 'Vectorbase Genes', 'vectorbase_gene', $POS++,
     'gene_label'           => sub { return $_[0]->biotype eq 'bacterial_contaminant' ? 'Bac. cont.' : ( $_[0]->biotype eq 'pseudogene' ? 'Pseudogene' : ( $_[0]->external_name || 'NOVEL' ) ) },
			       'gene_col'             => sub { return $_[0]->biotype eq 'bacterial_contaminant' ? '_BACCOM'    : ( $_[0]->biotype eq 'pseudogene' ? '_PSEUDO'    : '_'.$_[0]->external_status          ) },
     'logic_name'           => 'vectorbase psuedogene', @_
			       );

   $self->add_new_track_gene( 'wormbase', 'Wormbase Genes', 'wormbase_gene', $POS++,
			       'gene_label'           => sub { return $_[0]->biotype eq 'bacterial_contaminant' ? 'Bac. cont.' : ( $_[0]->biotype eq 'pseudogene' ? 'Pseudogene' : ( $_[0]->external_name || 'NOVEL' ) ) },
			       'gene_col'             => sub { return $_[0]->biotype eq 'bacterial_contaminant' ? '_BACCOM'    : ( $_[0]->biotype eq 'pseudogene' ? '_PSEUDO'    : '_'.$_[0]->external_status          ) },
			       'logic_name'           => 'wormbase psuedogene', @_
			       );
    $self->add_new_track_gene( 'genebuilderbeeflymosandswall', 'Bee Genes', 'bee_gene', $POS++,
			       'gene_label'           => sub { return $_[0]->biotype eq 'bacterial_contaminant' ? 'Bac. cont.' : ( $_[0]->biotype eq 'pseudogene' ? 'Pseudogene' : ( $_[0]->external_name || 'NOVEL' ) ) },
			       'gene_col'             => sub { return $_[0]->biotype eq 'bacterial_contaminant' ? '_BACCOM'    : ( $_[0]->biotype eq 'pseudogene' ? '_PSEUDO'    : '_'.$_[0]->external_status          ) },
			       @_
			       );
    $self->add_new_track_gene( 'SGD', 'SGD Genes', 'sgd_gene', $POS++,
			       'gene_label'           => sub { return $_[0]->biotype eq 'bacterial_contaminant' ? 'Bac. cont.' : ( $_[0]->biotype eq 'pseudogene' ? 'Pseudogene' : ( $_[0]->external_name || 'NOVEL' ) ) },
			       'gene_col'             => sub { return $_[0]->biotype eq 'bacterial_contaminant' ? '_BACCOM'    : ( $_[0]->biotype eq 'pseudogene' ? '_PSEUDO'    : '_'.$_[0]->external_status          ) },
			       @_
			       );
  $self->add_new_track_gene( 'gsten', 'Genoscope Genes', 'genoscope_gene', $POS++,
			       'gene_label'           => sub { return $_[0]->stable_id },
			       'gene_col'             => sub { return $_[0]->biotype eq 'Genoscope_predicted' ? '_GSTEN'    : '_HOX' },
			       'logic_name'           => 'gsten hox cyt', @_
			       );
  #not sure this is actually used!!
  $self->add_new_track_gene( 'otter', 'Vega Havana Genes', 'vega_gene_havana', $POS++,
                             'database' => 'vega', 'available' => 'database_features ENSEMBL_VEGA.OTTER',
                             'gene_col'             => sub { return $_[0]->biotype.'_'.$_[0]->status; },
                             'gene_label'           => sub { $_[0]->external_name || $_[0]->stable_id; },
                             'glyphset' => 'evega_gene',
                               @_ );
  $self->add_new_track_gene( 'otter_external', 'Vega External Genes', 'vega_gene_external', $POS++,
                             'database' => 'vega', 'available' => 'database_features ENSEMBL_VEGA.OTTER_EXTERNAL',
                              'gene_col'            => sub { return $_[0]->biotype.'_'.$_[0]->status; },
                             'gene_label'           => sub { $_[0]->external_name || $_[0]->stable_id; },
                             'glyphset' => 'evega_gene',
                              @_ );    
    #for genes in Vega
    $self->add_new_track_gene('vega_eucomm_gene', 'EUCOMM KO genes', 'vega_gene_eucomm', $POS++,
    'available' => 'features VEGA_GENES_OTTER_EUCOMM', 'glyphset' => 'vega_gene',
    'logic_name' => 'otter_eucomm', 'gene_col' => 'vega_gene', @_);
    $self->add_new_track_gene('vega_komp_gene', 'KOMP KO genes', 'vega_gene_komp', $POS++,
    'available' => 'features VEGA_GENES_OTTER_KOMP', 'glyphset' => 'vega_gene',
    'logic_name' => 'otter_komp', 'gene_col' => 'vega_gene', @_);
    $self->add_new_track_gene( 'vega_gene', 'Vega Genes', 'vega_gene', $POS++,
	'available' => 'features VEGA_GENES_OTTER', 'glyphset' => 'vega_gene',
	'logic_name' => 'otter', 'gene_col' => 'vega_gene', @_);
    $self->add_new_track_gene( 'vega_corf_gene', 'CORF Genes', 'vega_gene', $POS++,
	'available' => 'features VEGA_GENES_OTTER_CORF', 'glyphset' => 'vega_gene',
	'logic_name' => 'otter_corf', 'gene_col' => 'vega_gene', @_); 
	$self->add_new_track_gene( 'vega_external_gene', 'External Genes', 'vega_gene_external', $POS++,
    'available' => 'features VEGA_GENES_OTTER_EXTERNAL', 'glyphset' => 'vega_gene',
    'logic_name' => 'otter_external', 'gene_col' => 'vega_gene', @_);
    return $POS;
}

sub ADD_ALL_PROTEIN_FEATURE_TRACKS {
  my $self = shift;
  my $POS = shift || 2000;
  $self->add_protein_domain_track( 'Prints', 'PRINTS', $POS++ );
  $self->add_protein_domain_track( 'PrositePatterns', 'Prosite patterns', $POS++ );
  $self->add_protein_domain_track( 'scanprosite',     'Prosite patterns', $POS++ );
  $self->add_protein_domain_track( 'PrositeProfiles', 'Prosite profiles', $POS++ );
  $self->add_protein_domain_track( 'pfscan',          'Prosite profiles', $POS++ );

  $self->add_protein_domain_track( 'Pfam', 'Pfam', $POS++ );
  $self->add_protein_domain_track( 'Tigrfam', 'TIGRFAM', $POS++ );
  $self->add_protein_domain_track( 'Superfamily', 'SUPERFAMILY', $POS++ );
  $self->add_protein_domain_track( 'Smart', 'SMART', $POS++ );
  $self->add_protein_domain_track( 'PIRSF', 'PIR SuperFamily', $POS++ );

  $self->add_protein_feature_track( 'ncoils',  'Coiled coils',      $POS++ );
  $self->add_protein_feature_track( 'SignalP', 'Sig.Pep cleavage',  $POS++ );
  $self->add_protein_feature_track( 'Seg',     'Low complex seq',   $POS++ );
  $self->add_protein_feature_track( 'tmhmm',   'Transmem helices',  $POS++ );
}

sub ADD_ALL_PROTEIN_FEATURE_TRACKS_GSV {
  my $self = shift;
  my $POS = shift || 2000;
  $self->add_GSV_protein_domain_track( 'Prints', 'PRINTS', $POS++ );
  $self->add_GSV_protein_domain_track( 'PrositePatterns', 'Prosite patterns', $POS++ );
  $self->add_GSV_protein_domain_track( 'scanprosite',     'Prosite patterns', $POS++ );
  $self->add_GSV_protein_domain_track( 'PrositeProfiles', 'Prosite profiles', $POS++ );
  $self->add_GSV_protein_domain_track( 'pfscan',          'Prosite profiles', $POS++ );

  $self->add_GSV_protein_domain_track( 'Pfam',            'PFam', $POS++ );
  $self->add_GSV_protein_domain_track( 'Tigrfam',         'TIGRFAM', $POS++ );
  $self->add_GSV_protein_domain_track( 'Superfamily',     'SUPERFAMILY', $POS++ );
  $self->add_GSV_protein_domain_track( 'Smart',           'SMART', $POS++ );
  $self->add_GSV_protein_domain_track( 'PIRSF',           'PIR SuperFamily', $POS++ );
}

1;
