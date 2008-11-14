package EnsEMBL::Web::ImageConfig;

use strict;
use Data::Dumper;
use Storable qw( nfreeze freeze thaw);
use Sanger::Graphics::TextHelper;
use Bio::EnsEMBL::Registry;
use EnsEMBL::Web::OrderedTree;
use EnsEMBL::Web::RegObj;

my $reg = "Bio::EnsEMBL::Registry";
my @TRANSCRIPT_TYPES = qw(transcript alignslice_transcript tsv_transcript gsv_transcript TSE_transcript gene);

our $MEMD = EnsEMBL::Web::Cache->new;

#########
# 'general' settings contain defaults.
# 'user' settings are restored from cookie if available
# 'general' settings are overridden by 'user' settings
#

sub new {
  my $class   = shift;
  my $adaptor = shift;
  my $can_attach_user = shift;
  my $type    = $class =~/([^:]+)$/ ? $1 : $class;
  my $style   = $adaptor->get_species_defs->ENSEMBL_STYLE || {};
  my $self = {
    '_colourmap'        => $adaptor->colourmap,
    '_font_face'        => $style->{GRAPHIC_FONT}                                   || 'Arial',
    '_font_size'        => ( $style->{GRAPHIC_FONTSIZE} * $style->{GRAPHIC_LABEL} ) || 20,
    '_texthelper'       => new Sanger::Graphics::TextHelper,
    '_db'               => $adaptor->get_adaptor,
    'type'              => $type,
    'species'           => $ENV{'ENSEMBL_SPECIES'} || '',
    'species_defs'      => $adaptor->get_species_defs,
    'exturl'            => $adaptor->exturl,
    'general'           => {},
    'user'              => {},
    '_useradded'        => {}, # contains list of added features....
    '_r'                => undef, # $adaptor->{'r'} || undef,
    'no_load'           => undef,
    'storable'          => 1,
    'altered'           => 0,
## Core objects...       { for setting URLs .... }
    '_core'             => undef,
## Glyphset tree...      { Tree of glyphsets to render.... }
    '_tree'             => EnsEMBL::Web::OrderedTree->new(),
## Generic parameters... { Generic parameters for glyphsets.... }
    '_parameters'       => {},
## Better way to store cache { 
    '_cache'            => {}

  };

  bless($self, $class);
## Check to see if we have a user/session saved copy of tree.... 
##   Load tree from cache...
##   If not check to see if we have a "common" saved copy of tree
##     If not generate and cache it!
##   If we have a (user/session) modify the common tree
##     Cache the user/session version.

  ########## init sets up defaults in $self->{'general'}
  ## Check memcached for defaults
  if (my $defaults = $MEMD ? $MEMD->get("::${class}::$ENV{ENSEMBL_SPECIES}") : undef) {
    $self->{$_} = $defaults->{$_} for keys %$defaults;
  } else {
    ## No cached defaults found,
    ## so initialize them
    $self->init if $self->can('init');
    ## And cahce
    if ($MEMD) {
      my $defaults = {
        _tree       => $self->{'_tree'},
        _parameters => $self->{'_parameters'},
        general     => $self->{'general'},
      };
      $MEMD->set(
        "::${class}::$ENV{ENSEMBL_SPECIES}",
        $defaults,
        undef,
        'IMAGE_CONFIG',
        $ENV{ENSEMBL_SPECIES},
      );
    }
  }
  
  $self->{'no_image_frame'}=1;
## At this point tree doesn't depend on session/user....
#  if( $can_attach_user ) {
    $self->load_user_tracks( $adaptor );
#  }
## Add user defined data sources.....
## Now tree does depend on session/user...
#
  ########## load sets up user prefs in $self->{'user'}
#  $self->load() unless(defined $self->{'no_load'});
  return $self;
}

sub load_user_tracks {
  my( $self, $session ) = @_;
  my $menu = $self->get_node('user_data');
  return unless $menu;
  my $DAS = $EnsEMBL::Web::RegObj::ENSEMBL_WEB_REGISTRY->get_all_das();

  foreach my $source ( sort { ($a->caption||$a->label) cmp ($b->caption||$b->label) } values %$DAS ) {
    next if $self->get_node('das_'.$source->logic_name);
    $source->is_on($self->{'type'}) || next;
    $self->add_das_track( 'user_data', $source );
  }

  my $user = $EnsEMBL::Web::RegObj::ENSEMBL_WEB_REGISTRY->get_user(); #  #EnsEMBL::Web::Data::User->new($ENV{'ENSEMBL_USER_ID'});

### Get the tracks that are temporarily stored - as "files" not in the DB....
## Firstly "upload data" not yet committed to the database...
## Then those attached as URLs to either the session or the User

  my %T = %{ $session->get_tmp_data || {} };

  if( $T{'species'} eq $self->{'species'} ) {
    $menu->append($self->create_track( 'temporary_user_data', 'Temporary user data', {
      %T,
      '_class'      => 'user',
      'glyphset'    => '_tmp_user_data',
      'url'         => 'tmp',
      'caption'     => 'Temporary data',
      'description' => 'Temporary uploaded user data',
      'display'     => 'normal',
      'renderers'   => [qw(off Off normal Normal)],
      'strand'      => 'b',
    }));
  }
  
## Do we have a user?!

### Now get the tracks that have been stored in the database...
## Firstly those shared (and attached to the session)

## Then those attached to the user account
  my $i = 0;
  
  if( $user ) {
    foreach my $upload ($user->uploads) {
      if ($upload->species eq $self->{'species'}) {
        foreach my $logic_name( split ', ', $upload->analyses ) {
          $menu->append($self->create_track( "user_$logic_name", $logic_name, {
            '_class'      => 'user',
            'glyphset'    => '_tmp_user_data',
            'url'         => 'tmp',
            'caption'     => $logic_name,
            'logic_names' => [$logic_name],
            'description' => $upload->format.' file saved in your user account',
            'display'     => 'normal',
            'renderers'   => [qw(off Off normal Normal)],
            'strand'      => 'b',
          }));
          $i++;
        }
      }
    }
  }

## 
  return;
}

sub update_from_input {
  my( $self, $input ) = @_;
  
  if( $input->param('reset') ) {
    return $self->tree->flush_user;
  }
  my $flag = 0;
  foreach my $node ($self->tree->nodes) {
    my $key = $node->key;
    if( defined $input->param($key) ) {
      $flag += $node->set_user( 'display', $input->param( $key ) );
    }
  }
  $self->altered = 1 if $flag;
  return $flag;
}
#=============================================================================
# General setting/getting cache values...
#=============================================================================

sub cache {
  my $self = shift;
  my $key  = shift;
  $self->{'_cache'}{$key} = shift if @_;
  return $self->{'_cache'}{$key}
}

#=============================================================================
# General setting/getting parameters...
#=============================================================================

sub set_parameters {
  my( $self, $params ) = @_;

  foreach (keys %$params) {
    $self->{'_parameters'}{$_} = $params->{$_};
  } 
}

sub get_parameters {
  my $self = shift;
  return $self->{'_parameters'};
}

