# $Id$

package EnsEMBL::Web::Command::UserData::AttachRemote;

use strict;

use EnsEMBL::Web::Tools::Misc qw(get_url_filesize);
use EnsEMBL::Web::Root;

use base qw(EnsEMBL::Web::Command);

sub process {
  my $self     = shift;
  my $hub      = $self->hub;
  my $format = $hub->param('format');;

  ## Has a file format been supplied?
  if (!$format) {
    ## Try to guess format from file name
    my @path = split '/', $hub->param('url');
    my $filename = $path[-1];
    my @bits = split /\./, $filename;
    my $extension = $bits[-1] eq 'gz' ? $bits[-2] : $bits[-1];
    $format = uc($extension);
  }

  my $class = 'EnsEMBL::Web::Command::UserData::Attach';
  
  my @remote_formats = @{$hub->species_defs->USERDATA_REMOTE_FORMATS};

  my $remote = grep(/^$format$/, @remote_formats) ? $format : 'URL';
  $class .= $remote;

  if ($self->dynamic_use($class)) {
    my $module = $class->new({
            object => $self->object,
            hub    => $hub,
            page   => $self->page,
            node   => $self->node
          });

    $module->process;
  }
}

1;
