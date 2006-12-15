package EnsEMBL::Web::DASConfig;

use strict;
use Data::Dumper;
use Time::HiRes qw(time);

our %DAS_DEFAULTS = (
  'LABELFLAG'      => 'u',
  'STRAND'         => 'b',
  'DEPTH'          => '4',
  'GROUP'          => '1',
  'DEFAULT_COLOUR' => 'grey50',
  'STYLESHEET'     => 'Y',
  'SCORE'          => 'N',
  'FG_MERGE'       => 'A',
  'FG_GRADES'      => 20,
  'FG_DATA'        => 'O',
  'FG_MIN'         => 0,
  'FG_MAX'         => 100,
);

sub new {
  my $class   = shift;
  my $adaptor = shift;
  my $self = {
#    '_db'       => $adaptor->{'user_db'},
#    '_r'        => $adaptor->{'r'},
    '_data'     => {},
    '_type'     => 'external',
    '_altered'  => 0,
    '_deleted'  => 0
  };

  bless($self, $class);
  return $self;
}

sub set_internal {
  my $self = shift;
  $self->{_type} = 'internal';
}

sub set_external {
  my $self = shift;
  $self->{_type} = 'external';
}

sub touch_key {
  my $self = shift;
  $self->{'_data'}{'name'} .= '::'. $self->unique_string;
}

sub get_key {
  my $self = shift;
  return $self->{'_data'}{'name'};
}

sub unique_string {
  my $self = shift;
  return join '*', $self->{'_data'}{'url'}, $self->{'_data'}{'dsn'}, $self->{'_data'}{'types'};
}

sub get_name {
  my $self = shift;
  return $self->{'_data'}{'name'};
}

sub get_data {
  my $self = shift;
  return $self->{'_data'};
}

sub set_data {
  my( $self , $data ) = @_;
  $self->{'_data'} = $data;
}

sub is_deleted {
  my $self = shift;
  return $self->{'_deleted'};
}

sub mark_clean {
  my $self = shift;
  $self->{'_altered'} = 0;
  $self->{'_deleted'} = 0;
}

sub mark_deleted {
  my $self = shift;
  $self->{'_deleted'} = 1;
  $self->{'_altered'} = 1;
}

sub mark_altered {
  my $self = shift;
  $self->{'_altered'} = 1;
}

sub is_altered {
### a
### Set to one if the configuration has been updated...
  my $self = shift;
  return $self->{'_altered'};
}

sub delete {
  my $self = shift;
  $self->mark_deleted;
#  $self->set_data();
}

sub load {
  my( $self, $hash_ref ) = @_;
  $self->mark_clean;
  $self->set_data( $hash_ref );
}

sub amend {
  my( $self, $hash_ref ) = @_;
  return if $self->is_deleted; ## Can't amend a deleted source!
  $self->mark_altered;
  $self->set_data( $hash_ref );
  $self->dump();
}

sub dump {
  my ($self) = @_;
  print STDERR Dumper($self);
}

