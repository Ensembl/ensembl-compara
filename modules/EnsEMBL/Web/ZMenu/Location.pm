# $Id$

package EnsEMBL::Web::ZMenu::Location;

use strict;

use base qw(EnsEMBL::Web::ZMenu);

sub content {
  my $self = shift;
  
  my $object        = $self->object;
  my $species       = $object->species;
  my $action        = $object->action || 'View';
  my $r             = $object->param('r');
  my $alt_assembly  = $object->param('assembly'); # code for alternative assembly
  my $alt_clone     = $object->param('jump_loc'); # code for alternative clones
  my $threshold     = 1000100 * ($object->species_defs->ENSEMBL_GENOME_SIZE||1);
  my $this_assembly = $object->species_defs->ASSEMBLY_NAME;
  my ($chr, $loc)   = split ':', $r;
  my ($start,$stop) = split '-', $loc;

  # go to Overview if region too large for View
  $action = 'Overview' if ($stop - $start + 1 > $threshold) && $action eq 'View';
  
  my $url = $object->_url({
    type   => 'Location',
    action => $action
  });
  
  my ($caption, $link_title);
  
  if ($alt_assembly) { 
    my $l = $object->param('new_r');
    
    $caption = $alt_assembly . ':' . $l;
    
    if ($this_assembly =~ /VEGA/) {
      $url = sprintf '%s%s/%s/%s?r=%s', $self->object->species_defs->ENSEMBL_EXTERNAL_URLS->{'ENSEMBL'}, $species, 'Location', $action, $l;
      $link_title = 'Jump to Ensembl';
    } elsif ($alt_assembly =~ /VEGA/) {
      $url = sprintf '%s%s/%s/%s?r=%s', $self->object->species_defs->ENSEMBL_EXTERNAL_URLS->{'VEGA'}, $species, 'Location', $action, $l;
      $link_title = 'Jump to VEGA';
    } else {
      # TODO: put URL to the latest archive site showing the other assembly (from mapping_session table)
    }
    
    $self->add_entry({ 
      label => "Assembly: $alt_assembly"
    });
  } elsif ($alt_clone) { 
    my $status = $object->param('status');
    
    ($caption) = split ':', $alt_clone;
    
    if ($this_assembly eq 'VEGA') {
      $link_title = 'Jump to Ensembl';
      $url = sprintf '%s%s/%s/%s?r=%s', $object->species_defs->ENSEMBL_EXTERNAL_URLS->{'ENSEMBL'}, $species, 'Location', $action, $alt_clone;
    } else {
      $link_title = 'Jump to Vega';
      $url = sprintf '%s%s/%s/%s?r=%s', $object->species_defs->ENSEMBL_EXTERNAL_URLS->{'VEGA'}, $species, 'Location', $action, $alt_clone;
    }
    
    $status =~ s/_clone/ version/g;
    
    $self->add_entry({
      label => "Status: $status"
    });
  }
  
  $self->caption($caption || $r);
  
  $self->add_entry({
    label => $link_title || $r,
    link  => $url
  });
}

1;