sub get_parameter {
  my($self,$key) = @_;
  return $self->{'_parameters'}{$key};
}

sub set_parameter {
  my($self,$key,$value) = @_;
  $self->{'_parameters'}{$key} = $value;
}

#-----------------------------------------------------------------------------
# Specific parameter setting - image width/container width
#-----------------------------------------------------------------------------
sub title {
  my $self = shift;
  $self->set_parameter( 'title', shift ) if @_;
  return $self->get_parameter( 'title' );
}

sub container_width {
  my $self = shift;
  $self->set_parameter( 'container_width', shift ) if @_;
  return $self->get_parameter( 'container_width' );
}

sub image_width {
  my $self = shift;
  $self->set_parameter( 'image_width', shift ) if @_;
  return $self->get_parameter( 'image_width' );
}

sub slice_number {
  my $self = shift;
  $self->set_parameter( 'slice_number', shift ) if @_;
  return $self->get_parameter( 'slice_number' );
}

sub get_track_key {
  my( $self, $prefix, $obj ) = @_;

  my $logic_name = $obj->gene ? $obj->gene->analysis->logic_name : $obj->analysis->logic_name;
  my $db         = $obj->get_db();
  my $db_key     = 'DATABASE_'.uc($db);
  my $key        = $obj->species_defs->databases->{$db_key}{'tables'}{'gene'}{'analyses'}{$logic_name}{'web'}{'key'} || $logic_name;
  return join '_', $prefix, $db, $key;
}

sub modify_configs {
  my( $self, $nodes, $config ) = @_;
  foreach my $conf_key ( @$nodes ) {
    my $n = $self->get_node( $conf_key );
    next unless $n;
    foreach my $t ( $n->nodes ) {
      next unless $t->get('node_type') eq 'track';
      foreach ( keys %$config) {
        $t->set($_,$config->{$_});
      }
    }
  }
}

sub _update_missing {
  my( $self,$object ) = @_;
  my $count_missing = grep { $_->get('display') eq 'off' || !$_->get('display') } $self->glyphset_configs; 
  my $missing = $self->get_node( 'missing' );
  if( $missing ) {
    $missing->set( 'text' => $count_missing > 0 ? "There are currently $count_missing tracks turned off." : "All tracks are turned on" );
  }
  my $info = sprintf "%s %s version %s.%s (%s) %s: %s - %s",
      $self->species_defs->ENSEMBL_SITETYPE,
      $self->species_defs->SPECIES_BIO_NAME,
      $self->species_defs->ENSEMBL_VERSION,
      $self->species_defs->SPECIES_RELEASE_VERSION,
      $self->species_defs->ASSEMBLY_NAME,
      $object->seq_region_type_and_name,
      $object->thousandify($object->seq_region_start),
      $object->thousandify($object->seq_region_end) ;

  my $information = $self->get_node( 'info' );
  if( $information ) {
    $information->set( 'text' => $info );
  }
  return { 'count' => $count_missing, 'information' => $info };
}
#=============================================================================
# General setting tree stuff...
#=============================================================================


sub tree {
  return $_[0]{_tree};
}

### create_menus - takes an "associate array" i.e. ordered key value pairs
### to configure the menus to be seen on the display..
### key and value pairs are the code and the text of the menu...

sub create_menus {
  my( $self, @list ) = @_;
  while( my( $key, $caption ) = splice(@list,0,2) ) {
    $self->create_submenu( $key, $caption );
  }
}

### load_tracks - loads in various database derived tracks; 
###   loop through core like dbs, compara like dbs, funcgen like dbs;
###                variation like dbs

sub load_tracks { 
  my $self       = shift;
  my $species    = $ENV{'ENSEMBL_SPECIES'};
  my $dbs_hash   = $self->species_defs->databases;
  my $multi_hash = $self->species_defs->multi_hash;
  foreach my $db ( @{$self->species_defs->core_like_databases||[]} ) {
    next unless exists $dbs_hash->{$db};
    my $key = lc(substr($db,9));
## Look through tables in databases and add data from each one...
    $self->add_dna_align_feature(     $key,$dbs_hash->{$db}{'tables'} ); # To cDNA/mRNA, est, RNA, other_alignment trees ##DONE
#    $self->add_ditag_feature(         $key,$dbs_hash->{$db}{'tables'} ); # To ditag_feature tree                         ##DONE
    $self->add_gene(                  $key,$dbs_hash->{$db}{'tables'} ); # To gene, transcript, align_slice_transcript, tsv_transcript trees
    $self->add_marker_feature(        $key,$dbs_hash->{$db}{'tables'} ); # To marker tree                                ##DONE
    $self->add_qtl_feature(           $key,$dbs_hash->{$db}{'tables'} ); # To marker tree                                ##DONE
    $self->add_misc_feature(          $key,$dbs_hash->{$db}{'tables'} ); # To misc_feature tree                          ##DONE
    $self->add_oligo_probe(           $key,$dbs_hash->{$db}{'tables'} ); # To oligo tree                                 ##DONE
    $self->add_prediction_transcript( $key,$dbs_hash->{$db}{'tables'} ); # To prediction_transcript tree                 ##DONE
    $self->add_protein_align_feature( $key,$dbs_hash->{$db}{'tables'} ); # To protein_align_feature_tree                 ##DONE
    $self->add_protein_feature(       $key,$dbs_hash->{$db}{'tables'} ); # To protein_feature_tree                       ## 2 do ##
    $self->add_repeat_feature(        $key,$dbs_hash->{$db}{'tables'} ); # To repeat_feature tree                        ##DONE
    $self->add_simple_feature(        $key,$dbs_hash->{$db}{'tables'} ); # To simple_feature tree                        ##DONE
    $self->add_assemblies(            $key,$dbs_hash->{$db}{'tables'} ); # To sequence tree!                             ## 2 do ##
    $self->add_decorations(           $key,$dbs_hash->{$db}{'tables'} );
  }

  foreach my $db ( @{$self->species_defs->compara_like_databases||[]} ) {
    next unless exists $multi_hash->{$db};
    my $key = lc(substr($db,9));
    ## Configure dna_dna_align features and synteny tracks
    $self->add_synteny(               $key,$multi_hash->{$db}, $species ); # Add to synteny tree                         ##DONE
    $self->add_alignments(            $key,$multi_hash->{$db}, $species ); # Add to compara_align tree                   ##DONE
  }
  foreach my $db ( @{$self->species_defs->funcgen_like_databases||[]} ) {
    next unless exists $dbs_hash->{$db};
    my $key = lc(substr($db,9));
    ## Configure 
    $self->add_regulation_feature(    $key,$dbs_hash->{$db}{'tables'}, $species ); # Add to regulation_feature tree
  }
  foreach my $db ( @{$self->species_defs->variation_like_databases||[]} ) {
    next unless exists $dbs_hash->{$db};
    my $key = lc(substr($db,9));
    ## Configure variation features
    $self->add_variation_feature(     $key,$dbs_hash->{$db}{'tables'} ); # To variation_feature tree
  }
}
 
