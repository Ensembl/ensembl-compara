package EnsEMBL::Web::ImageConfig;

use strict;
use Data::Dumper;
use Storable qw( nfreeze freeze thaw);
use Sanger::Graphics::TextHelper;
use Bio::EnsEMBL::Registry;
use EnsEMBL::Web::OrderedTree;

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
    'altered'           => 0,
    '_core'             => undef,
    '_tree'             => EnsEMBL::Web::OrderedTree->new()
  };

  bless($self, $class);

		
  ########## init sets up defaults in $self->{'general'}
  $self->init( ) if($self->can('init'));
  $self->{'no_image_frame'}=1;
  $self->das_sources( @_ ) if(@_); # we have das sources!!

  ########## load sets up user prefs in $self->{'user'}
#  $self->load() unless(defined $self->{'no_load'});
  return $self;
}

sub set_title {
  my( $self, $title ) = @_;
  $self->{'title'} = $title;
}
sub title {
  return $_[0]{'title'};
}

sub create_menus {
  my( $self, @list ) = @_;
  while( my( $key, $tracks ) = splice(0,2,@_) ) {
    $self->create_submenu( $key, $caption );
  }
}

sub load_tracks() { 
  my $self     = shift;
  my $dbs_hash = $self->species_defs->get_config('databases');
  foreach my $db ( @{$self->species_defs->get_config('core_link_databases')} ) {
    next unless exists $dbs_hash->{$db};
    my $key = $db eq 'ENSEMBL_DB' ? 'core' : lc(substr($db,8));
## Look through tables in databases and add data from each one...
    $self->add_dna_align_feature(     $key,$dbs_hash->{$db}{'tables'} ); # To cDNA/mRNA, est, RNA, other_alignment trees
    $self->add_ditag_feature(         $key,$dbs_hash->{$db}{'tables'} ); # To ditag_feature tree
    $self->add_gene(                  $key,$dbs_hash->{$db}{'tables'} ); # To gene, transcript, align_slice_transcript, tsv_transcript trees
    $self->add_marker_feature(        $key,$dbs_hash->{$db}{'tables'} ); # To marker tree
    $self->add_misc_feature(          $key,$dbs_hash->{$db}{'tables'} ); # To misc_feature tree
    $self->add_oligo_probe(           $key,$dbs_hash->{$db}{'tables'} ); # To oligo tree
    $self->add_prediction_transcript( $key,$dbs_hash->{$db}{'tables'} ); # To prediction_transcript tree
    $self->add_protein_align_feature( $key,$dbs_hash->{$db}{'tables'} ); # To protein_align_feature_tree
    $self->add_protein_feature(       $key,$dbs_hash->{$db}{'tables'} ); # To protein_feature_tree
    $self->add_repeat_feature(        $key,$dbs_hash->{$db}{'tables'} ); # To repeat_feature tree
    $self->add_simple_feature(        $key,$dbs_hash->{$db}{'tables'} ); # To simple_feature tree
    $self->add_assemblies(            $key,$dbs_hash->{$db}{'tables'} ); # To sequence tree!
  }
  foreach my $db ( 'ENSEMBL_COMPARA') {   # @{$self->species_defs->get_config('compara_databases')} ) {
    next unless exists $dbs_hash->{$db};
    my $key = $db eq 'ENSEMBL_DB' ? 'core' : lc(substr($db,8));
    ## Configure dna_dna_align features and synteny tracks
    $self->add_synteny_feature(       $key,$dbs_hash->{$db}{'tables'} ); # Add to synteny tree
    $self->add_alignments(            $key,$dbs_hash->{$db}{'tables'} ); # Add to compara_align tree
  }
  foreach my $db ( 'ENSEMBL_FUNCGEN' ) {  # @{$self->species_defs->get_config('funcgen_databases')} ) {
    next unless exists $dbs_hash->{$db};
    my $key = $db eq 'ENSEMBL_DB' ? 'core' : lc(substr($db,8));
    ## Configure 
    $self->add_regulation_feature(    $key,$dbs_hash->{$db}{'tables'} ); # Add to regulation_feature tree
  }
  foreach my $db ( 'ENSEMBL_VARATION' ) { # @{$self->species_defs->get_config('variation_databases')} ) {
    next unless exists $dbs_hash->{$db};
    my $key = $db eq 'ENSEMBL_DB' ? 'core' : lc(substr($db,8));
    ## Configure variation features
    $self->add_variation_feature(     $key,$dbs_hash->{$db}{'tables'} ); # To variation_feature tree
  }
  ## Now we do the das stuff - to append to menus (if the menu exists!!)
  foreach my $das( qw(das_sources) ) { ## Add to approriate menu if it exists!!
    next;
    $self->add_source( $das );
  }
}

