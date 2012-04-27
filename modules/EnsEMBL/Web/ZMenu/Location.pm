# $Id$

package EnsEMBL::Web::ZMenu::Location;

use strict;

use base qw(EnsEMBL::Web::ZMenu);

sub content {
  my $self           = shift;
  my $hub            = $self->hub;
  my $species_defs   = $hub->species_defs;
  my $species        = $hub->species;
  my $r              = $hub->param('r');
  my $alt_assembly   = $hub->param('assembly'); # code for alternative assembly
  my $alt_clone      = $hub->param('jump_loc'); # code for alternative clones
  my $class          = $hub->param('class');    # code for patch regions
  my $target         = $hub->param('target');   # code for patch regions - compare patch with reference
  my $threshold      = 1000100 * ($species_defs->ENSEMBL_GENOME_SIZE||1);
  my $this_assembly  = $species_defs->ASSEMBLY_NAME;
  my ($chr, $loc)    = split ':', $r;
  my ($start, $stop) = split '-', $loc;
  my $action         = $hub->action || 'View';
     $action         = 'Overview' if $stop - $start + 1 > $threshold && $action eq 'View'; # go to Overview if region too large for View
  my $url            = $hub->url({ type => 'Location', action => $action });
  my ($caption, $link_title);
  
  if ($alt_assembly) {
    my $l = $hub->param('new_r');
    $caption = "$alt_assembly:$l";
    
    if ($this_assembly =~ /VEGA/) {
      $link_title = 'Jump to Ensembl';
      $url        = sprintf '%s%s/%s/%s?r=%s', $species_defs->ENSEMBL_EXTERNAL_URLS->{'ENSEMBL'}, $species, 'Location', $action, $l;
    } elsif ($alt_assembly =~ /VEGA/) {
      $link_title = 'Jump to VEGA';
      $url        = sprintf '%s%s/%s/%s?r=%s', $species_defs->ENSEMBL_EXTERNAL_URLS->{'VEGA'}, $species, 'Location', $action, $l;
    } else {
      # TODO: put URL to the latest archive site showing the other assembly (from mapping_session table)
    }
    
    $self->add_entry({ label => "Assembly: $alt_assembly" });
  } elsif ($alt_clone) { 
    my $status = $hub->param('status');
    ($caption) = split ':', $alt_clone;
    
    if ($this_assembly =~ /VEGA/) {
      $link_title = 'Jump to Ensembl';
      $url        = sprintf '%s%s/%s/%s?r=%s', $species_defs->ENSEMBL_EXTERNAL_URLS->{'ENSEMBL'}, $species, 'Location', $action, $alt_clone;
    } else {
      $link_title = 'Jump to Vega';
      $url        = sprintf '%s%s/%s/%s?r=%s', $species_defs->ENSEMBL_EXTERNAL_URLS->{'VEGA'}, $species, 'Location', $action, $alt_clone;
    }
    
    $status =~ s/_clone/ version/g;
    
    $self->add_entry({ label => "Status: $status" });
  } elsif ($class && $class =~ /^patch/) {
    my $db_adaptor  = $hub->database('core');
    my $slice       = $db_adaptor->get_SliceAdaptor->fetch_by_region('chromosome', $chr);
    my $projections = $db_adaptor->get_CoordSystemAdaptor->fetch_by_name('supercontig') ? $slice->project('supercontig') : [];
    my $synonym;
       $synonym .= $_->name . ', ' for map @{$_->to_Slice->get_all_synonyms}, @$projections;
    
    if ($synonym =~ /^\w/) {
      $synonym =~ s/,\s$//;
      $self->add_entry({ label => "Synonyms: $synonym" });
    }
  }
  
  $self->caption($caption || $r);
  $self->add_entry({ label => $link_title || $r, link => $url });
  
  if ($target) {
    $self->add_entry({
      label => 'Compare with ' . (grep($chr eq $_, @{$species_defs->ENSEMBL_CHROMOSOMES}) ? $hub->param('target_type') eq 'HAP' ? 'haplotype' : 'patch' : 'reference'),
      link  => $hub->url({
        action   => 'Multi',
        function => undef,
        r        => $r,
        s1       => "$species--$target" 
      })
    });
  }
}

1;