sub load_configured_das {
  my $self=shift;
  ## Now we do the das stuff - to append to menus (if the menu exists!!)
  my $internal_das_sources = $self->species_defs->get_all_das;
  foreach my $source ( sort { $a->caption cmp $b->caption } values %$internal_das_sources ) {
    $source->is_on($self->{'type'}) || next;
    $self->add_das_track( $source->category,  $source );
  }
}

sub add_das_track {
  my( $self, $menu, $source ) = @_;
  my $node = $self->get_node($menu);
  if (!$node) {
    if (grep { $menu eq $_ } @TRANSCRIPT_TYPES) {
      for (@TRANSCRIPT_TYPES) {
        $node = $self->get_node($_);
        last if $node;
      }
    }
    $node ||= $self->get_node('external_data');
  }
  
  return unless $node;
  my $caption =  $source->caption || $source->label;
  my $desc    =  $source->description;
  my $homepage = $source->homepage;
  if ($homepage) {
    $desc .= sprintf ' [<a href="%s">Homepage</a>]', $homepage;
  }
  my $t = $self->create_track( "das_".$source->logic_name,$source->label, {
    '_class'      => 'DAS',
    'glyphset'    => '_das',
    'display'     => 'off',
    'renderers'   => ['off' => 'Off', 'nolabels' => 'No labels', 'labels' => 'With labels'],
    'logicnames'  => [ $source->logic_name ],
    'caption'     => $caption,
    'description' => $desc,
  });
  $node->append($t) if $t;
}

#-----------------------------------------------------------------------------
# Functions to add tracks from core like databases....
#-----------------------------------------------------------------------------

sub _check_menus {
  my $self = shift;
  foreach( @_ ) {
    return 1 if $self->tree->get_node( $_ );
  }
  return 0;
}

sub _merge {
  my( $self, $_sub_tree, $sub_type ) = @_;
  my $data = {};
  my $tree = $_sub_tree->{'analyses'};
  my $config_name = $self->{'type'};

  foreach my $analysis (keys %$tree) {
    my $sub_tree = $tree->{$analysis};
    next unless $sub_tree->{'disp'}; ## Don't include non-displayable tracks
#local $Data::Dumper::Indent=0;
    #warn Data::Dumper::Dumper($sub_tree->{'web'});
    #warn ".... $sub_type {",$sub_tree->{'web'}{ $sub_type },"}";
    next if exists $sub_tree->{'web'}{ $sub_type }{'do_not_display'};
    my $key = $sub_tree->{'web'}{'key'} || $analysis;
    foreach ( keys %{$sub_tree->{'web'}||{}} ) {
#warn "............ $_ ...............";
      next if $_ eq 'desc';
      if( $_ eq 'default' ) {
#warn ".... $_ $config_name : ",keys %{$sub_tree->{'web'}{$_}||{}};
	if ( ref($sub_tree->{'web'}{$_}) eq 'HASH') {
	  $data->{$key}{'display'} ||= $sub_tree->{'web'}{$_}{$config_name};
	}
	else {
	  $data->{$key}{'display'} ||= $sub_tree->{'web'}{$_};
        }
      } else {
        $data->{$key}{$_}    ||= $sub_tree->{'web'}{$_};     # Longer form for help and configuration!
      }
    }
    if( $sub_tree->{'web'}{'key'} ) {
      if( $sub_tree->{'desc'} ) {
        $data->{$key}{'html_desc'}   ||= "<dl>\n";
        $data->{$key}{'description'} ||= '';
        $data->{$key}{'html_desc'} .= sprintf(
          "  <dt>%s</dt>\n  <dd>%s</dd>\n",
          CGI::escapeHTML( $sub_tree->{'web'}{'name'}       ),     # Description for pop-help - merged of all descriptions!!
          CGI::escapeHTML( $sub_tree->{'desc'})
        );
        $data->{$key}{'description'}.= ($data->{$key}{'description'}?'; ':'').$sub_tree->{'desc'};
      }
    } else {
      $data->{$key}{'description'} = $sub_tree->{'desc'};
      $data->{$key}{'html_desc'} .= sprintf(
        '<p>%s</p>',
        CGI::escapeHTML( $sub_tree->{'desc'})
      );
    }
    push @{$data->{$key}{'logic_names'}}, $analysis;
  }
  foreach my $key (keys %$data) {
    $data->{$key}{'name'} ||= $tree->{$key}{'name'};
    $data->{$key}{'caption'} ||= $data->{$key}{'name'} || $tree->{$key}{'name'};
    $data->{$key}{'description'} .= '</dl>' if $data->{$key}{'description'} =~ '<dl>';
  }
  return ( [sort { $data->{$a}{'name'} cmp $data->{$b}{'name'} } keys %$data], $data );
}

sub add_assemblies {
  my( $self, $key, $hashref ) = @_;
  return unless $self->_check_menus( 'sequence' );
}

### add_dna_align_feature...
### loop through all core databases - and attach the dna align
### features from the dna_align_feature tables...
### these are added to one of four menus: cdna/mrna, est, rna, other
### depending whats in the web_data column in the database

sub add_dna_align_feature {
  my( $self, $key, $hashref ) = @_;
  return unless $self->_check_menus( 'dna_align_cdna' );
  my( $keys, $data ) = $self->_merge( $hashref->{'dna_align_feature'} , 'dna_align' );
  
  foreach my $key_2 ( @$keys ) {
    my $K = $data->{$key_2}{'type'}||'other';
    my $menu = $self->tree->get_node( "dna_align_$K" );
    if( $menu ) {
      $menu->append( $self->create_track( 'dna_align_'.$key.'_'.$key_2, $data->{$key_2}{'name'}, {
        'db'          => $key,
        'glyphset'    => '_alignment',
        'sub_type'    => lc($K),
        'colourset'   => 'feature',
        'logicnames'  => $data->{$key_2}{'logic_names'},
        'caption'     => $data->{$key_2}{'caption'},
        'description' => $data->{$key_2}{'description'},
        'display'     => $data->{$key_2}{'display'}||'off', ## Default to on at the moment - change to off by default!
        'renderers'   => [
          'off'         => 'Off',
          'normal'      => 'Normal',
          'half_height' => 'Half height',
          'stack'       => 'Stacked',
          'unlimited'   => 'Stacked unlimited',
          'ungrouped'   => 'Ungrouped'
        ],
        'strand'      => 'b'
      }));
    }
  }
}

### add_protein_align_feature...
### loop through all core databases - and attach the protein align
### features from the protein_align_feature tables...

sub add_protein_align_feature {
  my( $self, $key, $hashref ) = @_;
  return unless $self->_check_menus( 'protein_align' );
  my( $keys, $data ) = $self->_merge( $hashref->{'protein_align_feature'} );
  
  my $menu = $self->tree->get_node( "protein_align" );
  foreach my $key_2 ( @$keys ) {
    $menu->append( $self->create_track( 'protein_'.$key.'_'.$key_2, $data->{$key_2}{'name'},{
      'db'          => $key,
      'glyphset'    => '_alignment',
      'sub_type'    => 'protein',
      'object_type' => 'ProteinAlignFeature',
      'colourset'   => 'feature',
      'logicnames'  => $data->{$key_2}{'logic_names'},
      'caption'     => $data->{$key_2}{'caption'},
      'description' => $data->{$key_2}{'description'},
      'display'     => $data->{$key_2}{'display'}||'off', ## Default to on at the moment - change to off by default!
      'renderers'   => [
        'off'         => 'Off',
        'normal'      => 'Normal',
        'half_height' => 'Half height',
        'stack'       => 'Stacked',
        'unlimited'   => 'Stacked unlimited',
        'ungrouped'   => 'Ungrouped'
      ],
      'strand'      => 'b'
    }));
  }
}