#----------------------------------------------------------------------#
# Functions to add tracks from core like databases....
#----------------------------------------------------------------------#

sub _check_menus {
  my $self = shift;
  foreach( @_ ) {
    return 1 if $self->get_node( $_ );
  }
  return 0;
}

sub _merge {
  my( $self, $_sub_tree ) = @_;
  my $data = {};
  my $sub_tree = $_sub_tree->{'analyses'};
  foreach my $analysis (%$sub_tree) {
    my $key = $sub_tree->{'web'}{'key'} || $analysis;
    $data->{$key}{'name'}    ||= $sub_tree->{'web'}{'name'};     # Longer form for help and configuration!
    $data->{$key}{'type'}    ||= $sub_tree->{'web'}{'type'};
    $data->{$key}{'caption'} ||= $sub_tree->{'web'}{'caption'};  # Short form for LHS
    if( $sub_tree->{'web'}{'key'} ) {
      if( $sub_tree->{'description'} ) {
         $data->{$key}{'description'} ||= "<dl>\n";
        $data->{$key}{'description'} .= sprintf(
          "  <dt>%s</dt>\n  <dd>%d</dd>\n",
          CGI::escapeHTML( $sub_tree->{'web'}{'name'}       ),     # Description for pop-help - merged of all descriptions!!
          CGI::escapeHTML( $sub_tree->{'description'})
        );
      }
    } else {
      $data->{$key}{'description'} .= sprintf(
        '<p>%d</p>',
        CGI::escapeHTML( $sub_tree->{'description'})
      );
    }
    push @{$data->{$key}{'logic_names'}}, $analysis;
  }
  foreach my $key (keys %$data) {
    $data->{$key}{'description'} .= '</dl>' if $data->{$key}{'description'} =~ '<dl>';
  }
  return [ sort { $data->{$a}{'name'} cmp $data->{$b}{'name'}  $data;
}

sub add_assemblies {
  my( $self, $key, $hashref ) = @_;
  return unless $self->_check_menus( 'sequence' );
}

sub add_dna_align_features {
  my( $self, $key, $hashref ) = @_;
  return unless $self->_check_menus( 'dna_align_cdna' );
  my $data      = $self->_merge( $hashref->{'dna_align_feature'} ){
  
  foreach my $key_2 (sort keys %$data) {
    my $K = $data->{$key_2}{'type'}||'other';
    my $menu = $self->get_node( "dna_align_$K" );
    if( $menu ) {
      $menu->append( $self->create_node( 'dna_align_'.$key.'_'.$key_2, $data->{$key_2}{'name'},
        'db'          => $key,
        'glyphset'    => 'generic_alignment',
        'sub_type'    => $data->{$key_2}{'type'},
        'logicnames'  => $data->{$key_2}{'logic_names'},
        'name'        => $data->{$key_2}{'name'},
        'caption'     => $data->{$key_2}{'caption'},
        'description' => $data->{$key_2}{'description'},
      );
    }
  }
}

sub add_ditag_features {
  my( $self, $key, $hashref ) = @_;
  return unless $self->_check_menus( 'ditag' );
}

sub add_gene {
  my( $self, $key, $hashref ) = @_;
## Gene features end up in each of these menus..

  my @types = qw(transcript alignslice_transcript tsv_transcript gsv_transcript tse_transcript gene);

  return unless $self->_check_menus( @types );

  my $data      = $self->_merge( $hashref->{'gene'} );

  foreach my $type ( @types ) {
    my $menu = $self->get_node( $type );
    next unless $menu;
    foreach my $key_2 (sort keys %$data) {
      $menu->append( $self->create_node( $type.'_'.$key.'_'.$key_2, $data->{$key_2}{'name'}, {
        'db'          => $key,
        'glyphset'    => $type,
        'logicnames'  => $data->{$key_2}{'logic_names'},
        'name'        => $data->{$key_2}{'name'},
        'caption'     => $data->{$key_2}{'caption'},
        'description' => $data->{$key_2}{'description'},
      }));
    }
  }
}

sub add_marker_feature {
  my( $self, $key, $hashref ) = @_;
  return unless $self->get_node( 'marker' );
  my $data      = $self->_merge( $hashref->{'marker_feature'} );
  my $menu      = $self->get_node( 'marker' );
  foreach my $key_2 (sort keys %$data) {
    $menu->append( $self->create_node( 'marker_'.$key.'_'.$key_2, $data->{$key_2}{'name'}, {
      'db'          => $key,
      'glyphset'    => 'marker',
      'logicnames'  => $data->{$key_2}{'logic_names'},
      'name'        => $data->{$key_2}{'name'},
      'caption'     => $data->{$key_2}{'caption'},
      'description' => $data->{$key_2}{'description'},
    }));
  }
}

sub add_misc_feature {
  my( $self, $key, $hashref ) = @_;
  return unless $self->get_node( 'misc_feature' );
}

sub add_oligo_probe {
  my( $self, $key, $hashref ) = @_;
  return unless $self->get_node( 'oligo_probe' );
}

sub add_prediction_transcript {
  my( $self, $key, $hashref ) = @_;
  return unless $self->get_node( 'prediction_transcript' );
}

sub add_protein_align_feature {
  my( $self, $key, $hashref ) = @_;
  return unless $self->get_node( 'protein_align_feature' );
}

sub add_protein_feature {
  my( $self, $key, $hashref ) = @_;
  return unless $self->get_node( 'protein' ) ||
                $self->get_node( 'tsv_protein' );
}

sub add_feature {
  my( $self, $key, $hashref ) = @_;
  return unless $self->get_node( 'prediction_transcript' );
}

sub add_repeat_feature {
  my( $self, $key, $hashref ) = @_;
  return unless $self->get_node( 'repeat_feature' );
}

sub add_simple_feature {
  my( $self, $key, $hashref ) = @_;
  return unless $self->get_node( 'simple_feature' );
}

#----------------------------------------------------------------------#
# Functions to add tracks from compara like databases....
#----------------------------------------------------------------------#

sub add_synteny {
  my( $self, $key, $hashref ) = @_;
  return unless $self->get_node( 'synteny' );
}

sub add_alignments {
  my( $self, $key, $hashref ) = @_;
  return unless $self->get_node( 'compara_alignments' );
}

#----------------------------------------------------------------------#
# Functions to add tracks from functional genomics like databases....
#----------------------------------------------------------------------#

sub add_regulation_feature {
  my( $self, $key, $hashref ) = @_;
  return unless $self->get_node( 'regulation_feature' );
}

#----------------------------------------------------------------------#
# Functions to add tracks from variation like databases....
#----------------------------------------------------------------------#

sub add_variation_feature {
  my( $self, $key, $hashref ) = @_;
  return unless $self->get_node( 'variation_feature' );
}

#----------------------------------------------------------------------#
# Functions to add tracks from core like databases....
#----------------------------------------------------------------------#

sub set_track_sets {
  my( $self, @params ) = @_;
  while( my( $key, $tracks ) = splice(0,2,@_) ) {
    $self->create_submenu( $key, $caption,  
  }
}
sub create_submenu {
  my ($self, $code, $caption, $options ) = @_;
  my $details = { 'caption'    => $caption };
  foreach ( keys %{$options||{}} ) {
    $details->{$_} = $options->{$_};
  }
  return $self->tree->create_node( $code, $details );
}

sub create_node {
  my ( $self, $code, $caption, $options ) = @_;
  my $details = { 'caption'    => $caption };
  foreach ( keys %{$options||{}} ) {
    $details->{$_} = $options->{$_};
  }
  $self->tree->create_node( $code, $details );
}

sub _add_tracks_legends {
  my $branch = $self->create_submenu( 'legends', 'Legends' );
  foreach( qw( gene variation ) ) {
    $branch->append( $self->create_node( $_.'_legend', ucfirst($_).' legend', {
      'on' => 'on'
    }) );
  }
}

sub _set_core { $_[0]->{'_core'} = $_[1]; }
sub core_objects { return $_[0]->{'_core'}; }

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
  #$self->save; - deprecated
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
    ) if $self->{'_db'};
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
  return 1;
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

1;
