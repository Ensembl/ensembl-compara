package EnsEMBL::Web::Document::DropDown::Menu::DAS;

use strict;
use EnsEMBL::Web::ExternalDAS;
use EnsEMBL::Web::Document::DropDown::Menu;

our @ISA =qw( EnsEMBL::Web::Document::DropDown::Menu );
use Data::Dumper;

sub new {
  my $class = shift;
  my $self = $class->SUPER::new(
    @_, ## This contains the menu containers as the first element
    'image_name'  => 'y-dassource',
    'image_width' => 98,
    'alt'         => 'DAS sources'
  );

  my $script = $self->{'script'} || $ENV{ENSEMBL_SCRIPT};
  my $config = $self->{config};
  my $ext_das = new EnsEMBL::Web::ExternalDAS( $self->{'location'} );
  $ext_das->getConfigs($script, $script);

  foreach my $dconf (CGI::param("add_das_source")) {
    $dconf =~ s/[\(|\)]//g;
    my @das_keys = split(/\s/, $dconf);
    my %das_data = map { split (/\=/, $_,2) } @das_keys; 
    my $das_name = $das_data{name} || $das_data{dsn} || 'NamelessSource';
      
    if ( ! exists $das_data{url} || ! exists $das_data{dsn} || ! exists $das_data{type}) {
      warn("WARNING: DAS source $das_name has not been added: Missing parameters");
      next;
    }

    if( my $src = $ext_das->{'data'}->{$das_name}){ 
      if (join('*',$src->{url}, $src->{dsn}, $src->{type}) eq join('*', $das_data{url}, $das_data{dsn}, $das_data{type})) {
        warn("WARNING: DAS source $das_name has not been added: It is already attached");
        next;
      }
      
      my $das_name_ori = $das_name;
      for( my $i = 1; 1; $i++ ){
        $das_name = $das_name_ori ."_$i";
        if( ! exists($ext_das->{'data'}->{$das_name}  )){
          $das_data{name} =  $das_name;
          last;
        }
      }
    }
    
      # Add to the conf list
    $das_data{label} or $das_data{label} = $das_data{name};
    $das_data{caption} or $das_data{caption} = $das_data{name};
    $das_data{stylesheet} or $das_data{stylesheet} = 'n';
    $das_data{score} or $das_data{score} = 'n';
    $das_data{fg_merge} or $das_data{fg_merge} = 'a';
    $das_data{fg_grades} or $das_data{fg_grades} = 20;
    $das_data{fg_data} or $das_data{fg_data} = 'o';
    $das_data{fg_min} or $das_data{fg_min} = 0;
    $das_data{fg_max} or $das_data{fg_max} = 100;
    $das_data{group} or $das_data{group} = 'y';
    $das_data{strand} or $das_data{strand} = 'b';
    if (exists $das_data{enable}) {
      my @enable_on = split(/\,/, $das_data{enable});
      delete $das_data{enable};
      push @{$das_data{enable}}, @enable_on;
    }

    if (my $link_url = $das_data{linkurl}) {
      $link_url =~ s/\$3F/\?/g;
      $link_url =~ s/\$3A/\:/g;
      $link_url =~ s/\$23/\#/g;
      $link_url =~ s/\$26/\&/g;
      $das_data{linkurl} = $link_url;
    }
    push @{$das_data{enable}}, $script;
    push @{$das_data{mapping}} , split(/\,/, $das_data{type});
    $das_data{conftype} = 'external';
    $das_data{type} = 'mixed' if (scalar(@{$das_data{mapping}} > 1));

    if ($das_data{active}) {
      $config->set("managed_extdas_$das_name", 'on', 'on', 1);

      $das_data{depth} and $config->set( "managed_extdas_$das_name", "dep", $das_data{depth}, 1);
      $das_data{group} and $config->set( "managed_extdas_$das_name", "group", $das_data{group}, 1);
      $das_data{strand} and $config->set( "managed_extdas_$das_name", "str", $das_data{strand}, 1);
      $das_data{stylesheet} and $config->set( "managed_extdas_$das_name", "stylesheet", $das_data{stylesheet}, 1);
      $das_data{labelflag} or $das_data{labelflag} = 'u';
      $config->set( "managed_extdas_$das_name", "lflag", $das_data{labelflag}, 1);
      $config->set( "managed_extdas_$das_name", "manager", 'das', 1);
      $das_data{color} and $config->set( "managed_extdas_$das_name", "col", $das_data{col}, 1);
      $das_data{linktext} and $config->set( "managed_extdas_$das_name", "linktext", $das_data{linktext}, 1);
      $das_data{linkurl} and $config->set( "managed_extdas_$das_name", "linkurl", $das_data{linkurl}, 1);
    }

    $ext_das->add_das_source(\%das_data);
  }


  foreach my $source (grep {$_ } CGI::param('das_sources')) {
    $config->set("managed_extdas_$source", 'on', 'on', 1);
  }
  $config->save;

  my $ds2 = $ext_das->{'data'};

  my %das_list = map {(exists $ds2->{$_}->{'species'} && $ds2->{$_}->{'species'} ne $self->{'species'}) ? ():($_,$ds2->{$_}) } keys %$ds2;
  my $EXT = $self->{config}->{species_defs}->ENSEMBL_INTERNAL_DAS_SOURCES;

  foreach my $source ( sort { $EXT->{$a}->{'label'} cmp $EXT->{$b}->{'label'} }  keys %$EXT ) {
# skip those that not configured for this view      
    my @valid_views = defined ($EXT->{$source}->{enable}) ? @{$EXT->{$source}->{enable}} : (defined($EXT->{$source}->{on}) ? @{$EXT->{$source}->{on}} : []);
    next if (! grep {$_ eq $script} @valid_views);

    if (my @select_views = defined ($EXT->{$source}->{select}) ? @{$EXT->{$source}->{select}} : ()) {
      if (grep {$_ eq $script} @select_views) {
        my $c = $self->{config};   
        if ( ! defined($c->get("managed_$source", "on"))) {
          $c->set("managed_$source", "on", "on", 1);
        }
      }
    }

    $self->add_checkbox( "managed_$source", $EXT->{$source}->{'label'} || $source );
  }

  foreach my $source ( sort { $das_list{$a}->{'label'} cmp $das_list{$b}->{'label'} } keys %das_list ) {
# skip those that not configured for this view      
    my @valid_views = defined ($das_list{$source}->{enable}) ? @{$das_list{$source}->{enable}} : (defined($das_list{$source}->{on}) ? @{$das_list{$source}->{on}} : []);
    next if (! grep {$_ eq $script} @valid_views);
    my $c = $self->{config};
    $self->add_checkbox( "managed_extdas_$source", $das_list{$source}->{'label'} || $source );
#   warn("$source:".$c->get("managed_extdas_$source", 'on').':'.Dumper($das_list{$source}));
  }


  my $URL = sprintf qq(/%s/dasconfview?conf_script=%s;%s), $self->{'species'}, $script, $self->{'LINK'};
  $self->add_link( "Manage sources...", qq(javascript:X=window.open('$URL','das_sources','left=10,top=10,resizable,scrollbars=yes');X.focus()), '');

  $URL = sprintf qq(/%s/%s?%sscript=%s), $self->{'species'}, 'urlsource', $self->{'LINK'}, $script;
  $self->add_link( "URL based data...",  qq(javascript:X=window.open('$URL','urlsources','left=10,top=10,scrollbars=yes');X.focus()),'');

  return $self;
}

1;