sub add_simple_feature {
  my( $self, $key, $hashref ) = @_;
  return unless $self->get_node( 'simple' );
  my( $keys, $data ) = $self->_merge( $hashref->{'simple_feature'} );
  
  my $menu = $self->tree->get_node( "simple" );
  foreach my $key_2 ( @$keys ) {
    $menu->append( $self->create_track( 'simple_'.$key.'_'.$key_2, $data->{$key_2}{'name'}, {
      'db'          => $key,
      'glyphset'    => '_simple',
      'logicnames'  => $data->{$key_2}{'logic_names'},
      'colourset'   => 'simple',
      'caption'     => $data->{$key_2}{'caption'},
      'description' => $data->{$key_2}{'description'},
      'display'     => $data->{$key_2}{'display'}||'off', ## Default to on at the moment - change to off by default!
      'renderers'   => [qw(off Off normal Normal)],
      'strand'      => 'r'
    }));
  }
}

sub add_prediction_transcript {
  my( $self, $key, $hashref ) = @_;
  return unless $self->get_node( 'prediction' );
  my( $keys, $data ) = $self->_merge( $hashref->{'prediction_transcript'} );
  
  my $menu = $self->tree->get_node( "prediction" );
  foreach my $key_2 ( @$keys ) {
    $menu->append( $self->create_track( 'transcript_'.$key.'_'.$key_2, $data->{$key_2}{'name'}, {
      'db'          => $key,
      'glyphset'    => '_prediction_transcript',
      'logicnames'  => $data->{$key_2}{'logic_names'},
      'caption'     => $data->{$key_2}{'caption'},
      'colourset'   => 'prediction',
      'colour_key'  => lc($key_2),
      'description' => $data->{$key_2}{'description'},
      'display'     => $data->{$key_2}{'display'}||'off', ## Default to on at the moment - change to off by default!
      'renderers'   => [qw(off Off), 'transcript_nolabel' => 'No labels', 'transcript_label' => 'With labels'],
      'strand'      => 'b'
    }));
  }
}

sub add_ditag_feature {
  my( $self, $key, $hashref ) = @_;
  return unless $self->_check_menus( 'ditag' );
  my( $keys, $data ) = $self->_merge( $hashref->{'ditag_feature'} );
  my $menu = $self->tree->get_node( 'ditag' );
  foreach my $key_2 ( @$keys ) {
    if( $menu ) {
      $menu->append( $self->create_track( 'ditag_'.$key.'_'.$key_2, $data->{$key_2}{'name'}, {
        'db'          => $key,
        'glyphset'    => '_ditag',
        'logicnames'  => $data->{$key_2}{'logic_names'},
        'caption'     => $data->{$key_2}{'caption'},
        'description' => $data->{$key_2}{'description'},
        'display'     => $data->{$key_2}{'display'}||'off', ## Default to on at the moment - change to off by default!
        'renderers'   => [qw(off Off normal Normal)],
        'strand'      => 'b'
      }));
    }
  }
}

### add_gene...
### loop through all core databases - and attach the gene
### features from the gene tables...
### there are a number of menus sub-types these are added to:
### * gene                    # genes
### * transcript              # ordinary transcripts
### * alignslice_transcript   # transcripts in align slice co-ordinates
### * tse_transcript          # transcripts in collapsed intro co-ords
### * tsv_transcript          # transcripts in collapsed intro co-ords
### * gsv_transcript          # transcripts in collapsed gene co-ords
### depending on which menus are configured

sub add_gene {
  my( $self, $key, $hashref ) = @_;
## Gene features end up in each of these menus..

  return unless $self->_check_menus( @TRANSCRIPT_TYPES );

  my( $keys, $data )   = $self->_merge( $hashref->{'gene'}, 'gene' );

  my $flag = 0;
  foreach my $type ( @TRANSCRIPT_TYPES ) {
    my $menu = $self->get_node( $type );
    next unless $menu;
    foreach my $key_2 ( @$keys ) {
      $menu->append( $self->create_track( $type.'_'.$key.'_'.$key_2, $data->{$key_2}{'name'}, {
        'db'          => $key,
        'glyphset'    => ($type=~/_/?'':'_').$type, ## QUICK HACK..
        'logicnames'  => $data->{$key_2}{'logic_names'},
        'colours'     => $self->species_defs->colour( 'gene' ),
        'caption'     => $data->{$key_2}{'caption'},
	'colour_key'  => $data->{$key_2}{'colour_key'},
        'label_key'   => $data->{$key_2}{'label_key'},
        'description' => $data->{$key_2}{'description'},
        'display'     => $data->{$key_2}{'display'}||'off', ## Default to on at the moment - change to off by default!
        'renderers'   => $type eq 'transcript' ?
          [qw(off Off), 
            'transcript_nolabel' => 'Expanded without labels',  'transcript_label' => 'Expanded with labels',
            'collapsed_nolabel'  => 'Collapsed without labels', 'collapsed_label'  => 'Collapsed with labels',
          ] : 
          [qw(off Off gene_nolabel), 'No labels', 'gene_label', 'With labels'],
        'strand'      => $type eq 'gene' ? 'r' : 'b'
      }));
      $flag=1;
    }
  }
  ## Need to add the gene menu track here....
  if( $flag ) {
    $self->add_track( 'information', 'gene_legend', 'Gene Legend', 'gene_legend', { 'strand' => 'r' } );
  }
}

sub add_marker_feature {
  my( $self, $key, $hashref ) = @_;
  return unless $self->get_node( 'marker' );
  my( $keys, $data ) = $self->_merge( $hashref->{'marker_feature'} );
  my $menu      = $self->get_node( 'marker' );
  foreach my $key_2 (@$keys) {
    $menu->append( $self->create_track( 'marker_'.$key.'_'.$key_2, $data->{$key_2}{'name'}, {
      'db'          => $key,
      'glyphset'    => '_marker',
      'labels'      => 'on',
      'logicnames'  => $data->{$key_2}{'logic_names'},
      'caption'     => $data->{$key_2}{'caption'},
      'colours'     => $self->species_defs->colour( 'marker' ),
      'description' => $data->{$key_2}{'description'},
      'priority'    => $data->{$key_2}{'priority'},
      'display'     => $data->{$key_2}{'display'}||'off', ## Default to on at the moment - change to off by default!
      'renderers'   => [qw(off Off normal Normal)],
      'strand'      => 'r'
    }));
  }
}