sub create_from_URL {
  my( $self, $URL ) = @_;
  $URL =~ s/[\(|\)]//g;                                # remove ( and |
  my @das_keys = split(/\s/, $URL);                    # break on spaces...
  my %das_data = map { split (/\=/, $_,2) } @das_keys; # split each entry on spaces
  my $das_name = $das_data{name} || $das_data{dsn} || 'NamelessSource';
  unless( exists $das_data{url} && exists $das_data{dsn} && exists $das_data{type}) {
    warn("WARNING: DAS source $das_name has not been added: Missing parameters");
    next;
  }
  $das_data{name} = $das_name;
# this bit should be handled outside when das confs are merged...
#  if( my $src = $ext_das->{'data'}->{$das_name}){
#    if (join('*',$src->{url}, $src->{dsn}, $src->{type}) eq join('*', $das_data{url}, $das_data{dsn}, $das_data{type})) {
#      warn("WARNING: DAS source $das_name has not been added: It is already attached");
#      next;
#    }
#    my $das_name_ori = $das_name;
#    for( my $i = 1; 1; $i++ ){
#      $das_name = $das_name_ori ."_$i";
#      if( ! exists($ext_das->{'data'}->{$das_name}  )){
#        $das_data{name} =  $das_name;
#        last;
#      }
#    }
#  }
      # Add to the conf list
  $das_data{label}      ||= $das_name;
  $das_data{caption}    ||= $das_name;
## Set these to the dafault values....
  $das_data{stylesheet} ||= $DAS_DEFAULTS{STYLESHEET};
  $das_data{score}      ||= $DAS_DEFAULTS{SCORE};
  $das_data{fg_merge}   ||= $DAS_DEFAULTS{FG_MERGE};
  $das_data{fg_grades}  ||= $DAS_DEFAULTS{FG_GRADES};
  $das_data{fg_data}    ||= $DAS_DEFAULTS{FG_DATA};
  $das_data{fg_min}     ||= $DAS_DEFAULTS{FG_MIN};
  $das_data{fg_max}     ||= $DAS_DEFAULTS{FG_MAX};
  $das_data{group}      ||= $DAS_DEFAULTS{GROUP};
  $das_data{strand}     ||= $DAS_DEFAULTS{STRAND};
  $das_data{enable}       = [split /,/, $das_data{enable}];
  $das_data{labelflag}  ||= $DAS_DEFAULTS{LABELFLAG};

  if (my $link_url = $das_data{linkurl}) {
    $link_url =~ s/\$3F/\?/g;
    $link_url =~ s/\$3A/\:/g;
    $link_url =~ s/\$23/\#/g;
    $link_url =~ s/\$26/\&/g;
    $das_data{linkurl} = $link_url;
  }
  push @{$das_data{enable}}, $ENV{'ENSEMBL_SCRIPT'} unless $ENV{'ENSEMBL_SCRIPT'} eq 'dasconfview';
  push @{$das_data{mapping}} , split(/\,/, $das_data{type});
  $das_data{conftype} = 'external';
  $das_data{type}     = 'mixed'    if scalar @{$das_data{mapping}} > 1;

## Store the configuration back on this object....
  $self->amend( \%das_data );

#  if( $das_data{active} ) {
#    $config->set("managed_extdas_$das_name", 'on', 'on', 1);
#    $das_data{depth}      and $config->set( "managed_extdas_$das_name", "dep", $das_data{depth}, 1);
#    $das_data{group}      and $config->set( "managed_extdas_$das_name", "group", $das_data{group}, 1);
#    $das_data{strand}     and $config->set( "managed_extdas_$das_name", "str", $das_data{strand}, 1);
#    $das_data{stylesheet} and $config->set( "managed_extdas_$das_name", "stylesheet", $das_data{stylesheet}, 1);
#    $config->set( "managed_extdas_$das_name", "lflag", $das_data{labelflag}, 1);
#    $config->set( "managed_extdas_$das_name", "manager", 'das', 1);
#    $das_data{color} and $config->set( "managed_extdas_$das_name", "col", $das_data{col}, 1);
#    $das_data{linktext} and $config->set( "managed_extdas_$das_name", "linktext", $das_data{linktext}, 1);
#    $das_data{linkurl} and $config->set( "managed_extdas_$das_name", "linkurl", $das_data{linkurl}, 1);
#  }
}

sub create_from_hash_ref {
  my( $self, $hash_ref ) = @_;
  $self->amend(  $hash_ref );
}

sub update_from_hash_ref {
  my( $self, $hash_ref ) = @_;
  $self->mark_altered;
  return;
warn "....";
  foreach my $key ( keys %$hash_ref ) {
warn $key;
    if( ref($self->{'_data'}{$key}) eq 'ARRAY' ) {
warn "YAR";
      my @old = sort @{$self->{'_data'}{$key}};
      my @new = sort @{$hash_ref->{$key}};
      my $C = 0;
      foreach my $o (@old) {
warn "ALTERED.... @old/@new";
        $self->mark_altered if $o ne $new[$C];
        $C++;
      }
    } else {
warn "ARG ", $self->{'_data'}{$key},' = ', $hash_ref->{$key};
      next if $self->{'_data'}{$key} eq $hash_ref->{$key};
      $self->mark_altered;
    }
    $self->{'_data'}{$key} = $hash_ref->{$key}
  }
}

=head

sub attach_to_configs {
  my( $self, %script_config_names ) = @_;
 ) {
    my %image_configs = %{$script_config->{'_user_config_names'}}
    foreach my $name ( keys %image_configs ) { 
      next if $image_configs->{$name} ne 'das'; ## Only deal with dasable configs...
      if( $script_configs ) 
## loop through each image_config
    foreach my $config ( @image_configs ) {
      next unless $config->is_das_enabled;
      my $config_key = "managed_extdas_".$self->get_key;
      $config->set( $config_key, 'on', 'on', 1);
      $config->set( $config_key, 'dep',        $self->get_data->{'depth'},     1 ) if  $self->get_data->{'depth'};
      $config->set( $config_key, 'group',      $self->get_data->{'group'},     1 ) if  $self->get_data->{'group'};
      $config->set( $config_key, 'str',        $self->get_data->{'strand'},    1 ) if  $self->get_data->{'strand'};
      $config->set( $config_key, 'stylesheet', $self->get_data->{'stylesheet'},1 ) if  $self->get_data->{'stylesheet'};
      $config->set( $config_key, 'lflag',      $self->get_data->{'labelflag'}, 1 ) if  $self->get_data->{'labeflag'};
      $config->set( $config_key, 'manager',    'das',                          1 );
      $config->set( $config_key, 'col',        $self->get_data->{'color'},     1 ) if  $self->get_data->{'color'};
      $config->set( $config_key, 'linktext',   $self->get_data->{'linktext'},  1 ) if  $self->get_data->{'linktext'};
      $config->set( $config_key, 'linkurl',    $self->get_data->{'linkurl'},   1 ) if  $self->get_data->{'linkurl'};
    }
  }
}
=cut

1;
