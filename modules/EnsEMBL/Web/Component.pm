package EnsEMBL::Web::Component;

use strict;
use Data::Dumper;
$Data::Dumper::Indent = 3;
use EnsEMBL::Web::File::Text;
use Exporter;
use EnsEMBL::Web::Document::SpreadSheet;

use base qw(EnsEMBL::Web::Root Exporter);
our @EXPORT_OK = qw(cache cache_print);
our @EXPORT    = @EXPORT_OK;

sub image_width {
  my $self = shift;

  return $self->object->param('image_width')||800;
}
sub new {
  my( $class, $object ) = shift;
  my $self = {
    'object' => shift,
  };
  bless $self,$class;
  $self->_init();
  return $self;
}

sub object {
  my $self = shift;
  $self->{'object'} = shift if @_;
  return $self->{'object'};
}

sub cacheable {
  my $self = shift;
  $self->{'cacheable'} = shift if @_;
  return $self->{'cacheable'};
}

sub ajaxable {
  my $self = shift;
  $self->{'ajaxable'} = shift if @_;
  return $self->{'ajaxable'};
}

sub configurable {
  my $self = shift;
  $self->{'configurable'} = shift if @_;
  return $self->{'configurable'};
}

sub cache_key {
  return undef;
}

sub _init {
  return;
}

sub caption {
  return undef;
}
sub cache {
  my( $panel, $obj, $type, $name ) = @_;
  my $cache = new EnsEMBL::Web::File::Text( $obj->species_defs );
  $cache->set_cache_filename( $type, $name );
  return $cache;
}

sub cache_print {
  my( $cache, $string_ref ) =@_;
  $cache->print( $$string_ref ) if $string_ref;
}

sub site_name {
  my $self = shift;
  our $sitename = $SiteDefs::ENSEMBL_SITETYPE eq 'EnsEMBL' ? 'Ensembl' : $SiteDefs::ENSEMBL_SITETYPE;
  return $sitename;
}

sub pretty_date {
### Converts a MySQL datestamp into something human-readable
  my ($self, $datetime) = @_;
  my ($date, $time) = split(' ', $datetime);
  my ($year, $mon, $day) = split('-', $date);
  my ($hour, $min, $sec) = split(':', $date);

  my @months = ('', 'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August',
                'September', 'October', 'November', 'December');

  $day =~ s/^0//;
  return $day.' '.$months[$mon].' '.$year;
}

=pod
sub message {
  ### Displays a message (e.g. error) from the Controller::Command module
  my ($panel, $object) = @_;
  my $command = $panel->{command};

  my $html;
  if ($command) { 
    if ( $command->get_message) {
      $html = $command->get_message;
    }
    else {
      $html = '<p>'.$command->filters->message.'</p>';
    }
  }
  else {
    $html = '<p>Unknown error</p>';
  }
  $panel->print($html);
}
=cut

1;