sub add_qtl_feature {
  my( $self, $key, $hashref ) = @_;
  return unless $self->get_node( 'marker' );
  my( $keys, $data ) = $self->_merge( $hashref->{'qtl'} );
  my $menu      = $self->get_node( 'marker' );
  foreach my $key_2 (@$keys) {
    $menu->append( $self->create_track( 'qtl_'.$key.'_'.$key_2, $data->{$key_2}{'name'}, {
      'db'          => $key,
      'glyphset'    => '_qtl',
      'logicnames'  => $data->{$key_2}{'logic_names'},
      'caption'     => $data->{$key_2}{'caption'},
      'colourset'   => 'qtl',
      'description' => $data->{$key_2}{'description'},
      'display'     => $data->{$key_2}{'display'}||'off', ## Default to on at the moment - change to off by default!
      'renderers'   => [qw(off Off normal Normal)],
      'strand'      => 'r'
    }));
  }
}

sub add_misc_feature {
  my( $self, $key, $hashref ) = @_;
  #set some defaults and available tracks
  my $default_tracks = {
      'cytoview'   => {'tilepath' => {'default'   => 'normal'},
		       'encode'   => {'threshold' => 'no'},
		   },
      'contigviewbottom' => {'ntctgs' => {'available' => 'no'},
			     'encode'   => {'threshold' => 'no'},}
  };
  return unless $self->get_node( 'misc_feature' );
  my $config_name = $self->{'type'};
  my $menu = $self->get_node('misc_feature');
  ## Different loop - no analyses - just misc_sets... 
  my $data = $hashref->{'misc_feature'}{'sets'};
  foreach my $key_2 ( sort { $data->{$a}{'name'} cmp $data->{$b}{'name'} } keys %$data ) {
    next if ($default_tracks->{$config_name}{$key_2}{'available'} eq 'no');
    my $dets =  {
        'glyphset'    => '_clone',
        'db'          => $key,
        'set'         => $key_2,
        'colourset'   => 'clone',
        'caption'     => $data->{$key_2}{'name'},
        'description' => $data->{$key_2}{'desc'},
        'max_length'  => $data->{$key_2}{'max_length'},
        'strand'      => 'r',
        'display'     => $default_tracks->{$config_name}{$key_2}{'default'}||$data->{$key_2}{'display'}||'off',
        'renderers'   => [qw(off Off normal Normal)],
    };
    unless ($default_tracks->{$config_name}{$key_2}{'threshold'} eq 'no') {
	$dets->{'outline_threshold'} = 350000;
    }
    $menu->append( $self->create_track( 'misc_feature_'.$key.'_'.$key_2, $data->{$key_2}{'name'}, $dets));
  }
}

sub add_oligo_probe {
  my( $self, $key, $hashref ) = @_;
  return unless $self->get_node( 'oligo' );

  my $menu = $self->get_node('oligo');
  my $data = $hashref->{'oligo_feature'}{'arrays'};
  my $description = $hashref->{'oligo_feature'}{'analyses'}{'AlignAffy'}{'desc'};
  ## Different loop - no analyses - base on probeset query results... = $hashref->{'oligo_feaature'}{'arrays'};
  foreach my $key_2 ( sort keys %$data ) {
    $menu->append( $self->create_track( 'oligo_'.$key.'_'.$key_2, $key_2, {
      'glyphset'    => '_oligo',
      'db'          => $key,
      'sub_type'    => 'oligo',
      'array'       => $key_2,
      'object_type' => 'OligoProbe',
      'colourset'   => 'feature',
      'description' => $description,
      'caption'     => $key_2,
      'strand'      => 'b',
      'display'     => 'off', 
      'renderers'   => [
        'off'         => 'Off',
        'normal'      => 'Normal',
        'half_height' => 'Half height',
        'stack'       => 'Stacked',
        'unlimited'   => 'Stacked unlimited',
        'ungrouped'   => 'Ungrouped'
      ]
    }));
  }
}


sub add_protein_feature {
  my( $self, $key, $hashref ) = @_;

  my %menus = (
    'domain'     => [ 'domain',    'P_domain',   'normal' ],
    'feature'    => [ 'feature',   'P_feature',  'normal' ],
    'alignment'  => [ 'alignment', 'P_domain',   'off'    ],
    'gsv_domain' => [ 'domain',    'gsv_domain', 'normal' ]
  );
  ## We have two separate glyphsets in this in this case
  ## P_feature and P_domain - plus domains get copied onto gsv_domain as well...

  return unless $self->_check_menus( keys %menus );

  my( $keys, $data )   = $self->_merge( $hashref->{'protein_feature'} );

  foreach my $menu_code ( keys %menus ) {
    my $menu = $self->get_node( $menu_code );
    next unless $menu;
    my $type = $menus{$menu_code}[0];
    my $gset = $menus{$menu_code}[1];
    my $renderer =  $menus{$menu_code}[2];
    foreach my $key_2 ( @$keys ) {
      next if $self->tree->get_node( $type.'_'.$key_2 );
      next if $type ne $data->{$key_2}{'type'}; ## Don't separate by db in this case!
      $menu->append( $self->create_track( $type.'_'.$key_2, $data->{$key_2}{'name'}, {
        'strand'      => $gset =~ /P_/ ? 'f' : 'b',
        'depth'       => 1e6,
        'glyphset'    => $gset,
        'logicnames'  => $data->{$key_2}{'logic_names'},
        'name'        => $data->{$key_2}{'name'},
        'caption'     => $data->{$key_2}{'caption'},
        'colourset'   => 'protein_feature',
        'description' => $data->{$key_2}{'description'},
        'display'     => $renderer, ## Default to on at the moment - change to off by default!
        'renderers'   => [qw(off Off normal Normal)],
      }));
    }
  }
}

sub add_repeat_feature {
  my( $self, $key, $hashref ) = @_;
  return unless $self->get_node( 'repeat' );
## Add generic feature track...
  return unless $hashref->{'repeat_feature'}{'rows'}>0; ## We have repeats...
  my $data = $hashref->{'repeat_feature'}{'analyses'};
  my $menu = $self->get_node( 'repeat' );
  $menu->append( $self->create_track( 'repeat_'.$key, "All repeats", {
    'db'          => $key,
    'glyphset'    => '_repeat',
    'logicnames'  => [undef],                ## All logic names...
    'types'       => [undef],                ## All repeat types...
    'name'        => 'All repeats',
    'description' => 'All repeats',
    'colourset'   => 'repeat',
    'display'     => 'off', ## Default to on at the moment - change to off by default!
    'renderers'   => [qw(off Off normal Normal)],
    'optimizable' => 1,
    'depth'       => 0.5,
    'bump_width'  => 0,
    'strand'      => 'r'
  }));
  my $flag = keys %$data > 1;
  foreach my $key_2 ( sort { $data->{$a}{'name'} cmp $data->{$b}{'name'} } keys %$data ) {
## Add track for each analysis ()... break down 1
    if( $flag ) {
      $menu->append( $self->create_track( 'repeat_'.$key.'_'.$key_2, $data->{$key_2}{'name'}, {
        'db'          => $key,
        'glyphset'    => '_repeat',
        'logicnames'  => [ $key_2 ],           ## Restrict to a single supset of logic names...
        'types'       => [ undef  ],
        'name'        => $data->{$key_2}{'name'},
        'description' => $data->{$key_2}{'desc'},
        'colours'     => $self->species_defs->colour( 'repeat' ),
        'display'     => 'off', ## Default to on at the moment - change to off by default!
        'renderers'   => [qw(off Off normal Normal)],
        'optimizable' => 1,
        'depth'       => 0.5,
        'bump_width'  => 0,
        'strand'      => 'r'
      }));
    }
## Add track for each repeat_type ();
    my $d2 = $data->{$key_2}{'types'};
    if( keys %$d2 > 1 ) {
      foreach my $key_3 ( sort keys %$d2 ) {
        (my $key_3a = $key_3) =~ s/\W/_/g;
        my $n = $key_3;
           $n.= " (".$data->{$key_2}{'name'}.")" unless $data->{$key_2}{'name'} eq 'Repeats';
        $menu->append( $self->create_track( 'repeat_'.$key.'_'.$key_2.'_'.$key_3a, $n,{
          'db'          => $key,
          'glyphset'    => '_repeat',
          'logicnames'  => [ $key_2 ],
          'types'       => [ $key_3 ],
          'name'        => $n,
          'description' => $data->{$key_2}{'desc'}." ($key_3)",
          'colours'     => $self->species_defs->colour( 'repeat' ),
          'display'     => 'off', ## Default to on at the moment - change to off by default!
          'renderers'   => [qw(off Off normal Normal)],
          'optimizable' => 1,
          'depth'       => 0.5,
          'bump_width'  => 0,
          'strand'      => 'r'
        }));
      }
    }
  }
}

#----------------------------------------------------------------------#
# Functions to add tracks from compara like databases....
#----------------------------------------------------------------------#

sub add_synteny {
  my( $self, $key, $hashref, $species ) = @_;
  return unless $self->get_node( 'synteny' );
  my @synteny_species = sort keys %{$hashref->{'SYNTENY'}{$species}||{}};
  return unless @synteny_species;
  my $menu = $self->get_node( 'synteny' );
  my $self_label = $self->species_defs->species_label( $species );
  foreach my $species ( @synteny_species ) {
    ( my $species_readable = $species ) =~ s/_/ /g;
    my ($a,$b) = split / /, $species_readable;
    my $caption = substr($a,0,1).".$b synteny";
    my $label = $self->species_defs->species_label( $species );
    ( my $name = "Synteny with $label" ) =~ s/<.*?>//g;
    $menu->append( $self->create_track( 'synteny_'.$species, $name, {
      'db'          => $key,
      'glyphset'    => '_synteny',
      'species'     => $species,
      'species_hr'  => $species_readable,
      'caption'     => $caption,
      'description' => "Synteny regions between $self_label and $label",
      'colours'     => $self->species_defs->colour( 'synteny' ),
      'display'     => 'off', ## Default to on at the moment - change to off by default!
      'renderers'   => [qw(off Off normal Normal)],
      'height'      => 4,
      'strand'      => 'r'
    }));
  }
}

sub add_alignments {
  my( $self, $key, $hashref,$species ) = @_;
  return unless $self->_check_menus( qw(multiple_align pairwise_tblat pairwise_blastz pairwise_other) );
  my $alignments = {};
  my $regexp = $species =~ /^([A-Z])[a-z]*_([a-z]{3})/ ? "-?$1.$2-?" : 'xxxxxx';
  foreach my $row ( values %{$hashref->{'ALIGNMENTS'}} ) {
    next unless $row->{'species'}{$species};
    if( $row->{'class'} =~ /pairwise_alignment/ ) {
      my( $other_species ) = grep { $species ne $_ } keys %{$row->{'species'}};
      (my $other_species_hr = $other_species ) =~ s/_/ /g;
      my $menu_key = $row->{'type'} =~ /BLASTZ/ ? 'pairwise_blastz' 
                   : $row->{'type'} =~ /TRANSLATED_BLAT/  ? 'pairwise_tblat'
           : 'pairwise_align'
           ;
      (my $caption = $row->{'name'}) =~s/blastz-net \(on.*?\)/BLASTz net/g;
      $caption =~ s/translated-blat-net/Trans. BLAT net/g;
      $caption =~ s/$regexp//;
      $alignments->{$menu_key}{ $row->{'id'} } = {
        'db'             => $key,
        'glyphset'       => '_alignment_pairwise',
        'name'           => $row->{'name'},
        'caption'        => $caption,
        'type'           => $row->{'type'},
        'species_set_id' => $row->{'species_set_id'},
        'species'        => $other_species,
        'species_hr'     => $other_species_hr,
        '_assembly'      => $self->species_defs->other_species( $other_species, 'ENSEMBL_GOLDEN_PATH' ),
        'class'          => $row->{'class'},
        'description'    => "Pairwise alignments",
        'order'          => $row->{'type'}.'::'.$other_species,
        'colourset'      => 'pairwise',
        'strand'         => 'r',
        'display'        => 'off', ## Default to on at the moment - change to off by default!
        'renderers'      => [qw(off Off compact Compact normal Normal)],
      };
    } else {
      my $n_species = grep { $_ ne 'Ancestral_sequences' } keys %{$row->{'species'}};
      if( $row->{'conservation_score'} ) {
        $alignments->{'multiple_align'}{ $row->{'id'}.'_scores' } = {
          'db' => $key,
          'glyphset'       => '_alignment_multiple',
          'name'           => "Conservation score for ".$row->{'name'},
          'short_name'     => $row->{'name'},
          'caption'        => "Cons. score $n_species way",
          'type'           => $row->{'type'},
          'species_set_id' => $row->{'species_set_id'},
          'method_link_species_set_id' => $row->{'id'},
          'class'          => $row->{'class'},
          'conservation_score'  => $row->{'conservation_score'},
          'description'    => "Multiple alignments",
          'colourset'      => 'multiple',
          'order'          => sprintf( '%12d::%s::%s',1e12-$n_species*10, $row->{'type'}, $row->{'name'} ),
          'strand'         => 'f',
          'display'        => 'signal_map', ## Default to on at the moment - change to off by default!
          'renderers'      => ['off'=>'Off','signal_map'=>'Signal map']
        };
        $alignments->{'multiple_align'}{ $row->{'id'}.'_constrained' } = {
          'db' => $key,
          'glyphset'       => '_alignment_multiple',
          'name'           => "Constrained elements for ".$row->{'name'},
          'short_name'     => $row->{'name'},
          'caption'        => "Constrained el. $n_species way",
          'type'           => $row->{'type'},
          'species_set_id' => $row->{'species_set_id'},
          'method_link_species_set_id' => $row->{'id'},
          'class'          => $row->{'class'},
          'constrained_element' => $row->{'constrained_element'},
          'description'    => "Multiple alignments",
          'colourset'      => 'multiple',
          'order'          => sprintf( '%12d::%s::%s',1e12-$n_species*10+1, $row->{'type'}, $row->{'name'} ),
          'strand'         => 'f',
          'display'        => 'compact', ## Default to on at the moment - change to off by default!
          'renderers'      => [qw(off Off compact Normal)]
        };
      }
      $alignments->{'multiple_align'}{ $row->{'id'} } = {
        'db' => $key,
        'glyphset'       => '_alignment_multiple',
        'name'           => $row->{'name'},
        'short_name'     => $row->{'name'},
        'caption'        => $row->{'name'},
        'type'           => $row->{'type'},
        'species_set_id' => $row->{'species_set_id'},
        'method_link_species_set_id' => $row->{'id'},
        'class'          => $row->{'class'},
        'description'    => "Multiple alignments",
        'colourset'      => 'multiple',
        'order'          => sprintf( '%12d::%s::%s',1e12-$n_species*10-1, $row->{'type'}, $row->{'name'} ),
        'strand'         => 'f',
        'display'        => 'off', ## Default to on at the moment - change to off by default!
        'renderers'      => [qw(off Off compact Normal)],
      };
    } 
  }
  foreach my $menu_key ( keys %$alignments ) {
    my $menu = $self->get_node( $menu_key );
    next unless $menu;
    foreach my $key_2 ( sort {
      $alignments->{$menu_key}{$a}{'order'} cmp  $alignments->{$menu_key}{$b}{'order'}
    } keys %{$alignments->{$menu_key}} ) {
      my $row = $alignments->{$menu_key}{$key_2};
      $menu->append( $self->create_track( 'alignment_'.$key.'_'.$key_2, $row->{'caption'}, $row ));
    }
  }
}

sub add_option {
  my( $self, $key, $caption, $values ) = @_;
  my $menu = $self->get_node( 'options' );
  return unless $menu;
  $menu->append( $self->create_option( $key, $caption, $values ) );
}

sub add_options {
  my $self = shift;
  my $menu = $self->get_node( 'options' );
  return unless $menu;
  foreach my $row (@_) {
    my ($key, $caption, $values ) = @$row;
    $menu->append( $self->create_option( $key, $caption, $values ) );
  } 
}

sub create_track {
  my ( $self, $code, $caption, $options ) = @_;
  my $details = { 'name'    => $caption, 'node_type' => 'track' };
  foreach ( keys %{$options||{}} ) {
    $details->{$_} = $options->{$_};
  }
  $details->{'strand'}   ||= 'b';      # Make sure we have a strand setting!!
  $details->{'display'}  ||= 'normal'; # Show unless we explicitly say no!!
  $details->{'renderers'}||= [qw(off Off normal Normal)];
  $details->{'colours'}  ||= $self->species_defs->colour( $options->{'colourset'} ) if exists $options->{'colourset'};
  $details->{'glyphset'} ||= $code;
  $details->{'caption'}  ||= $caption;
  return $self->tree->create_node( $code, $details );
}

sub add_track {
  my( $self, $menu_key, $key, $caption, $glyphset, $params ) = @_;
  my $menu =  $self->get_node( $menu_key );
  return unless $menu;
  return if $self->get_node( $key ); ## Don't add duplicates...
  $params->{'glyphset'} = $glyphset;
  $menu->append( $self->create_track( $key, $caption, $params ) );
}

sub add_tracks {
  my $self     = shift;
  my $menu_key = shift;
  my $menu =  $self->get_node( $menu_key );
  return unless $menu;
  foreach my $row (@_) {
    my ( $key, $caption, $glyphset, $params ) = @$row; 
    next if $self->get_node( $key ); ## Don't add duplicates...
    $params->{'glyphset'} = $glyphset;
    $menu->append( $self->create_track( $key, $caption, $params ) );
  }
}

#----------------------------------------------------------------------#
# Functions to add tracks from functional genomics like database....
#----------------------------------------------------------------------#

sub add_regulation_feature { ## needs configuring so tracks only display if data in species fg_database
  my( $self, $key, $hashref, $species ) = @_;
  return unless $self->get_node( 'functional' );
  my ( $keys, $data) = $self->_merge( $hashref->{'result_set'}); foreach ( keys %$data) {warn $_;}
  return  unless $hashref->{'feature_set'}{'rows'} > 0;
  my $menu = $self->get_node( 'functional' );
  if ($species eq 'Homo_sapiens') {
    $menu->append($self->create_track('fg_regulatory_features_'.$key, sprintf("Reg. Features"),{
      'db'          => $key,
      'glyphset'    => 'fg_regulatory_features',
      'sources'     => undef,
      'strand'      => 'r',
      'labels'      => 'on',
      'depth'       => 10,
      'colourset'   => 'fg_regulatory_features',
      'description' => 'Features from Ensembl Regulatory build',
      'display'     => 'normal'
    }));
    $menu->append($self->create_track('regulatory_search_regions_'.$key, sprintf("cisRED Search Regions"),{
      'db'          => $key,
      'glyphset'    => 'regulatory_search_regions',
      'sources'     => undef,
      'strand'      => 'r',
      'labels'      => 'on',
      'depth'       =>  0.5,
      'colourset'   => 'regulatory_search_regions',
      'description' => 'cisRED Search regions',
      'display'     => 'off'
    }));
    $menu->append( $self->create_track('regulatory_regions_'.$key, sprintf("cisRED/miRanda/VISTA"),{
      'db'          => $key,
      'glyphset'    => 'regulatory_regions',
      'sources'     => undef,
      'strand'      => 'r',
      'labels'      => 'on',
      'depth'       =>  0.5,
      'colourset'   => 'synteny',
      'description' => ' cisRED motifs; VISTA enhancer set; miRanda miRNA',
      'display'     => 'off'
    }));
    $menu->append($self->create_track('ctcf_wiggle_'.$key, sprintf("CTCF chip"),{
      'db'          => $key,
      'glyphset'    => 'ctcf',
      'sources'     => undef,
      'strand'      => 'r',
      'labels'      => 'on',
      'colourset'   => 'ctcf',
      'description' => 'Nessie_NG_STD_2_ctcf_ren_BR1',
      'renderers'      => ['off'=>'Off','signal_map'=>'Normal'],
     'display'     => 'off'
    }));
    $menu->append( $self->create_track('ctcf_blocks_'.$key, sprintf("CTCF peaks"),{
      'db'          => $key,
      'glyphset'    => 'ctcf',
      'sources'     => undef,
      'strand'      => 'r',
      'labels'      => 'on',
      'colourset'   => 'ctcf',
      'description' => 'CTCF',
      'display'     => 'off',
      'renderers'   => [qw(off Off compact Normal)]
    }));
    $self->add_track('information', 'fg_regulatory_features_legend', 'Reg. Features Legend', 'fg_regulatory_features_legend', {'strand' => 'r'});
  } elsif ($species eq 'Mus_musculus'){
    $menu->append($self->create_track('regulatory_search_regions_'.$key, sprintf("cisRED Search Regions"),{
      'db'          => $key,
      'glyphset'    => 'regulatory_search_regions',
      'sources'     => undef,
      'strand'      => 'r',
      'labels'      => 'on',
      'depth'       =>  0.5,
      'colourset'   => 'regulatory_search_regions',
      'description' => 'cisRED search regions',
      'display'     => 'off'
    }));
    $menu->append( $self->create_track('regulatory_regions_'.$key, sprintf("cisRED Motifs"),{
      'db'          => $key,
      'glyphset'    => 'regulatory_regions',
      'sources'     => undef,
      'strand'      => 'r',
      'labels'      => 'on',
      'depth'       =>  0.5,
      'colourset'   => 'synteny',
      'description' => 'cisRED motifs',
      'display'     => 'off'
    }));
    $menu->append($self->create_track('histone_modifications_'.$key, sprintf("Histone modifications"),{
      'db'          => $key,
      'glyphset'    => 'histone_modifications',
      'sources'     => undef,
      'strand'      => 'r',
      'labels'      => 'on',
      'colourset'   => 'ctcf',
      'description' => 'Histone modifications - Vienna MEFf H3K4me3',
      'renderers'      => ['off'=>'Off','signal_map'=>'Signal map'],
      'display'     => 'off'
    }));
  }elsif ($species eq 'Drosophila_melanogaster'){
    $menu->append( $self->create_track('regulatory_regions_'.$key, sprintf("'REDfly/BioTIFFIN"),{
      'db'          => $key,
      'glyphset'    => 'regulatory_regions',
      'sources'     => undef,
      'strand'      => 'r',
      'labels'      => 'on',
      'depth'       =>  0.5,
      'colourset'   => 'synteny',
      'description' => 'REDfly CRMs, REDfly TFBSs and BioTIFFIN motifs.',
      'display'     => 'off'
    }));

  }
return;
}

sub add_decorations {
  my( $self, $key, $hashref ) = @_;
  my $menu = $self->get_node( 'decorations' ); 
  return unless $menu;
  if( $key eq 'core' && $hashref->{'assembly_exception'}{'rows'} > 0 ) {
    $menu->append( $self->create_track( 'assembly_exception_'.$key, 'Assembly exceptions',{
      'db'            => $key,
      'glyphset'      => 'assemblyexception',
      'height'        => 2,
      'display'       => 'normal',
      'strand'        => 'x',
      'label_strand'  => 'r',
      'short_labels'  => 0,
      'description'   => 'Haplotype (HAPs) and Pseudo autosomal regions (PARs)',
      'colourset'     => 'assembly_exception'
    }));
  }
}
#----------------------------------------------------------------------#
# Functions to add tracks from variation like databases....
#----------------------------------------------------------------------#

sub add_variation_feature {
  my( $self, $key, $hashref ) = @_;
  my $menu = $self->get_node( 'variation' );
  return unless $menu;
  return unless $hashref->{'variation_feature'}{'rows'} > 0;
  $menu->append( $self->create_track( 'variation_feature_'.$key, sprintf( "All variations" ), {
    'db'          => $key,
    'glyphset'    => '_variation',
    'sources'     => undef,
    'strand'      => 'r',
    'depth'       => 0.5,
    'bump_width'  => 0,
    'colourset'   => 'variation',
    'description' => 'Variation features from all sources',
    'display'          => 'off'
  }));
  $menu->append( $self->create_track( 'variation_feature_genotyped_'.$key, sprintf( "Genotyped variations" ), {
    'db'          => $key,
    'glyphset'    => '_variation',
    'sources'     => undef,
    'strand'      => 'r',
    'depth'       => 0.5,
    'bump_width'  => 0,
    'filter'      => 'genotyped',
    'colourset'   => 'variation',
    'description' => 'Genotyped variation features from all sources',
    'display'          => 'off'
  }));

  foreach my $key_2 (sort keys %{$hashref->{'source'}{'counts'}||{}}) {
    ( my $k = $key_2 ) =~ s/\W/_/g;
    $menu->append( $self->create_track( 'variation_feature_'.$key.'_'.$k, sprintf( "%s variations", $key_2 ), {
      'db'          => $key,
      'glyphset'    => '_variation',
      'caption'     => $key_2,
      'sources'     => [ $key_2 ],
      'strand'      => 'r',
      'depth'       => 0.5,
      'bump_width'  => 0,
      'colourset'   => 'variation',
      'description' => sprintf( 'Variation features from the "%s" source', $key_2 ),
      'display'          => 'off'
    }));
  }
  $self->add_track( 'information', 'variation_legend', 'Variation Legend', 'variation_legend', { 'strand' => 'r' } );
}

## return a list of glyphsets...
sub glyphset_configs {
  my $self = shift;
  return grep { $_->data->{'node_type'} eq 'track' } $self->tree->nodes;
}

sub get_node {
  my $self = shift;
  return $self->tree->get_node(@_);
}

sub create_submenu {
  my ($self, $code, $caption, $options ) = @_;
  my $details = { 'caption'    => $caption, 'node_type' => 'menu' };
  foreach ( keys %{$options||{}} ) {
    $details->{$_} = $options->{$_};
  }
  return $self->tree->create_node( $code, $details );
}


sub create_option {
  my ( $self, $code, $caption, $values ) = @_;
  $values ||= {qw(0 no 1 yes)};
  return $self->tree->create_node( $code, {
    'node_type' => 'option',
    'caption'   => $caption,
    'name'      => $caption,
    'values'    => $values,
  });
}

sub _set_core { $_[0]->{'_core'} = $_[1]; }
sub core_objects { return $_[0]->{'_core'}; }

sub storable :lvalue {
### a
### Set whether this ViewConfig is changeable by the User, and hence needs to
### access the database to set storable do $view_config->storable = 1; in SC code...
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
  return $self->tree->user_data;
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

sub save {
  my ($self) = @_;
  warn "ImageConfig->save - Deprecated call now handled by session";
  return;
}

sub reset {
  my ($self) = @_;
  $self->{'user'}->{$self->{'type'}} = {}; 
  $self->altered = 1;
  return;
}

sub reset_subsection {
  my ($self, $subsection) = @_;
  return unless(defined $subsection);

  $self->{'user'}->{$self->{'type'}}->{$subsection} = {}; 
  $self->altered = 1;
  return;
}

sub subsections {
  my ($self,$flag) = @_;
  my @keys;
  @keys = grep { /^managed_/ } keys %{$self->{'user'}} if $flag==1;
  return @{$self->{'general'}->{$self->{'type'}}->{'_artefacts'}},@keys;
}

sub species_defs {
### a
  my $self = shift;
  return $self->{'species_defs'};
}

sub colourmap {
### a
  my $self = shift;
  return $self->{'_colourmap'};
}

sub image_height {
### a
  my $self = shift;
  $self->set_parameter('_height',shift) if @_;
  return $self->get_parameter('_height');
}

sub bgcolor {
### a
  my $self = shift;
  $self->get_parameter( 'bgcolor' ) || 'background1';
}

sub bgcolour {
### a
  my $self = shift;
  return $self->bgcolor;
}

sub texthelper {
### a
  my $self = shift;
  return $self->{'_texthelper'};
}

sub scalex {
  my $self = shift;
  if(@_) {
    $self->{'_scalex'} = shift;
    $self->{'_texthelper'}->scalex($self->{'_scalex'});
  }
  return $self->{'_scalex'};
}

sub set_width {
  my( $self, $val ) = @_;
  $self->set_parameter( 'width', $val );
}

sub transform {
  my $self = shift;
  return $self->{'transform'};
}

1;
